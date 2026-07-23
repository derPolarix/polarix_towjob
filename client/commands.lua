local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")

RegisterCommand('openNui', function()
    OpenNui()
end, false)

RegisterCommand('sendmsg', function()
    OpenNui()
    SendMessage('updateMessage', {
        message = 'Hello from the client side!'
    })
end, false)

-- Temporary: verify Framework.GiveVehicleKeys per-framework, remove in Phase 14.1
RegisterCommand('towjobtestkeys', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        Framework.Notify("Get in a vehicle first.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    Framework.GiveVehicleKeys(vehicle, plate)
    Framework.Notify("GiveVehicleKeys called for plate " .. plate, "info")
end, false)
