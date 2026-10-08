local debug = require("shared.debug")
local clientConfig = require("config.client")
local Locale = require("shared.locale")

Vehicle = {}

local VEHICLE_FOUND_RADIUS = clientConfig.VehicleFoundRadius or 12.0
local SPAWN_POINT_CLEARANCE = clientConfig.SpawnPointClearance or 4.0

-- Set when Accept returns needsParkOut; resumed by ContinueAfterParkOut.
local pendingMission = nil

-- Occupied or mission-flagged vehicles block a spot instead of being deleted. The player's own truck isn't mission-flagged, hence the explicit guard.
local function isProtectedVehicle(vehicle)
    if IsEntityAMissionEntity(vehicle) then return true end
    if not IsVehicleSeatFree(vehicle, -1) or GetVehicleNumberOfPassengers(vehicle) > 0 then return true end

    return vehicle == GetVehiclePedIsIn(PlayerPedId(), true)
end

local function tryClearSpawnPoint(point)
    local coords = vector3(point.x, point.y, point.z)
    local blocking = {}

    -- Collected first so a spot rejected late doesn't leave earlier vehicles already deleted.
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - coords) <= SPAWN_POINT_CLEARANCE then
            if isProtectedVehicle(vehicle) then return false end

            blocking[#blocking + 1] = vehicle
        end
    end

    for _, vehicle in ipairs(blocking) do
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteEntity(vehicle)
    end

    return true
end

-- If every spot is blocked the last is used anyway. Returns the candidate index so the server can free the other reservations.
local function spawnTargetVehicle(mission)
    local candidates = mission.spawn_candidates or {}
    if #candidates == 0 then
        debug.Warn("Vehicle.spawnTargetVehicle: mission", mission.id, "has no spawn candidates")
        return nil
    end

    local chosenIndex = #candidates
    for index, candidate in ipairs(candidates) do
        if tryClearSpawnPoint(candidate.point) then
            chosenIndex = index
            break
        end
    end

    local chosen = candidates[chosenIndex]
    local point = chosen.point

    lib.requestModel(mission.vehicle_model)

    local entity = CreateVehicle(mission.vehicle_model, point.x, point.y, point.z, point.heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(mission.vehicle_model)
    SetVehicleOnGroundProperly(entity)

    if mission.vehicle_colors then
        SetVehicleColours(entity, mission.vehicle_colors.primary, mission.vehicle_colors.secondary)
    end

    debug.DebugPrint("Vehicle.spawnTargetVehicle: spawned", mission.vehicle_model, "at", point.x, point.y, point.z)

    return entity, chosenIndex, chosen.hint
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

-- Towing uses GTA's native mechanics; there is no attach step.
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
                Framework.Notify(Locale("notify.vehicle_located"), "success")
                return
            end

            Wait(500)
        end
    end)
end

function Vehicle.EndDelivery(reason)
    -- Drop a pending park-out so the next one doesn't resume an ended delivery.
    pendingMission = nil

    if not currentDelivery then return end

    local target = currentDelivery.targetVehicle
    if target and DoesEntityExist(target) then
        DetachVehicleFromAnyTowTruck(target)

        -- Priority targets are real player cars; only an impound removes them.
        if not currentDelivery.isPriority or reason == "completed" then
            DeleteEntity(target)
        end
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

function Vehicle.GetCurrentDelivery()
    return currentDelivery
end

-- A priority target only resolves once streamed in, so it is adopted on arrival; if it never resolves the server sweep cancels without a failure.
local function adoptTargetVehicle(delivery)
    CreateThread(function()
        while currentDelivery == delivery and delivery.state == "searching" do
            local entity = NetworkDoesEntityExistWithNetworkId(delivery.targetNetId)
                and NetworkGetEntityFromNetworkId(delivery.targetNetId) or nil

            if entity and entity ~= 0 and DoesEntityExist(entity) then
                delivery.targetVehicle = entity
                setupFoundDetection(entity)
                return
            end

            Wait(1000)
        end
    end)
end

local function beginDelivery(deliveryId, mission, deadlineMs)
    -- Leftover from an ended delivery; target and blips would leak.
    if currentDelivery then Vehicle.EndDelivery("cancelled") end

    local isPriority = mission.is_priority == true
    local targetVehicle, netId, searchHint

    if isPriority then
        netId = mission.target_net_id
        searchHint = mission.search_hint
    else
        local pointIndex
        targetVehicle, pointIndex, searchHint = spawnTargetVehicle(mission)
        if not targetVehicle then
            Framework.Notify(Locale("notify.spawn_failed"), "error")
            return
        end

        netId = NetworkGetNetworkIdFromEntity(targetVehicle)
        TriggerServerEvent("polarix_towjob:setTargetVehicle", deliveryId, netId, pointIndex)
    end

    -- Circle is around the server's hint center, not the vehicle.
    local blip, searchRouteBlip = createSearchBlip(searchHint, mission.search_hint_radius or 60.0)

    currentDelivery = {
        deliveryId = deliveryId,
        mission = mission,
        targetVehicle = targetVehicle,
        targetNetId = netId,
        searchHint = searchHint,
        blip = blip,
        searchRouteBlip = searchRouteBlip,
        state = "searching",
        deadlineMs = deadlineMs,
        isPriority = isPriority,
    }

    if mission.is_test then
        currentDelivery.dropoffBlip = createDropoffBlip(mission.dropoff)
    end

    if isPriority then
        adoptTargetVehicle(currentDelivery)
    else
        setupFoundDetection(targetVehicle)
    end

    Framework.Notify(Locale("notify.new_tow_job"):format(mission.name), "info")
end

-- result.usedRental without result.rental means the rental is already spawned.
local function handleAcceptResult(result)
    if not result then
        return { ok = false, reason = "no_response" }
    end

    if not result.ok then
        return result
    end

    -- Local monotonic timer, so time spent choosing a truck still runs down the deadline.
    local deadlineMs = result.secondsRemaining and (GetGameTimer() + result.secondsRemaining * 1000) or nil

    if result.needsParkOut then
        pendingMission = { deliveryId = result.deliveryId, mission = result.mission, deadlineMs = deadlineMs }
        return result
    end

    if result.usedRental and result.rental then
        Garage.SpawnRental(result.rental)
    elseif result.vehicle then
        Garage.SpawnVehicle(result.vehicle)
    end

    beginDelivery(result.deliveryId, result.mission, deadlineMs)

    return result
end

function Vehicle.AcceptPagerOffer()
    local result = handleAcceptResult(lib.callback.await("polarix_towjob:acceptPage", false))

    if result.ok and result.needsParkOut then
        Framework.Notify(Locale("notify.park_out_to_start"), "info")
    end

    return result
end

function Vehicle.AdminTestRunMission(missionId)
    return handleAcceptResult(lib.callback.await("polarix_towjob:adminTestRunMission", false, missionId))
end

-- Returns true if a pending mission was resumed (caller closes the Dashboard).
function Vehicle.ContinueAfterParkOut()
    if not pendingMission then return false end

    local mission = pendingMission
    pendingMission = nil
    beginDelivery(mission.deliveryId, mission.mission, mission.deadlineMs)

    return true
end
