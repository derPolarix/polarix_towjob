local ESX
local config = require("config.server")

local function getESX()
    ESX = ESX or exports.es_extended:getSharedObject()
    return ESX
end

return {
    IsAdmin = function(source)
        local xPlayer = getESX().GetPlayerFromId(source)
        if not xPlayer then return false end
        local group = xPlayer.getGroup()
        for _, g in ipairs(config.AdminGroups or {}) do
            if g == group then return true end
        end
        return false
    end,

    GetPlayerIdentifier = function(source)
        local xPlayer = getESX().GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    end,

    GetPlayerName = function(source)
        local xPlayer = getESX().GetPlayerFromId(source)
        return xPlayer and xPlayer.getName() or "Unknown"
    end,

    AddMoney = function(source, amount)
        local xPlayer = getESX().GetPlayerFromId(source)
        if xPlayer then xPlayer.addAccountMoney("bank", amount) end
    end,

    RemoveMoney = function(source, amount)
        local xPlayer = getESX().GetPlayerFromId(source)
        if xPlayer then xPlayer.removeAccountMoney("bank", amount) end
    end,

    GetMoney = function(source)
        local xPlayer = getESX().GetPlayerFromId(source)
        if not xPlayer then return 0 end
        local account = xPlayer.getAccount("bank")
        return account and account.money or 0
    end,

    HasJob = function(source, jobName)
        local xPlayer = getESX().GetPlayerFromId(source)
        return xPlayer and xPlayer.job.name == jobName or false
    end,

    -- ESX has no duty concept: always true, so RequireOnDuty is a no-op here.
    GetJob = function(source)
        local xPlayer = getESX().GetPlayerFromId(source)
        if not xPlayer then return nil end
        return { name = xPlayer.job.name, grade = xPlayer.job.grade or 0, onDuty = true }
    end,

    GetVehicleOwner = function(plate)
        local ok, owner = pcall(MySQL.scalar.await, "SELECT owner FROM owned_vehicles WHERE TRIM(plate) = ? LIMIT 1", { plate })
        return ok and owner or nil
    end,

    -- Stock ESX has no impound state; "framework" mode can only store the vehicle. Use "event" with an impound resource.
    ImpoundVehicle = function(plate)
        local ok = pcall(MySQL.update.await, "UPDATE owned_vehicles SET stored = 1 WHERE TRIM(plate) = ?", { plate })
        return ok
    end,

    OnPlayerLoaded = function(callback)
        AddEventHandler("esx:playerLoaded", function(playerId)
            callback(playerId)
        end)
    end,

    OnPlayerUnload = function(callback)
        AddEventHandler("esx:playerDropped", function(playerId)
            callback(playerId)
        end)
    end,

    -- no-op: ESX has no standardized key system
    GiveVehicleKeys = function(_src, _vehicleNetId)
    end,
}
