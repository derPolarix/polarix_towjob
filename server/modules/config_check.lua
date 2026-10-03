-- Validates config values against what the resource actually ships and prints a
-- clear server console error for each misconfiguration.
local sharedConfig = require("config.shared")
local serverConfig = require("config.server")
local debug = require("shared.debug")

local ALLOWED_FRAMEWORKS = { qbox = true, ["qb-core"] = true, esx = true }

local function listKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return table.concat(keys, ", ")
end

local function checkUniqueIds(list, label)
    local seen = {}
    for _, entry in ipairs(list or {}) do
        if entry.id ~= nil then
            if seen[entry.id] then
                debug.Error(("Duplicate %s id \"%s\" — every id must be unique"):format(label, tostring(entry.id)))
            end
            seen[entry.id] = true
        end
    end
end

if not ALLOWED_FRAMEWORKS[sharedConfig.Framework] then
    debug.Error(("Invalid Framework \"%s\" in config/shared.lua — allowed values: %s")
        :format(tostring(sharedConfig.Framework), listKeys(ALLOWED_FRAMEWORKS)))
end

local language = sharedConfig.Language or "en"
if not LoadResourceFile(GetCurrentResourceName(), ("locales/%s.json"):format(language)) then
    debug.Error(("Invalid Language \"%s\" in config/shared.lua — no locales/%s.json found, falling back to English")
        :format(tostring(language), tostring(language)))
end

checkUniqueIds(serverConfig.VehicleTiers, "VehicleTiers")

local skills = {}
for _, branch in ipairs(sharedConfig.Skills and sharedConfig.Skills.branches or {}) do
    for _, skill in ipairs(branch.skills or {}) do skills[#skills + 1] = skill end
end
checkUniqueIds(skills, "Skills")
