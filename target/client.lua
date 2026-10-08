-- Normalized option schema every provider accepts:
--   { name, icon = "fa-solid fa-...", label, distance?, canInteract?(entity), onSelect?(entity) }
local config = require("config.shared")

Target = {}

local ok, provider = pcall(require, "target." .. tostring(config.Target) .. ".client")
if not ok then
    error(("[polarix_towjob] Unknown target system in config/shared.lua: %s"):format(tostring(config.Target)))
end

for fnName, fn in pairs(provider) do
    Target[fnName] = fn
end
