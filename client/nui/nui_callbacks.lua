local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")

RegisterNUICallback('closeNui', function(data, cb)
    SetNuiFocus(false, false)
    cb({ ok = true, message = 'NUI closed' })
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

    result = result or { ok = false, reason = "no_response" }
    result.missionStarted = result.ok and Vehicle.ContinueAfterParkOut() or false

    cb(result)
end)

RegisterNUICallback('parkInVehicle', function(data, cb)
    local result = lib.callback.await("polarix_towjob:parkInVehicle", false, data and data.vehicleId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('unlockSkill', function(data, cb)
    local result = lib.callback.await("polarix_towjob:unlockSkill", false, data and data.skillId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('toggleOnCall', function(data, cb)
    local result = lib.callback.await("polarix_towjob:toggleOnCall", false, data and data.onCall)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('startStandaloneRental', function(data, cb)
    local result = lib.callback.await("polarix_towjob:startStandaloneRental", false)
    if result and result.ok and result.rental then
        Garage.SpawnRental(result.rental)
    end
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('returnRental', function(data, cb)
    local result = lib.callback.await("polarix_towjob:returnRental", false)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('acceptPage', function(data, cb)
    local result = Vehicle.AcceptPagerOffer()
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('declinePage', function(data, cb)
    local result = lib.callback.await("polarix_towjob:declinePage", false)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('abortDelivery', function(data, cb)
    local result = lib.callback.await("polarix_towjob:abortDelivery", false, data and data.deliveryId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('getLeaderboard', function(data, cb)
    local result = lib.callback.await("polarix_towjob:getLeaderboard", false)
    cb(result or { entries = {}, own = nil })
end)

RegisterNUICallback('getRecentDeliveries', function(data, cb)
    local result = lib.callback.await("polarix_towjob:getRecentDeliveries", false, data and data.limit)
    cb(result or { entries = {} })
end)

RegisterNUICallback('getDeliveryHistory', function(data, cb)
    local result = lib.callback.await("polarix_towjob:getDeliveryHistory", false, data and data.offset)
    cb(result or { entries = {}, total = 0, offset = 0, pageSize = 20 })
end)

-- Phase 13: Admin Settings UI. Server-side Framework.IsAdmin is re-checked inside every
-- one of the polarix_towjob:admin* lib.callbacks below (ground rule 4) — these are thin
-- dispatchers only, same shape as every other callback in this file.

RegisterNUICallback('adminListMissions', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminListMissions", false)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminCreateMission', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminCreateMission", false, data)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminUpdateMission', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminUpdateMission", false, data and data.missionId, data and data.mission)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminSetMissionActive', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminSetMissionActive", false, data and data.missionId, data and data.isActive)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminDeleteMission', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminDeleteMission", false, data and data.missionId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminTestRunMission', function(data, cb)
    local result = Vehicle.AdminTestRunMission(data and data.missionId)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminListAreas', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminListAreas", false)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminCreateArea', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminCreateArea", false, data)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminUpdateArea', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminUpdateArea", false, data and data.areaId, data and data.area)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminSetAreaActive', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminSetAreaActive", false, data and data.areaId, data and data.isActive)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminGetSettings', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminGetSettings", false)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminSetSetting', function(data, cb)
    local result = lib.callback.await("polarix_towjob:adminSetSetting", false, data and data.key, data and data.value)
    cb(result or { ok = false, reason = "no_response" })
end)

RegisterNUICallback('adminGetCurrentPosition', function(data, cb)
    cb(Admin.GetCurrentPosition())
end)

RegisterNUICallback('adminSetDropoffPreview', function(data, cb)
    Admin.SetDropoffPreview(data)
    cb({ ok = true })
end)

RegisterNUICallback('adminPreviewSpawnPoint', function(data, cb)
    cb(Admin.PreviewSpawnPoint(data))
end)

RegisterNUICallback('adminConfirmSpawnPoint', function(data, cb)
    Admin.ConfirmSpawnPoint(data)
    cb({ ok = true })
end)

RegisterNUICallback('adminClearSpawnPointGhosts', function(data, cb)
    Admin.ClearSpawnPointGhosts()
    cb({ ok = true })
end)
