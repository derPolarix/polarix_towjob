local clientConfig = require("config.client")

Garage = {}

local deployedVehicles = {} -- [plate] = { id = vehicleId }
local rentalVehicle = nil

local function applyHealth(entity, bodyHealth, engineHealth)
    SetVehicleBodyHealth(entity, bodyHealth)
    SetVehicleEngineHealth(entity, engineHealth)
end

local function warpOrLeaveForPlayer(entity)
    if clientConfig.AutoEnterTowTruck then
        TaskWarpPedIntoVehicle(PlayerPedId(), entity, -1)
    end
end

function Garage.SpawnVehicle(vehicleData)
    lib.requestModel(vehicleData.model)

    local coords = clientConfig.TowTruckSpawnCoords
    local entity = CreateVehicle(vehicleData.model, coords.x, coords.y, coords.z, coords.w, true, false)
    SetModelAsNoLongerNeeded(vehicleData.model)

    SetVehicleNumberPlateText(entity, vehicleData.plate)
    applyHealth(entity, vehicleData.body_health, vehicleData.engine_health)

    Framework.GiveVehicleKeys(entity, vehicleData.plate)
    warpOrLeaveForPlayer(entity)

    deployedVehicles[vehicleData.plate] = { id = vehicleData.id }

    return entity
end

function Garage.SpawnRental(rentalData)
    lib.requestModel(rentalData.model)

    local coords = clientConfig.TowTruckSpawnCoords
    rentalVehicle = CreateVehicle(rentalData.model, coords.x, coords.y, coords.z, coords.w, true, false)
    SetModelAsNoLongerNeeded(rentalData.model)

    local plate = GetVehicleNumberPlateText(rentalVehicle):gsub("%s+$", "")
    Framework.GiveVehicleKeys(rentalVehicle, plate)
    warpOrLeaveForPlayer(rentalVehicle)

    return rentalVehicle
end

local function findDeployedVehicleNearPlayer()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return nil end

    local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+$", "")
    local tracked = deployedVehicles[plate]
    if not tracked then return nil end

    return tracked, vehicle, plate
end

local function attemptStore()
    local tracked, vehicle = findDeployedVehicleNearPlayer()
    if not tracked then
        Framework.Notify("You're not in one of your tow trucks.", "error")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        Framework.Notify("You must be in the driver seat.", "error")
        return
    end

    if GetEntitySpeed(vehicle) > 0.5 then
        Framework.Notify("Come to a complete stop first.", "error")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await("polarix_towjob:storeVehicle", false, tracked.id, netId)

    if not result or not result.ok then
        Framework.Notify("Could not store the vehicle.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+$", "")
    deployedVehicles[plate] = nil
    DeleteEntity(vehicle)
    Framework.Notify("Vehicle stored.", "success")
end

local function setupParkingInteraction()
    local zone = clientConfig.ParkingZone

    if GetResourceState("ox_target") == "started" then
        exports.ox_target:addSphereZone({
            coords = zone.coords,
            radius = zone.radius,
            options = {
                {
                    name = "polarix_towjob:storevehicle",
                    icon = "fa-solid fa-warehouse",
                    label = "Store Tow Truck",
                    canInteract = function()
                        return findDeployedVehicleNearPlayer() ~= nil
                    end,
                    onSelect = attemptStore,
                },
            },
        })
        return
    end

    CreateThread(function()
        local promptShown = false

        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - zone.coords)
            local sleep = 1000

            if dist < zone.radius and findDeployedVehicleNearPlayer() then
                sleep = 0
                DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, zone.radius, zone.radius, 1.0, 40, 120, 200, 100, false, true, 2, false, nil, nil, false)

                if not promptShown then
                    promptShown = true
                    lib.showTextUI("[E] Store Tow Truck")
                end

                if IsControlJustReleased(0, 38) then
                    attemptStore()
                end
            elseif promptShown then
                promptShown = false
                lib.hideTextUI()
            end

            Wait(sleep)
        end
    end)
end

RegisterNetEvent("polarix_towjob:syncDeployedVehicles", function(vehicles)
    for _, vehicle in ipairs(vehicles) do
        deployedVehicles[vehicle.plate] = { id = vehicle.id }
    end
end)

RegisterNetEvent("polarix_towjob:vehicleHealthRestored", function(plate)
    local tracked = deployedVehicles[plate]
    if not tracked then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end

    if GetVehicleNumberPlateText(vehicle):gsub("%s+$", "") == plate then
        applyHealth(vehicle, 1000.0, 1000.0)
    end
end)

RegisterNetEvent("polarix_towjob:spawnRentalTruck", function(rentalData)
    Garage.SpawnRental(rentalData)
end)

RegisterNetEvent("polarix_towjob:repossessRental", function()
    if rentalVehicle and DoesEntityExist(rentalVehicle) then
        DeleteEntity(rentalVehicle)
    end
    rentalVehicle = nil
end)

CreateThread(setupParkingInteraction)
