local debug = require("shared.debug")

AdminAreas = {}

local function requireAdmin(source)
    if not Framework.IsAdmin(source) then return false, "not_admin" end
    return true
end

-- An area is a polygon, not a pin — needs at least 3 vertices to enclose any space.
local function isValidPoints(points)
    if type(points) ~= "table" or #points < 3 then return false end
    for _, point in ipairs(points) do
        if type(point) ~= "table" or type(point.x) ~= "number" or type(point.y) ~= "number" then
            return false
        end
    end
    return true
end

local function isValidMultiplier(value)
    return value == nil or (type(value) == "number" and value >= 0 and value <= 10)
end

local function slugify(name)
    local base = "area_" .. (name or "area"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "area_" then base = "area_untitled" end

    local candidate = base
    local suffix = 0
    while DB.AreaIdExists(candidate) do
        suffix = suffix + 1
        candidate = ("%s_%d"):format(base, suffix)
    end
    return candidate
end

function AdminAreas.ListForAdmin(source)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    local rows = DB.GetAllAreasAdmin()
    for _, row in ipairs(rows) do
        row.is_active = DB.ToBool(row.is_active)
        row.is_default = DB.ToBool(row.is_default)
        row.reward_multiplier = tonumber(row.reward_multiplier) or 1.0
        row.xp_multiplier = tonumber(row.xp_multiplier) or 1.0
        row.points = row.points and json.decode(row.points) or {}
    end

    return { ok = true, areas = rows }
end

-- points are GTA world coords, stored verbatim (the map component converts clicks, see web/src/lib/gtaMap.ts). unlock_cost falls back to the default setting when blank.
function AdminAreas.Create(source, area)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    if not area.name or area.name == "" then return { ok = false, reason = "invalid_name" } end
    if DB.AreaNameTaken(area.name) then return { ok = false, reason = "name_taken" } end
    if not isValidPoints(area.points) then return { ok = false, reason = "invalid_position" } end
    if not isValidMultiplier(area.reward_multiplier) or not isValidMultiplier(area.xp_multiplier) then
        return { ok = false, reason = "invalid_multiplier" }
    end

    local areaId = slugify(area.name)
    area.id = areaId
    if area.unlock_cost == nil then
        area.unlock_cost = Settings.GetDefaultAreaUnlockCost()
    end

    DB.InsertArea(area)

    debug.DebugPrint(("AdminAreas.Create: created area %s"):format(areaId))

    return { ok = true, areaId = areaId }
end

function AdminAreas.Update(source, areaId, area)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end
    if not DB.AreaIdExists(areaId) then return { ok = false, reason = "not_found" } end

    if not area.name or area.name == "" then return { ok = false, reason = "invalid_name" } end
    if DB.AreaNameTaken(area.name, areaId) then return { ok = false, reason = "name_taken" } end
    if not isValidPoints(area.points) then return { ok = false, reason = "invalid_position" } end
    if not isValidMultiplier(area.reward_multiplier) or not isValidMultiplier(area.xp_multiplier) then
        return { ok = false, reason = "invalid_multiplier" }
    end

    DB.UpdateArea(areaId, area)

    debug.DebugPrint(("AdminAreas.Update: updated area %s"):format(areaId))

    return { ok = true }
end

function AdminAreas.SetActive(source, areaId, isActive)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end
    if not DB.AreaIdExists(areaId) then return { ok = false, reason = "not_found" } end

    DB.SetAreaActive(areaId, isActive)

    return { ok = true }
end

lib.callback.register("polarix_towjob:adminListAreas", function(source) return AdminAreas.ListForAdmin(source) end)
lib.callback.register("polarix_towjob:adminCreateArea", function(source, area) return AdminAreas.Create(source, area) end)
lib.callback.register("polarix_towjob:adminUpdateArea", function(source, areaId, area) return AdminAreas.Update(source, areaId, area) end)
lib.callback.register("polarix_towjob:adminSetAreaActive", function(source, areaId, isActive) return AdminAreas.SetActive(source, areaId, isActive) end)
