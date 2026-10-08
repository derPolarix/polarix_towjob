local debug = require("shared.debug")

Areas = {}

-- unlock_cost has the player's Access-branch discount applied so it matches what Areas.Unlock charges.
function Areas.GetMapAreas(source)
    local unlockedIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedIds[id] = true
    end

    local discount = Skills.GetAreaUnlockDiscount(source)

    local areas = {}
    for _, row in ipairs(DB.GetActiveAreas() or {}) do
        areas[#areas + 1] = {
            id = row.id,
            name = row.name,
            region = row.region,
            points = row.points and json.decode(row.points) or {},
            unlock_cost = math.floor((row.unlock_cost or 0) * (1 - discount) + 0.5),
            level_required = row.level_required,
            reward_multiplier = tonumber(row.reward_multiplier) or 1.0,
            xp_multiplier = tonumber(row.xp_multiplier) or 1.0,
            note = row.note,
            is_default = row.is_default == 1,
            unlocked = unlockedIds[row.id] == true,
        }
    end

    return areas
end

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

    local cost = math.floor((area.unlock_cost or 0) * (1 - Skills.GetAreaUnlockDiscount(source)) + 0.5)
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
