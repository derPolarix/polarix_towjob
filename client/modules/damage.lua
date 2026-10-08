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

-- Only outright destruction is fast-reported; despawn is left to the server sweep so an unstreamed target isn't misread as gone.
-- damagePercent is display-only; Missions.Complete recomputes it server-side.
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
