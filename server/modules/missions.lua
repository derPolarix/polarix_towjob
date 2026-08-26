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

-- Shared by Missions.Accept and Missions.AcceptViaOnCall — the client-safe mission payload
-- both hand off to the find/attach/tow/deliver loop is identical either way.
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

-- Tracks, per source, everything about the delivery that's currently active for them:
-- the target vehicle's net-id (reported by the client once it spawns it, Step 8.2.3),
-- the tow truck's net-id once attached (Step 9.2), and the server-stamped timed-mission
-- deadline (Step 9.3, set at accept time — never derived from a client-reported value).
-- In-memory only (net-ids are session-scoped handles, not something that belongs in the
-- `deliveries` table). Phase 10 (damage tracking) is the next intended reader via
-- Missions.GetActiveDeliveryState.
local activeDeliveryState = {} -- [source] = { deliveryId, targetNetId, towTruckNetId, attached, deadlineAt }

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

-- Step 9.2: the client reports both net-ids once it calls AttachVehicleToTowTruck
-- locally; the server re-validates before trusting the attach happened at all —
-- never assumes a client-reported "I attached it" claim (ground rule 4). Rejects a
-- mismatched/forged target net-id and confirms the entity's model actually matches
-- the mission's expected vehicle before flagging the delivery as attached.
RegisterNetEvent("polarix_towjob:attachVehicle", function(deliveryId, towNetId, targetNetId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then return end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or state.targetNetId ~= targetNetId then
        debug.DebugPrint("Missions.attachVehicle: rejected mismatched target net-id for source", source)
        return
    end

    local mission = DB.GetMission(delivery.mission_id)
    local entity = NetworkGetEntityFromNetworkId(targetNetId)
    if not mission or not entity or entity == 0 or GetEntityModel(entity) ~= GetHashKey(mission.vehicle_model) then
        debug.DebugPrint("Missions.attachVehicle: rejected model mismatch for source", source)
        return
    end

    state.attached = true
    state.towTruckNetId = towNetId

    -- Damage window is "attach to placement" (design-decisions table) — baseline is read
    -- directly off the live entity here, server-side, so Missions.Complete (Phase 10.3)
    -- never has to trust a client-reported health number, only re-read the same entity.
    state.bodyHealthBaseline = GetVehicleBodyHealth(entity)
    state.engineHealthBaseline = GetVehicleEngineHealth(entity)

    debug.DebugPrint(("Missions.attachVehicle: delivery %d attached for %s"):format(deliveryId, player.identifier))
end)

function Missions.GetActiveDeliveryState(source)
    return activeDeliveryState[source]
end

-- Shared by the immediate client-reported destruction event and the periodic sweep
-- backstop below — resolves both tracked net-ids server-side and independently confirms
-- destruction itself (ground rule 4: never trust a client's "it's destroyed" claim alone).
local function isDeliveryVehicleDestroyed(state)
    local target = state.targetNetId and NetworkGetEntityFromNetworkId(state.targetNetId)
    local towTruck = state.towTruckNetId and NetworkGetEntityFromNetworkId(state.towTruckNetId)

    local targetDestroyed = target and target ~= 0 and (not DoesEntityExist(target) or IsEntityDead(target))
    local towTruckDestroyed = towTruck and towTruck ~= 0 and (not DoesEntityExist(towTruck) or IsEntityDead(towTruck))

    return targetDestroyed or towTruckDestroyed
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
            elseif state.attached and isDeliveryVehicleDestroyed(state) then
                Missions.Fail(source, state.deliveryId, "vehicle_destroyed")
            end
        end
    end
end)

Framework.OnPlayerUnload(function(source)
    activeDeliveryState[source] = nil
end)

-- Step 8.1: validates and starts a delivery. No longer reachable from normal play (jobs are
-- paged, not accepted from a list — see Missions.AcceptViaOnCall) — kept solely as the
-- vehicle-provisioning path for the Phase 13 admin "Test mission" button, which needs to work
-- regardless of the admin's own owned/deployed-vehicle state. Vehicle assignment follows the
-- ownership rules from Phase 7's design-decision table:
--   0 owned            -> rental auto-used
--   1 owned (stored)    -> that vehicle auto-parked-out and spawned
--   2+ owned            -> client keeps the Dashboard open; player must Park Out
--                          one themselves (Vehicle.ContinueAfterParkOut on the client
--                          picks the delivery back up once that succeeds)
-- Edge case (not spelled out in the plan): a player's only/all owned vehicles are
-- currently `deployed` (left un-stored from an earlier session/standalone Park Out).
-- There's no "reuse the already-deployed entity" path since the client has no
-- guarantee that entity still exists — reject with `no_stored_vehicle` and let the
-- player store it via the parking zone first, same as any other stuck state.
-- `bypassGates` is never client-controlled — only AdminMissions.TestRun (Phase 13, which
-- re-checks Framework.IsAdmin itself) passes true, to skip the mission-availability gates
-- (level/area-lock) for QA purposes without touching the player-state checks below them.
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
    local storedCount = 0
    for _, vehicle in ipairs(owned) do
        if vehicle.state == "stored" then storedCount = storedCount + 1 end
    end

    if #owned > 0 and storedCount == 0 then
        return { ok = false, reason = "no_stored_vehicle" }
    end

    local mission = buildMissionPayload(row)

    local usedRental = #owned == 0
    local deliveryId = DB.CreateDelivery(missionId, player.identifier, usedRental)

    -- Deadline is stamped here, at accept time, per the design-decisions table — the
    -- server is the sole authority on it regardless of when/whether the client actually
    -- reports setTargetVehicle afterward (see the merge logic in that handler above).
    local deadlineAt = mission.time_limit_minutes and (os.time() + mission.time_limit_minutes * 60) or nil
    activeDeliveryState[source] = { deliveryId = deliveryId, deadlineAt = deadlineAt }

    local response = { ok = true, deliveryId = deliveryId, mission = mission, deadlineAt = deadlineAt }

    if usedRental then
        response.usedRental = true
        response.rental = serverConfig.RentalTruck
        Vehicles.StartRental(source, deliveryId)
    elseif #owned == 1 then
        local parkResult = Vehicles.ParkOut(source, owned[1].id)
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

-- On-call pager's accept path (server/modules/oncall.lua's OnCall.AcceptOffer is the only
-- caller). Deliberately doesn't share Missions.Accept's body: on-call's own precondition is
-- that a vehicle (owned or rental) is *already* deployed, so unlike Accept there's no
-- rental-spawn / auto-park-out / needsParkOut branching here — the client just starts the
-- find/attach loop against the truck the player is already driving around.
function Missions.AcceptViaOnCall(source, missionId, usedRental)
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
    if effectiveLevelRequired > player.level then
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
    if not unlockedAreaIds[row.area_id] then
        return { ok = false, reason = "area_locked" }
    end

    local mission = buildMissionPayload(row)
    local deliveryId = DB.CreateDelivery(missionId, player.identifier, usedRental)

    local deadlineAt = mission.time_limit_minutes and (os.time() + mission.time_limit_minutes * 60) or nil
    activeDeliveryState[source] = { deliveryId = deliveryId, deadlineAt = deadlineAt }

    debug.DebugPrint(("Missions.AcceptViaOnCall: %s accepted paged mission %s (delivery %d)"):format(player.identifier, missionId, deliveryId))

    return { ok = true, deliveryId = deliveryId, mission = mission, deadlineAt = deadlineAt }
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

-- Step 10.3: server computes the final damage penalty itself from health values it reads
-- directly off the tracked entities (baseline captured at attach time, Step 9.2's handler
-- above) — never from a client-reported number. Also re-validates the towed vehicle's
-- actual position/heading against the dropoff rectangle before paying out.
function Missions.Complete(source, deliveryId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local delivery = DB.GetActiveDelivery(player.identifier)
    if not delivery or delivery.id ~= deliveryId then
        return { ok = false, reason = "no_active_delivery" }
    end

    local state = activeDeliveryState[source]
    if not state or state.deliveryId ~= deliveryId or not state.attached then
        return { ok = false, reason = "not_attached" }
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

    local towTruck = state.towTruckNetId and NetworkGetEntityFromNetworkId(state.towTruckNetId)
    local resistance = (towTruck and towTruck ~= 0) and Vehicles.GetDamageResistanceForModel(GetEntityModel(towTruck)) or 0.0
    local skillReduction = Skills.GetDamageReduction(source)

    local reductionFactor = math.max(0, 1 - resistance - skillReduction)
    local healthLoss = (bodyLoss + engineLoss) * reductionFactor

    local damagePenalty = math.floor(healthLoss * (serverConfig.DamagePenaltyPerHealthPoint or 0.5) + 0.5)

    -- Phase 13's global reward_multiplier is a base economy-tuning knob, applied to
    -- reward_base before anything else (cap included) so an admin's multiplier scales the
    -- mission's whole economy proportionally, not just the payout on top.
    local effectiveRewardBase = mission.reward_base * Settings.GetRewardMultiplier()

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
    local xpPaid = math.floor(mission.xp_base * Settings.GetXpMultiplier() + 0.5)

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
