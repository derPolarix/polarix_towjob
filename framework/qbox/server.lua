local config = require("config.server")

return {
    IsAdmin = function(source)
        local ok, result = pcall(function() return exports.qbx_core:HasPermission(source, config.AdminPermission) end)
        if ok then return result == true end
        return IsPlayerAceAllowed(source, "command." .. config.AdminAceSuffix)
    end,

    GetPlayerIdentifier = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end,

    GetPlayerName = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return "Unknown" end
        local d = player.PlayerData.charinfo
        return d.firstname .. " " .. d.lastname
    end,

    AddMoney = function(source, amount)
        local player = exports.qbx_core:GetPlayer(source)
        if player then player.Functions.AddMoney("bank", amount) end
    end,

    RemoveMoney = function(source, amount)
        local player = exports.qbx_core:GetPlayer(source)
        if player then player.Functions.RemoveMoney("bank", amount) end
    end,

    GetMoney = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.money.bank or 0
    end,

    HasJob = function(source, jobName)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.job.name == jobName or false
    end,

    GetJob = function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return nil end
        local job = player.PlayerData.job
        return { name = job.name, grade = job.grade and job.grade.level or 0, onDuty = job.onduty == true }
    end,

    GetVehicleOwner = function(plate)
        local ok, owner = pcall(MySQL.scalar.await, "SELECT citizenid FROM player_vehicles WHERE TRIM(plate) = ? LIMIT 1", { plate })
        return ok and owner or nil
    end,

    ImpoundVehicle = function(plate)
        -- qbx/qb garage state: 0 = out, 1 = garaged, 2 = impounded.
        local ok = pcall(MySQL.update.await,
            "UPDATE player_vehicles SET state = 2, garage = ?, depotprice = ? WHERE TRIM(plate) = ?",
            { config.ImpoundGarage, config.ImpoundFee, plate })
        return ok
    end,

    OnPlayerLoaded = function(callback)
        RegisterNetEvent("QBCore:Server:PlayerLoaded", function(player)
            callback(player.PlayerData.source)
        end)
    end,

    OnPlayerUnload = function(callback)
        RegisterNetEvent("QBCore:Server:OnPlayerUnload", function(source)
            callback(source)
        end)
    end,

    GiveVehicleKeys = function(src, vehicleNetId)
        if GetResourceState("qbx_vehiclekeys") ~= "started" then return end
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if vehicle and vehicle ~= 0 then
            exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
        end
    end,
}
