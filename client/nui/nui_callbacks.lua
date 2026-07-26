local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")

RegisterNUICallback('closeNui', function(data, cb)
    SetNuiFocus(false, false)
    print(json.encode(data))
    cb({ ok = true, message = 'NUI closed' })
end)

RegisterNUICallback('getAvailableJobs', function(data, cb)
    local jobs = lib.callback.await("polarix_towjob:getAvailableJobs", false)
    cb(jobs or {})
end)

RegisterNUICallback('getMapAreas', function(data, cb)
    local areas = lib.callback.await("polarix_towjob:getMapAreas", false)
    cb(areas or {})
end)

RegisterNUICallback('unlockArea', function(data, cb)
    local result = lib.callback.await("polarix_towjob:unlockArea", false, data and data.areaId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('getOwnedVehicles', function(data, cb)
    local result = lib.callback.await("polarix_towjob:getOwnedVehicles", false)
    cb(result or { vehicles = {}, vehicleTiers = {}, repairCostPerHealthPoint = 0 })
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
    local result = lib.callback.await("polarix_towjob:purchaseVehicle", false, data and data.tierId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('repairVehicle', function(data, cb)
    local result = lib.callback.await("polarix_towjob:repairVehicle", false, data and data.vehicleId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('parkOutVehicle', function(data, cb)
    local result = lib.callback.await("polarix_towjob:parkOutVehicle", false, data and data.vehicleId)
    if result and result.ok and result.vehicle then
        Garage.SpawnVehicle(result.vehicle)
    end
    cb(result or { ok = false, reason = "no_response" })
end)
