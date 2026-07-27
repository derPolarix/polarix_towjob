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

function DB.GetAreaCount()
    return MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.areas) or 0
end

function DB.InsertArea(area)
    MySQL.insert.await("INSERT INTO " .. server.Tables.areas .. " (id, name, region, map_x, map_y, unlock_cost, level_required, is_default) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", {
        area.id,
        area.name,
        area.region,
        area.map_x,
        area.map_y,
        area.unlock_cost or 0,
        area.level_required or 1,
        area.is_default and 1 or 0,
    })
end

function DB.GetArea(areaId)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.areas .. " WHERE id = ? AND is_active = 1", { areaId })
end

function DB.GetActiveAreas()
    return MySQL.query.await("SELECT * FROM " .. server.Tables.areas .. " WHERE is_active = 1")
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

function DB.GetMissionCount()
    return MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.missions) or 0
end

function DB.InsertMission(mission)
    MySQL.insert.await("INSERT INTO " .. server.Tables.missions .. [[ (
        id, area_id, name, vehicle_model, vehicle_label, vehicle_colors,
        search_center_x, search_center_y, search_center_z, search_radius,
        dropoff_x, dropoff_y, dropoff_z, dropoff_heading, dropoff_width, dropoff_length,
        reward_base, xp_base, time_limit_minutes, difficulty, level_required
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        mission.id,
        mission.area_id,
        mission.name,
        mission.vehicle_model,
        mission.vehicle_label,
        json.encode(mission.vehicle_colors or {}),
        mission.search_center.x,
        mission.search_center.y,
        mission.search_center.z,
        mission.search_radius or 60.0,
        mission.dropoff.x,
        mission.dropoff.y,
        mission.dropoff.z,
        mission.dropoff.heading,
        mission.dropoff_width or 6.0,
        mission.dropoff_length or 10.0,
        mission.reward_base,
        mission.xp_base,
        mission.time_limit_minutes,
        mission.difficulty or "easy",
        mission.level_required or 1,
    })
end

function DB.GetOwnedVehicles(identifier)
    return MySQL.query.await("SELECT * FROM " .. server.Tables.vehicles .. " WHERE identifier = ? ORDER BY purchased_at ASC", { identifier })
end

function DB.GetVehicle(vehicleId)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.vehicles .. " WHERE id = ?", { vehicleId })
end

function DB.GetVehicleByPlate(plate)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.vehicles .. " WHERE plate = ?", { plate })
end

function DB.CreateVehicle(identifier, tierId, plate)
    return MySQL.insert.await("INSERT INTO " .. server.Tables.vehicles .. " (identifier, tier_id, plate) VALUES (?, ?, ?)", { identifier, tierId, plate })
end

function DB.SaveVehicleHealth(vehicleId, bodyHealth, engineHealth)
    MySQL.update.await("UPDATE " .. server.Tables.vehicles .. " SET body_health = ?, engine_health = ? WHERE id = ?", { bodyHealth, engineHealth, vehicleId })
end

-- Joins area name/region in for Missions.GetAvailableForPlayer's grouped-by-area output.
function DB.GetActiveMissionsWithAreas()
    return MySQL.query.await([[
        SELECT m.*, a.name AS area_name, a.region AS area_region
        FROM ]] .. server.Tables.missions .. [[ m
        JOIN ]] .. server.Tables.areas .. [[ a ON a.id = m.area_id
        WHERE m.is_active = 1 AND a.is_active = 1
    ]])
end

function DB.GetMission(missionId)
    return MySQL.single.await("SELECT * FROM " .. server.Tables.missions .. " WHERE id = ? AND is_active = 1", { missionId })
end

function DB.CreateDelivery(missionId, identifier, usedRental)
    return MySQL.insert.await(
        "INSERT INTO " .. server.Tables.deliveries .. " (mission_id, identifier, status, used_rental) VALUES (?, ?, 'active', ?)",
        { missionId, identifier, usedRental and 1 or 0 }
    )
end