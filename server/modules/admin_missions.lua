local debug = require("shared.debug")
local serverConfig = require("config.server")
local seedData = require("server.seed_data")

AdminMissions = {}

local function requireAdmin(source)
    if not Framework.IsAdmin(source) then return false, "not_admin" end
    return true
end

local function slugify(name)
    local base = "mission_" .. (name or "mission"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "mission_" then base = "mission_untitled" end

    local candidate = base
    local suffix = 0
    while DB.MissionIdExists(candidate) do
        suffix = suffix + 1
        candidate = ("%s_%d"):format(base, suffix)
    end
    return candidate
end

-- The admin form works with flat columns (matches DB.GetAllMissionsAdmin's SELECT output
-- and DB.UpdateMission's flat shape) but DB.InsertMission expects the nested
-- dropoff shape config/server.lua's SeedMissions data uses — reshape here
-- rather than duplicating the INSERT statement or changing InsertMission's seed-facing signature.
local function toNestedMission(flat)
    return {
        area_id = flat.area_id,
        name = flat.name,
        vehicle_model = flat.vehicle_model,
        vehicle_label = flat.vehicle_label,
        vehicle_colors = flat.vehicle_colors,
        spawn_points = flat.spawn_points,
        dropoff = { x = flat.dropoff_x, y = flat.dropoff_y, z = flat.dropoff_z, heading = flat.dropoff_heading },
        dropoff_width = flat.dropoff_width,
        dropoff_length = flat.dropoff_length,
        reward_base = flat.reward_base,
        xp_base = flat.xp_base,
        time_limit_minutes = flat.time_limit_minutes,
        difficulty = flat.difficulty,
        level_required = flat.level_required,
    }
end

-- Re-validated here rather than trusted from the NUI form (ground rule 4): every point must
-- carry a complete coordinate, because the spawn path has no radius left to fall back on.
local function validateSpawnPoints(points)
    if type(points) ~= "table" or #points < 1 then return "no_spawn_points" end
    if #points > serverConfig.MaxSpawnPointsPerMission then return "too_many_spawn_points" end

    for _, point in ipairs(points) do
        if type(point) ~= "table"
            or type(point.x) ~= "number" or type(point.y) ~= "number" or type(point.z) ~= "number"
            or type(point.heading) ~= "number" then
            return "invalid_spawn_point"
        end
    end

    return nil
end

local function validateMission(mission)
    if not mission.name or mission.name == "" then return "invalid_name" end
    if not mission.area_id or not DB.AreaIdExists(mission.area_id) then return "invalid_area" end
    if not mission.vehicle_model or mission.vehicle_model == "" then return "invalid_vehicle_model" end
    if type(mission.reward_base) ~= "number" or type(mission.xp_base) ~= "number" then return "invalid_reward" end
    if mission.dropoff_x == nil then return "invalid_position" end

    local spawnPointsReason = validateSpawnPoints(mission.spawn_points)
    if spawnPointsReason then return spawnPointsReason end

    return nil
end

function AdminMissions.ListForAdmin(source)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    local rows = DB.GetAllMissionsAdmin()
    for _, row in ipairs(rows) do
        row.vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or { primary = 0, secondary = 0 }
        row.spawn_points = row.spawn_points and json.decode(row.spawn_points) or {}
        row.is_active = row.is_active == 1
        row.delivery_count = DB.CountDeliveriesForMission(row.id)
    end

    return { ok = true, missions = rows }
end

function AdminMissions.Create(source, mission)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    local invalidReason = validateMission(mission)
    if invalidReason then return { ok = false, reason = invalidReason } end

    local player = Player.GetData(source)
    local missionId = slugify(mission.name)

    local nested = toNestedMission(mission)
    nested.id = missionId
    DB.InsertMission(nested)
    DB.SetMissionCreatedBy(missionId, player and player.identifier)

    debug.DebugPrint(("AdminMissions.Create: %s created mission %s"):format(player and player.identifier or source, missionId))

    return { ok = true, missionId = missionId }
end

function AdminMissions.Update(source, missionId, mission)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end
    if not DB.MissionIdExists(missionId) then return { ok = false, reason = "not_found" } end

    local invalidReason = validateMission(mission)
    if invalidReason then return { ok = false, reason = invalidReason } end

    local player = Player.GetData(source)
    DB.UpdateMission(missionId, mission, player and player.identifier)

    debug.DebugPrint(("AdminMissions.Update: %s updated mission %s"):format(player and player.identifier or source, missionId))

    return { ok = true }
end

function AdminMissions.SetActive(source, missionId, isActive)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end
    if not DB.MissionIdExists(missionId) then return { ok = false, reason = "not_found" } end

    local player = Player.GetData(source)
    DB.SetMissionActive(missionId, isActive, player and player.identifier)

    return { ok = true }
end

-- Soft-delete (is_active=0, via SetActive) is always available; hard-delete only when
-- no delivery row references this mission, so History/Leaderboard-adjacent joins never
-- lose their mission_name lookup for a completed/failed/aborted delivery (Phase 12's
-- DB.GetDeliveryHistory already LEFT JOINs for exactly this reason).
function AdminMissions.Delete(source, missionId)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    if DB.CountDeliveriesForMission(missionId) > 0 then
        return { ok = false, reason = "has_delivery_history" }
    end

    DB.DeleteMissionHard(missionId)

    debug.DebugPrint(("AdminMissions.Delete: mission %s hard-deleted"):format(missionId))

    return { ok = true }
end

-- Areas and missions import as one set: the seed missions reference the seed area ids, so
-- a server with either table populated has content of its own and is left alone (the Admin
-- UI only offers the button when both lists are empty, but that is a hint, not the gate).
function AdminMissions.ImportSeedData(source)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    if (DB.GetMissionCount() or 0) > 0 or (DB.GetAreaCount() or 0) > 0 then
        return { ok = false, reason = "not_empty" }
    end

    for _, area in ipairs(seedData.areas) do
        DB.InsertArea(area)
    end

    for _, mission in ipairs(seedData.missions) do
        DB.InsertMission(mission)
    end

    debug.DebugPrint(("AdminMissions.ImportSeedData: imported %d area(s) and %d mission(s)")
        :format(#seedData.areas, #seedData.missions))

    return { ok = true, areas = #seedData.areas, missions = #seedData.missions }
end

-- Step 13.3: QA-only test button — bypasses level_required/area_locked (the mission-
-- availability gates) the same way trucker job's TestRun bypasses level/hazmat/long-hauler,
-- but never the player's own active-delivery/vehicle-state checks inside Missions.Accept,
-- so testing can never leave the admin's own account stuck (e.g. a phantom active delivery
-- or a desynced vehicle). Re-checks Framework.IsAdmin itself (ground rule 4) even though the
-- NUI callback -> lib.callback path that reaches this already does too.
function AdminMissions.TestRun(source, missionId)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    return Missions.Accept(source, missionId, true)
end

lib.callback.register("polarix_towjob:adminListMissions", function(source) return AdminMissions.ListForAdmin(source) end)
lib.callback.register("polarix_towjob:adminCreateMission", function(source, mission) return AdminMissions.Create(source, mission) end)
lib.callback.register("polarix_towjob:adminUpdateMission", function(source, missionId, mission) return AdminMissions.Update(source, missionId, mission) end)
lib.callback.register("polarix_towjob:adminSetMissionActive", function(source, missionId, isActive) return AdminMissions.SetActive(source, missionId, isActive) end)
lib.callback.register("polarix_towjob:adminDeleteMission", function(source, missionId) return AdminMissions.Delete(source, missionId) end)
lib.callback.register("polarix_towjob:adminImportSeedData", function(source) return AdminMissions.ImportSeedData(source) end)
lib.callback.register("polarix_towjob:adminTestRunMission", function(source, missionId) return AdminMissions.TestRun(source, missionId) end)
