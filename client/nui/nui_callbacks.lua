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
