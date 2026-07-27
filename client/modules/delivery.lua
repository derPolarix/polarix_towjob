local HUD_UPDATE_INTERVAL_MS = 500

local function buildUpdatePayload(delivery)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local objective = delivery.state == "searching" and delivery.mission.search_center or delivery.mission.dropoff
    local distance = math.floor(#(playerCoords - vector3(objective.x, objective.y, objective.z)) + 0.5)

    local secondsRemaining = nil
    if delivery.deadlineAt then
        secondsRemaining = math.max(0, delivery.deadlineAt - os.time())
    end

    return {
        deliveryId = delivery.deliveryId,
        state = delivery.state,
        missionName = delivery.mission.name,
        vehicleLabel = delivery.mission.vehicle_label,
        vehicleColors = delivery.mission.vehicle_colors,
        distance = distance,
        secondsRemaining = secondsRemaining,
    }
end

CreateThread(function()
    local wasActive = false

    while true do
        local delivery = Vehicle.GetCurrentDelivery()

        if delivery then
            wasActive = true
            SendMessage("activeDeliveryUpdate", buildUpdatePayload(delivery))
        elseif wasActive then
            wasActive = false
            SendMessage("activeDeliveryEnded", {})
        end

        Wait(HUD_UPDATE_INTERVAL_MS)
    end
end)
