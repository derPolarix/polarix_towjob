local debug = require("shared.debug")
local server = require("config.server")
local shared = require("shared.debug")

function LoadDatabaseToCache()
    -- Example function to load data from the database into a cache
    -- local result = MySQL.query.await("SELECT * FROM " .. server.database_table)

    -- for _, row in ipairs(result) do
    --     LocalCache.table[row.COLUMNNAME] = row
    -- end
    -- return true
end

DB = {}

function DB.GetPlayer(identifier)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.players .. " WHERE identifier = ?", { identifier })
end

function DB.CreatePlayer(identifier, name)
    MySQL.insert.await("INSERT INTO " .. server.Tables.players .. " (identifier, name) VALUES (?, ?)", { identifier, name })
    return DB.GetPlayer(identifier)
end

function DB.SavePlayer(identifier, data)
    MySQL.update.await("UPDATE " .. server.Tables.players .. " SET name = ?, level = ?, xp = ?, skill_points = ?, skills = ?, total_earnings = ?, total_deliveries = ?, failed_deliveries = ?, aborted_deliveries = ? WHERE identifier = ?", {
        data.name,
        data.level,
        data.xp,
        data.skill_points,
        json.encode(data.skills or {}),
        data.total_earnings,
        data.total_deliveries,
        data.failed_deliveries,
        data.aborted_deliveries,
        identifier,
    })
end

function DB.GetDefaultAreaIds()
    local rows = MySQL.query.await("SELECT id FROM " .. server.Tables.areas .. " WHERE is_default = 1 AND is_active = 1")
    local ids = {}
    for _, row in ipairs(rows or {}) do
        ids[#ids + 1] = row.id
    end
    return ids
end

function DB.GetUnlockedAreas(identifier)
    local rows = MySQL.query.await("SELECT area_id FROM " .. server.Tables.player_areas .. " WHERE identifier = ?", { identifier })
    local ids = {}
    for _, row in ipairs(rows or {}) do
        ids[#ids + 1] = row.area_id
    end
    return ids
end

function DB.UnlockArea(identifier, areaId)
    MySQL.insert.await("INSERT IGNORE INTO " .. server.Tables.player_areas .. " (identifier, area_id) VALUES (?, ?)", { identifier, areaId })
end

-- Used by Player.Load's stale-delivery cleanup (Step 3.4); DB.SetVehicleState is also
-- the exact function Phase 7.1 specifies, so vehicle purchase/repair/garage code should
-- call this same one rather than adding a duplicate.
function DB.GetActiveDelivery(identifier)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.deliveries .. " WHERE identifier = ? AND status = 'active' LIMIT 1", { identifier })
end

function DB.FailDelivery(deliveryId)
    MySQL.update.await("UPDATE " .. server.Tables.deliveries .. " SET status = 'failed', completed_at = NOW() WHERE id = ?", { deliveryId })
end

function DB.GetDeployedVehicles(identifier)
    return MySQL.query.await("SELECT * FROM " .. server.Tables.vehicles .. " WHERE identifier = ? AND state = 'deployed'", { identifier })
end

function DB.SetVehicleState(vehicleId, state)
    MySQL.update.await("UPDATE " .. server.Tables.vehicles .. " SET state = ? WHERE id = ?", { state, vehicleId })
end