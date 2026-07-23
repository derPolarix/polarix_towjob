local sharedConfig = require("config.shared")

lib.callback.register("polarix_towjob:openDashboard", function(source)
    local playerData = Player.GetData(source)
    if not playerData then
        return nil
    end

    return {
        player = playerData,
        levelTitles = sharedConfig.LevelTitles,
        xpThresholds = sharedConfig.XPThresholds,
        unlockedAreaIds = Player.GetUnlockedAreaIds(source),
        missions = Missions.GetAvailableForPlayer(source),
        vehicles = {}, -- populated in Phase 7
    }
end)

-- Used by the Available Jobs tab to refresh its list without reopening the whole
-- Dashboard (e.g. after an area unlock in Phase 6, or a level-up in Phase 11).
lib.callback.register("polarix_towjob:getAvailableJobs", function(source)
    return Missions.GetAvailableForPlayer(source)
end)
