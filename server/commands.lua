local debug = require("shared.debug")
local server = require("config.server")
local shared = require("shared.debug")

RegisterCommand('debugprintserver', function()
    Wait(1000) -- wait so output stays in order
    debug.DebugPrint("Dies ist ein Debug Print Test von commands.lua!")
    Wait(1000)
    debug.DebugPrint("Das ist eine"," weitere Zeile mit", "mehreren", "Argumenten.")
    Wait(1000)
    debug.DebugPrint("Das ist eine Zeile", {key = "value", number = 42, bool = true})
    Wait(1000)
    debug.DebugPrint({nested = {table = {with = {multiple = "levels"}}}})
    Wait(1000)
    debug.DebugPrint(nil)
    Wait(1000)
    debug.DebugPrint(12345)
    Wait(1000)
    debug.DebugPrint(true)
    Wait(1000)
end, false)

-- Temporary: inserts a fake active delivery row so Player.Load's stale-delivery
-- cleanup (Phase 3.4) can be exercised on next reconnect. Remove in Phase 14.1.
RegisterCommand('towjobtestactive', function(source)
    local identifier = Framework.GetPlayerIdentifier(source)
    if not identifier then
        debug.DebugPrint("towjobtestactive: could not resolve identifier for source", source)
        return
    end

    MySQL.insert.await(
        "INSERT INTO " .. server.Tables.deliveries .. " (mission_id, identifier, status, used_rental) VALUES (?, ?, 'active', 0)",
        { "debug-test-mission", identifier }
    )
    debug.DebugPrint("towjobtestactive: inserted a fake active delivery for", identifier, "- reconnect to trigger stale-delivery cleanup")
end, false)