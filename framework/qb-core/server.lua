local QBCore
local config = require("config.server")

local function getQBCore()
    QBCore = QBCore or exports["qb-core"]:GetCoreObject()
    return QBCore
end

return {
    IsAdmin = function(source)
        local ok, result = pcall(function() return getQBCore().Functions.HasPermission(source, config.AdminPermission) end)
        if ok then return result == true end
        return IsPlayerAceAllowed(source, "command." .. config.AdminAceSuffix)
    end,

    GetPlayerIdentifier = function(source)
        local player = getQBCore().Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end,

    GetPlayerName = function(source)
        local player = getQBCore().Functions.GetPlayer(source)
        if not player then return "Unknown" end
        local d = player.PlayerData.charinfo
        return d.firstname .. " " .. d.lastname
    end,

    AddMoney = function(source, amount)
        local player = getQBCore().Functions.GetPlayer(source)
        if player then player.Functions.AddMoney("bank", amount) end
    end,

    RemoveMoney = function(source, amount)
        local player = getQBCore().Functions.GetPlayer(source)
        if player then player.Functions.RemoveMoney("bank", amount) end
    end,

    GetMoney = function(source)
        local player = getQBCore().Functions.GetPlayer(source)
        return player and player.PlayerData.money.bank or 0
    end,

    HasJob = function(source, jobName)
        local player = getQBCore().Functions.GetPlayer(source)
        return player and player.PlayerData.job.name == jobName or false
    end,

    GetJob = function(source)
        local player = getQBCore().Functions.GetPlayer(source)
        if not player then return nil end
        local job = player.PlayerData.job
        return { name = job.name, grade = job.grade and job.grade.level or 0, onDuty = job.onduty == true }
    end,

    GetVehicleOwner = function(plate)
        local ok, owner = pcall(MySQL.scalar.await, "SELECT citizenid FROM player_vehicles WHERE TRIM(plate) = ? LIMIT 1", { plate })
        return ok and owner or nil
    end,

    ImpoundVehicle = function(plate)
        -- qb garage state: 0 = out, 1 = garaged, 2 = impounded.
        local ok = pcall(MySQL.update.await,
            "UPDATE player_vehicles SET state = 2, garage = ?, depotprice = ? WHERE TRIM(plate) = ?",
            { config.ImpoundGarage, config.ImpoundFee, plate })
        return ok
    end,

    OnPlayerLoaded = function(callback)
        AddEventHandler("QBCore:Server:PlayerLoaded", function(player)
            callback(player.PlayerData.source)
        end)
    end,

    OnPlayerUnload = function(callback)
        AddEventHandler("QBCore:Server:OnPlayerUnload", function(source)
            callback(source)
        end)
    end,

    -- no-op: qb-core grants keys client-side via vehiclekeys:client:SetOwner
    GiveVehicleKeys = function(_src, _vehicleNetId)
    end,
}
