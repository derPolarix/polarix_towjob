local debug = require("shared.debug")

AdminAreas = {}

local function requireAdmin(source)
    if not Framework.IsAdmin(source) then return false, "not_admin" end
    return true
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
        row.is_active = row.is_active == 1
        row.is_default = row.is_default == 1
    end

    return { ok = true, areas = rows }
end

-- map_x/map_y are Leaflet coord-space (captured by the admin clicking the reused Phase 6
-- map component, see MapTab.vue's own comment) — never a GTA world position, no conversion
-- needed here. unlock_cost falls back to Settings.GetDefaultAreaUnlockCost() when the admin
-- leaves it blank, matching Step 13.5's "default area unlock cost" setting.
function AdminAreas.Create(source, area)
    local ok, reason = requireAdmin(source)
    if not ok then return { ok = false, reason = reason } end

    if not area.name or area.name == "" then return { ok = false, reason = "invalid_name" } end
    if area.map_x == nil or area.map_y == nil then return { ok = false, reason = "invalid_position" } end

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
    if area.map_x == nil or area.map_y == nil then return { ok = false, reason = "invalid_position" } end

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
