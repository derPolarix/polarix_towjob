local serverConfig = require("config.server")
local clientConfig = require("config.client")
local debug = require("shared.debug")
local Locale = require("shared.locale")

Vehicles = {}

local MAX_HEALTH = 1000.0
local PLATE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

-- netId of each deployed truck's entity as reported by the client; lets ParkIn despawn and read health from anywhere. Session-scoped.
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

-- Resolves damage_resistance from the entity's model hash so the rental (no tier_id) works via the "standard" tier model.
function Vehicles.GetDamageResistanceForModel(modelHash)
    for _, tier in ipairs(serverConfig.VehicleTiers) do
        if GetHashKey(tier.model) == modelHash then
            return tier.damage_resistance or 0.0
        end
    end
    return 0.0
end

-- Best resistance among deployed trucks.
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

-- Prices include the player's Economy-branch discount so they match what Purchase charges.
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

-- Rate read through Settings so admin edits apply immediately.
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

-- Repair yields between pricing and charging; concurrent calls would charge against stale health.
local repairing = {}

local function repair(source, vehicleId)
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

    -- A deployed truck's health lives on its entity: the repair only counts if the client can control it. Asked before charging.
    if vehicle.state == "deployed" then
        local ok, reachable = pcall(lib.callback.await, "polarix_towjob:canRepairLiveTruck", source, vehicle.plate)
        if not ok or reachable ~= true then
            return { ok = false, reason = "truck_unreachable" }
        end
    end

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

function Vehicles.Repair(source, vehicleId)
    if repairing[source] then return { ok = false, reason = "busy" } end

    repairing[source] = true
    local ok, result = pcall(repair, source, vehicleId)
    repairing[source] = nil

    if not ok then error(result, 0) end
    return result
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
            livery = tier.livery,
            extras = tier.extras,
            colors = tier.colors,
            mods = tier.mods,
        },
        vehicles = Vehicles.GetOwnedForPlayer(source),
    }
end

local ENTITY_POLL_MS = 200
local ENTITY_POLL_ATTEMPTS = 15

local function trimPlate(plate)
    return (tostring(plate or ""):gsub("%s+$", ""))
end

-- The client reports netId/plate before they reach the server, so a failed match is retried for a few seconds.
local function awaitVehicleEntity(netId, matches)
    if type(netId) ~= "number" then return nil end

    for attempt = 1, ENTITY_POLL_ATTEMPTS do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2 and matches(entity) then
            return entity
        end

        if attempt < ENTITY_POLL_ATTEMPTS then Wait(ENTITY_POLL_MS) end
    end

    return nil
end

Vehicles.AwaitEntity = awaitVehicleEntity

local function isDeployedRowEntity(row, entity)
    local tier = findTier(row.tier_id)

    return tier ~= nil
        and GetEntityModel(entity) == GetHashKey(tier.model)
        and trimPlate(GetVehicleNumberPlateText(entity)) == row.plate
end

-- Only an entity of this tier's model wearing its plate is trusted: the netId feeds DeleteEntity.
RegisterNetEvent("polarix_towjob:registerDeployedTruck", function(vehicleId, netId)
    local source = source
    local player = Player.GetData(source)
    if not player then return end

    local vehicle = DB.GetVehicle(vehicleId)
    if not vehicle or vehicle.identifier ~= player.identifier or vehicle.state ~= "deployed" then return end

    local entity = awaitVehicleEntity(netId, function(candidate) return isDeployedRowEntity(vehicle, candidate) end)
    if not entity then
        debug.Warn(("registerDeployedTruck: rejected netId for vehicle %s from source %s"):format(tostring(vehicleId), source))
        return
    end

    if not Player.GetData(source) then return end

    deployedTruckNetIds[source] = deployedTruckNetIds[source] or {}
    deployedTruckNetIds[source][vehicleId] = netId
end)

-- Deployed trucks, or a client-created rental-model vehicle while a rental is active (no plate on record, hence the owner check).
function Vehicles.AwaitOwnTruck(source, netId)
    local player = Player.GetData(source)
    if not player then return nil end

    local rows = DB.GetDeployedVehicles(player.identifier) or {}
    local rentalModel = Vehicles.IsRentalActive(source) and GetHashKey(serverConfig.RentalTruck.model) or nil

    return awaitVehicleEntity(netId, function(entity)
        for _, row in ipairs(rows) do
            if isDeployedRowEntity(row, entity) then return true end
        end

        return rentalModel ~= nil and GetEntityModel(entity) == rentalModel and NetworkGetEntityOwner(entity) == source
    end)
end

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

-- Dashboard park-in works from anywhere. Health is read off the entity when the netId resolves, else the last stored value is kept. Blocked during a delivery.
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

-- A truck destroyed mid-delivery leaves its row stuck in `deployed`; force it back to stored at zero health and clear the client cache and wreck.
function Vehicles.HandleOwnedTruckDestroyed(source, truckNetId)
    local player = Player.GetData(source)
    if not player then return end

    local targetVehicleId = nil
    local byId = deployedTruckNetIds[source]
    if byId and truckNetId then
        for vehicleId, netId in pairs(byId) do
            if netId == truckNetId then
                targetVehicleId = vehicleId
                break
            end
        end
    end

    -- No netId match: fall back only when exactly one truck is deployed, so the wrong one can't be reset.
    if not targetVehicleId then
        local deployed = DB.GetDeployedVehicles(player.identifier)
        if #deployed == 1 then targetVehicleId = deployed[1].id else return end
    end

    DB.SaveVehicleHealth(targetVehicleId, 0.0, 0.0)
    DB.SetVehicleState(targetVehicleId, "stored")

    if deployedTruckNetIds[source] then
        deployedTruckNetIds[source][targetVehicleId] = nil
    end

    local row = DB.GetVehicle(targetVehicleId)
    if row then
        TriggerClientEvent("polarix_towjob:truckParkedIn", source, { plate = row.plate, needsClientDelete = true })
    end

    debug.DebugPrint(("Vehicles.HandleOwnedTruckDestroyed: %s truck %d reset to stored"):format(player.identifier, targetVehicleId))
end

-- Health is read off the networked entity, not client-supplied (else a wrecked truck could be stored as undamaged for a free repair).
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

    if DB.GetActiveDelivery(player.identifier) then
        return { ok = false, reason = "delivery_in_progress" }
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

-- standalone = on-call rental persisting across jobs; otherwise a delivery-scoped admin test rental, torn down when its delivery ends.
local rentalState = {} -- [source] = { lastCharge, warned5, warned1, deliveryId, standalone, free }

function Vehicles.CanAffordRental(source)
    return Framework.GetMoney(source) >= Settings.GetRentalPricePerCharge()
end

-- The first interval is charged up front, otherwise return-and-rerent would run free. Admin test runs are free.
function Vehicles.StartRental(source, deliveryId, standalone, free)
    if rentalState[source] then return false, "already_renting" end

    if not free then
        local price = Settings.GetRentalPricePerCharge()
        if Framework.GetMoney(source) < price then return false, "insufficient_funds" end

        Framework.RemoveMoney(source, price)
        TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.rental_payment_charged"), "info")
    end

    rentalState[source] = { lastCharge = os.time(), warned5 = false, warned1 = false, deliveryId = deliveryId, standalone = standalone or false, free = free or false }
    return true
end

function Vehicles.StopRental(source)
    rentalState[source] = nil
end

function Vehicles.IsRentalActive(source)
    return rentalState[source] ~= nil
end

-- Once the delivery exists, a missed payment routes through Missions.Fail instead of plain repossession.
function Vehicles.SetRentalDeliveryId(source, deliveryId)
    local state = rentalState[source]
    if state then state.deliveryId = deliveryId end
end

-- Standalone rentals survive their delivery; only the delivery-scoped rental is torn down.
function Vehicles.OnDeliveryEnded(source)
    local state = rentalState[source]
    if not state then return end

    if state.standalone then
        state.deliveryId = nil
    else
        Vehicles.StopRental(source)
    end
end

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
        -- Read from Settings each tick so admin edits apply without a restart.
        local intervalSeconds = Settings.GetRentalIntervalMinutes() * 60
        local warnAt5 = (serverConfig.RentalWarningMinutesBefore[1] or 5) * 60
        local warnAt1 = (serverConfig.RentalWarningMinutesBefore[2] or 1) * 60

        for source, state in pairs(rentalState) do
            if state.free then goto continue end

            local remaining = intervalSeconds - (now - state.lastCharge)

            if remaining <= 0 then
                local price = Settings.GetRentalPricePerCharge()
                if Framework.GetMoney(source) >= price then
                    Framework.RemoveMoney(source, price)
                    state.lastCharge = now
                    state.warned5 = false
                    state.warned1 = false
                    TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.rental_payment_charged"), "info")
                else
                    -- With a delivery on this rental: Missions.Fail. Standalone with no delivery: just clear on-call and rental state.
                    -- State is cleared before either branch so mid-pairs() iteration is safe.
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
                TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.rental_payment_due_1m"), "warning")
            elseif remaining <= warnAt5 and not state.warned5 then
                state.warned5 = true
                TriggerClientEvent("polarix_towjob:notify", source, Locale("notify.rental_payment_due_5m"), "warning")
            end

            ::continue::
        end
    end
end)

-- Keeps the client's Store cache correct across reconnects (it only self-populates from ParkOut in the current session).
Framework.OnPlayerLoaded(function(source)
    TriggerClientEvent("polarix_towjob:syncDeployedVehicles", source, Vehicles.GetDeployedForPlayer(source))
end)

Framework.OnPlayerUnload(function(source)
    Vehicles.StopRental(source)
    deployedTruckNetIds[source] = nil
end)
