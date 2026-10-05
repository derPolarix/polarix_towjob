local clientConfig = require("config.client")
local Locale = require("shared.locale")
local Keybinds = require("client.lib.keybinds")

Garage = {}

local deployedVehicles = {} -- [plate] = { id = vehicleId, entity = vehicleId? }
local rentalVehicle = nil

local function stripPlate(plate)
    return plate:gsub("%s+$", "")
end

local function applyHealth(entity, bodyHealth, engineHealth)
    SetVehicleBodyHealth(entity, bodyHealth)
    SetVehicleEngineHealth(entity, engineHealth)
end

local function applyAppearance(entity, data)
    if data.colors then
        SetVehicleColours(entity, data.colors.primary or 0, data.colors.secondary or 0)
    end

    if data.mods or data.livery then
        SetVehicleModKit(entity, 0)
    end

    for modType, index in pairs(data.mods or {}) do
        SetVehicleMod(entity, modType, index, false)
    end

    if data.livery then
        SetVehicleMod(entity, 48, data.livery, false)
        SetVehicleLivery(entity, data.livery)
    end

    for extraId, shown in pairs(data.extras or {}) do
        SetVehicleExtra(entity, extraId, not shown)
    end
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
    applyAppearance(entity, vehicleData)

    Framework.GiveVehicleKeys(entity, vehicleData.plate)
    warpOrLeaveForPlayer(entity)

    deployedVehicles[vehicleData.plate] = { id = vehicleData.id, entity = entity }
    TriggerServerEvent("polarix_towjob:registerDeployedTruck", vehicleData.id, NetworkGetNetworkIdFromEntity(entity))

    return entity
end

function Garage.SpawnRental(rentalData)
    lib.requestModel(rentalData.model)

    local coords = clientConfig.TowTruckSpawnCoords
    rentalVehicle = CreateVehicle(rentalData.model, coords.x, coords.y, coords.z, coords.w, true, false)
    SetModelAsNoLongerNeeded(rentalData.model)

    applyAppearance(rentalVehicle, rentalData)

    local plate = GetVehicleNumberPlateText(rentalVehicle):gsub("%s+$", "")
    Framework.GiveVehicleKeys(rentalVehicle, plate)
    warpOrLeaveForPlayer(rentalVehicle)

    return rentalVehicle
end

local function findDeployedVehicleNearPlayer()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return nil end

    local plate = stripPlate(GetVehicleNumberPlateText(vehicle))
    local tracked = deployedVehicles[plate]
    if not tracked then return nil end

    return tracked, vehicle, plate
end

-- Resolves the tow truck the active delivery is being run with, for client/modules/damage.lua's
-- truck-destroyed watch: the on-call rental first, then the deployed owned truck the player is
-- sitting in, else the nearest deployed owned truck.
function Garage.ResolveActiveTruck()
    if rentalVehicle and DoesEntityExist(rentalVehicle) then
        return rentalVehicle
    end

    local ped = PlayerPedId()
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 and deployedVehicles[stripPlate(GetVehicleNumberPlateText(current))] then
        return current
    end

    local pedCoords = GetEntityCoords(ped)
    local best, bestDist = nil, math.huge
    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(veh) and deployedVehicles[stripPlate(GetVehicleNumberPlateText(veh))] then
            local dist = #(pedCoords - GetEntityCoords(veh))
            if dist < bestDist then best, bestDist = veh, dist end
        end
    end
    return best
end

local function attemptStore()
    local tracked, vehicle = findDeployedVehicleNearPlayer()
    if not tracked then
        Framework.Notify(Locale("notify.not_in_your_tow_truck"), "error")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        Framework.Notify(Locale("notify.must_be_driver_seat"), "error")
        return
    end

    if GetEntitySpeed(vehicle) > 0.5 then
        Framework.Notify(Locale("notify.come_to_stop_first"), "error")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await("polarix_towjob:storeVehicle", false, tracked.id, netId)

    if not result or not result.ok then
        local key = result and result.reason == "delivery_in_progress" and "error.finish_delivery_before_park_in" or "notify.store_vehicle_failed"
        Framework.Notify(Locale(key), "error")
        return
    end

    local plate = stripPlate(GetVehicleNumberPlateText(vehicle))
    deployedVehicles[plate] = nil
    DeleteEntity(vehicle)
    Framework.Notify(Locale("notify.vehicle_stored"), "success")
end

local function setupParkingInteraction()
    local zone = clientConfig.ParkingZone

    if Target.IsAvailable() then
        Target.AddSphereZone("polarix_towjob:parking", zone.coords, zone.radius, {
            {
                name = "polarix_towjob:storevehicle",
                icon = "fa-solid fa-warehouse",
                label = Locale("ui.store_tow_truck"),
                canInteract = function()
                    return findDeployedVehicleNearPlayer() ~= nil
                end,
                onSelect = attemptStore,
            },
        })
        return
    end

    local promptShown = false

    Keybinds.Register("StoreTruck", function()
        if promptShown then attemptStore() end
    end)

    CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - zone.coords)
            local sleep = 1000

            if dist < zone.radius and findDeployedVehicleNearPlayer() then
                sleep = 0
                DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, zone.radius, zone.radius, 1.0, 40, 120, 200, 100, false, true, 2, false, nil, nil, false)

                if not promptShown then
                    promptShown = true
                    lib.showTextUI(Keybinds.Prompt("StoreTruck", "ui.store_tow_truck"))
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

    -- Re-attach any live entities (deployed in an earlier session) and report their netIds so
    -- Vehicles.ParkIn can despawn them straight from the Dashboard.
    for _, veh in ipairs(GetGamePool("CVehicle")) do
        local tracked = deployedVehicles[stripPlate(GetVehicleNumberPlateText(veh))]
        if tracked then
            tracked.entity = veh
            TriggerServerEvent("polarix_towjob:registerDeployedTruck", tracked.id, NetworkGetNetworkIdFromEntity(veh))
        end
    end
end)

-- Server has stored the truck (Vehicles.ParkIn). Drop it from the local cache and, when the
-- server couldn't resolve the entity itself (truck not streamed to any player), best-effort
-- delete it here.
RegisterNetEvent("polarix_towjob:truckParkedIn", function(data)
    local tracked = deployedVehicles[data.plate]
    local entity = tracked and tracked.entity

    if (not entity or not DoesEntityExist(entity)) then
        for _, veh in ipairs(GetGamePool("CVehicle")) do
            if stripPlate(GetVehicleNumberPlateText(veh)) == data.plate then
                entity = veh
                break
            end
        end
    end

    if data.needsClientDelete and entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    deployedVehicles[data.plate] = nil
end)

-- The deployed truck's live entity, wherever it stands (only trucks this client tracks), so a
-- repair paid for in the Dashboard also reaches a truck the player is not sitting in.
local function findDeployedEntity(plate)
    local tracked = deployedVehicles[plate]
    if not tracked then return nil end

    if tracked.entity and DoesEntityExist(tracked.entity) then return tracked.entity end

    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if stripPlate(GetVehicleNumberPlateText(veh)) == plate then
            tracked.entity = veh
            return veh
        end
    end

    return nil
end

local function takeControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    for _ = 1, 10 do
        Wait(100)
        if NetworkHasControlOfEntity(entity) then return true end
    end

    return false
end

lib.callback.register("polarix_towjob:canRepairLiveTruck", function(plate)
    local entity = findDeployedEntity(plate)
    return entity ~= nil and takeControl(entity)
end)

RegisterNetEvent("polarix_towjob:vehicleHealthRestored", function(plate)
    local entity = findDeployedEntity(plate)
    if entity and takeControl(entity) then
        applyHealth(entity, 1000.0, 1000.0)
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
