local debug = require("shared.debug")
local server = require("config.server")
local shared = require("shared.debug")

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    LoadDatabaseToCache()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
end)
