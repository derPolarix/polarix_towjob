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
        missions = {}, -- populated in Phase 5
        vehicles = {}, -- populated in Phase 7
    }
end)
