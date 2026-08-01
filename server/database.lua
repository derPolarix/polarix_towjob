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

function DB.CompleteDelivery(deliveryId, rewardPaid, xpPaid, damagePenalty)
    MySQL.update.await(
        "UPDATE " .. server.Tables.deliveries .. " SET status = 'completed', reward_paid = ?, xp_paid = ?, damage_penalty = ?, completed_at = NOW() WHERE id = ?",
        { rewardPaid, xpPaid, damagePenalty, deliveryId }
    )
end

function DB.AbortDelivery(deliveryId)
    MySQL.update.await("UPDATE " .. server.Tables.deliveries .. " SET status = 'aborted', completed_at = NOW() WHERE id = ?", { deliveryId })
end

function DB.GetTopEarners(limit)
    return MySQL.query.await(
        "SELECT identifier, name, level, total_earnings FROM " .. server.Tables.players .. " ORDER BY total_earnings DESC LIMIT ?",
        { limit }
    )
end

function DB.GetPlayerRank(identifier)
    return MySQL.scalar.await([[
        SELECT COUNT(*) + 1 FROM ]] .. server.Tables.players .. [[
        WHERE total_earnings > (SELECT total_earnings FROM ]] .. server.Tables.players .. [[ WHERE identifier = ?)
    ]], { identifier }) or 1
end

-- LEFT JOIN, not DB.GetMission's `is_active = 1`-filtered lookup: a deactivated or
-- (per Step 13.3) hard-deleted mission template must not erase its own delivery history.
function DB.GetDeliveryHistory(identifier, limit, offset)
    return MySQL.query.await([[
        SELECT d.id, d.status, d.reward_paid, d.xp_paid, d.damage_penalty, d.started_at, d.completed_at, m.name AS mission_name
        FROM ]] .. server.Tables.deliveries .. [[ d
        LEFT JOIN ]] .. server.Tables.missions .. [[ m ON m.id = d.mission_id
        WHERE d.identifier = ?
        ORDER BY d.started_at DESC
        LIMIT ? OFFSET ?
    ]], { identifier, limit, offset })
end

function DB.GetDeliveryCount(identifier)
    return MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.deliveries .. " WHERE identifier = ?", { identifier }) or 0
end

-- Phase 13: admin CRUD helpers. Unlike DB.GetArea/DB.GetMission (player-facing, hard-filtered
-- to is_active = 1), these intentionally return every row so the Admin UI can see/manage
-- deactivated content too.
function DB.GetAllAreasAdmin()
    return MySQL.query.await("SELECT * FROM " .. server.Tables.areas .. " ORDER BY id")
end

function DB.AreaIdExists(areaId)
    return (MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.areas .. " WHERE id = ?", { areaId }) or 0) > 0
end

function DB.UpdateArea(areaId, area)
    MySQL.update.await(
        "UPDATE " .. server.Tables.areas .. " SET name=?, region=?, map_x=?, map_y=?, unlock_cost=?, level_required=?, is_default=? WHERE id=?",
        { area.name, area.region, area.map_x, area.map_y, area.unlock_cost or 0, area.level_required or 1, area.is_default and 1 or 0, areaId }
    )
end

function DB.SetAreaActive(areaId, isActive)
    MySQL.update.await("UPDATE " .. server.Tables.areas .. " SET is_active = ? WHERE id = ?", { isActive and 1 or 0, areaId })
end

-- LEFT JOIN (not DB.GetActiveMissionsWithAreas' is_active-filtered join) so a mission
-- whose area was deactivated still shows up for editing.
function DB.GetAllMissionsAdmin()
    return MySQL.query.await([[
        SELECT m.*, a.name AS area_name
        FROM ]] .. server.Tables.missions .. [[ m
        LEFT JOIN ]] .. server.Tables.areas .. [[ a ON a.id = m.area_id
        ORDER BY m.id
    ]])
end

function DB.MissionIdExists(missionId)
    return (MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.missions .. " WHERE id = ?", { missionId }) or 0) > 0
end

-- Flat column shape (matches DB.GetAllMissionsAdmin's SELECT output and the admin form) —
-- unlike DB.InsertMission, which keeps its nested search_center/dropoff shape because
-- config/server.lua's SeedMissions data is written that way and Missions.SeedIfEmpty
-- depends on it unchanged.
function DB.UpdateMission(missionId, mission, adminIdentifier)
    MySQL.update.await("UPDATE " .. server.Tables.missions .. [[ SET
        area_id=?, name=?, vehicle_model=?, vehicle_label=?, vehicle_colors=?,
        search_center_x=?, search_center_y=?, search_center_z=?, search_radius=?,
        dropoff_x=?, dropoff_y=?, dropoff_z=?, dropoff_heading=?, dropoff_width=?, dropoff_length=?,
        reward_base=?, xp_base=?, time_limit_minutes=?, difficulty=?, level_required=?, updated_by=?
        WHERE id=?
    ]], {
        mission.area_id, mission.name, mission.vehicle_model, mission.vehicle_label,
        json.encode(mission.vehicle_colors or {}),
        mission.search_center_x, mission.search_center_y, mission.search_center_z, mission.search_radius or 60.0,
        mission.dropoff_x, mission.dropoff_y, mission.dropoff_z, mission.dropoff_heading or 0.0,
        mission.dropoff_width or 6.0, mission.dropoff_length or 10.0,
        mission.reward_base, mission.xp_base, mission.time_limit_minutes, mission.difficulty or "easy",
        mission.level_required or 1, adminIdentifier, missionId,
    })
end

function DB.SetMissionActive(missionId, isActive, adminIdentifier)
    MySQL.update.await("UPDATE " .. server.Tables.missions .. " SET is_active = ?, updated_by = ? WHERE id = ?", { isActive and 1 or 0, adminIdentifier, missionId })
end

-- DB.InsertMission (seed + admin create) doesn't know about the audit columns, so admin
-- create calls this right after to stamp both created_by/updated_by in one statement.
function DB.SetMissionCreatedBy(missionId, adminIdentifier)
    MySQL.update.await("UPDATE " .. server.Tables.missions .. " SET created_by = ?, updated_by = ? WHERE id = ?", { adminIdentifier, adminIdentifier, missionId })
end

function DB.CountDeliveriesForMission(missionId)
    return MySQL.scalar.await("SELECT COUNT(*) FROM " .. server.Tables.deliveries .. " WHERE mission_id = ?", { missionId }) or 0
end

function DB.DeleteMissionHard(missionId)
    MySQL.query.await("DELETE FROM " .. server.Tables.missions .. " WHERE id = ?", { missionId })
end

function DB.GetAllSettings()
    return MySQL.query.await("SELECT * FROM " .. server.Tables.settings)
end

function DB.UpsertSetting(key, value, adminIdentifier)
    MySQL.query.await(
        "INSERT INTO " .. server.Tables.settings .. " (setting_key, setting_value, updated_by) VALUES (?, ?, ?) " ..
        "ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)",
        { key, json.encode(value), adminIdentifier }
    )
end