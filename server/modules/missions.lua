local serverConfig = require("config.server")
local debug = require("shared.debug")

Missions = {}

function Missions.SeedIfEmpty()
    if (DB.GetMissionCount() or 0) > 0 then return end

    local seeds = serverConfig.SeedMissions
    if not seeds or #seeds == 0 then
        debug.DebugPrint("Missions.SeedIfEmpty: no SeedMissions configured, skipping")
        return
    end

    for _, mission in ipairs(seeds) do
        DB.InsertMission(mission)
    end

    debug.DebugPrint(("Missions.SeedIfEmpty: seeded %d mission(s)"):format(#seeds))
end

-- Grouped by area for the Available Jobs tab; sorting (reward/xp/distance/difficulty)
-- happens client-side (Step 5.4), this only filters by level + unlocked areas and
-- attaches a server-computed distance so the client can't spoof its own position.
function Missions.GetAvailableForPlayer(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))

    local groups = {}
    local groupIndex = {}

    for _, row in ipairs(DB.GetActiveMissionsWithAreas() or {}) do
        if row.level_required <= player.level and unlockedAreaIds[row.area_id] then
            local group = groupIndex[row.area_id]
            if not group then
                group = { area_id = row.area_id, area_name = row.area_name, region = row.area_region, missions = {} }
                groupIndex[row.area_id] = group
                groups[#groups + 1] = group
            end

            local searchCenter = vector3(row.search_center_x, row.search_center_y, row.search_center_z)

            group.missions[#group.missions + 1] = {
                id = row.id,
                name = row.name,
                vehicle_label = row.vehicle_label,
                vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or nil,
                reward_base = row.reward_base,
                xp_base = row.xp_base,
                difficulty = row.difficulty,
                time_limit_minutes = row.time_limit_minutes,
                level_required = row.level_required,
                distance = math.floor(#(playerCoords - searchCenter) + 0.5),
            }
        end
    end

    return groups
end

-- Tracks, per source, the target vehicle's net-id against the delivery that's
-- currently active for them — reported by the client once it spawns the target
-- vehicle (Step 8.2.3). In-memory only (net-ids are session-scoped handles, not
-- something that belongs in the `deliveries` table). Phase 9 (attach validation)
-- and Phase 10 (damage tracking) are the intended readers via Missions.GetActiveDeliveryState.
local activeDeliveryState = {} -- [source] = { deliveryId, targetNetId }

RegisterNetEvent("polarix_towjob:setTargetVehicle", function(deliveryId, netId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    activeDeliveryState[source] = { deliveryId = deliveryId, targetNetId = netId }
end)

function Missions.GetActiveDeliveryState(source)
    return activeDeliveryState[source]
end

Framework.OnPlayerUnload(function(source)
    activeDeliveryState[source] = nil
end)

-- Step 8.1: validates and starts a delivery. Vehicle assignment follows the
-- ownership rules from Phase 7's design-decision table:
--   0 owned            -> rental auto-used
--   1 owned (stored)    -> that vehicle auto-parked-out and spawned
--   2+ owned            -> client keeps the Dashboard open; player must Park Out
--                          one themselves (Vehicle.ContinueAfterParkOut on the client
--                          picks the delivery back up once that succeeds)
-- Edge case (not spelled out in the plan): a player's only/all owned vehicles are
-- currently `deployed` (left un-stored from an earlier session/standalone Park Out).
-- There's no "reuse the already-deployed entity" path since the client has no
-- guarantee that entity still exists — reject with `no_stored_vehicle` and let the
-- player store it via the parking zone first, same as any other stuck state.
function Missions.Accept(source, missionId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end

    local row = DB.GetMission(missionId)
    if not row then
        return { ok = false, reason = "mission_not_found" }
    end

    if row.level_required > player.level then
        return { ok = false, reason = "level_too_low" }
    end

    local area = DB.GetArea(row.area_id)
    if not area then
        return { ok = false, reason = "mission_not_found" }
    end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end
    if not unlockedAreaIds[row.area_id] then
        return { ok = false, reason = "area_locked" }
    end

    local owned = DB.GetOwnedVehicles(player.identifier)
    local storedCount = 0
    for _, vehicle in ipairs(owned) do
        if vehicle.state == "stored" then storedCount = storedCount + 1 end
    end

    if #owned > 0 and storedCount == 0 then
        return { ok = false, reason = "no_stored_vehicle" }
    end

    local mission = {
        id = row.id,
        name = row.name,
        vehicle_model = row.vehicle_model,
        vehicle_label = row.vehicle_label,
        vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or nil,
        search_center = { x = row.search_center_x, y = row.search_center_y, z = row.search_center_z },
        search_radius = row.search_radius,
        dropoff = { x = row.dropoff_x, y = row.dropoff_y, z = row.dropoff_z, heading = row.dropoff_heading },
        dropoff_width = row.dropoff_width,
        dropoff_length = row.dropoff_length,
        reward_base = row.reward_base,
        xp_base = row.xp_base,
        time_limit_minutes = row.time_limit_minutes,
    }

    local usedRental = #owned == 0
    local deliveryId = DB.CreateDelivery(missionId, player.identifier, usedRental)

    local response = { ok = true, deliveryId = deliveryId, mission = mission }

    if usedRental then
        response.usedRental = true
        response.rental = serverConfig.RentalTruck
        Vehicles.StartRental(source, deliveryId)
    elseif #owned == 1 then
        local parkResult = Vehicles.ParkOut(source, owned[1].id)
        if not parkResult.ok then
            DB.FailDelivery(deliveryId)
            return { ok = false, reason = parkResult.reason }
        end
        response.vehicle = parkResult.vehicle
    else
        response.needsParkOut = true
    end

    debug.DebugPrint(("Missions.Accept: %s accepted mission %s (delivery %d)"):format(player.identifier, missionId, deliveryId))

    return response
end
