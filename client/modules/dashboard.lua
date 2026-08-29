local Locale = require("shared.locale")

Dashboard = {}

function Dashboard.Open()
    local payload = lib.callback.await("polarix_towjob:openDashboard", false)
    if not payload then
        Framework.Notify(Locale("notify.dashboard_load_failed"), "error")
        return
    end

    SetFocus(true)
    SendMessage("openDashboard", payload)
end
