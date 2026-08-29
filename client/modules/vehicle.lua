local debug = require("shared.debug")
local clientConfig = require("config.client")

Vehicle = {}

local VEHICLE_FOUND_RADIUS = clientConfig.VehicleFoundRadius or 12.0

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
    local area = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipColour(area, 5)
    SetBlipAlpha(area, 128)

    local route = AddBlipForCoord(center.x, center.y, center.z)
    SetBlipSprite(route, 1)
    SetBlipColour(route, 5)
    SetBlipRoute(route, true)
    SetBlipRouteColour(route, 5)

    return area, route
end

local function createDropoffBlip(dropoff)
    local id = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
    SetBlipSprite(id, 477)
    SetBlipColour(id, 5)
    SetBlipRoute(id, true)
    SetBlipRouteColour(id, 5)
    return id
end

-- `state` is "searching" or "found". The player rigs and tows the vehicle with GTA's native
-- tow mechanics — reaching it is all the job tracks, there is no attach step.
local currentDelivery = nil

local function setupFoundDetection(entity)
    CreateThread(function()
        while currentDelivery and currentDelivery.targetVehicle == entity and DoesEntityExist(entity)
            and currentDelivery.state == "searching" do
            if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity)) <= VEHICLE_FOUND_RADIUS then
                currentDelivery.state = "found"

                if currentDelivery.blip then
                    RemoveBlip(currentDelivery.blip)
                    currentDelivery.blip = nil
                end
                if currentDelivery.searchRouteBlip then
                    RemoveBlip(currentDelivery.searchRouteBlip)
                    currentDelivery.searchRouteBlip = nil
                end
                currentDelivery.dropoffBlip = createDropoffBlip(currentDelivery.mission.dropoff)

                TriggerServerEvent("polarix_towjob:vehicleFound", currentDelivery.deliveryId)
                Framework.Notify("Vehicle located — hook it up and tow it to the drop-off.", "success")
                return
            end

            Wait(500)
        end
    end)
end

-- Detaches/despawns the target vehicle and clears delivery state. Called directly for
-- the in-world completion confirm, and via the `polarix_towjob:deliveryEnded` net event
-- below for every server-driven end (complete/fail/abort).
function Vehicle.EndDelivery(reason)
    if not currentDelivery then return end

    local target = currentDelivery.targetVehicle
    if DoesEntityExist(target) then
        DetachVehicleFromAnyTowTruck(target)
        DeleteEntity(target)
    end

    if currentDelivery.blip then
        RemoveBlip(currentDelivery.blip)
    end
    if currentDelivery.searchRouteBlip then
        RemoveBlip(currentDelivery.searchRouteBlip)
    end
    if currentDelivery.dropoffBlip then
        RemoveBlip(currentDelivery.dropoffBlip)
    end

    currentDelivery = nil
end

RegisterNetEvent("polarix_towjob:deliveryEnded", function(reason)
    Vehicle.EndDelivery(reason)
end)

-- Read-only accessor for client/modules/delivery.lua's periodic Active Delivery UI push.
function Vehicle.GetCurrentDelivery()
    return currentDelivery
end

local function beginDelivery(deliveryId, mission, deadlineAt)
    local targetVehicle = spawnTargetVehicle(mission)
    local netId = NetworkGetNetworkIdFromEntity(targetVehicle)
    TriggerServerEvent("polarix_towjob:setTargetVehicle", deliveryId, netId)

    local blip, searchRouteBlip = createSearchBlip(mission.search_center, mission.search_radius)

    currentDelivery = {
        deliveryId = deliveryId,
        mission = mission,
        targetVehicle = targetVehicle,
        targetNetId = netId,
        blip = blip,
        searchRouteBlip = searchRouteBlip,
        state = "searching",
        deadlineAt = deadlineAt,
    }

    setupFoundDetection(targetVehicle)

    Framework.Notify(("New tow job: %s"):format(mission.name), "info")
end

-- Turns a Missions.Accept response into the right client action: spawn a rental / owned
-- truck when the server provisioned one, stash the mission for Vehicle.ContinueAfterParkOut
-- when the player has 2+ trucks to pick from, otherwise just start the find loop (a truck
-- is already out). `result.usedRental` without `result.rental` = rental already spawned.
local function handleAcceptResult(result)
    if not result then
        return { ok = false, reason = "no_response" }
    end

    if not result.ok then
        return result
    end

    if result.needsParkOut then
        pendingMission = { deliveryId = result.deliveryId, mission = result.mission, deadlineAt = result.deadlineAt }
        return result
    end

    if result.usedRental and result.rental then
        Garage.SpawnRental(result.rental)
    elseif result.vehicle then
        Garage.SpawnVehicle(result.vehicle)
    end

    beginDelivery(result.deliveryId, result.mission, result.deadlineAt)

    return result
end

-- On-call pager accept.
function Vehicle.AcceptPagerOffer()
    local result = handleAcceptResult(lib.callback.await("polarix_towjob:acceptPage", false))

    if result.ok and result.needsParkOut then
        Framework.Notify("Open the Dashboard and Park Out a tow truck to start the job.", "info")
    end

    return result
end

-- QA test-run button — same client orchestration as a pager accept.
function Vehicle.AdminTestRunMission(missionId)
    return handleAcceptResult(lib.callback.await("polarix_towjob:adminTestRunMission", false, missionId))
end

-- Called after a successful `parkOutVehicle` NUI callback (client/nui/nui_callbacks.lua)
-- to pick the delivery back up once the player has parked out a truck themselves.
-- Returns true if a pending mission was actually resumed, so the caller knows
-- whether to close the Dashboard.
function Vehicle.ContinueAfterParkOut()
    if not pendingMission then return false end

    local mission = pendingMission
    pendingMission = nil
    beginDelivery(mission.deliveryId, mission.mission, mission.deadlineAt)

    return true
end
