local serverConfig = require("config.server")
local clientConfig = require("config.client")
local debug = require("shared.debug")

Vehicles = {}

local MAX_HEALTH = 1000.0
local PLATE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

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
    if not entity or entity == 0 or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
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

    debug.DebugPrint(("Vehicles.Store: %s stored vehicle %d"):format(player.identifier, vehicleId))

    return { ok = true, vehicles = Vehicles.GetOwnedForPlayer(source) }
end

-- Rental billing (Step 7.5). `Vehicles.StartRental`/`StopRental` are the interface
-- Phase 8's mission-accept/complete flow will call; not wired to any real accept flow
-- yet since Phase 8 doesn't exist in this build. Exercised standalone in the meantime
-- via /towjobtestrental (server/commands.lua), same precedent as /towjobtestactive.
local rentalState = {} -- [source] = { lastCharge, warned5, warned1, deliveryId }

function Vehicles.StartRental(source, deliveryId)
    rentalState[source] = { lastCharge = os.time(), warned5 = false, warned1 = false, deliveryId = deliveryId }
end

function Vehicles.StopRental(source)
    rentalState[source] = nil
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
                    -- table: "Missed rental payment → same auto-fail path") — Missions.Fail
                    -- clears activeDeliveryState and calls Vehicles.StopRental itself, which nils
                    -- this very `rentalState[source]` entry; safe to do mid-`pairs()` iteration
                    -- since Lua only forbids adding new keys during traversal, not clearing existing ones.
                    TriggerClientEvent("polarix_towjob:repossessRental", source)
                    Missions.Fail(source, state.deliveryId, "rental_repossessed")
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

Framework.OnPlayerUnload(Vehicles.StopRental)
