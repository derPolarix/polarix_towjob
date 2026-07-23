local serverConfig = require("config.server")
local debug = require("shared.debug")

Areas = {}

function Areas.SeedIfEmpty()
    if (DB.GetAreaCount() or 0) > 0 then return end

    local seeds = serverConfig.SeedAreas
    if not seeds or #seeds == 0 then
        debug.DebugPrint("Areas.SeedIfEmpty: no SeedAreas configured, skipping")
        return
    end

    for _, area in ipairs(seeds) do
        DB.InsertArea(area)
    end

    debug.DebugPrint(("Areas.SeedIfEmpty: seeded %d area(s)"):format(#seeds))
end

-- Full active-area list for the Map tab, each flagged `unlocked` from this player's
-- perspective (default areas + polarix_towjob_player_areas rows).
function Areas.GetMapAreas(source)
    local unlockedIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedIds[id] = true
    end

    local areas = {}
    for _, row in ipairs(DB.GetActiveAreas() or {}) do
        areas[#areas + 1] = {
            id = row.id,
            name = row.name,
            region = row.region,
            map_x = row.map_x,
            map_y = row.map_y,
            unlock_cost = row.unlock_cost,
            level_required = row.level_required,
            is_default = row.is_default == 1,
            unlocked = unlockedIds[row.id] == true,
        }
    end

    return areas
end

-- Re-validates cost/level requirement server-side (ground rule 4) — never trusts that
-- the client only shows the unlock button because it met these conditions itself.
function Areas.Unlock(source, areaId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local area = DB.GetArea(areaId)
    if not area then return { ok = false, reason = "area_not_found" } end

    local unlockedIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedIds[id] = true
    end

    if area.is_default == 1 or unlockedIds[areaId] then
        return { ok = false, reason = "already_unlocked" }
    end

    if player.level < (area.level_required or 1) then
        return { ok = false, reason = "level_too_low" }
    end

    local cost = area.unlock_cost or 0
    if cost > 0 then
        if Framework.GetMoney(source) < cost then
            return { ok = false, reason = "insufficient_funds" }
        end
        Framework.RemoveMoney(source, cost)
    end

    DB.UnlockArea(player.identifier, areaId)

    debug.DebugPrint(("Areas.Unlock: %s unlocked area %s for %d"):format(player.identifier, areaId, cost))

    return { ok = true, areaId = areaId, unlockedAreaIds = Player.GetUnlockedAreaIds(source) }
end
