local debug = require("shared.debug")
local client = require("config.client")
local shared = require("shared.debug")
local sharedConfig = require("config.shared")
local Keybinds = require("client.lib.keybinds")

function SetFocus(state)
    SetNuiFocus(state, state)
end

-- Every message carries language, currency and pager keys so App.vue stays in sync (keys can be rebound anytime).
function SendMessage(action, data)
    data = data or {}
    data.language = sharedConfig.Language
    data.currency = sharedConfig.Currency
    data.keybinds = {
        pagerAccept = Keybinds.GetDisplayKey("PagerAccept"),
        pagerDecline = Keybinds.GetDisplayKey("PagerDecline"),
    }
    SendNUIMessage({
        action = action,
        data = data
    })
end
