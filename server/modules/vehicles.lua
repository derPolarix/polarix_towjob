local serverConfig = require("config.server")
local clientConfig = require("config.client")
local debug = require("shared.debug")

Vehicles = {}

local MAX_HEALTH = 1000.0
local PLATE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

-- netId of every deployed truck's live entity, reported by the client on spawn/resync
-- (client/modules/garage.lua). Lets Vehicles.ParkIn despawn a truck from the Dashboard and
-- read its authoritative health regardless of where the truck sits in the world. Keyed by
-- source (session-scoped) — cleared on unload and on park-in.
local deployedTruckNetIds = {} -- [source] = { [vehicleId] = netId }

local function findTier(tierId)
    for _, tier in ipairs(serverConfig.VehicleTiers) do
        if tier.id == tierId then return tier end
    end
    return nil
end

local function generatePlate()
    local plate

    repeat
        local parts = {}
        for i = 1, 8 do
            local idx = math.random(1, #PLATE_CHARS)
            parts[i] = PLATE_CHARS:sub(idx, idx)
        end
        plate = table.concat(parts)
    until not DB.GetVehicleByPlate(plate)

    return plate
end

local function toClientVehicle(row)
    local tier = findTier(row.tier_id)
    return {
        id = row.id,
        tier_id = row.tier_id,
        label = tier and tier.label or row.tier_id,
        model = tier and tier.model or nil,
        plate = row.plate,
        body_health = row.body_health,
        engine_health = row.engine_health,
        state = row.state,
    }
end

-- Resolves a tow-truck-tier's damage_resistance from a live entity's model hash, not a
-- stored tier_id — works uniformly for owned vehicles (any tier) and the rental (no DB
-- row/tier_id at all, but its model matches the "standard" tier's model 1:1). Used by
-- Missions.Complete (Phase 10.3) to reduce the towed-vehicle damage penalty.
function Vehicles.GetDamageResistanceForModel(modelHash)
    for _, tier in ipairs(serverConfig.VehicleTiers) do
        if GetHashKey(tier.model) == modelHash then
            return tier.damage_resistance or 0.0
        end
    end
    return 0.0
end

-- Damage-resistance of the truck the player is running the delivery with, for
-- Missions.Complete. On-call guarantees a truck is deployed (or rented); best of the
-- deployed set wins if there are several.
function Vehicles.GetActiveTruckDamageResistance(source, identifier)
    if Vehicles.IsRentalActive(source) then
        return Vehicles.GetDamageResistanceForModel(GetHashKey(serverConfig.RentalTruck.model))
    end

    local best = 0.0
    for _, vehicle in ipairs(DB.GetDeployedVehicles(identifier) or {}) do
        local tier = findTier(vehicle.tier_id)
        if tier then best = math.max(best, tier.damage_resistance or 0.0) end
    end
    return best
end

-- Tier catalog with the player's own Economy-branch purchase discount already applied to
-- `price`, so the Vehicles tab's displayed price always matches what Purchase actually
-- charges — the client never has to know the discount rate itself to show a correct number.
function Vehicles.GetTiersForPlayer(source)
    local discount = Skills.GetPurchaseDiscount(source)
    local list = {}
    for _, tier in ipairs(serverConfig.VehicleTiers) do
        list[#list + 1] = {
            id = tier.id,
            model = tier.model,
            label = tier.label,
            price = math.floor(tier.price * (1 - discount) + 0.5),
            damage_resistance = tier.damage_resistance,
            level_required = tier.level_required,
        }
    end
    return list
end

-- Same idea as GetTiersForPlayer above, for the Repair action's displayed per-health-point
-- rate. Reads the base rate through Settings (Phase 13) so an admin edit is reflected
-- immediately, falling back to config/server.lua's RepairCost.perHealthPoint on first boot.
function Vehicles.GetRepairCostPerHealthPoint(source)
    return Settings.GetRepairCostPerHealthPoint() * (1 - Skills.GetRepairDiscount(source))
end

function Vehicles.GetOwnedForPlayer(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local list = {}
    for _, row in ipairs(DB.GetOwnedVehicles(player.identifier)) do
        list[#list + 1] = toClientVehicle(row)
    end
    return list
end

function Vehicles.GetDeployedForPlayer(source)
    local player = Player.GetData(source)
    if not player then return {} end

    local list = {}
    for _, row in ipairs(DB.GetDeployedVehicles(player.identifier)) do
        local tier = findTier(row.tier_id)
        list[#list + 1] = { id = row.id, plate = row.plate, model = tier and tier.model or nil }
    end
    return list
end

-- Economy skill branch (e2 "Bulk Discount") reduces this cost via Skills.GetPurchaseDiscount.
function Vehicles.Purchase(source, tierId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local tier = findTier(tierId)
    if not tier then return { ok = false, reason = "invalid_tier" } end

    if player.level < (tier.level_required or 1) then
        return { ok = false, reason = "level_too_low" }
    end

    for _, row in ipairs(DB.GetOwnedVehicles(player.identifier)) do
        if row.tier_id == tierId then
            return { ok = false, reason = "already_owned" }
        end
    end

    local price = math.floor(tier.price * (1 - Skills.GetPurchaseDiscount(source)) + 0.5)

    if Framework.GetMoney(source) < price then
        return { ok = false, reason = "insufficient_funds" }
    end

    Framework.RemoveMoney(source, price)

    local plate = generatePlate()
    DB.CreateVehicle(player.identifier, tierId, plate)

    debug.DebugPrint(("Vehicles.Purchase: %s bought tier %s (plate %s)"):format(player.identifier, tierId, plate))

    return { ok = true, vehicles = Vehicles.GetOwnedForPlayer(source) }
end

-- Same Economy-branch discount as Purchase above, via Skills.GetRepairDiscount.
function Vehicles.Repair(source, vehicleId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier then
        return { ok = false, reason = "not_owned" }
    end

    local missing = (MAX_HEALTH - vehicle.body_health) + (MAX_HEALTH - vehicle.engine_health)
    if missing <= 0 then
        return { ok = false, reason = "already_full_health" }
    end

    local cost = math.floor(missing * Settings.GetRepairCostPerHealthPoint() * (1 - Skills.GetRepairDiscount(source)) + 0.5)

    if Framework.GetMoney(source) < cost then
        return { ok = false, reason = "insufficient_funds" }
    end

    Framework.RemoveMoney(source, cost)
    DB.SaveVehicleHealth(vehicleId, MAX_HEALTH, MAX_HEALTH)

    if vehicle.state == "deployed" then
        TriggerClientEvent("polarix_towjob:vehicleHealthRestored", source, vehicle.plate)
    end

    debug.DebugPrint(("Vehicles.Repair: %s repaired vehicle %d for %d"):format(player.identifier, vehicleId, cost))

    return { ok = true, cost = cost, vehicles = Vehicles.GetOwnedForPlayer(source) }
end

function Vehicles.ParkOut(source, vehicleId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier then
        return { ok = false, reason = "not_owned" }
    end

    if vehicle.state ~= "stored" then
        return { ok = false, reason = "not_stored" }
    end

    local tier = findTier(vehicle.tier_id)
    if not tier then return { ok = false, reason = "invalid_tier" } end

    DB.SetVehicleState(vehicleId, "deployed")

    return {
        ok = true,
        vehicle = {
            id = vehicle.id,
            model = tier.model,
            plate = vehicle.plate,
            body_health = vehicle.body_health,
            engine_health = vehicle.engine_health,
        },
        vehicles = Vehicles.GetOwnedForPlayer(source),
    }
end

RegisterNetEvent("polarix_towjob:registerDeployedTruck", function(vehicleId, netId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier or vehicle.state ~= "deployed" then return end

    deployedTruckNetIds[source] = deployedTruckNetIds[source] or {}
    deployedTruckNetIds[source][vehicleId] = netId
end)

local function resolveDeployedTruckEntity(source, vehicleId)
    local byId = deployedTruckNetIds[source]
    local netId = byId and byId[vehicleId]
    if not netId then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return nil
    end
    return entity
end

-- Dashboard "Park in" — stores a deployed truck from anywhere (design decision: no depot
-- requirement, unlike the in-world Vehicles.Store prompt). Health is read off the live entity
-- server-side when the netId still resolves (ground rule 4), otherwise the last stored health
-- is kept and the client is asked to best-effort despawn it. Blocked while a delivery is
-- active so the player can't strand their tow job (Missions would then fail on truck loss).
function Vehicles.ParkIn(source, vehicleId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier then
        return { ok = false, reason = "not_owned" }
    end

    if vehicle.state ~= "deployed" then
        return { ok = false, reason = "not_deployed" }
    end

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "delivery_in_progress" }
    end

    local entity = resolveDeployedTruckEntity(source, vehicleId)
    if entity then
        DB.SaveVehicleHealth(vehicleId, GetVehicleBodyHealth(entity), GetVehicleEngineHealth(entity))
        DeleteEntity(entity)
    end

    DB.SetVehicleState(vehicleId, "stored")

    if deployedTruckNetIds[source] then
        deployedTruckNetIds[source][vehicleId] = nil
    end

    TriggerClientEvent("polarix_towjob:truckParkedIn", source, { plate = vehicle.plate, needsClientDelete = entity == nil })

    debug.DebugPrint(("Vehicles.ParkIn: %s parked in vehicle %d"):format(player.identifier, vehicleId))

    return { ok = true, vehicles = Vehicles.GetOwnedForPlayer(source) }
end

-- Reads the towed... er, tow truck's live health straight off the networked entity
-- instead of trusting a client-supplied number (ground rule 4) — a lying client could
-- otherwise "store" a wrecked vehicle as if it were undamaged and get a free repair.
function Vehicles.Store(source, vehicleId, netId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier then
        return { ok = false, reason = "not_owned" }
    end

    if vehicle.state ~= "deployed" then
        return { ok = false, reason = "not_deployed" }
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return { ok = false, reason = "invalid_vehicle" }
    end

    local plate = GetVehicleNumberPlateText(entity):gsub("%s+$", "")
    if plate ~= vehicle.plate then
        return { ok = false, reason = "plate_mismatch" }
    end

    local zone = clientConfig.ParkingZone
    local dist = #(GetEntityCoords(entity) - zone.coords)
    if dist > zone.radius then
        return { ok = false, reason = "not_in_zone" }
    end

    DB.SaveVehicleHealth(vehicleId, GetVehicleBodyHealth(entity), GetVehicleEngineHealth(entity))
    DB.SetVehicleState(vehicleId, "stored")

    if deployedTruckNetIds[source] then
        deployedTruckNetIds[source][vehicleId] = nil
    end

    debug.DebugPrint(("Vehicles.Store: %s stored vehicle %d"):format(player.identifier, vehicleId))

    return { ok = true, vehicles = Vehicles.GetOwnedForPlayer(source) }
end

-- Rental billing (Step 7.5). `standalone` distinguishes an on-call rental (spawned via
-- OnCall.StartStandaloneRental with no delivery yet, persists across however many paged jobs
-- the player runs on it) from the older delivery-scoped rental Missions.Accept still spawns
-- for the Admin "Test mission" bypass path — only the latter should be torn down the instant
-- its one delivery ends; see Vehicles.OnDeliveryEnded below.
local rentalState = {} -- [source] = { lastCharge, warned5, warned1, deliveryId, standalone }

function Vehicles.StartRental(source, deliveryId, standalone)
    rentalState[source] = { lastCharge = os.time(), warned5 = false, warned1 = false, deliveryId = deliveryId, standalone = standalone or false }
end

function Vehicles.StopRental(source)
    rentalState[source] = nil
end

function Vehicles.IsRentalActive(source)
    return rentalState[source] ~= nil
end

-- Called once OnCall.AcceptOffer's delivery is created, so a missed payment mid-delivery
-- still routes through Missions.Fail (deliveryId now set) instead of the no-delivery
-- repossession path.
function Vehicles.SetRentalDeliveryId(source, deliveryId)
    local state = rentalState[source]
    if state then state.deliveryId = deliveryId end
end

-- Called from Missions.Complete/Fail/Abort instead of a blanket StopRental — a standalone
-- on-call rental should survive the delivery it was just used for (the player keeps driving
-- the same truck, on-call resumes waiting for the next page); only the delivery-scoped
-- admin-test-run rental gets fully torn down here.
function Vehicles.OnDeliveryEnded(source)
    local state = rentalState[source]
    if not state then return end

    if state.standalone then
        state.deliveryId = nil
    else
        Vehicles.StopRental(source)
    end
end

-- Explicit "give the rental back" action (Vehicles tab) — only valid for a standalone
-- rental with no delivery currently riding on it.
function Vehicles.ReturnRental(source)
    local state = rentalState[source]
    if not state or not state.standalone then
        return { ok = false, reason = "no_active_rental" }
    end
    if state.deliveryId then
        return { ok = false, reason = "delivery_in_progress" }
    end

    rentalState[source] = nil
    TriggerClientEvent("polarix_towjob:repossessRental", source)

    return { ok = true }
end

CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()
        -- Interval/price read fresh from Settings every tick (not cached at thread start) so
        -- a Phase 13 admin edit takes effect on the next tick, no resource restart needed.
        local intervalSeconds = Settings.GetRentalIntervalMinutes() * 60
        local warnAt5 = (serverConfig.RentalWarningMinutesBefore[1] or 5) * 60
        local warnAt1 = (serverConfig.RentalWarningMinutesBefore[2] or 1) * 60

        for source, state in pairs(rentalState) do
            local remaining = intervalSeconds - (now - state.lastCharge)

            if remaining <= 0 then
                local price = Settings.GetRentalPricePerCharge()
                if Framework.GetMoney(source) >= price then
                    Framework.RemoveMoney(source, price)
                    state.lastCharge = now
                    state.warned5 = false
                    state.warned1 = false
                    TriggerClientEvent("polarix_towjob:notify", source, "Rental payment charged.", "info")
                else
                    -- Same auto-fail path as vehicle destruction/timed expiry (design-decisions
                    -- table: "Missed rental payment → same auto-fail path") when a delivery is
                    -- actually riding on this rental. A standalone on-call rental with no
                    -- deliveryId (not currently on a paged job) has nothing for Missions.Fail to
                    -- fail — just clear on-call and the rental state directly instead.
                    -- Cleared before either branch runs (not after) so mid-`pairs()` iteration is
                    -- safe and neither branch can double-clear a nil'd-out entry.
                    TriggerClientEvent("polarix_towjob:repossessRental", source)
                    local deliveryId = state.deliveryId
                    rentalState[source] = nil
                    if deliveryId then
                        Missions.Fail(source, deliveryId, "rental_repossessed")
                    else
                        OnCall.HandleRentalRepossessed(source)
                    end
                end
            elseif remaining <= warnAt1 and not state.warned1 then
                state.warned1 = true
                TriggerClientEvent("polarix_towjob:notify", source, "Rental payment due in 1 minute.", "warning")
            elseif remaining <= warnAt5 and not state.warned5 then
                state.warned5 = true
                TriggerClientEvent("polarix_towjob:notify", source, "Rental payment due in 5 minutes.", "warning")
            end
        end
    end
end)

-- Keeps the client's Store-interaction cache correct across reconnects — otherwise a
-- vehicle deployed in an earlier session would be untrackable by plate after rejoining
-- (see client/modules/garage.lua's `deployedVehicles` cache, which only self-populates
-- from ParkOut calls made in the current session).
Framework.OnPlayerLoaded(function(source)
    TriggerClientEvent("polarix_towjob:syncDeployedVehicles", source, Vehicles.GetDeployedForPlayer(source))
end)

Framework.OnPlayerUnload(function(source)
    Vehicles.StopRental(source)
    deployedTruckNetIds[source] = nil
end)
