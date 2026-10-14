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

-- The admin form uses flat columns; DB.InsertMission expects the nested dropoff shape of seed_data.lua, so reshape here.
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
        reward_per_km = flat.reward_per_km,
        xp_per_km = flat.xp_per_km,
        time_limit_minutes = flat.time_limit_minutes,
        difficulty = flat.difficulty,
        level_required = flat.level_required,
    }
end

-- Every point needs a complete coordinate; the spawn path has no radius fallback.
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

local function validateMission(mission, exceptId)
    if not mission.name or mission.name == "" then return "invalid_name" end
    if DB.MissionNameTaken(mission.name, exceptId) then return "name_taken" end
    if not mission.area_id or not DB.AreaIdExists(mission.area_id) then return "invalid_area" end
    if not mission.vehicle_model or mission.vehicle_model == "" then return "invalid_vehicle_model" end
    if type(mission.reward_base) ~= "number" or mission.reward_base <= 0
        or type(mission.xp_base) ~= "number" or mission.xp_base <= 0 then
        return "invalid_reward"
    end

    for _, key in ipairs({ "reward_per_km", "xp_per_km" }) do
        if mission[key] ~= nil and (type(mission[key]) ~= "number" or mission[key] < 0) then return "invalid_reward" end
    end

    for _, key in ipairs({ "dropoff_x", "dropoff_y", "dropoff_z", "dropoff_heading" }) do
        if type(mission[key]) ~= "number" then return "invalid_position" end
    end

    if type(mission.dropoff_width) ~= "number" or mission.dropoff_width <= 0
        or type(mission.dropoff_length) ~= "number" or mission.dropoff_length <= 0 then
        return "invalid_field"
    end
    if type(mission.level_required) ~= "number" or mission.level_required < 1 then return "invalid_field" end
    if mission.time_limit_minutes ~= nil and (type(mission.time_limit_minutes) ~= "number" or mission.time_limit_minutes < 1) then
        return "invalid_field"
    end
    if mission.difficulty ~= "easy" and mission.difficulty ~= "medium" and mission.difficulty ~= "hard" then
        return "invalid_field"
    end

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
        row.is_active = DB.ToBool(row.is_active)
        row.delivery_count = DB.CountDeliveriesForMission(row.id)
    end

    return { ok = true, missions = rows, testActive = Missions.IsTestActive(source) }
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

    local invalidReason = validateMission(mission, missionId)
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

-- Hard-delete only when no delivery references the mission, so history joins keep their mission_name; otherwise soft-delete.
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

-- Areas and missions import as one set (seed missions reference seed area ids); refused if either table has rows. The UI button is a hint, not the gate.
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

-- Bypasses level/area gates but not Missions.Accept's own active-delivery/vehicle checks, so a test can't leave the admin stuck. Re-checks IsAdmin.
function AdminMissions.TestRun(source, missionId)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    return Missions.Accept(source, missionId, true)
end

function AdminMissions.EndTest(source)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    local state = Missions.GetActiveDeliveryState(source)
    if not state or not state.isTest then return { ok = false, reason = "no_active_test" } end

    return Missions.FinishTest(source, state.deliveryId, "aborted")
end

lib.callback.register("polarix_towjob:adminListMissions", function(source) return AdminMissions.ListForAdmin(source) end)
lib.callback.register("polarix_towjob:adminCreateMission", function(source, mission) return AdminMissions.Create(source, mission) end)
lib.callback.register("polarix_towjob:adminUpdateMission", function(source, missionId, mission) return AdminMissions.Update(source, missionId, mission) end)
lib.callback.register("polarix_towjob:adminSetMissionActive", function(source, missionId, isActive) return AdminMissions.SetActive(source, missionId, isActive) end)
lib.callback.register("polarix_towjob:adminDeleteMission", function(source, missionId) return AdminMissions.Delete(source, missionId) end)
lib.callback.register("polarix_towjob:adminImportSeedData", function(source) return AdminMissions.ImportSeedData(source) end)
lib.callback.register("polarix_towjob:adminEndTestMission", function(source) return AdminMissions.EndTest(source) end)
lib.callback.register("polarix_towjob:adminTestRunMission", function(source, missionId) return AdminMissions.TestRun(source, missionId) end)
