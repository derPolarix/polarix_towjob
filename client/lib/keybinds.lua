-- Single entry point for keybinds; default keys come from config/client.lua (Keybinds).
-- Usage: local Keybinds = require("client.lib.keybinds")
local clientConfig = require("config.client")
local Locale = require("shared.locale")

-- Names must stay stable: FiveM stores each player's custom binding under this name.
local BINDS = {
    OpenDashboard   = { name = "polarix_towjob_open_dashboard",   description = "keybind.open_dashboard" },
    StoreTruck      = { name = "polarix_towjob_store_truck",      description = "keybind.store_truck" },
    ConfirmDelivery = { name = "polarix_towjob_confirm_delivery", description = "keybind.confirm_delivery" },
}

local Keybinds = {}
local registered = {}

function Keybinds.Register(action, onPressed)
    local bind = BINDS[action]
    registered[action] = lib.addKeybind({
        name = bind.name,
        description = Locale(bind.description),
        defaultKey = clientConfig.Keybinds[action],
        onPressed = onPressed,
    })
end

-- Key the player currently has bound, falling back to the config default.
function Keybinds.GetKey(action)
    local keybind = registered[action]
    local key = keybind and keybind:getCurrentKey()
    if not key or key == "" then
        return clientConfig.Keybinds[action]
    end
    return key
end

-- Prompt text like "[E] Store Tow Truck".
function Keybinds.Prompt(action, localeKey)
    return ("[%s] %s"):format(Keybinds.GetKey(action), Locale(localeKey))
end

return Keybinds
