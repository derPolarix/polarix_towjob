local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")
local sharedConfig = require("config.shared")
local Keybinds = require("client.lib.keybinds")

function SetFocus(state)
    SetNuiFocus(state, state)
end

-- Every NUI message carries the active language so App.vue can keep vue-i18n in sync with
-- Config.Language regardless of which message opens or updates the UI. The pager keys ride
-- along for the same reason: the player may rebind them at any time.
function SendMessage(action, data)
    data = data or {}
    data.language = sharedConfig.Language
    data.keybinds = {
        pagerAccept = Keybinds.GetDisplayKey("PagerAccept"),
        pagerDecline = Keybinds.GetDisplayKey("PagerDecline"),
    }
    SendNUIMessage({
        action = action,
        data = data
    })
end
