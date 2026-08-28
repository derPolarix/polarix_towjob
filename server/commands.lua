local debug = require("shared.debug")
local sharedConfig = require("config.shared")

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

-- Debug-only tester: page yourself a random eligible mission to exercise the pager flow
-- without waiting on the on-call scheduler. Registered only when config.shared.Debug is set
-- so it can't exist on a production build, and still admin-gated on top of that — the Debug
-- flag is a build switch, not an auth check (ground rule 4).
if sharedConfig.Debug then
    RegisterCommand('towjobtestpage', function(source)
        if source == 0 then return end -- needs a real player to page

        if not Framework.IsAdmin(source) then
            debug.DebugPrint(("towjobtestpage: non-admin %s attempted /towjobtestpage"):format(source))
            TriggerClientEvent("polarix_towjob:notify", source, "You do not have permission to do that.", "error")
            return
        end

        local result = OnCall.DebugSendTestPage(source)
        if not result.ok then
            TriggerClientEvent("polarix_towjob:notify", source, ("Test page failed: %s"):format(result.reason), "error")
            return
        end

        TriggerClientEvent("polarix_towjob:notify", source, ("Paged you a test mission: %s"):format(result.name), "success")
    end, false)
end
