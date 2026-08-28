local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")

RegisterNetEvent("polarix_towjob:notify", function(message, notifType, duration)
    Framework.Notify(message, notifType, duration)
end)

RegisterNetEvent("polarix_towjob:onCallStateUpdate", function(data)
    SendMessage("onCallStateUpdate", data)
end)

-- Pager offer/clear events live in client/modules/pager.lua.
