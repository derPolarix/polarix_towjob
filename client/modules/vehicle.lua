local debug = require("shared.debug")

Vehicle = {}

-- Set once Accept returns `needsParkOut` (2+ owned tow trucks) — the delivery row
-- already exists server-side at this point, we're just waiting for the player to
-- Park Out a truck (Phase 7's VehiclesTab action) before spawning the target vehicle.
local pendingMission = nil

local function randomPointInRadius(center, radius)
    local angle = math.random() * 2 * math.pi
    local dist = math.sqrt(math.random()) * radius
    return vector3(center.x + math.cos(angle) * dist, center.y + math.sin(angle) * dist, center.z)
end

local function spawnTargetVehicle(mission)
    lib.requestModel(mission.vehicle_model)

    local point = randomPointInRadius(mission.search_center, mission.search_radius)
    local heading = math.random(0, 359) * 1.0
    local entity = CreateVehicle(mission.vehicle_model, point.x, point.y, point.z, heading, true, false)
    SetModelAsNoLongerNeeded(mission.vehicle_model)
    SetVehicleOnGroundProperly(entity)

    if mission.vehicle_colors then
        SetVehicleColours(entity, mission.vehicle_colors.primary, mission.vehicle_colors.secondary)
    end

    debug.DebugPrint("Vehicle.spawnTargetVehicle: spawned", mission.vehicle_model, "at", point.x, point.y, point.z)

    return entity
end

local function createSearchBlip(center, radius)
    local id = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipColour(id, 5)
    SetBlipAlpha(id, 128)
    return id
end

-- Client-side delivery state Phase 9 will build the Active Delivery UI/attach logic
-- on top of — deliberately not inventing a Phase 9 NUI message contract here, since
-- that view/store don't exist yet and would likely be replaced once they do.
local currentDelivery = nil

local function beginDelivery(deliveryId, mission)
    local targetVehicle = spawnTargetVehicle(mission)
    local netId = NetworkGetNetworkIdFromEntity(targetVehicle)
    TriggerServerEvent("polarix_towjob:setTargetVehicle", deliveryId, netId)

    local blip = createSearchBlip(mission.search_center, mission.search_radius)

    currentDelivery = {
        deliveryId = deliveryId,
        mission = mission,
        targetVehicle = targetVehicle,
        targetNetId = netId,
        blip = blip,
    }

    Framework.Notify(("New tow job: %s"):format(mission.name), "info")
end

function Vehicle.AcceptMission(missionId)
    local result = lib.callback.await("polarix_towjob:acceptMission", false, missionId)
    if not result then
        return { ok = false, reason = "no_response" }
    end

    if not result.ok then
        return result
    end

    if result.needsParkOut then
        pendingMission = { deliveryId = result.deliveryId, mission = result.mission }
        return result
    end

    if result.usedRental then
        Garage.SpawnRental(result.rental)
    elseif result.vehicle then
        Garage.SpawnVehicle(result.vehicle)
    end

    beginDelivery(result.deliveryId, result.mission)

    return result
end

-- Called after a successful `parkOutVehicle` NUI callback (client/nui/nui_callbacks.lua)
-- to pick the delivery back up once the player has parked out a truck themselves.
-- Returns true if a pending mission was actually resumed, so the caller knows
-- whether to close the Dashboard.
function Vehicle.ContinueAfterParkOut()
    if not pendingMission then return false end

    local mission = pendingMission
    pendingMission = nil
    beginDelivery(mission.deliveryId, mission.mission)

    return true
end
