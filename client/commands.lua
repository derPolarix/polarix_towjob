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