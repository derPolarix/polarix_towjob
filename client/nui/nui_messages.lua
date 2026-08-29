local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")
local sharedConfig = require("config.shared")

function SetFocus(state)
    SetNuiFocus(state, state)
end

-- Every NUI message carries the active language so App.vue can keep vue-i18n in sync with
-- Config.Language regardless of which message opens or updates the UI.
function SendMessage(action, data)
    data = data or {}
    data.language = sharedConfig.Language
    SendNUIMessage({
        action = action,
        data = data
    })
end
