local clientConfig = require("config.client")

local trackedDeliveryId = nil
local baseline = nil
local reportedDestroyed = false

local function isDestroyed(entity)
    return entity and DoesEntityExist(entity) and IsEntityDead(entity)
end

local function resetTracking()
    trackedDeliveryId = nil
    baseline = nil
    reportedDestroyed = false
end

-- From attach to placement (design-decisions table): polls the towed vehicle's body/engine
-- health, computes a local display-only damage percent (Vehicle.GetCurrentDelivery() is a
-- shared table reference, so writing `.damagePercent` here is read directly by
-- client/modules/delivery.lua's periodic Active Delivery UI push) and reports vehicle
-- destruction to the server. This preview is not authoritative — Missions.Complete
-- (server) re-reads the same entities independently for the real payout math.
CreateThread(function()
    while true do
        local delivery = Vehicle.GetCurrentDelivery()

        if delivery and delivery.state == "attached" then
            if trackedDeliveryId ~= delivery.deliveryId then
                trackedDeliveryId = delivery.deliveryId
                reportedDestroyed = false
                baseline = DoesEntityExist(delivery.targetVehicle) and {
                    body = GetVehicleBodyHealth(delivery.targetVehicle),
                    engine = GetVehicleEngineHealth(delivery.targetVehicle),
                } or nil
            end

            local target = delivery.targetVehicle
            local towTruck = delivery.towTruck

            if not reportedDestroyed and (not DoesEntityExist(target) or isDestroyed(target) or isDestroyed(towTruck)) then
                reportedDestroyed = true
                TriggerServerEvent("polarix_towjob:reportVehicleDestroyed", delivery.deliveryId)
            elseif baseline and DoesEntityExist(target) then
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
