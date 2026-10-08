local serverConfig = require("config.server")
local debug = require("shared.debug")
local Locale = require("shared.locale")
local Money = require("shared.currency")

Missions = {}

-- Priority jobs live in memory with the same row shape, so resolve missions through here instead of DB.GetMission.
local function getMissionRow(missionId, includeInactive)
    if Priority and Priority.IsPriorityId(missionId) then
        return Priority.GetJobRow(missionId)
    end

    if includeInactive then return DB.GetMissionIncludingInactive(missionId) end

    return DB.GetMission(missionId)
end

-- Level/area filter shared by the pager pick and Missions.Accept.
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

-- Reward/xp before multipliers for one spawn point. The picked point is only known after the client spawns, so pager/editor show the range.
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

-- Spawn-point reservations by deliveryId, so a second player is never sent to an occupied point. Released on complete/fail/abort/unload.
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

-- Hint circle is offset 35-70% of its radius from the spawn point, rolled server-side so the client can't shortcut to the true spot.
local function rollHintCenter(point, radius)
    local angle = math.random() * 2 * math.pi
    local distance = radius * (0.35 + math.random() * 0.35)

    return {
        x = point.x + math.cos(angle) * distance,
        y = point.y + math.sin(angle) * distance,
        z = point.z,
    }
end

-- Falls back to the unfiltered list if all spots are reserved. Several candidates are sent because the client skips blocked spots; each has its own hint center.
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
        -- Sent down so the client preview matches the server tolerance (client scripts can't require server config). Read through Settings so admin edits apply.
        dropoff_heading_tolerance = Settings.GetDeliveryHeadingTolerance(),
        reward_base = row.reward_base,
        xp_base = row.xp_base,
        time_limit_minutes = row.time_limit_minutes,
    }
end

-- deadlineAt is stamped server-side at accept time.
local activeDeliveryState = {} -- [source] = { deliveryId, targetNetId, found, deadlineAt, bodyHealthBaseline, engineHealthBaseline }

-- Accept/Complete/Abort yield on DB awaits; one in-flight call per source prevents double payout and double active deliveries.
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

-- Target is trusted only once the netId resolves to the mission's vehicle model at the spawn point it names; otherwise the delivery ends without penalty. Not used for priority jobs.
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

-- Re-checks distance against the tracked entity before trusting the claim; a claim arriving while the target is pending waits for it.
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

function Missions.IsTargetNetId(netId)
    if not netId then return false end

    for _, state in pairs(activeDeliveryState) do
        if state.targetNetId == netId then return true end
    end

    return false
end

-- Re-confirms a tracked entity server-side for client events and the sweep. seenKey flips once the netId has resolved, so an unresolvable id only counts as gone after being seen alive.
-- "destroyed" and "gone" stay apart: a priority target can vanish through no fault of the operator, a wreck is still a failure.
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

-- The client reports destruction fast; the sweep below is the backstop for disconnect/crash.
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

-- No-penalty end for a target that stopped being towable (priority car cleaned up or moved, unverifiable spawn). Stored as status aborted but recorded as "cancelled", which counts against nothing.
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

-- Shared fail path: timeout, destruction, missed rental payment.
function Missions.Fail(source, deliveryId, reason)
    if busy[source] then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    if state.isTest then
        DB.DeleteDelivery(deliveryId)
    else
        DB.FailDelivery(deliveryId)
    end

    -- A destroyed truck can't stay rented: tear the rental down so the player isn't billed for it.
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

-- Server is the sole authority on deadlines (deadlineAt); a 5s sweep is enough.
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
                -- A priority target can be cleaned up or stored by its owner with the operator nowhere near; that ends the job without a failure.
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

    -- Claimed requests are only swept via delivery state, which is gone: return it to the pool.
    if state and state.isPriority and state.missionId then
        Priority.OnDeliveryEnded(state.missionId, source, "disconnected")
    end
end)

-- Single accept path (pager and admin test run). Vehicle assignment:
--   truck already deployed / rental already active -> reused as-is, no spawn
--   0 owned, no rental                             -> rental auto-used and spawned
--   exactly 1 owned, stored                        -> auto-parked-out and spawned
--   2+ owned, none deployed                        -> needsParkOut: client keeps the
--        Dashboard open, player Parks Out one (Vehicle.ContinueAfterParkOut resumes it)
-- isTest is never client-controlled; only AdminMissions.TestRun passes it: skips level/area gates and leaves no trace (no payout, XP, stats, history, rental charge).
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

    -- Police dispatch skips level/area gates; inherits the donor mission's area for multipliers.
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
        -- Nothing is spawned: the client adopts the existing entity.
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

    -- Before anything is created: no truck means a rental, with its first payment up front.
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

    -- Candidates stay held until the client reports which one it used (setTargetVehicle). Priority jobs reserve nothing.
    local reserved = {}
    for i, candidate in ipairs(spawnCandidates or {}) do
        reserved[i] = vector3(candidate.point.x, candidate.point.y, candidate.point.z)
    end
    reservedSpawnPoints[deliveryId] = reserved

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

    -- Undo when the vehicle can't be provided; a claimed priority request returns to the queue.
    local function rollback(reason)
        if isTest then DB.DeleteDelivery(deliveryId) else DB.FailDelivery(deliveryId) end
        activeDeliveryState[source] = nil
        releaseSpawnPoints(deliveryId)
        if isPriority then Priority.OnDeliveryEnded(missionId, source, "accept_failed") end

        return { ok = false, reason = reason }
    end

    -- Time left, not a timestamp: the client clock may differ.
    local response = { ok = true, deliveryId = deliveryId, mission = mission, secondsRemaining = mission.time_limit_minutes and mission.time_limit_minutes * 60 or nil }

    if rentalActive then
        Vehicles.SetRentalDeliveryId(source, deliveryId)
        response.usedRental = true
    elseif deployedCount > 0 then
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

-- Rotates coords into the dropoff rectangle's frame and checks position bounds and heading tolerance. Authoritative copy of the client preview.
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

-- Damage penalty and placement are computed/validated server-side, never from client-reported numbers.
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

    -- Area multipliers stack multiplicatively with the global Settings ones; neutral 1.0 if the area was deactivated/deleted.
    local missionArea = DB.GetArea(mission.area_id)
    local areaRewardMultiplier = missionArea and tonumber(missionArea.reward_multiplier) or 1.0
    local areaXpMultiplier = missionArea and tonumber(missionArea.xp_multiplier) or 1.0

    -- Global reward_multiplier applies to reward_base first (cap included).
    local rewardBase, xpBase = mission.reward_base, mission.xp_base
    if state.spawnCoords then
        rewardBase, xpBase = payoutAt(mission, state.spawnCoords)
    end

    local effectiveRewardBase = rewardBase * Settings.GetRewardMultiplier() * areaRewardMultiplier

    -- Cap is a fraction of the multiplier-adjusted reward_base, independent of the player's payout_bonus.
    local cap = math.floor(effectiveRewardBase * Settings.GetDamagePenaltyCapPercent())
    damagePenalty = math.min(damagePenalty, cap)

    -- Economy bonus applies before the damage penalty so it isn't eaten by the cap.
    local payoutBonus = Skills.GetPayoutBonus(source)
    local bonusedReward = math.floor(effectiveRewardBase * (1 + payoutBonus) + 0.5)

    local rewardPaid = math.max(0, bonusedReward - damagePenalty)
    local xpPaid = math.floor(xpBase * Settings.GetXpMultiplier() * areaXpMultiplier + 0.5)

    Framework.AddMoney(source, rewardPaid)

    DB.CompleteDelivery(deliveryId, rewardPaid, xpPaid, damagePenalty)

    -- Impound event/write, officer cut, drop from pool. The client deletes the entity on deliveryEnded.
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

-- Admin test runs end here whatever the cause: row dropped, nothing paid or counted.
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

    -- A still-valid request returns to the queue; the car is still where it was called in.
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
