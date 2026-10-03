local debug = require("shared.debug")
local server = require("config.server")
local shared = require("shared.debug")
require("server.modules.areas")
require("server.modules.missions")
require("server.modules.settings")
require("server.modules.player")

local function loadSchema()
    local sql = LoadResourceFile(GetCurrentResourceName(), "sql/init.sql")
    if not sql then
        debug.Error("sql/init.sql not found, skipping schema creation")
        return
    end

    for statement in sql:gmatch("[^;]+") do
        local trimmed = statement:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            local ok, err = pcall(MySQL.query.await, trimmed)
            if not ok then
                debug.Warn("Schema statement failed:", trimmed, err)
            end
        end
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    loadSchema()
    LoadDatabaseToCache()
    Settings.Load()

    -- A mid-session restart wipes PlayerCache but the framework's "player loaded" event
    -- only fires on initial connect, so already-connected players would be stuck with no
    -- cached data (dashboard fails to load) until they relog. Repopulate them here.
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source then
            local ok, err = pcall(Player.Load, source)
            if not ok then
                debug.Warn("onResourceStart: Player.Load failed for", source, err)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
end)
