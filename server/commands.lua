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

-- Temporary: exercises Step 7.5's rental billing loop ahead of Phase 8's real mission
-- accept flow, which is the eventual real caller of Vehicles.StartRental. Remove in Phase 14.1.
RegisterCommand('towjobtestrental', function(source)
    local identifier = Framework.GetPlayerIdentifier(source)
    if not identifier then
        debug.DebugPrint("towjobtestrental: could not resolve identifier for source", source)
        return
    end

    local deliveryId = MySQL.insert.await(
        "INSERT INTO " .. server.Tables.deliveries .. " (mission_id, identifier, status, used_rental) VALUES (?, ?, 'active', 1)",
        { "debug-test-mission", identifier }
    )

    Vehicles.StartRental(source, deliveryId)
    TriggerClientEvent("polarix_towjob:spawnRentalTruck", source, server.RentalTruck)
    debug.DebugPrint("towjobtestrental: started rental billing for", identifier, "delivery", deliveryId)
end, false)

-- Phase 13.2: the one deliberate, permanent admin tool (kept past Phase 14.1's debug-command
-- cleanup, unlike the /towjobtest* commands above). Framework.IsAdmin is re-checked here at
-- open time AND again inside every individual admin* lib.callback (ground rule 4) — this
-- command opening the UI must never be the only gate.
RegisterCommand('towjobadmin', function(source)
    if source == 0 then return end -- console has no NUI to open

    if not Framework.IsAdmin(source) then
        debug.DebugPrint(("towjobadmin: non-admin %s attempted /towjobadmin"):format(source))
        TriggerClientEvent("polarix_towjob:notify", source, "You do not have permission to do that.", "error")
        return
    end

    TriggerClientEvent("polarix_towjob:openAdminUi", source)
end, false)