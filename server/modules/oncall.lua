local serverConfig = require("config.server")
local debug = require("shared.debug")

OnCall = {}

-- [source] = { onCall = true, pendingOffer = { missionId, expiresAt } | nil, nextPageAt, declineStreak }
-- In-memory only, same precedent as Missions' activeDeliveryState — on-call is a live
-- session concept, not something that needs to survive a resource restart or reconnect.
local state = {}

-- Survives going off-call, so toggling on-call can't reset the decline streak or skip the wait
-- a decline earned. [source] = { declineStreak, nextPageAt }
local carried = {}

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

local function stashCooldown(source)
    local s = state[source]
    if s then carried[source] = { declineStreak = s.declineStreak, nextPageAt = s.nextPageAt } end
end

local function startOnCall(source)
    local previous = carried[source]
    state[source] = { onCall = true, pendingOffer = nil, declineStreak = previous and previous.declineStreak or 0 }
    scheduleNextPage(source, { fast = true })

    if previous and previous.nextPageAt and previous.nextPageAt > state[source].nextPageAt then
        state[source].nextPageAt = previous.nextPageAt
    end
end

-- Player-initiated toggle (Dashboard Overview tab). On-call is decoupled from having a
-- truck deployed — the pager accept path (Missions.Accept) parks a stored truck out or
-- spawns a rental when a job is taken. Only requirement: a way to tow at all, i.e. owning
-- at least one truck or an active rental; zero of both routes through the rental prompt.
function OnCall.SetOnCall(source, wantOn)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if not wantOn then
        local s = state[source]
        -- An unanswered offer counts as a decline, otherwise going off-call would be a free re-roll.
        if s and s.pendingOffer then
            TriggerClientEvent("polarix_towjob:pagerOfferCleared", source)
            OnCall.DeclineOffer(source)
        end

        stashCooldown(source)
        state[source] = nil
        return { ok = true, onCall = false }
    end

    if state[source] and state[source].onCall then
        return { ok = true, onCall = true }
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

    startOnCall(source)

    return { ok = true, onCall = true }
end

-- Called once OnCall.StartStandaloneRental's rental spawn succeeds — the vehicle is
-- deployed at that point, so this skips SetOnCall's own gate checks rather than re-running
-- a second round-trip of the same checks against state we just established ourselves.
function OnCall.ForceOnAfterRentalSpawn(source)
    startOnCall(source)
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

    local started, reason = Vehicles.StartRental(source, nil, true)
    if not started then return { ok = false, reason = reason } end

    OnCall.ForceOnAfterRentalSpawn(source)

    debug.DebugPrint(("OnCall.StartStandaloneRental: %s started a standalone rental"):format(player.identifier))

    return { ok = true, onCall = true, rental = serverConfig.RentalTruck }
end

-- Called by Priority.Mark: a police request queue-jumps the pager but doesn't page anyone
-- instantly, so this only caps how long an idle operator's next page can still be away.
-- Resolution is the scheduler's 10s tick, which is plenty for a ~45s cap.
function OnCall.PullInPages(maxWaitSeconds)
    local cap = os.time() + (maxWaitSeconds or 45)

    for source, s in pairs(state) do
        if s.onCall and not s.pendingOffer and s.nextPageAt and s.nextPageAt > cap then
            local player = Player.GetData(source)
            if player and not DB.GetActiveDelivery(player.identifier) then
                s.nextPageAt = cap
            end
        end
    end
end

function OnCall.HandleRentalRepossessed(source)
    if not state[source] then return end
    stashCooldown(source)
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
    elseif Priority.IsPriorityId(offer.missionId) then
        -- Accept refused it (target gone, no truck available, ...) — drop the offer lock so
        -- the request can reach somebody else instead of sitting on this player.
        Priority.OnOfferFailed(source, offer.missionId)
    end

    return result
end

-- Also the timeout path (the scheduler thread below calls this identically for an expired
-- offer, per the confirmed design: "timeout behaves like an explicit decline").
function OnCall.DeclineOffer(source)
    local s = state[source]
    if not s or not s.pendingOffer then return { ok = false, reason = "no_offer" } end

    if Priority.IsPriorityId(s.pendingOffer.missionId) then
        Priority.OnOfferDeclined(source, s.pendingOffer.missionId)
    end

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
    offer.expiresIn = serverConfig.PagerOfferTimeoutSeconds
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
                        -- Police requests queue-jump: the player's next page serves the oldest
                        -- open one instead of a random template.
                        local offer = Priority.TakeNextFor(source) or Missions.PickRandomForPager(source)
                        if offer then
                            local expiresAt = now + serverConfig.PagerOfferTimeoutSeconds
                            s.pendingOffer = { missionId = offer.id, expiresAt = expiresAt }
                            offer.expiresIn = serverConfig.PagerOfferTimeoutSeconds
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
    local s = state[source]
    if s and s.pendingOffer and Priority.IsPriorityId(s.pendingOffer.missionId) then
        Priority.OnOfferFailed(source, s.pendingOffer.missionId)
    end

    state[source] = nil
    carried[source] = nil
end)
