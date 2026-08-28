local serverConfig = require("config.server")
local debug = require("shared.debug")

OnCall = {}

-- [source] = { onCall = true, pendingOffer = { missionId, expiresAt } | nil, nextPageAt, declineStreak }
-- In-memory only, same precedent as Missions' activeDeliveryState — on-call is a live
-- session concept, not something that needs to survive a resource restart or reconnect.
local state = {}

local function hasDeployedOwnedVehicle(source)
    local player = Player.GetData(source)
    if not player then return false end
    return #DB.GetDeployedVehicles(player.identifier) > 0
end

function OnCall.IsOnCall(source)
    local s = state[source]
    return s ~= nil and s.onCall == true
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

-- Player-initiated toggle (Dashboard Overview tab). Turning on re-checks the same
-- "deployed vehicle" precondition every time — never trusts that a prior check (e.g. the
-- client's own button state) still holds, per ground rule 4.
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

    if not Vehicles.IsRentalActive(source) and not hasDeployedOwnedVehicle(source) then
        local owned = DB.GetOwnedVehicles(player.identifier)
        if #owned == 0 then
            return { ok = false, reason = "needs_rental" }
        end
        return { ok = false, reason = "no_deployed_vehicle" }
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
    if #DB.GetOwnedVehicles(player.identifier) > 0 then
        return { ok = false, reason = "owned_vehicle_exists" }
    end

    Vehicles.StartRental(source, nil, true)
    OnCall.ForceOnAfterRentalSpawn(source)

    debug.DebugPrint(("OnCall.StartStandaloneRental: %s started a standalone rental"):format(player.identifier))

    return { ok = true, onCall = true, rental = serverConfig.RentalTruck }
end

-- Confirmed with user: storing your on-call vehicle auto-cancels on-call rather than
-- leaving it "on" with nothing deployed for the scheduler to page.
function OnCall.HandleVehicleStored(source)
    local s = state[source]
    if not s or not s.onCall then return end

    state[source] = nil
    TriggerClientEvent("polarix_towjob:onCallStateUpdate", source, { onCall = false })
    TriggerClientEvent("polarix_towjob:notify", source, "You stored your tow truck — you're off-call.", "info")
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

    local usedRental = Vehicles.IsRentalActive(source)
    local result = Missions.AcceptViaOnCall(source, offer.missionId, usedRental)

    if result.ok then
        s.pendingOffer = nil
        s.declineStreak = 0
        if usedRental then
            Vehicles.SetRentalDeliveryId(source, result.deliveryId)
        end
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
