local sharedConfig = require("config.shared")
local serverConfig = require("config.server")
local Locale = require("shared.locale")
local debug = require("shared.debug")

local function localizeList(keys)
    local out = {}
    for i, key in ipairs(keys or {}) do out[i] = Locale(key) end
    return out
end

lib.callback.register("polarix_towjob:openDashboard", function(source)
    -- Player.Load normally runs on the framework's "player loaded" event, but that doesn't
    -- fire for players already connected when the resource restarts. Rebuild the cache on
    -- demand here so a mid-session `ensure` doesn't leave the dashboard unusable until relog.
    local playerData = Player.GetData(source)
    if not playerData then
        pcall(Player.Load, source)
        playerData = Player.GetData(source)
        if not playerData then
            debug.Error(("openDashboard: could not load player for source %s (identifier=%s)"):format(source, tostring(Framework.GetPlayerIdentifier(source))))
            return nil
        end
    end

    local ok, payload = pcall(function()
        return {
            player = playerData,
            language = sharedConfig.Language,
            levelTitles = localizeList(sharedConfig.LevelTitles),
            xpThresholds = sharedConfig.XPThresholds,
            unlockedAreaIds = Player.GetUnlockedAreaIds(source),
            areas = Areas.GetMapAreas(source),
            vehicles = Vehicles.GetOwnedForPlayer(source),
            vehicleTiers = Vehicles.GetTiersForPlayer(source),
            repairCostPerHealthPoint = Vehicles.GetRepairCostPerHealthPoint(source),
            activeDelivery = Missions.GetActiveDeliverySummary(source),
            skillBranches = Skills.ResolveBranches(),
            onCall = OnCall.IsOnCall(source),
            rentalActive = Vehicles.IsRentalActive(source),
            rentalPricePerCharge = Settings.GetRentalPricePerCharge(),
            rentalIntervalMinutes = Settings.GetRentalIntervalMinutes(),
            rentalTruckLabel = serverConfig.RentalTruck.label,
        }
    end)

    if not ok then
        debug.Error(("openDashboard: payload build errored for source %s: %s"):format(source, tostring(payload)))
        return nil
    end

    return payload
end)

-- Used by the Areas tab to refresh area unlock state without reopening the whole Dashboard.
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

lib.callback.register("polarix_towjob:parkInVehicle", function(source, vehicleId)
    return Vehicles.ParkIn(source, vehicleId)
end)

lib.callback.register("polarix_towjob:unlockSkill", function(source, skillId)
    return Skills.Unlock(source, skillId)
end)

lib.callback.register("polarix_towjob:toggleOnCall", function(source, wantOn)
    return OnCall.SetOnCall(source, wantOn)
end)

lib.callback.register("polarix_towjob:startStandaloneRental", function(source)
    return OnCall.StartStandaloneRental(source)
end)

lib.callback.register("polarix_towjob:returnRental", function(source)
    return Vehicles.ReturnRental(source)
end)

lib.callback.register("polarix_towjob:acceptPage", function(source)
    return OnCall.AcceptOffer(source)
end)

lib.callback.register("polarix_towjob:declinePage", function(source)
    return OnCall.DeclineOffer(source)
end)

lib.callback.register("polarix_towjob:completeDelivery", function(source, deliveryId)
    return Missions.Complete(source, deliveryId)
end)

lib.callback.register("polarix_towjob:abortDelivery", function(source, deliveryId)
    return Missions.Abort(source, deliveryId)
end)

-- Police "mark for tow" (client/modules/police.lua). The client only ever learns *whether*
-- it may mark and how to trigger it; every rule about what may be marked is re-checked in
-- Priority.Mark itself (ground rule 4).
lib.callback.register("polarix_towjob:getPoliceMarkConfig", function(source)
    local canMark = Priority.CanMark(source)

    return {
        canMark = canMark,
        command = serverConfig.PoliceMarkCommand,
        distance = serverConfig.PoliceMarkDistance,
        blips = canMark and Priority.GetBlipsForOfficer(source) or {},
    }
end)

lib.callback.register("polarix_towjob:markForTow", function(source, netId, label, colors)
    return Priority.Mark(source, netId, label, colors)
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
