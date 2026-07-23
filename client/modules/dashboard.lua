Dashboard = {}

function Dashboard.Open()
    local payload = lib.callback.await("polarix_towjob:openDashboard", false)
    if not payload then
        Framework.Notify("Could not load your dashboard data. Try again.", "error")
        return
    end

    SetFocus(true)
    SendMessage("openDashboard", payload)
end
