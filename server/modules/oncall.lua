local serverConfig = require("config.server")
local debug = require("shared.debug")

OnCall = {}

-- In-memory. [source] = { onCall, pendingOffer = { missionId, expiresAt } | nil, nextPageAt, declineStreak }
local state = {}

-- Survives going off-call so toggling can't reset the decline wait. [source] = { declineStreak, nextPageAt }
local carried = {}

function OnCall.IsOnCall(source)
    local s = state[source]
    return s ~= nil and s.onCall == true
end

-- Refused when no active missions exist at all (server-wide, not per-player; the scheduler retries for players matching nothing).
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

-- Requires a way to tow: an owned truck or an active rental; with neither the rental prompt is shown.
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

-- Skips SetOnCall's gate checks: the rental spawn just established that state.
function OnCall.ForceOnAfterRentalSpawn(source)
    startOnCall(source)
end

-- Players with no owned vehicle are prompted to rent; this rental is standalone (no deliveryId), unlike the delivery-scoped admin test rental.
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

-- Police requests queue-jump the pager; this only caps how long an idle operator's next page can still be away.
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

    -- Missions.Accept provisions the vehicle (reuse, auto park-out, rental, or needsParkOut).
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

-- Also the timeout path: an expired offer behaves like a decline.
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

-- Debug helper for /towjobtestpage: pages one eligible mission now, going on-call first if needed.
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
                        -- Police requests queue-jump: serve the oldest open one.
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
