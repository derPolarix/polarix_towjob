local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")

function SetFocus(state)
    SetNuiFocus(state, state)
end

function SendMessage(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end