local serverConfig = require("config.server")
local debug = require("shared.debug")
local Locale = require("shared.locale")
local Money = require("shared.currency")

Missions = {}

-- Priority jobs (server/modules/priority.lua) live in memory, never in the missions table,
-- but carry the same row shape — so every accept/complete path resolves a mission through
-- here instead of calling DB.GetMission directly.
local function getMissionRow(missionId, includeInactive)
    if Priority and Priority.IsPriorityId(missionId) then
        return Priority.GetJobRow(missionId)
    end

    if includeInactive then return DB.GetMissionIncludingInactive(missionId) end

    return DB.GetMission(missionId)
end

-- Level/area-eligibility filter shared by the pager's random pick below and (inline)
-- Missions.Accept's own gate check — replaces the old Available Jobs list query
-- (Missions.GetAvailableForPlayer) now that jobs are paged rather than browsed.
local function getEligibleMissionRows(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end

    local levelReduction = Skills.GetLevelRequirementReduction(source)
    local eligible = {}

    for _, row in ipairs(DB.GetActiveMissionsWithAreas() or {}) do
        local effectiveLevelRequired = math.max(1, row.level_required - levelReduction)
        if effectiveLevelRequired <= player.level and unlockedAreaIds[row.area_id] then
            eligible[#eligible + 1] = row
        end
    end

    return eligible
end

local function distanceKm(from, row)
    return #(vector3(from.x, from.y, from.z) - vector3(row.dropoff_x, row.dropoff_y, row.dropoff_z)) / 1000.0
end

local function distanceBonus(perKm, km)
    return math.floor((perKm or 0) * km + 0.5)
end

-- Reward/xp before any multiplier, for one spawn point. The picked point is only known once
-- the client spawns the target, so the pager and editor show the range over every point.
local function payoutAt(row, point)
    local km = distanceKm(point, row)
    return row.reward_base + distanceBonus(row.reward_per_km, km), row.xp_base + distanceBonus(row.xp_per_km, km)
end

local function payoutRange(row)
    local points = row.spawn_points and json.decode(row.spawn_points) or {}
    local minReward, maxReward, minXp, maxXp = row.reward_base, row.reward_base, row.xp_base, row.xp_base

    for i, point in ipairs(points) do
        local reward, xp = payoutAt(row, point)
        if i == 1 then
            minReward, maxReward, minXp, maxXp = reward, reward, xp, xp
        else
            minReward, maxReward = math.min(minReward, reward), math.max(maxReward, reward)
            minXp, maxXp = math.min(minXp, xp), math.max(maxXp, xp)
        end
    end

    return minReward, maxReward, minXp, maxXp
end

local lastPagedMissionId = {} -- [source] = id of the mission paged last

-- Called by the on-call scheduler (server/modules/oncall.lua) to pick one job to page.
-- Deliberately no `distance`/exact coords here — the old Available Jobs payload already
-- didn't send raw search/dropoff coords, and a pager offer sends even less (no client-side
-- distance calc to spoof-check against, since there's no list to sort by it anymore).
function Missions.PickRandomForPager(source)
    local eligible = getEligibleMissionRows(source)
    if #eligible == 0 then return nil end

    -- Never the same job twice in a row, unless it is the only one left.
    if #eligible > 1 then
        for i, candidate in ipairs(eligible) do
            if candidate.id == lastPagedMissionId[source] then
                table.remove(eligible, i)
                break
            end
        end
    end

    local row = eligible[math.random(1, #eligible)]
    lastPagedMissionId[source] = row.id
    local minReward, maxReward, minXp, maxXp = payoutRange(row)

    return {
        id = row.id,
        name = row.name,
        vehicle_label = row.vehicle_label,
        difficulty = row.difficulty,
        reward_base = minReward,
        reward_max = maxReward,
        xp_base = minXp,
        xp_max = maxXp,
        time_limit_minutes = row.time_limit_minutes,
        level_required = row.level_required,
        area_name = row.area_name,
    }
end

-- Spawn-point reservations, keyed by deliveryId: every active delivery holds the spots it
-- was handed, so a second player is never sent to a point a target vehicle already occupies.
-- Released on complete/fail/abort/unload.
local reservedSpawnPoints = {}

local function releaseSpawnPoints(deliveryId)
    reservedSpawnPoints[deliveryId] = nil
end

local function isSpawnPointReserved(point)
    local minDistance = serverConfig.SpawnPointReservationDistance or 8.0
    local coords = vector3(point.x, point.y, point.z)

    for _, points in pairs(reservedSpawnPoints) do
        for _, reserved in ipairs(points) do
            if #(coords - reserved) <= minDistance then return true end
        end
    end

    return false
end

-- The search-hint circle is deliberately not centered on the spawn point — it's offset by a
-- random 35-70% of its own radius, so the point stays inside the circle but never dead-center.
-- Rolled server-side (one per candidate) so the client can't shortcut back to the true spot.
local function rollHintCenter(point, radius)
    local angle = math.random() * 2 * math.pi
    local distance = radius * (0.35 + math.random() * 0.35)

    return {
        x = point.x + math.cos(angle) * distance,
        y = point.y + math.sin(angle) * distance,
        z = point.z,
    }
end

-- Picks the spots one delivery may use. Reserved spots are filtered out first; if that leaves
-- nothing, the unfiltered list is used anyway rather than refusing an otherwise valid job.
-- More than one candidate is sent because the client falls through to the next spot when one
-- is physically blocked (see client/modules/vehicle.lua) — each carries its own hint center so
-- the circle still contains the car after a fallback.
local function buildSpawnCandidates(row)
    local points = row.spawn_points and json.decode(row.spawn_points) or {}
    if #points == 0 then return nil end

    local pool = {}
    for _, point in ipairs(points) do
        if not isSpawnPointReserved(point) then pool[#pool + 1] = point end
    end
    if #pool == 0 then
        for _, point in ipairs(points) do pool[#pool + 1] = point end
    end

    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local radius = Settings.GetSearchHintRadius()
    local candidates = {}

    for i = 1, math.min(#pool, serverConfig.SpawnPointCandidates or 3) do
        local point = pool[i]
        candidates[i] = {
            point = { x = point.x, y = point.y, z = point.z, heading = point.heading or 0.0 },
            hint = rollHintCenter(point, radius),
        }
    end

    return candidates, radius
end

-- Client-safe mission payload handed to the find/tow/deliver loop on accept.
local function buildMissionPayload(row)
    return {
        id = row.id,
        name = row.name,
        vehicle_model = row.vehicle_model,
        vehicle_label = row.vehicle_label,
        vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or nil,
        dropoff = { x = row.dropoff_x, y = row.dropoff_y, z = row.dropoff_z, heading = row.dropoff_heading },
        dropoff_width = row.dropoff_width,
        dropoff_length = row.dropoff_length,
        -- Sent down so the client's live placement preview (Step 10.2) stays in sync with the
        -- server's own authoritative tolerance (Missions.Complete) without requiring server-only
        -- config from client code (client_scripts can't require() a server_scripts-only file).
        -- Reads through Settings so a Phase 13 admin edit is reflected on the next accept.
        dropoff_heading_tolerance = Settings.GetDeliveryHeadingTolerance(),
        reward_base = row.reward_base,
        xp_base = row.xp_base,
        time_limit_minutes = row.time_limit_minutes,
    }
end

-- In-memory per-source delivery state. `deadlineAt` is server-stamped at accept time, never
-- derived from anything client-reported.
local activeDeliveryState = {} -- [source] = { deliveryId, targetNetId, found, deadlineAt, bodyHealthBaseline, engineHealthBaseline }

-- Accept/Complete/Abort yield on DB awaits, so two concurrent calls from one player would both
-- pass their state checks (double payout, two active deliveries). One in-flight call per source.
local busy = {}

local function exclusive(fn)
    return function(source, ...)
        if busy[source] then return { ok = false, reason = "busy" } end

        busy[source] = true
        local ok, result = pcall(fn, source, ...)
        busy[source] = nil

        if not ok then error(result, 0) end
        return result
    end
end

-- The target is trusted only once the entity behind the reported netId is the mission's vehicle
-- model standing at the spawn point it names; anything else ends the delivery without penalty.
-- Registered once, and never for a priority job (its target is fixed server-side at accept).
RegisterNetEvent("polarix_towjob:setTargetVehicle", function(deliveryId, netId, pointIndex)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end
    if state.isPriority or state.targetNetId or state.targetPending then return end

    state.targetPending = true

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        state.targetPending = nil
        return
    end

    local mission = getMissionRow(state.missionId, true)
    local reserved = reservedSpawnPoints[deliveryId]
    local spawnPoint = type(pointIndex) == "number" and reserved and reserved[pointIndex] or nil

    local entity = mission and spawnPoint and Vehicles.AwaitEntity(netId, function(candidate)
        return GetEntityModel(candidate) == GetHashKey(mission.vehicle_model)
            and #(GetEntityCoords(candidate) - spawnPoint) <= serverConfig.SpawnPointVerifyDistance
    end)

    if activeDeliveryState[source] ~= state then return end
    state.targetPending = nil

    if not entity then
        debug.Warn(("Missions.setTargetVehicle: rejected target for delivery %s from source %s"):format(tostring(deliveryId), source))
        Missions.Cancel(source, deliveryId, "target_invalid")
        return
    end

    -- The client reports which candidate it actually spawned at (it skips blocked spots), so
    -- the ones it didn't use are freed for other players.
    state.targetNetId = netId
    state.spawnCoords = spawnPoint
    reservedSpawnPoints[deliveryId] = { spawnPoint }
end)

-- Client reports reaching the target; server re-checks the distance against the tracked
-- entity before trusting it (ground rule 4). The target is only set once verified, so a claim
-- that arrives while that is still pending waits for it.
RegisterNetEvent("polarix_towjob:vehicleFound", function(deliveryId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or state.found then return end

    for _ = 1, 20 do
        if state.targetNetId or activeDeliveryState[source] ~= state then break end
        Wait(200)
    end

    if state.found or activeDeliveryState[source] ~= state or not state.targetNetId then return end

    local entity = NetworkGetEntityFromNetworkId(state.targetNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(entity)) > serverConfig.VehicleFoundMaxDistance then
        debug.Warn("Missions.vehicleFound: rejected out-of-range claim for source", source)
        return
    end

    state.bodyHealthBaseline = GetVehicleBodyHealth(entity)
    state.engineHealthBaseline = GetVehicleEngineHealth(entity)
    state.found = true

    debug.DebugPrint(("Missions.vehicleFound: delivery %d found for %s"):format(deliveryId, player.identifier))
end)

function Missions.GetActiveDeliveryState(source)
    return activeDeliveryState[source]
end

-- Used by Priority.Mark to refuse marking a car that is already somebody's tow target.
function Missions.IsTargetNetId(netId)
    if not netId then return false end

    for _, state in pairs(activeDeliveryState) do
        if state.targetNetId == netId then return true end
    end

    return false
end

-- Re-confirms a tracked delivery entity server-side (ground rule 4) for both the
-- client-reported events and the periodic sweep backstop. `seenKey` flips true the first
-- time the netId resolves to a live entity, so an unresolvable netId only counts as
-- gone once we've actually seen it alive — never in the tick-or-two before the client's
-- CreateVehicle propagates to the server.
-- "destroyed" and "gone" are kept apart because a priority job's target is a real player
-- vehicle that can be cleaned up through no fault of the operator (Priority's no-penalty
-- cancel), where a wrecked one is still a failed delivery.
local function trackedEntityStatus(state, netId, seenKey)
    if not netId then return "alive" end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        state[seenKey] = true
        -- IsEntityDead is client-only; server-side a destroyed vehicle reports entity health 0.
        return GetEntityHealth(entity) <= 0 and "destroyed" or "alive"
    end

    return state[seenKey] == true and "gone" or "alive"
end

local function isDeliveryVehicleDestroyed(state)
    return trackedEntityStatus(state, state.targetNetId, "targetSeen") ~= "alive"
end

local function isTowTruckDestroyed(state)
    return trackedEntityStatus(state, state.truckNetId, "truckSeen") ~= "alive"
end

-- Step 10.1: client-side damage.lua detects destruction fast (for responsiveness) and
-- reports it here; the sweep thread below is the backstop for a client that never gets
-- to report (disconnect/crash at the moment of destruction).
RegisterNetEvent("polarix_towjob:reportVehicleDestroyed", function(deliveryId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    local status = trackedEntityStatus(state, state.targetNetId, "targetSeen")
    if status == "alive" then
        debug.Warn("Missions.reportVehicleDestroyed: rejected unverified destruction claim for source", source)
        return
    end

    if status == "gone" and state.isPriority then
        Missions.Cancel(source, deliveryId, "target_gone")
        return
    end

    Missions.Fail(source, deliveryId, "vehicle_destroyed")
end)

-- Client reports the tow truck the delivery is being run with (rental or owned) — netId is
-- tracked so the destruction re-check below and the sweep can verify server-side.
RegisterNetEvent("polarix_towjob:setTowTruck", function(deliveryId, netId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    state.truckNetId = netId
end)

RegisterNetEvent("polarix_towjob:reportTowTruckDestroyed", function(deliveryId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    if not isTowTruckDestroyed(state) then
        debug.Warn("Missions.reportTowTruckDestroyed: rejected unverified destruction claim for source", source)
        return
    end

    Missions.Fail(source, deliveryId, "truck_destroyed")
end)

-- No-penalty end for a delivery whose target stopped being towable through no fault of the
-- operator: a priority job's real player vehicle got cleaned up or driven off, or a spawned
-- target could not be verified. Uses the delivery row's `aborted` status (there is no separate
-- enum value) but deliberately records a "cancelled" outcome, which
-- Player.RecordDeliveryOutcome counts against nothing.
function Missions.Cancel(source, deliveryId, reason)
    if busy[source] then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    if state.isTest then
        DB.DeleteDelivery(deliveryId)
    else
        DB.CancelDelivery(deliveryId)
    end
    Vehicles.OnDeliveryEnded(source)

    local missionId = state.missionId
    activeDeliveryState[source] = nil
    releaseSpawnPoints(deliveryId)
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "cancelled")

    if missionId then Priority.OnDeliveryEnded(missionId, source, reason) end

    local messageKeys = {
        target_moved = "notify.cancel_target_left_scene",
        target_gone = "notify.cancel_target_gone",
        target_invalid = "notify.spawn_failed",
    }
    TriggerClientEvent("polarix_towjob:notify", source, Locale(messageKeys[reason] or "notify.cancel_target_gone"), "error")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "cancelled")

    debug.DebugPrint(("Missions.Cancel: delivery %d cancelled for source %s (%s)"):format(deliveryId, source, reason))
end

-- Shared fail path — called for timed-mission expiry (Step 9.3), vehicle destruction
-- (Step 10.1) and missed rental payments (server/modules/vehicles.lua), so the
-- delivery-row/notify/cleanup/counter sequence only lives in one place.
function Missions.Fail(source, deliveryId, reason)
    if busy[source] then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    if state.isTest then
        DB.DeleteDelivery(deliveryId)
    else
        DB.FailDelivery(deliveryId)
    end

    -- A destroyed tow truck can't keep being rented — tear the rental down (and pull the
    -- wreck) rather than leaving the player billed for a truck that no longer exists. For a
    -- delivery run on the rental, that truck IS the rental (see Missions.Accept's reuse rule).
    if reason == "truck_destroyed" and Vehicles.IsRentalActive(source) then
        Vehicles.StopRental(source)
        TriggerClientEvent("polarix_towjob:repossessRental", source)
    else
        if reason == "truck_destroyed" then
            Vehicles.HandleOwnedTruckDestroyed(source, state.truckNetId)
        end
        Vehicles.OnDeliveryEnded(source)
    end

    activeDeliveryState[source] = nil
    releaseSpawnPoints(deliveryId)
    OnCall.HandleDeliveryEnded(source)

    if not state.isTest then Player.RecordDeliveryOutcome(source, "failed") end

    if state.isPriority and state.missionId then
        Priority.OnDeliveryEnded(state.missionId, source, reason)
    end

    local messageKeys = {
        time_limit_exceeded = "notify.fail_time_limit",
        vehicle_destroyed = "notify.fail_vehicle_destroyed",
        truck_destroyed = "notify.fail_truck_destroyed",
        rental_repossessed = "notify.fail_rental_repossessed",
    }
    TriggerClientEvent("polarix_towjob:notify", source, Locale(messageKeys[reason] or "notify.delivery_failed"), "error")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "failed")

    debug.DebugPrint(("Missions.Fail: delivery %d failed for source %s (%s)"):format(deliveryId, source, reason))
end

-- Step 9.3: server is the sole authority on timed-mission expiry — `deadlineAt` is
-- stamped once at accept time (see Missions.Accept) and never re-derived from anything
-- client-reported. A lightweight 5s sweep is enough; these are minute-scale deadlines.
CreateThread(function()
    while true do
        Wait(5000)

        local now = os.time()
        for source, state in pairs(activeDeliveryState) do
            local targetStatus = trackedEntityStatus(state, state.targetNetId, "targetSeen")

            if state.deadlineAt and now >= state.deadlineAt then
                Missions.Fail(source, state.deliveryId, "time_limit_exceeded")
            elseif targetStatus == "destroyed" then
                Missions.Fail(source, state.deliveryId, "vehicle_destroyed")
            elseif targetStatus == "gone" then
                -- A priority target is a real player vehicle: it can be cleaned up or stored
                -- by its owner with the operator nowhere near it, so that ends the job without
                -- a failure on their record.
                if state.isPriority then
                    Missions.Cancel(source, state.deliveryId, "target_gone")
                else
                    Missions.Fail(source, state.deliveryId, "vehicle_destroyed")
                end
            elseif state.isPriority and (Priority.GetTargetDrift(state.missionId) or 0) > (serverConfig.PriorityAbandonDistance or 150.0) then
                Missions.Cancel(source, state.deliveryId, "target_moved")
            elseif isTowTruckDestroyed(state) then
                Missions.Fail(source, state.deliveryId, "truck_destroyed")
            end
        end
    end
end)

Framework.OnPlayerUnload(function(source)
    lastPagedMissionId[source] = nil
    local state = activeDeliveryState[source]
    if state then releaseSpawnPoints(state.deliveryId) end
    activeDeliveryState[source] = nil

    -- A claimed request is only swept through its delivery state, which is gone now: hand it
    -- back to the pool like any other operator-side ending, or it would stay claimed forever.
    if state and state.isPriority and state.missionId then
        Priority.OnDeliveryEnded(state.missionId, source, "disconnected")
    end
end)

-- Validates and starts a delivery — the single accept path, shared by the on-call pager
-- (OnCall.AcceptOffer) and the Phase 13 admin "Test mission" button. Vehicle assignment:
--   truck already deployed / rental already active -> reused as-is, no spawn
--   0 owned, no rental                             -> rental auto-used and spawned
--   exactly 1 owned, stored                        -> auto-parked-out and spawned
--   2+ owned, none deployed                        -> needsParkOut: client keeps the
--        Dashboard open, player Parks Out one (Vehicle.ContinueAfterParkOut resumes it)
-- `isTest` is never client-controlled — only AdminMissions.TestRun (which re-checks
-- Framework.IsAdmin itself) passes true: it skips the level/area-lock gates and the run
-- leaves no trace (no payout, XP, stats, history row or rental charge).
local function accept(source, missionId, isTest)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end

    local row = getMissionRow(missionId)
    if not row then
        return { ok = false, reason = "mission_not_found" }
    end

    -- A police dispatch is an emergency call, not a farmable template: it skips the level and
    -- area-unlock gates (confirmed design) and only inherits its donor mission's area so the
    -- area reward/xp multipliers still apply.
    local isPriority = row.is_priority == true

    local effectiveLevelRequired = math.max(1, row.level_required - Skills.GetLevelRequirementReduction(source))
    if not isTest and not isPriority and effectiveLevelRequired > player.level then
        return { ok = false, reason = "level_too_low" }
    end

    local area = DB.GetArea(row.area_id)
    if not area and not isPriority then
        return { ok = false, reason = "mission_not_found" }
    end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end
    if not isTest and not isPriority and not unlockedAreaIds[row.area_id] then
        return { ok = false, reason = "area_locked" }
    end

    local spawnCandidates, searchHintRadius, priorityTarget

    if isPriority then
        -- Nothing is spawned: the target already exists in the world, so the client adopts
        -- the tracked entity instead (client/modules/vehicle.lua).
        priorityTarget = Priority.PrepareTarget(missionId)
        if not priorityTarget then
            return { ok = false, reason = "priority_target_gone" }
        end
    else
        spawnCandidates, searchHintRadius = buildSpawnCandidates(row)
        if not spawnCandidates then
            return { ok = false, reason = "no_spawn_points" }
        end
    end

    local owned = DB.GetOwnedVehicles(player.identifier)
    local storedCount, deployedCount = 0, 0
    local firstStored = nil
    for _, vehicle in ipairs(owned) do
        if vehicle.state == "stored" then
            storedCount = storedCount + 1
            firstStored = firstStored or vehicle
        elseif vehicle.state == "deployed" then
            deployedCount = deployedCount + 1
        end
    end

    local rentalActive = Vehicles.IsRentalActive(source)

    -- Checked before anything is created: no truck of their own means a rental, and its first
    -- payment is taken up front.
    if not rentalActive and deployedCount == 0 and #owned == 0 and not isTest and not Vehicles.CanAffordRental(source) then
        return { ok = false, reason = "insufficient_funds" }
    end

    local mission = buildMissionPayload(row)
    mission.is_test = isTest == true

    if isPriority then
        mission.is_priority = true
        mission.target_net_id = priorityTarget.netId
        mission.search_hint = priorityTarget.hint
        mission.search_hint_radius = priorityTarget.radius
    else
        mission.spawn_candidates = spawnCandidates
        mission.search_hint_radius = searchHintRadius
    end

    local usedRental = rentalActive or #owned == 0
    local deliveryId = DB.CreateDelivery(missionId, player.identifier, usedRental, row.name, isTest)

    -- Every candidate is held until the client reports which one it used (setTargetVehicle),
    -- so a concurrent accept can't be handed a spot this delivery may still spawn at.
    -- Priority jobs reserve nothing: their target is already standing where it stands.
    local reserved = {}
    for i, candidate in ipairs(spawnCandidates or {}) do
        reserved[i] = vector3(candidate.point.x, candidate.point.y, candidate.point.z)
    end
    reservedSpawnPoints[deliveryId] = reserved

    -- Server is the sole authority on the deadline, stamped here at accept time.
    local deadlineAt = mission.time_limit_minutes and (os.time() + mission.time_limit_minutes * 60) or nil
    activeDeliveryState[source] = {
        deliveryId = deliveryId,
        missionId = missionId,
        deadlineAt = deadlineAt,
        isPriority = isPriority,
        isTest = isTest == true,
        targetNetId = isPriority and priorityTarget.netId or nil,
    }

    if isPriority then Priority.OnClaimed(missionId, source, deliveryId) end

    -- Undoes everything above when the vehicle for the job can't be provided; a claimed priority
    -- request goes back to the queue instead of staying claimed by a delivery that never started.
    local function rollback(reason)
        if isTest then DB.DeleteDelivery(deliveryId) else DB.FailDelivery(deliveryId) end
        activeDeliveryState[source] = nil
        releaseSpawnPoints(deliveryId)
        if isPriority then Priority.OnDeliveryEnded(missionId, source, "accept_failed") end

        return { ok = false, reason = reason }
    end

    -- Time left rather than the timestamp: the client's own clock need not match the server's.
    local response = { ok = true, deliveryId = deliveryId, mission = mission, secondsRemaining = mission.time_limit_minutes and mission.time_limit_minutes * 60 or nil }

    if rentalActive then
        -- Standalone on-call rental already out — reuse it, no spawn.
        Vehicles.SetRentalDeliveryId(source, deliveryId)
        response.usedRental = true
    elseif deployedCount > 0 then
        -- An owned truck is already out — reuse it, no spawn.
    elseif #owned == 0 then
        response.usedRental = true
        response.rental = serverConfig.RentalTruck
        local started, rentalReason = Vehicles.StartRental(source, deliveryId, false, isTest)
        if not started then return rollback(rentalReason) end
    elseif storedCount == 1 then
        local parkResult = Vehicles.ParkOut(source, firstStored.id)
        if not parkResult.ok then return rollback(parkResult.reason) end
        response.vehicle = parkResult.vehicle
    else
        response.needsParkOut = true
    end

    debug.DebugPrint(("Missions.Accept: %s accepted mission %s (delivery %d)"):format(player.identifier, missionId, deliveryId))

    return response
end

-- Used by polarix_towjob:openDashboard so the Dashboard can show an "active delivery"
-- banner with an Abort action (Step 10.4 — abort is Dashboard-only, no in-world trigger).
function Missions.GetActiveDeliverySummary(source)
    local player = Player.GetData(source)
    if not player then return nil end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery then return nil end

    local mission = getMissionRow(delivery.mission_id, true)
    return {
        deliveryId = delivery.id,
        missionName = (mission and mission.name) or delivery.mission_name or Locale("misc.unknown_job"),
        isPriority = Priority.IsPriorityId(delivery.mission_id),
    }
end

-- Rotates `coords` into the dropoff rectangle's local frame (heading-aligned) and checks
-- both the position bound (mission's own dropoff_width/dropoff_length) and the heading
-- tolerance (config.server.DeliveryHeadingTolerance). Mirrors the client-side preview in
-- client/modules/delivery.lua — that copy is display-only, this one is authoritative.
local function isWithinDropoffZone(mission, coords, heading)
    local center = vector3(mission.dropoff_x, mission.dropoff_y, mission.dropoff_z)
    local rad = math.rad(mission.dropoff_heading or 0.0)
    local lengthDir = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local widthDir = vector3(math.cos(rad), math.sin(rad), 0.0)

    local delta = coords - center
    local projLength = delta.x * lengthDir.x + delta.y * lengthDir.y
    local projWidth = delta.x * widthDir.x + delta.y * widthDir.y

    if math.abs(projLength) > (mission.dropoff_length or 10.0) / 2 then return false end
    if math.abs(projWidth) > (mission.dropoff_width or 6.0) / 2 then return false end

    local headingDiff = (heading - (mission.dropoff_heading or 0.0)) % 360.0
    if headingDiff > 180.0 then headingDiff = 360.0 - headingDiff end

    return headingDiff <= Settings.GetDeliveryHeadingTolerance()
end

-- Server computes the damage penalty from health it reads off the tracked entity (baseline
-- from the vehicleFound handler), and re-validates the towed vehicle's position/heading
-- against the dropoff rectangle — never trusts a client-reported number for either.
local function complete(source, deliveryId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        return { ok = false, reason = "no_active_delivery" }
    end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or not state.found then
        return { ok = false, reason = "vehicle_not_found_yet" }
    end

    local mission = getMissionRow(delivery.mission_id, true)
    if not mission then return { ok = false, reason = "mission_not_found" } end

    local target = state.targetNetId and NetworkGetEntityFromNetworkId(state.targetNetId)
    if not target or target == 0 or not DoesEntityExist(target) then
        return { ok = false, reason = "vehicle_missing" }
    end

    local vehicleCoords = GetEntityCoords(target)
    local vehicleHeading = GetEntityHeading(target)
    if #(GetEntityCoords(GetPlayerPed(source)) - vehicleCoords) > serverConfig.CompletionMaxDistance then
        return { ok = false, reason = "too_far" }
    end

    if not isWithinDropoffZone(mission, vehicleCoords, vehicleHeading) then
        return { ok = false, reason = "not_in_zone" }
    end

    if state.isTest then
        return Missions.FinishTest(source, deliveryId, "completed")
    end

    local bodyLoss = math.max(0, (state.bodyHealthBaseline or 1000.0) - GetVehicleBodyHealth(target))
    local engineLoss = math.max(0, (state.engineHealthBaseline or 1000.0) - GetVehicleEngineHealth(target))

    local resistance = Vehicles.GetActiveTruckDamageResistance(source, player.identifier)
    local skillReduction = Skills.GetDamageReduction(source)

    local reductionFactor = math.max(0, 1 - resistance - skillReduction)
    local healthLoss = (bodyLoss + engineLoss) * reductionFactor

    local damagePenalty = math.floor(healthLoss * (serverConfig.DamagePenaltyPerHealthPoint or 0.5) + 0.5)

    -- Area reward/xp multipliers (polarix_towjob_areas) stack multiplicatively with the
    -- global Settings ones — same composition point as the comment below, so an area's
    -- modifier scales the whole economy proportionally too, not just the payout on top.
    -- Falls back to neutral 1.0 if the mission's area was deactivated/deleted since creation.
    local missionArea = DB.GetArea(mission.area_id)
    local areaRewardMultiplier = missionArea and tonumber(missionArea.reward_multiplier) or 1.0
    local areaXpMultiplier = missionArea and tonumber(missionArea.xp_multiplier) or 1.0

    -- Phase 13's global reward_multiplier is a base economy-tuning knob, applied to
    -- reward_base before anything else (cap included) so an admin's multiplier scales the
    -- mission's whole economy proportionally, not just the payout on top.
    local rewardBase, xpBase = mission.reward_base, mission.xp_base
    if state.spawnCoords then
        rewardBase, xpBase = payoutAt(mission, state.spawnCoords)
    end

    local effectiveRewardBase = rewardBase * Settings.GetRewardMultiplier() * areaRewardMultiplier

    -- Cap is always a fraction of the (multiplier-adjusted) reward_base, never the
    -- Economy-branch-bonused amount below — confirmed with user, keeps the cap
    -- independent of the player's own payout_bonus skill.
    local cap = math.floor(effectiveRewardBase * Settings.GetDamagePenaltyCapPercent())
    damagePenalty = math.min(damagePenalty, cap)

    -- Economy branch ("Fair Rates") bonuses the reward before the damage penalty is
    -- subtracted — confirmed with user — so the bonus is additive on top, not eaten by
    -- a damage-cap that also scales with it.
    local payoutBonus = Skills.GetPayoutBonus(source)
    local bonusedReward = math.floor(effectiveRewardBase * (1 + payoutBonus) + 0.5)

    local rewardPaid = math.max(0, bonusedReward - damagePenalty)
    local xpPaid = math.floor(xpBase * Settings.GetXpMultiplier() * areaXpMultiplier + 0.5)

    Framework.AddMoney(source, rewardPaid)

    DB.CompleteDelivery(deliveryId, rewardPaid, xpPaid, damagePenalty)

    -- Emits the impound event / framework write and pays the officer's cut, then drops the
    -- request from the pool. The client deletes the towed entity on `deliveryEnded`.
    if state.isPriority then
        Priority.OnDeliveryCompleted(delivery.mission_id, source, rewardPaid)
    end

    Vehicles.OnDeliveryEnded(source)
    activeDeliveryState[source] = nil
    releaseSpawnPoints(deliveryId)
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "completed", rewardPaid)
    Player.AddXP(source, xpPaid)

    local message = damagePenalty > 0
        and Locale("notify.delivery_complete_with_damage"):format(Money(rewardPaid), Money(damagePenalty), xpPaid)
        or Locale("notify.delivery_complete"):format(Money(rewardPaid), xpPaid)
    TriggerClientEvent("polarix_towjob:notify", source, message, "success")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "completed")

    debug.DebugPrint(("Missions.Complete: delivery %d completed for %s (reward %d, penalty %d)"):format(deliveryId, player.identifier, rewardPaid, damagePenalty))

    return { ok = true, reward = rewardPaid, xp = xpPaid, damagePenalty = damagePenalty }
end

-- Admin test runs end here whatever the cause: the delivery row is dropped instead of
-- marked, and nothing is paid or counted.
function Missions.FinishTest(source, deliveryId, outcome)
    DB.DeleteDelivery(deliveryId)
    Vehicles.OnDeliveryEnded(source)

    activeDeliveryState[source] = nil
    releaseSpawnPoints(deliveryId)
    OnCall.HandleDeliveryEnded(source)

    TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.test_ended"), "info")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, outcome)

    debug.DebugPrint(("Missions.FinishTest: test delivery %d ended for source %s (%s)"):format(deliveryId, source, outcome))

    return { ok = true, reward = 0, xp = 0, damagePenalty = 0 }
end

function Missions.IsTestActive(source)
    local state = activeDeliveryState[source]
    return state ~= nil and state.isTest == true
end

-- Step 10.4: player-initiated cancel, Dashboard-only (no in-world trigger — confirmed
-- with user). Detach/despawn of the target vehicle happens client-side via the same
-- `polarix_towjob:deliveryEnded` event Complete/Fail already use.
local function abort(source, deliveryId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        return { ok = false, reason = "no_active_delivery" }
    end

    local state = activeDeliveryState[source]
    if state and state.isTest then
        return Missions.FinishTest(source, deliveryId, "aborted")
    end

    DB.AbortDelivery(deliveryId)
    Vehicles.OnDeliveryEnded(source)

    activeDeliveryState[source] = nil
    releaseSpawnPoints(deliveryId)
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "aborted")

    -- A still-valid request goes back in the queue rather than dying with the abort — the
    -- car is sitting exactly where the officer called it in.
    if state and state.isPriority and state.missionId then
        Priority.OnDeliveryEnded(state.missionId, source, "aborted")
    end

    TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.delivery_aborted"), "info")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "aborted")

    debug.DebugPrint(("Missions.Abort: delivery %d aborted for %s"):format(deliveryId, player.identifier))

    return { ok = true }
end

Missions.Accept = exclusive(accept)
Missions.Complete = exclusive(complete)
Missions.Abort = exclusive(abort)
