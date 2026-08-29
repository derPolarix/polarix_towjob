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

-- Level/area-eligibility filter shared by the pager's random pick below and (inline)
-- Missions.Accept's own gate check — replaces the old Available Jobs list query
-- (Missions.GetAvailableForPlayer) now that jobs are paged rather than browsed.
local function getEligibleMissionRows(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end

    local levelReduction = Skills.GetLevelRequirementReduction(source)
    local eligible = {}

    for _, row in ipairs(DB.GetActiveMissionsWithAreas() or {}) do
        local effectiveLevelRequired = math.max(1, row.level_required - levelReduction)
        if effectiveLevelRequired <= player.level and unlockedAreaIds[row.area_id] then
            eligible[#eligible + 1] = row
        end
    end

    return eligible
end

-- Called by the on-call scheduler (server/modules/oncall.lua) to pick one job to page.
-- Deliberately no `distance`/exact coords here — the old Available Jobs payload already
-- didn't send raw search/dropoff coords, and a pager offer sends even less (no client-side
-- distance calc to spoof-check against, since there's no list to sort by it anymore).
function Missions.PickRandomForPager(source)
    local eligible = getEligibleMissionRows(source)
    if #eligible == 0 then return nil end

    local row = eligible[math.random(1, #eligible)]

    return {
        id = row.id,
        name = row.name,
        vehicle_label = row.vehicle_label,
        difficulty = row.difficulty,
        reward_base = row.reward_base,
        xp_base = row.xp_base,
        time_limit_minutes = row.time_limit_minutes,
        level_required = row.level_required,
        area_name = row.area_name,
    }
end

-- Client-safe mission payload handed to the find/tow/deliver loop on accept.
local function buildMissionPayload(row)
    return {
        id = row.id,
        name = row.name,
        vehicle_model = row.vehicle_model,
        vehicle_label = row.vehicle_label,
        vehicle_colors = row.vehicle_colors and json.decode(row.vehicle_colors) or nil,
        search_center = { x = row.search_center_x, y = row.search_center_y, z = row.search_center_z },
        search_radius = row.search_radius,
        dropoff = { x = row.dropoff_x, y = row.dropoff_y, z = row.dropoff_z, heading = row.dropoff_heading },
        dropoff_width = row.dropoff_width,
        dropoff_length = row.dropoff_length,
        -- Sent down so the client's live placement preview (Step 10.2) stays in sync with the
        -- server's own authoritative tolerance (Missions.Complete) without requiring server-only
        -- config from client code (client_scripts can't require() a server_scripts-only file).
        -- Reads through Settings so a Phase 13 admin edit is reflected on the next accept.
        dropoff_heading_tolerance = Settings.GetDeliveryHeadingTolerance(),
        reward_base = row.reward_base,
        xp_base = row.xp_base,
        time_limit_minutes = row.time_limit_minutes,
    }
end

-- In-memory per-source delivery state. `deadlineAt` is server-stamped at accept time, never
-- derived from anything client-reported.
local activeDeliveryState = {} -- [source] = { deliveryId, targetNetId, found, deadlineAt, bodyHealthBaseline, engineHealthBaseline }

RegisterNetEvent("polarix_towjob:setTargetVehicle", function(deliveryId, netId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then
        state = { deliveryId = deliveryId }
        activeDeliveryState[source] = state
    end
    state.targetNetId = netId
end)

-- Client reports reaching the target; server re-checks the distance against the tracked
-- entity before trusting it (ground rule 4). An unresolvable entity still sets `found` —
-- Missions.Complete then falls back to a full-health damage baseline rather than stalling.
RegisterNetEvent("polarix_towjob:vehicleFound", function(deliveryId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or state.found then return end

    local entity = state.targetNetId and NetworkGetEntityFromNetworkId(state.targetNetId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(entity)) > serverConfig.VehicleFoundMaxDistance then
            debug.DebugPrint("Missions.vehicleFound: rejected out-of-range claim for source", source)
            return
        end
        state.bodyHealthBaseline = GetVehicleBodyHealth(entity)
        state.engineHealthBaseline = GetVehicleEngineHealth(entity)
    end

    state.found = true

    debug.DebugPrint(("Missions.vehicleFound: delivery %d found for %s"):format(deliveryId, player.identifier))
end)

function Missions.GetActiveDeliveryState(source)
    return activeDeliveryState[source]
end

-- Re-confirms destruction server-side (ground rule 4) for both the client-reported event and
-- the periodic sweep backstop.
local function isDeliveryVehicleDestroyed(state)
    local target = state.targetNetId and NetworkGetEntityFromNetworkId(state.targetNetId)
    if not target or target == 0 then return false end

    -- IsEntityDead is client-only; server-side a destroyed vehicle reports entity health 0.
    return not DoesEntityExist(target) or GetEntityHealth(target) <= 0
end

-- Step 10.1: client-side damage.lua detects destruction fast (for responsiveness) and
-- reports it here; the sweep thread below is the backstop for a client that never gets
-- to report (disconnect/crash at the moment of destruction).
RegisterNetEvent("polarix_towjob:reportVehicleDestroyed", function(deliveryId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    if not isDeliveryVehicleDestroyed(state) then
        debug.DebugPrint("Missions.reportVehicleDestroyed: rejected unverified destruction claim for source", source)
        return
    end

    Missions.Fail(source, deliveryId, "vehicle_destroyed")
end)

-- Shared fail path — called for timed-mission expiry (Step 9.3), vehicle destruction
-- (Step 10.1) and missed rental payments (server/modules/vehicles.lua), so the
-- delivery-row/notify/cleanup/counter sequence only lives in one place.
function Missions.Fail(source, deliveryId, reason)
    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId then return end

    DB.FailDelivery(deliveryId)
    Vehicles.OnDeliveryEnded(source)
    activeDeliveryState[source] = nil
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "failed")

    local messages = {
        time_limit_exceeded = "Time limit exceeded — delivery failed.",
        vehicle_destroyed = "The vehicle was destroyed — delivery failed.",
        rental_repossessed = "Rental payment missed — the tow truck has been repossessed.",
    }
    TriggerClientEvent("polarix_towjob:notify", source, messages[reason] or "Delivery failed.", "error")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "failed")

    debug.DebugPrint(("Missions.Fail: delivery %d failed for source %s (%s)"):format(deliveryId, source, reason))
end

-- Step 9.3: server is the sole authority on timed-mission expiry — `deadlineAt` is
-- stamped once at accept time (see Missions.Accept) and never re-derived from anything
-- client-reported. A lightweight 5s sweep is enough; these are minute-scale deadlines.
CreateThread(function()
    while true do
        Wait(5000)

        local now = os.time()
        for source, state in pairs(activeDeliveryState) do
            if state.deadlineAt and now >= state.deadlineAt then
                Missions.Fail(source, state.deliveryId, "time_limit_exceeded")
            elseif state.found and isDeliveryVehicleDestroyed(state) then
                Missions.Fail(source, state.deliveryId, "vehicle_destroyed")
            end
        end
    end
end)

Framework.OnPlayerUnload(function(source)
    activeDeliveryState[source] = nil
end)

-- Validates and starts a delivery — the single accept path, shared by the on-call pager
-- (OnCall.AcceptOffer) and the Phase 13 admin "Test mission" button. Vehicle assignment:
--   truck already deployed / rental already active -> reused as-is, no spawn
--   0 owned, no rental                             -> rental auto-used and spawned
--   exactly 1 owned, stored                        -> auto-parked-out and spawned
--   2+ owned, none deployed                        -> needsParkOut: client keeps the
--        Dashboard open, player Parks Out one (Vehicle.ContinueAfterParkOut resumes it)
-- `bypassGates` is never client-controlled — only AdminMissions.TestRun (which re-checks
-- Framework.IsAdmin itself) passes true, to skip the level/area-lock gates for QA.
function Missions.Accept(source, missionId, bypassGates)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "active_delivery_exists" }
    end

    local row = DB.GetMission(missionId)
    if not row then
        return { ok = false, reason = "mission_not_found" }
    end

    local effectiveLevelRequired = math.max(1, row.level_required - Skills.GetLevelRequirementReduction(source))
    if not bypassGates and effectiveLevelRequired > player.level then
        return { ok = false, reason = "level_too_low" }
    end

    local area = DB.GetArea(row.area_id)
    if not area then
        return { ok = false, reason = "mission_not_found" }
    end

    local unlockedAreaIds = {}
    for _, id in ipairs(Player.GetUnlockedAreaIds(source)) do
        unlockedAreaIds[id] = true
    end
    if not bypassGates and not unlockedAreaIds[row.area_id] then
        return { ok = false, reason = "area_locked" }
    end

    local owned = DB.GetOwnedVehicles(player.identifier)
    local storedCount, deployedCount = 0, 0
    local firstStored = nil
    for _, vehicle in ipairs(owned) do
        if vehicle.state == "stored" then
            storedCount = storedCount + 1
            firstStored = firstStored or vehicle
        elseif vehicle.state == "deployed" then
            deployedCount = deployedCount + 1
        end
    end

    local rentalActive = Vehicles.IsRentalActive(source)
    local mission = buildMissionPayload(row)
    local usedRental = rentalActive or #owned == 0
    local deliveryId = DB.CreateDelivery(missionId, player.identifier, usedRental)

    -- Server is the sole authority on the deadline, stamped here at accept time.
    local deadlineAt = mission.time_limit_minutes and (os.time() + mission.time_limit_minutes * 60) or nil
    activeDeliveryState[source] = { deliveryId = deliveryId, deadlineAt = deadlineAt }

    local response = { ok = true, deliveryId = deliveryId, mission = mission, deadlineAt = deadlineAt }

    if rentalActive then
        -- Standalone on-call rental already out — reuse it, no spawn.
        Vehicles.SetRentalDeliveryId(source, deliveryId)
        response.usedRental = true
    elseif deployedCount > 0 then
        -- An owned truck is already out — reuse it, no spawn.
    elseif #owned == 0 then
        response.usedRental = true
        response.rental = serverConfig.RentalTruck
        Vehicles.StartRental(source, deliveryId)
    elseif storedCount == 1 then
        local parkResult = Vehicles.ParkOut(source, firstStored.id)
        if not parkResult.ok then
            DB.FailDelivery(deliveryId)
            activeDeliveryState[source] = nil
            return { ok = false, reason = parkResult.reason }
        end
        response.vehicle = parkResult.vehicle
    else
        response.needsParkOut = true
    end

    debug.DebugPrint(("Missions.Accept: %s accepted mission %s (delivery %d)"):format(player.identifier, missionId, deliveryId))

    return response
end

-- Used by polarix_towjob:openDashboard so the Dashboard can show an "active delivery"
-- banner with an Abort action (Step 10.4 — abort is Dashboard-only, no in-world trigger).
function Missions.GetActiveDeliverySummary(source)
    local player = Player.GetData(source)
    if not player then return nil end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery then return nil end

    local mission = DB.GetMission(delivery.mission_id)
    return { deliveryId = delivery.id, missionName = mission and mission.name or "Unknown Job" }
end

-- Rotates `coords` into the dropoff rectangle's local frame (heading-aligned) and checks
-- both the position bound (mission's own dropoff_width/dropoff_length) and the heading
-- tolerance (config.server.DeliveryHeadingTolerance). Mirrors the client-side preview in
-- client/modules/delivery.lua — that copy is display-only, this one is authoritative.
local function isWithinDropoffZone(mission, coords, heading)
    local center = vector3(mission.dropoff_x, mission.dropoff_y, mission.dropoff_z)
    local rad = math.rad(mission.dropoff_heading or 0.0)
    local lengthDir = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local widthDir = vector3(math.cos(rad), math.sin(rad), 0.0)

    local delta = coords - center
    local projLength = delta.x * lengthDir.x + delta.y * lengthDir.y
    local projWidth = delta.x * widthDir.x + delta.y * widthDir.y

    if math.abs(projLength) > (mission.dropoff_length or 10.0) / 2 then return false end
    if math.abs(projWidth) > (mission.dropoff_width or 6.0) / 2 then return false end

    local headingDiff = (heading - (mission.dropoff_heading or 0.0)) % 360.0
    if headingDiff > 180.0 then headingDiff = 360.0 - headingDiff end

    return headingDiff <= Settings.GetDeliveryHeadingTolerance()
end

-- Server computes the damage penalty from health it reads off the tracked entity (baseline
-- from the vehicleFound handler), and re-validates the towed vehicle's position/heading
-- against the dropoff rectangle — never trusts a client-reported number for either.
function Missions.Complete(source, deliveryId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        return { ok = false, reason = "no_active_delivery" }
    end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or not state.found then
        return { ok = false, reason = "vehicle_not_found_yet" }
    end

    local mission = DB.GetMission(delivery.mission_id)
    if not mission then return { ok = false, reason = "mission_not_found" } end

    local target = state.targetNetId and NetworkGetEntityFromNetworkId(state.targetNetId)
    if not target or target == 0 or not DoesEntityExist(target) then
        return { ok = false, reason = "vehicle_missing" }
    end

    local vehicleCoords = GetEntityCoords(target)
    local vehicleHeading = GetEntityHeading(target)
    if not isWithinDropoffZone(mission, vehicleCoords, vehicleHeading) then
        return { ok = false, reason = "not_in_zone" }
    end

    local bodyLoss = math.max(0, (state.bodyHealthBaseline or 1000.0) - GetVehicleBodyHealth(target))
    local engineLoss = math.max(0, (state.engineHealthBaseline or 1000.0) - GetVehicleEngineHealth(target))

    local resistance = Vehicles.GetActiveTruckDamageResistance(source, player.identifier)
    local skillReduction = Skills.GetDamageReduction(source)

    local reductionFactor = math.max(0, 1 - resistance - skillReduction)
    local healthLoss = (bodyLoss + engineLoss) * reductionFactor

    local damagePenalty = math.floor(healthLoss * (serverConfig.DamagePenaltyPerHealthPoint or 0.5) + 0.5)

    -- Area reward/xp multipliers (polarix_towjob_areas) stack multiplicatively with the
    -- global Settings ones — same composition point as the comment below, so an area's
    -- modifier scales the whole economy proportionally too, not just the payout on top.
    -- Falls back to neutral 1.0 if the mission's area was deactivated/deleted since creation.
    local missionArea = DB.GetArea(mission.area_id)
    local areaRewardMultiplier = missionArea and tonumber(missionArea.reward_multiplier) or 1.0
    local areaXpMultiplier = missionArea and tonumber(missionArea.xp_multiplier) or 1.0

    -- Phase 13's global reward_multiplier is a base economy-tuning knob, applied to
    -- reward_base before anything else (cap included) so an admin's multiplier scales the
    -- mission's whole economy proportionally, not just the payout on top.
    local effectiveRewardBase = mission.reward_base * Settings.GetRewardMultiplier() * areaRewardMultiplier

    -- Cap is always a fraction of the (multiplier-adjusted) reward_base, never the
    -- Economy-branch-bonused amount below — confirmed with user, keeps the cap
    -- independent of the player's own payout_bonus skill.
    local cap = math.floor(effectiveRewardBase * Settings.GetDamagePenaltyCapPercent())
    damagePenalty = math.min(damagePenalty, cap)

    -- Economy branch ("Fair Rates") bonuses the reward before the damage penalty is
    -- subtracted — confirmed with user — so the bonus is additive on top, not eaten by
    -- a damage-cap that also scales with it.
    local payoutBonus = Skills.GetPayoutBonus(source)
    local bonusedReward = math.floor(effectiveRewardBase * (1 + payoutBonus) + 0.5)

    local rewardPaid = math.max(0, bonusedReward - damagePenalty)
    local xpPaid = math.floor(mission.xp_base * Settings.GetXpMultiplier() * areaXpMultiplier + 0.5)

    Framework.AddMoney(source, rewardPaid)

    DB.CompleteDelivery(deliveryId, rewardPaid, xpPaid, damagePenalty)
    Vehicles.OnDeliveryEnded(source)
    activeDeliveryState[source] = nil
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "completed", rewardPaid)
    Player.AddXP(source, xpPaid)

    local message = damagePenalty > 0
        and ("Delivery complete! $%d earned (-$%d damage), +%d XP."):format(rewardPaid, damagePenalty, xpPaid)
        or ("Delivery complete! $%d earned, +%d XP."):format(rewardPaid, xpPaid)
    TriggerClientEvent("polarix_towjob:notify", source, message, "success")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "completed")

    debug.DebugPrint(("Missions.Complete: delivery %d completed for %s (reward %d, penalty %d)"):format(deliveryId, player.identifier, rewardPaid, damagePenalty))

    return { ok = true, reward = rewardPaid, xp = xpPaid, damagePenalty = damagePenalty }
end

-- Step 10.4: player-initiated cancel, Dashboard-only (no in-world trigger — confirmed
-- with user). Detach/despawn of the target vehicle happens client-side via the same
-- `polarix_towjob:deliveryEnded` event Complete/Fail already use.
function Missions.Abort(source, deliveryId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        return { ok = false, reason = "no_active_delivery" }
    end

    DB.AbortDelivery(deliveryId)
    Vehicles.OnDeliveryEnded(source)
    activeDeliveryState[source] = nil
    OnCall.HandleDeliveryEnded(source)

    Player.RecordDeliveryOutcome(source, "aborted")

    TriggerClientEvent("polarix_towjob:notify", source, "Delivery aborted.", "info")
    TriggerClientEvent("polarix_towjob:deliveryEnded", source, "aborted")

    debug.DebugPrint(("Missions.Abort: delivery %d aborted for %s"):format(deliveryId, player.identifier))

    return { ok = true }
end
