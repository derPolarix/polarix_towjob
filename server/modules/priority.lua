local serverConfig = require("config.server")
local debug = require("shared.debug")
local Locale = require("shared.locale")

Priority = {}

-- Police-marked tow subjects ("tow requests"). Deliberately in-memory only, same precedent
-- as OnCall's state: a job points at one live world entity by netId, and neither the entity
-- nor its netId survives a resource restart — persisting the job would outlive the thing it
-- describes. Each entry doubles as a mission row (see buildJobRow) so every existing
-- accept/complete path in server/modules/missions.lua works on it unchanged.
local pool = {} -- FIFO: oldest request is offered first
local sequence = 0
local lastMarkAt = {} -- [identifier] = os.time()

local ID_PREFIX = "prio_"

function Priority.IsPriorityId(missionId)
    return type(missionId) == "string" and missionId:sub(1, #ID_PREFIX) == ID_PREFIX
end

local function trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

local function findById(missionId)
    for _, job in ipairs(pool) do
        if job.id == missionId then return job end
    end
end

local function findByNetId(netId)
    for _, job in ipairs(pool) do
        if job.netId == netId then return job end
    end
end

-- Job/grade gate. Returns the job table only when this source may mark; nil otherwise, so
-- callers can use it as both the permission check and the job lookup.
local function officerJob(source)
    if not Framework.GetJob then return nil end

    local job = Framework.GetJob(source)
    if not job or not job.name then return nil end

    local minGrade = (serverConfig.PoliceJobs or {})[job.name]
    if minGrade == nil then return nil end
    if (job.grade or 0) < minGrade then return nil end
    if serverConfig.RequireOnDuty and not job.onDuty then return nil end

    return job
end

function Priority.CanMark(source)
    return officerJob(source) ~= nil
end

local function authorizedOfficers()
    local officers = {}
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source and officerJob(source) then officers[#officers + 1] = source end
    end
    return officers
end

local function resolveSourceByIdentifier(identifier, hintSource)
    if hintSource and Framework.GetPlayerIdentifier(hintSource) == identifier then return hintSource end

    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source and Framework.GetPlayerIdentifier(source) == identifier then return source end
    end
end

local function notifyMarker(job, message, notifyType)
    local source = resolveSourceByIdentifier(job.markedByIdentifier, job.markedBy)
    if not source then return end
    TriggerClientEvent("polarix_towjob:notify", source, message, notifyType or "info")
end

-- Blips live with every authorized officer, not just the marker, so a second unit can see a
-- car is already called in rather than re-marking it. They stay up while a job is claimed —
-- "someone is on the way" is exactly what the officer wants to know.
local function blipPayload(job)
    return {
        id = job.id,
        label = job.vehicle_label,
        coords = { x = job.markedCoords.x, y = job.markedCoords.y, z = job.markedCoords.z },
    }
end

local function broadcastAdded(job)
    for _, source in ipairs(authorizedOfficers()) do
        TriggerClientEvent("polarix_towjob:priorityJobAdded", source, blipPayload(job))
    end
end

local function broadcastRemoved(jobId)
    for _, source in ipairs(authorizedOfficers()) do
        TriggerClientEvent("polarix_towjob:priorityJobRemoved", source, jobId)
    end
end

-- Sent to an officer on load so a mid-session connect still sees the open requests.
function Priority.GetBlipsForOfficer(source)
    if not officerJob(source) then return {} end

    local blips = {}
    for i, job in ipairs(pool) do
        blips[i] = blipPayload(job)
    end
    return blips
end

local function removeJob(job, markerMessage, notifyType)
    for i, entry in ipairs(pool) do
        if entry == job then
            table.remove(pool, i)
            break
        end
    end

    broadcastRemoved(job.id)
    if markerMessage then notifyMarker(job, markerMessage, notifyType) end
end

local towTruckModels = nil
local function isTowTruckModel(modelHash)
    if not towTruckModels then
        towTruckModels = {}
        for _, tier in ipairs(serverConfig.VehicleTiers or {}) do
            towTruckModels[GetHashKey(tier.model)] = true
        end
        if serverConfig.RentalTruck then towTruckModels[GetHashKey(serverConfig.RentalTruck.model)] = true end
    end

    return towTruckModels[modelHash] == true
end

-- Donor mission: the marked car is towed to the nearest active mission's dropoff, and
-- inherits that mission's area purely so the area reward/xp multipliers still apply
-- (the area *gates* are skipped for priority jobs — confirmed design).
local function findNearestDonorMission(coords)
    local best, bestDistance

    for _, row in ipairs(DB.GetActiveMissionsWithAreas() or {}) do
        local distance = #(coords - vector3(row.dropoff_x, row.dropoff_y, row.dropoff_z))
        if not bestDistance or distance < bestDistance then
            best, bestDistance = row, distance
        end
    end

    return best, bestDistance
end

local function scaledValue(spec, distance)
    if not spec then return 0 end
    return math.floor(math.min(spec.max or math.huge, (spec.base or 0) + (spec.perMeter or 0) * distance) + 0.5)
end

-- Mirrors the polarix_towjob_missions column shape (JSON columns encoded, not decoded) so
-- Missions' buildMissionPayload/Complete read it exactly like a template row.
local function buildJobRow(job, donor, distance)
    job.is_priority = true
    job.area_id = donor.area_id
    job.area_name = donor.area_name
    job.name = Locale("mission.police_impound"):format(job.vehicle_label)
    job.vehicle_colors = job.vehicle_colors and json.encode(job.vehicle_colors) or nil
    job.spawn_points = nil
    job.dropoff_x = donor.dropoff_x
    job.dropoff_y = donor.dropoff_y
    job.dropoff_z = donor.dropoff_z
    job.dropoff_heading = donor.dropoff_heading
    job.dropoff_width = donor.dropoff_width
    job.dropoff_length = donor.dropoff_length
    job.reward_base = scaledValue(serverConfig.PriorityReward, distance)
    job.xp_base = scaledValue(serverConfig.PriorityXp, distance)
    job.time_limit_minutes = serverConfig.PriorityTimeLimitMinutes
    job.difficulty = "medium"
    job.level_required = 1
end

local MARK_REFUSALS = {
    not_authorized = "notify.mark_not_authorized",
    vehicle_not_found = "notify.mark_vehicle_not_found",
    too_far = "notify.mark_too_far",
    occupied = "notify.mark_occupied",
    is_tow_truck = "notify.mark_is_tow_truck",
    already_in_delivery = "notify.mark_already_in_delivery",
    not_player_owned = "notify.mark_not_player_owned",
    pool_full = "notify.mark_pool_full",
    officer_limit = "notify.mark_officer_limit",
    no_missions_configured = "notify.mark_no_missions",
    already_claimed = "notify.mark_already_claimed",
    cooldown = "notify.mark_cooldown",
}

local function refuse(source, reason, ...)
    local key = MARK_REFUSALS[reason]
    if key then
        local message = select("#", ...) > 0 and Locale(key):format(...) or Locale(key)
        TriggerClientEvent("polarix_towjob:notify", source, message, "error")
    end
    return { ok = false, reason = reason }
end

-- `label`/`colors` are display-only hints from the marking client (the server can't read a
-- vehicle's display name or colours). Everything the job is validated on — model, plate,
-- ownership, occupancy, position — is read server-side off the entity itself.
function Priority.Mark(source, netId, label, colors)
    if not officerJob(source) then return refuse(source, "not_authorized") end

    local identifier = Framework.GetPlayerIdentifier(source)
    if not identifier then return { ok = false, reason = "no_player" } end

    local vehicle = netId and NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return refuse(source, "vehicle_not_found")
    end

    -- Re-marking a request cancels it (any authorized officer may, the original marker is
    -- told), so a stuck request never needs an admin.
    local existing = findByNetId(netId)
    if existing then
        if existing.claimedBy then return refuse(source, "already_claimed") end

        removeJob(existing, Locale("notify.tow_request_cancelled"):format(existing.vehicle_label), "info")
        if existing.markedByIdentifier ~= identifier then
            TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.tow_request_cancelled"):format(existing.vehicle_label), "info")
        end

        debug.DebugPrint(("Priority.Mark: %s cancelled request %s"):format(identifier, existing.id))
        return { ok = true, unmarked = true }
    end

    local now = os.time()
    local cooldown = serverConfig.MarkCooldownSeconds or 0
    local elapsed = lastMarkAt[identifier] and (now - lastMarkAt[identifier]) or nil
    if elapsed and elapsed < cooldown then
        return refuse(source, "cooldown", cooldown - elapsed)
    end

    local officerPed = GetPlayerPed(source)
    local coords = GetEntityCoords(vehicle)
    -- Slack on top of the client's own reach for movement/latency, same idea as
    -- VehicleFoundMaxDistance's re-check of a "found" claim.
    if #(GetEntityCoords(officerPed) - coords) > (serverConfig.PoliceMarkDistance or 12.0) + 4.0 then
        return refuse(source, "too_far")
    end

    if isTowTruckModel(GetEntityModel(vehicle)) then return refuse(source, "is_tow_truck") end
    -- Driver seat only: the seat that matters for "is this car about to be driven off", and
    -- the one native that reads reliably server-side.
    if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return refuse(source, "occupied") end
    if Missions.IsTargetNetId(netId) then return refuse(source, "already_in_delivery") end

    local plate = trim(GetVehicleNumberPlateText(vehicle))
    local owner = plate ~= "" and Framework.GetVehicleOwner and Framework.GetVehicleOwner(plate) or nil
    if not owner then return refuse(source, "not_player_owned") end

    if #pool >= (serverConfig.MaxPriorityJobs or 5) then return refuse(source, "pool_full") end

    local openForOfficer = 0
    for _, job in ipairs(pool) do
        if job.markedByIdentifier == identifier and not job.claimedBy then openForOfficer = openForOfficer + 1 end
    end
    if openForOfficer >= (serverConfig.MaxMarksPerOfficer or 2) then return refuse(source, "officer_limit") end

    local donor, distance = findNearestDonorMission(coords)
    if not donor then return refuse(source, "no_missions_configured") end

    sequence = sequence + 1

    local job = {
        id = ID_PREFIX .. sequence,
        netId = netId,
        plate = plate,
        owner = owner,
        vehicle_model = GetEntityModel(vehicle),
        vehicle_label = trim(label) ~= "" and trim(label) or plate,
        vehicle_colors = colors,
        markedCoords = coords,
        markedBy = source,
        markedByIdentifier = identifier,
        createdAt = now,
        expiresAt = now + (serverConfig.PriorityExpiryMinutes or 15) * 60,
        suppressed = {}, -- [identifier] = true, players who declined/aborted this one
    }

    buildJobRow(job, donor, distance or 0.0)
    pool[#pool + 1] = job
    lastMarkAt[identifier] = now

    broadcastAdded(job)
    TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.tow_request_registered"):format(job.vehicle_label), "success")

    -- Priority jobs queue-jump the pager rather than paging instantly; this only stops an
    -- idle operator's next page from being up to PagerMaxIntervalMinutes away.
    OnCall.PullInPages(serverConfig.PriorityMaxWaitSeconds or 45)

    debug.DebugPrint(("Priority.Mark: %s marked %s (%s) as %s, reward %d"):format(identifier, plate, job.vehicle_label, job.id, job.reward_base))

    return { ok = true, id = job.id }
end

-- Pool-first half of Missions' mission-row resolver.
function Priority.GetJobRow(missionId)
    if not Priority.IsPriorityId(missionId) then return nil end
    return findById(missionId)
end

function Priority.GetTargetNetId(missionId)
    local job = findById(missionId)
    return job and job.netId or nil
end

-- FIFO pick for the on-call scheduler: oldest open request first, skipping ones this player
-- already declined or aborted, and ones another player is currently being offered.
function Priority.TakeNextFor(source)
    local identifier = Framework.GetPlayerIdentifier(source)
    if not identifier then return nil end

    local now = os.time()
    for _, job in ipairs(pool) do
        if not job.claimedBy and not job.offeredTo and not job.suppressed[identifier] and now < job.expiresAt then
            job.offeredTo = source
            job.offeredAt = now

            return {
                id = job.id,
                name = job.name,
                vehicle_label = job.vehicle_label,
                difficulty = job.difficulty,
                reward_base = job.reward_base,
                xp_base = job.xp_base,
                time_limit_minutes = job.time_limit_minutes,
                level_required = job.level_required,
                area_name = job.area_name,
                is_priority = true,
            }
        end
    end
end

function Priority.OnOfferDeclined(source, missionId)
    local job = findById(missionId)
    if not job or job.offeredTo ~= source then return end

    job.offeredTo = nil
    local identifier = Framework.GetPlayerIdentifier(source)
    if identifier then job.suppressed[identifier] = true end
end

-- Releases the offer lock without suppressing: used when Missions.Accept refused the job.
function Priority.OnOfferFailed(source, missionId)
    local job = findById(missionId)
    if job and job.offeredTo == source then job.offeredTo = nil end
end

function Priority.OnClaimed(missionId, source, deliveryId)
    local job = findById(missionId)
    if not job then return end

    job.offeredTo = nil
    job.claimedBy = source
    job.deliveryId = deliveryId
end

-- Validates a claimed job's target right before the delivery starts, and rolls the
-- search-hint circle around the marked position (tighter radius than a template mission's:
-- dispatch gave a location, it just isn't exact).
function Priority.PrepareTarget(missionId)
    local job = findById(missionId)
    if not job then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(job.netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local radius = serverConfig.PrioritySearchRadius or 25.0
    local angle = math.random() * 2 * math.pi
    local offset = radius * (0.35 + math.random() * 0.35)

    return {
        netId = job.netId,
        hint = {
            x = job.markedCoords.x + math.cos(angle) * offset,
            y = job.markedCoords.y + math.sin(angle) * offset,
            z = job.markedCoords.z,
        },
        radius = radius,
    }
end

-- How far the target has drifted from where it was marked. Claimed jobs tolerate a lot more
-- than unclaimed ones — rigging a car with the tow arm moves it, so only "left the scene"
-- distances may cancel a delivery that's already underway.
function Priority.GetTargetDrift(missionId)
    local job = findById(missionId)
    if not job then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(job.netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    return #(GetEntityCoords(vehicle) - job.markedCoords)
end

function Priority.OnDeliveryCompleted(missionId, source, rewardPaid)
    local job = findById(missionId)
    if not job then return end

    local mode = serverConfig.ImpoundMode or "event"

    if mode == "framework" and Framework.ImpoundVehicle then
        Framework.ImpoundVehicle(job.plate)
    end

    if mode ~= "none" then
        TriggerEvent("polarix_towjob:vehicleImpounded", {
            plate = job.plate,
            model = job.vehicle_model,
            owner = job.owner,
            markedBy = job.markedByIdentifier,
            towedBy = Framework.GetPlayerIdentifier(source),
            deliveryId = job.deliveryId,
            coords = { x = job.dropoff_x, y = job.dropoff_y, z = job.dropoff_z },
        })
    end

    local cut = math.floor((rewardPaid or 0) * (serverConfig.PoliceCutPercent or 0.0) + 0.5)
    if cut > 0 then
        local officer = resolveSourceByIdentifier(job.markedByIdentifier, job.markedBy)
        if officer then
            Framework.AddMoney(officer, cut)
            TriggerClientEvent("polarix_towjob:notify", officer, Locale("notify.police_cut_paid"):format(cut), "success")
        end
    end

    removeJob(job, Locale("notify.tow_request_completed"):format(job.vehicle_label), "success")

    debug.DebugPrint(("Priority.OnDeliveryCompleted: %s impounded (mode %s)"):format(job.plate, mode))
end

-- Only the target going bad kills a request: moved means its coords are stale, destroyed
-- and gone mean there is nothing left to tow. Every other ending (the operator aborted,
-- their truck was wrecked, their rental was repossessed, a timed job ran out) puts a
-- still-valid request back in the queue — the car is sitting right where the officer
-- called it in. A requeue keeps the ORIGINAL expiry, so total lifetime stays bounded.
local TARGET_LOST_MESSAGES = {
    target_moved = "notify.tow_request_target_moved",
    target_gone = "notify.tow_request_target_gone",
    vehicle_destroyed = "notify.tow_request_target_destroyed",
}

function Priority.OnDeliveryEnded(missionId, source, reason)
    local job = findById(missionId)
    if not job then return end

    local targetLost = TARGET_LOST_MESSAGES[reason]
    if targetLost then
        removeJob(job, Locale(targetLost):format(job.vehicle_label), "error")
        return
    end

    local identifier = Framework.GetPlayerIdentifier(source)
    if identifier then job.suppressed[identifier] = true end

    local vehicle = NetworkGetEntityFromNetworkId(job.netId)
    local stillThere = vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
        and GetEntityHealth(vehicle) > 0
        and GetPedInVehicleSeat(vehicle, -1) == 0
        and #(GetEntityCoords(vehicle) - job.markedCoords) <= (serverConfig.PriorityMoveTolerance or 10.0)

    if not stillThere then
        removeJob(job, Locale("notify.tow_request_target_gone"):format(job.vehicle_label), "error")
        return
    end

    job.claimedBy = nil
    job.deliveryId = nil
    job.offeredTo = nil

    debug.DebugPrint(("Priority.OnDeliveryEnded: %s requeued after %s"):format(job.id, tostring(reason)))
end

-- Unclaimed requests are validated against the live entity; a claimed one is the delivery
-- sweep's business (server/modules/missions.lua) so the two can't both end the same job.
CreateThread(function()
    local offerLockTimeout = (serverConfig.PagerOfferTimeoutSeconds or 30) + 15

    while true do
        Wait(5000)
        local now = os.time()

        for i = #pool, 1, -1 do
            local job = pool[i]

            -- A player who dropped or reconnected mid-offer would otherwise hold the lock forever.
            if job.offeredTo and job.offeredAt and now - job.offeredAt > offerLockTimeout then
                job.offeredTo = nil
            end

            if not job.claimedBy then
                local vehicle = NetworkGetEntityFromNetworkId(job.netId)
                local label = job.vehicle_label

                if now >= job.expiresAt then
                    removeJob(job, Locale("notify.tow_request_expired"):format(label), "info")
                elseif not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                    removeJob(job, Locale("notify.tow_request_target_gone"):format(label), "error")
                elseif GetEntityHealth(vehicle) <= 0 then
                    removeJob(job, Locale("notify.tow_request_target_destroyed"):format(label), "error")
                elseif GetPedInVehicleSeat(vehicle, -1) ~= 0 then
                    removeJob(job, Locale("notify.tow_request_target_occupied"):format(label), "info")
                elseif #(GetEntityCoords(vehicle) - job.markedCoords) > (serverConfig.PriorityMoveTolerance or 10.0) then
                    removeJob(job, Locale("notify.tow_request_target_moved"):format(label), "info")
                end
            end
        end
    end
end)

Framework.OnPlayerUnload(function(source)
    for _, job in ipairs(pool) do
        if job.offeredTo == source then job.offeredTo = nil end
    end
end)
