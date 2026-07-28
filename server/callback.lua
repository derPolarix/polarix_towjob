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
        areas = Areas.GetMapAreas(source),
        vehicles = Vehicles.GetOwnedForPlayer(source),
        vehicleTiers = Vehicles.GetTiersForPlayer(source),
        repairCostPerHealthPoint = Vehicles.GetRepairCostPerHealthPoint(source),
        activeDelivery = Missions.GetActiveDeliverySummary(source),
        skillBranches = sharedConfig.Skills.branches,
    }
end)

-- Used by the Available Jobs tab to refresh its list without reopening the whole
-- Dashboard (e.g. after an area unlock in Phase 6, or a level-up in Phase 11).
lib.callback.register("polarix_towjob:getAvailableJobs", function(source)
    return Missions.GetAvailableForPlayer(source)
end)

-- Used by the Map tab to refresh area unlock state without reopening the whole Dashboard.
lib.callback.register("polarix_towjob:getMapAreas", function(source)
    return Areas.GetMapAreas(source)
end)

lib.callback.register("polarix_towjob:unlockArea", function(source, areaId)
    return Areas.Unlock(source, areaId)
end)

-- Used by the Vehicles tab to refresh owned vehicles/catalog without reopening the whole Dashboard.
lib.callback.register("polarix_towjob:getOwnedVehicles", function(source)
    return {
        vehicles = Vehicles.GetOwnedForPlayer(source),
        vehicleTiers = Vehicles.GetTiersForPlayer(source),
        repairCostPerHealthPoint = Vehicles.GetRepairCostPerHealthPoint(source),
    }
end)

lib.callback.register("polarix_towjob:purchaseVehicle", function(source, tierId)
    return Vehicles.Purchase(source, tierId)
end)

lib.callback.register("polarix_towjob:repairVehicle", function(source, vehicleId)
    return Vehicles.Repair(source, vehicleId)
end)

lib.callback.register("polarix_towjob:parkOutVehicle", function(source, vehicleId)
    return Vehicles.ParkOut(source, vehicleId)
end)

lib.callback.register("polarix_towjob:storeVehicle", function(source, vehicleId, netId)
    return Vehicles.Store(source, vehicleId, netId)
end)

lib.callback.register("polarix_towjob:unlockSkill", function(source, skillId)
    return Skills.Unlock(source, skillId)
end)

lib.callback.register("polarix_towjob:acceptMission", function(source, missionId)
    return Missions.Accept(source, missionId)
end)

lib.callback.register("polarix_towjob:completeDelivery", function(source, deliveryId)
    return Missions.Complete(source, deliveryId)
end)

lib.callback.register("polarix_towjob:abortDelivery", function(source, deliveryId)
    return Missions.Abort(source, deliveryId)
end)

lib.callback.register("polarix_towjob:getLeaderboard", function(source)
    return Deliveries.GetLeaderboard(source)
end)

lib.callback.register("polarix_towjob:getRecentDeliveries", function(source, limit)
    return Deliveries.GetRecentForPlayer(source, limit)
end)

lib.callback.register("polarix_towjob:getDeliveryHistory", function(source, offset)
    return Deliveries.GetHistoryPage(source, offset)
end)
