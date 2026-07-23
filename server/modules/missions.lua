local serverConfig = require("config.server")
local debug = require("shared.debug")

Missions = {}

function Missions.SeedIfEmpty()
    if (DB.GetMissionCount() or 0) > 0 then return end

    local seeds = serverConfig.SeedMissions
    if not seeds or #seeds == 0 then
        debug.DebugPrint("Missions.SeedIfEmpty: no SeedMissions configured, skipping")
        return
    end

    for _, mission in ipairs(seeds) do
        DB.InsertMission(mission)
    end

    debug.DebugPrint(("Missions.SeedIfEmpty: seeded %d mission(s)"):format(#seeds))
end

-- Grouped by area for the Available Jobs tab; sorting (reward/xp/distance/difficulty)
-- happens client-side (Step 5.4), this only filters by level + unlocked areas and
-- attaches a server-computed distance so the client can't spoof its own position.
function Missions.GetAvailableForPlayer(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))

    local groups = {}
    local groupIndex = {}

    for _, row in ipairs(DB.GetActiveMissionsWithAreas() or {}) do
        if row.level_required <= player.level and unlockedAreaIds[row.area_id] then
            local group = groupIndex[row.area_id]
            if not group then
                group = { area_id = row.area_id, area_name = row.area_name, region = row.area_region, missions = {} }
                groupIndex[row.area_id] = group
                groups[#groups + 1] = group
            end

            local searchCenter = vector3(row.search_center_x, row.search_center_y, row.search_center_z)

            group.missions[#group.missions + 1] = {
                id = row.id,
                name = row.name,
                vehicle_label = row.vehicle_label,
                vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or nil,
                reward_base = row.reward_base,
                xp_base = row.xp_base,
                difficulty = row.difficulty,
                time_limit_minutes = row.time_limit_minutes,
                level_required = row.level_required,
                distance = math.floor(#(playerCoords - searchCenter) + 0.5),
            }
        end
    end

    return groups
end
