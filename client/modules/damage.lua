local clientConfig = require("config.client")

local trackedDeliveryId = nil
local baseline = nil
local reportedVehicleDestroyed = false
local reportedTruckDestroyed = false
local truckEntity = nil
local truckNetIdSent = false

local function isDestroyed(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and IsEntityDead(entity)
end

local function resetTracking()
    trackedDeliveryId = nil
    baseline = nil
    reportedVehicleDestroyed = false
    reportedTruckDestroyed = false
    truckEntity = nil
    truckNetIdSent = false
end

-- Fail-condition watch for the whole delivery: the target vehicle and the tow truck being
-- destroyed both fail the mission. The client only fast-reports outright destruction (dead
-- entity) — deletion/despawn is left to the server's own 5s sweep (server/modules/missions.lua)
-- so a target that's simply unstreamed during the search phase isn't misread as gone.
-- Also computes a local display-only towed-vehicle damage percent once the vehicle is found
-- (Vehicle.GetCurrentDelivery() is a shared table ref, so `.damagePercent` is read directly by
-- client/modules/delivery.lua's Active Delivery UI push). That preview is not authoritative —
-- Missions.Complete re-reads the entities server-side for the real payout math.
CreateThread(function()
    while true do
        local delivery = Vehicle.GetCurrentDelivery()

        if delivery then
            if trackedDeliveryId ~= delivery.deliveryId then
                resetTracking()
                trackedDeliveryId = delivery.deliveryId
            end

            local target = delivery.targetVehicle
            if not reportedVehicleDestroyed and isDestroyed(target) then
                reportedVehicleDestroyed = true
                TriggerServerEvent("polarix_towjob:reportVehicleDestroyed", delivery.deliveryId)
            end

            if not truckEntity or not DoesEntityExist(truckEntity) then
                truckEntity = Garage.ResolveActiveTruck()
                if truckEntity and not truckNetIdSent then
                    truckNetIdSent = true
                    TriggerServerEvent("polarix_towjob:setTowTruck", delivery.deliveryId, NetworkGetNetworkIdFromEntity(truckEntity))
                end
            elseif not reportedTruckDestroyed and isDestroyed(truckEntity) then
                reportedTruckDestroyed = true
                TriggerServerEvent("polarix_towjob:reportTowTruckDestroyed", delivery.deliveryId)
            end

            if delivery.state == "found" and DoesEntityExist(target) then
                baseline = baseline or {
                    body = GetVehicleBodyHealth(target),
                    engine = GetVehicleEngineHealth(target),
                }
                local bodyLoss = math.max(0, baseline.body - GetVehicleBodyHealth(target))
                local engineLoss = math.max(0, baseline.engine - GetVehicleEngineHealth(target))
                delivery.damagePercent = math.min(100, math.floor(((bodyLoss + engineLoss) / 2000.0) * 100 + 0.5))
            end
        else
            resetTracking()
        end

        Wait(clientConfig.DamageCheckIntervalMs)
    end
end)
