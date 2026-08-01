local debug = require("shared.debug")

-- Phase 13.2: the one deliberate, permanent admin tool. Framework.IsAdmin is
-- re-checked here at open time AND again inside every individual admin*
-- lib.callback (ground rule 4) — this command opening the UI must never be
-- the only gate.
RegisterCommand('towjobadmin', function(source)
    if source == 0 then return end -- console has no NUI to open

    if not Framework.IsAdmin(source) then
        debug.DebugPrint(("towjobadmin: non-admin %s attempted /towjobadmin"):format(source))
        TriggerClientEvent("polarix_towjob:notify", source, "You do not have permission to do that.", "error")
        return
    end

    TriggerClientEvent("polarix_towjob:openAdminUi", source)
end, false)
