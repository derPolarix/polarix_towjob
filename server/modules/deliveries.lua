local Locale = require("shared.locale")

Deliveries = {}

local LEADERBOARD_LIMIT = 10
local LEADERBOARD_CACHE_SECONDS = 30
local leaderboardCache = { entries = nil, expiresAt = 0 }

local function getCachedTopEarners()
    local now = os.time()
    if not leaderboardCache.entries or now >= leaderboardCache.expiresAt then
        leaderboardCache.entries = DB.GetTopEarners(LEADERBOARD_LIMIT) or {}
        leaderboardCache.expiresAt = now + LEADERBOARD_CACHE_SECONDS
    end
    return leaderboardCache.entries
end

-- Top-N is cached briefly; own rank/earnings are fetched fresh each call.
function Deliveries.GetLeaderboard(source)
    local topEarners = getCachedTopEarners()

    local entries = {}
    for i, row in ipairs(topEarners) do
        entries[i] = { rank = i, name = row.name, level = row.level, total_earnings = row.total_earnings }
    end

    local player = Player.GetData(source)
    local own = nil
    -- Same `total_earnings > 0` filter as DB.GetTopEarners.
    if player and (player.total_earnings or 0) > 0 then
        local ownRank = nil
        for i, row in ipairs(topEarners) do
            if row.identifier == player.identifier then
                ownRank = i
                break
            end
        end

        own = {
            rank = ownRank or DB.GetPlayerRank(player.identifier),
            name = player.name,
            level = player.level,
            total_earnings = player.total_earnings,
        }
    end

    return { entries = entries, own = own }
end

local function mapHistoryRow(row)
    return {
        id = row.id,
        missionName = row.mission_name or Locale("misc.unknown_job"),
        status = row.status,
        rewardPaid = row.reward_paid,
        xpPaid = row.xp_paid,
        damagePenalty = row.damage_penalty,
        startedAt = row.started_at,
        completedAt = row.completed_at,
    }
end

local RECENT_DEFAULT_LIMIT = 5

function Deliveries.GetRecentForPlayer(source, limit)
    local player = Player.GetData(source)
    if not player then return { entries = {} } end

    limit = tonumber(limit) or RECENT_DEFAULT_LIMIT

    local rows = DB.GetDeliveryHistory(player.identifier, limit, 0) or {}
    local entries = {}
    for i, row in ipairs(rows) do
        entries[i] = mapHistoryRow(row)
    end

    return { entries = entries }
end

local HISTORY_PAGE_SIZE = 20

function Deliveries.GetHistoryPage(source, offset)
    local player = Player.GetData(source)
    if not player then return { entries = {}, total = 0, offset = 0, pageSize = HISTORY_PAGE_SIZE } end

    offset = math.max(0, tonumber(offset) or 0)

    local rows = DB.GetDeliveryHistory(player.identifier, HISTORY_PAGE_SIZE, offset) or {}
    local entries = {}
    for i, row in ipairs(rows) do
        entries[i] = mapHistoryRow(row)
    end

    return {
        entries = entries,
        total = DB.GetDeliveryCount(player.identifier) or 0,
        offset = offset,
        pageSize = HISTORY_PAGE_SIZE,
    }
end
