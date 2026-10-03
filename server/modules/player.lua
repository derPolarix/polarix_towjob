local sharedConfig = require("config.shared")
local debug = require("shared.debug")
local Locale = require("shared.locale")

Player = {}

local PlayerCache = {}

local function computeLevel(xp)
    local thresholds = sharedConfig.XPThresholds
    local level = 1

    for i = 2, #thresholds do
        if xp >= thresholds[i] then
            level = i
        else
            break
        end
    end

    return level
end

local function reconcileStalePlayerState(source, identifier)
    -- "deployed" means "spawned in the world" — that entity is gone after a disconnect, so
    -- every deployed vehicle on load is an orphan. Re-store them all (the rental is not an
    -- owned vehicle row, so this never touches it).
    for _, vehicle in ipairs(DB.GetDeployedVehicles(identifier)) do
        DB.SetVehicleState(vehicle.id, "stored")
    end

    local delivery = DB.GetActiveDelivery(identifier)
    if not delivery then return end

    if delivery.is_test == 1 then
        DB.DeleteDelivery(delivery.id)
        debug.DebugPrint("Player.Load: dropped stale test delivery", delivery.id, "for", identifier)
        return
    end

    DB.FailDelivery(delivery.id)
    debug.DebugPrint("Player.Load: auto-failed stale active delivery", delivery.id, "for", identifier)
    TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.previous_delivery_interrupted"), "error")
end

function Player.Load(source)
    local identifier = Framework.GetPlayerIdentifier(source)
    if not identifier then
        debug.Warn("Player.Load: could not resolve identifier for source", source)
        return
    end

    local name = Framework.GetPlayerName(source)
    local row = DB.GetPlayer(identifier) or DB.CreatePlayer(identifier, name)

    PlayerCache[source] = {
        identifier = identifier,
        name = name,
        level = row.level,
        xp = row.xp,
        skill_points = row.skill_points,
        skills = (row.skills and json.decode(row.skills)) or {},
        total_earnings = row.total_earnings,
        total_deliveries = row.total_deliveries,
        failed_deliveries = row.failed_deliveries,
        aborted_deliveries = row.aborted_deliveries,
    }

    reconcileStalePlayerState(source, identifier)

    TriggerClientEvent("polarix_towjob:playerUpdate", source, Player.GetData(source))
end

function Player.Save(source)
    local player = PlayerCache[source]
    if not player then return end

    DB.SavePlayer(player.identifier, player)
end

function Player.GetData(source)
    return PlayerCache[source]
end

function Player.GetUnlockedAreaIds(source)
    local player = PlayerCache[source]
    if not player then return {} end

    local ids = DB.GetDefaultAreaIds()
    local seen = {}
    for _, id in ipairs(ids) do
        seen[id] = true
    end

    for _, id in ipairs(DB.GetUnlockedAreas(player.identifier)) do
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    return ids
end

function Player.AddXP(source, amount)
    local player = PlayerCache[source]
    if not player then return end

    player.xp = player.xp + amount

    local oldLevel = player.level
    local newLevel = computeLevel(player.xp)

    if newLevel > oldLevel then
        player.skill_points = player.skill_points + (newLevel - oldLevel) * sharedConfig.SkillPointsPerLevel
        player.level = newLevel
    end

    Player.Save(source)
    TriggerClientEvent("polarix_towjob:playerUpdate", source, Player.GetData(source))

    if newLevel > oldLevel then
        TriggerClientEvent("polarix_towjob:levelUp", source, { level = newLevel, title = Locale(sharedConfig.LevelTitles[newLevel] or "") })
    end
end

-- Called by Missions.Complete/Fail/Abort (Phase 10) to bump the relevant lifetime
-- counter. `reward` is only meaningful for "completed" — total_earnings tracks paid-out
-- money, not the mission's listed reward_base. Saves/broadcasts on its own since
-- Fail/Abort have no other mutation in flight; Complete additionally calls Player.AddXP
-- right after this, which does its own save/broadcast for the xp/level change.
function Player.RecordDeliveryOutcome(source, outcome, reward)
    local player = PlayerCache[source]
    if not player then return end

    if outcome == "completed" then
        player.total_deliveries = player.total_deliveries + 1
        player.total_earnings = player.total_earnings + (reward or 0)
    elseif outcome == "failed" then
        player.failed_deliveries = player.failed_deliveries + 1
    elseif outcome == "aborted" then
        player.aborted_deliveries = player.aborted_deliveries + 1
    end

    Player.Save(source)
    TriggerClientEvent("polarix_towjob:playerUpdate", source, Player.GetData(source))
end

function Player.HasSkill(source, skillId)
    local player = PlayerCache[source]
    if not player then return false end

    for _, id in ipairs(player.skills) do
        if id == skillId then return true end
    end

    return false
end

function Player.Unload(source)
    Player.Save(source)
    PlayerCache[source] = nil
end

Framework.OnPlayerLoaded(Player.Load)
Framework.OnPlayerUnload(Player.Unload)
