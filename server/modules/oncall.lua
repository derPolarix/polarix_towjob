local serverConfig = require("config.server")
local debug = require("shared.debug")

OnCall = {}

-- [source] = { onCall = true, pendingOffer = { missionId, expiresAt } | nil, nextPageAt, declineStreak }
-- In-memory only, same precedent as Missions' activeDeliveryState — on-call is a live
-- session concept, not something that needs to survive a resource restart or reconnect.
local state = {}

function OnCall.IsOnCall(source)
    local s = state[source]
    return s ~= nil and s.onCall == true
end

-- An admin who never set up (or deactivated all) missions leaves every player on-call
-- forever with nothing to receive, so going on-call is refused outright in that state.
-- Deliberately server-wide, not per-player: a player whose level/unlocked areas happen to
-- match nothing right now still goes on-call, and the scheduler below keeps retrying.
local function hasPlayableMissions()
    return (DB.GetActiveMissionCount() or 0) > 0
end

-- opts = { fast = bool, extraDelaySeconds = number } — `fast` picks the short post-accept window.
local function scheduleNextPage(source, opts)
    local s = state[source]
    if not s then return end

    opts = opts or {}
    local delaySeconds
    if opts.fast then
        delaySeconds = math.random(serverConfig.PagerPostAcceptMinSeconds, serverConfig.PagerPostAcceptMaxSeconds)
    else
        delaySeconds = math.random(serverConfig.PagerMinIntervalMinutes * 60, serverConfig.PagerMaxIntervalMinutes * 60)
    end

    s.nextPageAt = os.time() + delaySeconds + (opts.extraDelaySeconds or 0)
    debug.DebugPrint(("OnCall.scheduleNextPage: %s next page in %ds (fast=%s)"):format(source, s.nextPageAt - os.time(), tostring(opts.fast == true)))
end

-- Player-initiated toggle (Dashboard Overview tab). On-call is decoupled from having a
-- truck deployed — the pager accept path (Missions.Accept) parks a stored truck out or
-- spawns a rental when a job is taken. Only requirement: a way to tow at all, i.e. owning
-- at least one truck or an active rental; zero of both routes through the rental prompt.
function OnCall.SetOnCall(source, wantOn)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if not wantOn then
        state[source] = nil
        return { ok = true, onCall = false }
    end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end

    -- Checked before needs_rental so a truckless player isn't sold a rental on a server that
    -- can never page them anything.
    if not hasPlayableMissions() then
        return { ok = false, reason = "no_missions_configured" }
    end

    if not Vehicles.IsRentalActive(source) and #DB.GetOwnedVehicles(player.identifier) == 0 then
        return { ok = false, reason = "needs_rental" }
    end

    state[source] = { onCall = true, pendingOffer = nil, declineStreak = 0 }
    scheduleNextPage(source, { fast = true })

    return { ok = true, onCall = true }
end

-- Called once OnCall.StartStandaloneRental's rental spawn succeeds — the vehicle is
-- deployed at that point, so this skips SetOnCall's own gate checks rather than re-running
-- a second round-trip of the same checks against state we just established ourselves.
function OnCall.ForceOnAfterRentalSpawn(source)
    state[source] = { onCall = true, pendingOffer = nil, declineStreak = 0 }
    scheduleNextPage(source, { fast = true })
end

-- Confirmed with user: a zero-owned-vehicle player going on-call gets prompted (client-side
-- RentalPromptModal) to rent instead of being told to go buy a truck first — rentals here are
-- standalone (no deliveryId yet), unlike the delivery-scoped rental Missions.Accept spawns
-- for the Admin "Test mission" bypass path.
function OnCall.StartStandaloneRental(source)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end
    if Vehicles.IsRentalActive(source) then
        return { ok = false, reason = "already_renting" }
    end
    if not hasPlayableMissions() then
        return { ok = false, reason = "no_missions_configured" }
    end
    if #DB.GetOwnedVehicles(player.identifier) > 0 then
        return { ok = false, reason = "owned_vehicle_exists" }
    end

    Vehicles.StartRental(source, nil, true)
    OnCall.ForceOnAfterRentalSpawn(source)

    debug.DebugPrint(("OnCall.StartStandaloneRental: %s started a standalone rental"):format(player.identifier))

    return { ok = true, onCall = true, rental = serverConfig.RentalTruck }
end

function OnCall.HandleRentalRepossessed(source)
    if not state[source] then return end
    state[source] = nil
    TriggerClientEvent("polarix_towjob:onCallStateUpdate", source, { onCall = false })
end

-- Called from Missions.Complete/Fail/Abort right after activeDeliveryState is cleared for
-- this source — re-arms the scheduler for the next page now that the player is free again.
function OnCall.HandleDeliveryEnded(source)
    local s = state[source]
    if not s or not s.onCall then return end

    s.pendingOffer = nil
    scheduleNextPage(source, { fast = true })
end

function OnCall.AcceptOffer(source)
    local s = state[source]
    if not s or not s.onCall or not s.pendingOffer then
        return { ok = false, reason = "no_offer" }
    end

    local offer = s.pendingOffer
    if os.time() > offer.expiresAt then
        return { ok = false, reason = "offer_expired" }
    end

    -- Missions.Accept does the full vehicle provisioning: reuse a deployed truck or active
    -- rental as-is, auto-park-out the one stored truck, spawn a rental for a truckless
    -- player, or ask a 2+-truck player to pick one (needsParkOut).
    local result = Missions.Accept(source, offer.missionId)

    if result.ok then
        s.pendingOffer = nil
        s.declineStreak = 0
    end

    return result
end

-- Also the timeout path (the scheduler thread below calls this identically for an expired
-- offer, per the confirmed design: "timeout behaves like an explicit decline").
function OnCall.DeclineOffer(source)
    local s = state[source]
    if not s or not s.pendingOffer then return { ok = false, reason = "no_offer" } end

    s.pendingOffer = nil
    s.declineStreak = (s.declineStreak or 0) + 1
    scheduleNextPage(source, { extraDelaySeconds = serverConfig.PagerDeclineCooldownMinutes * 60 * s.declineStreak })

    return { ok = true }
end

-- Debug-only test helper, invoked by /towjobtestpage (server/commands.lua, itself gated on
-- config.shared.Debug and admin-only). Bypasses the random scheduler: picks one eligible
-- mission right now and pages it. Puts the player on-call if they weren't, since receiving a
-- page has no meaning off-call and Accept needs a live state entry to resolve against.
function OnCall.DebugSendTestPage(source)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end

    local offer = Missions.PickRandomForPager(source)
    if not offer then return { ok = false, reason = "no_eligible_mission" } end

    local s = state[source]
    if not s or not s.onCall then
        s = { onCall = true, pendingOffer = nil, declineStreak = 0 }
        state[source] = s
        TriggerClientEvent("polarix_towjob:onCallStateUpdate", source, { onCall = true })
    end

    local expiresAt = os.time() + serverConfig.PagerOfferTimeoutSeconds
    s.pendingOffer = { missionId = offer.id, expiresAt = expiresAt }
    offer.expiresAt = expiresAt
    TriggerClientEvent("polarix_towjob:pagerOffer", source, offer)

    debug.DebugPrint(("OnCall.DebugSendTestPage: paged %s mission %s (%s)"):format(source, offer.id, offer.name))
    return { ok = true, name = offer.name }
end

-- Ticks every on-call player: sweeps an expired pending offer (treated as a decline) and
-- offers a fresh page to anyone who's due, clear (no active delivery), and not already
-- waiting on an offer. A 10s resolution is plenty for minute-scale pager timing.
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()

        for source, s in pairs(state) do
            if s.onCall then
                if s.pendingOffer then
                    if now > s.pendingOffer.expiresAt then
                        TriggerClientEvent("polarix_towjob:pagerOfferCleared", source)
                        OnCall.DeclineOffer(source)
                    end
                elseif s.nextPageAt and now >= s.nextPageAt then
                    local player = Player.GetData(source)
                    if player and not DB.GetActiveDelivery(player.identifier) then
                        local offer = Missions.PickRandomForPager(source)
                        if offer then
                            local expiresAt = now + serverConfig.PagerOfferTimeoutSeconds
                            s.pendingOffer = { missionId = offer.id, expiresAt = expiresAt }
                            offer.expiresAt = expiresAt
                            TriggerClientEvent("polarix_towjob:pagerOffer", source, offer)
                        else
                            -- Nothing eligible right now (all done/leveled past/areas locked) —
                            -- retry soon rather than going quiet indefinitely.
                            scheduleNextPage(source, { fast = true, extraDelaySeconds = 30 })
                        end
                    end
                end
            end
        end
    end
end)

Framework.OnPlayerUnload(function(source)
    state[source] = nil
end)
