local debug = require("shared.debug")
local sharedConfig = require("config.shared")
local Locale = require("shared.locale")

-- IsAdmin is re-checked in every admin* callback; this command is not the only gate.
RegisterCommand('towjobadmin', function(source)
    if source == 0 then return end -- console has no NUI to open

    if not Framework.IsAdmin(source) then
        debug.Warn(("towjobadmin: non-admin %s attempted /towjobadmin"):format(source))
        TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.no_permission"), "error")
        return
    end

    TriggerClientEvent("polarix_towjob:openAdminUi", source)
end, false)

-- Debug-only: pages yourself a random mission. Still admin-gated; Debug is a build switch, not auth.
if sharedConfig.Debug then
    RegisterCommand('towjobtestpage', function(source)
        if source == 0 then return end -- needs a real player to page

        if not Framework.IsAdmin(source) then
            debug.Warn(("towjobtestpage: non-admin %s attempted /towjobtestpage"):format(source))
            TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.no_permission"), "error")
            return
        end

        local result = OnCall.DebugSendTestPage(source)
        if not result.ok then
            TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.test_page_failed"):format(result.reason), "error")
            return
        end

        TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.test_page_sent"):format(result.name), "success")
    end, false)
end
