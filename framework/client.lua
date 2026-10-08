local config = require("config.shared")
local Locale = require("shared.locale")

local ok, provider = pcall(require, "framework." .. config.Framework .. ".client")
if not ok then
    error(("[polarix_towjob] Unknown framework in config/shared.lua: %s"):format(tostring(config.Framework)))
end

function Framework.Notify(message, notifType, duration)
    lib.notify({ title = Locale("notify.title"), description = message, type = notifType or "info", duration = duration or 4000 })
end

for fnName, fn in pairs(provider) do
    Framework[fnName] = fn
end
