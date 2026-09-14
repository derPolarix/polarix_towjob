local clientConfig = require("config.client")
local Locale = require("shared.locale")

local HUD_UPDATE_INTERVAL_MS = 500
local DROPOFF_RENDER_DISTANCE = 30.0
-- dropoff_z is stored at ped-root height (admin editor's "use current position"); drop the
-- outline this far to paint it on the ground. Matches polarix_truckerjob's parking outline.
local GROUND_OFFSET = 0.8

local function buildUpdatePayload(delivery)
    local playerCoords = GetEntityCoords(PlayerPedId())
    -- While searching, distance is to the hint-circle center rather than the vehicle itself —
    -- the HUD must not be a more precise locator than the map blip.
    local objective = delivery.state == "searching" and delivery.searchHint or delivery.mission.dropoff
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
        damagePercent = delivery.state == "found" and delivery.damagePercent or nil,
        secondsRemaining = secondsRemaining,
    }
end

-- Global: also drawn by the admin mission editor's dropoff preview (client/modules/admin.lua).
function DrawOutlineRectangle(center, heading, length, width, correct)
    local rad = math.rad(heading or 0.0)
    local lengthDir = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local widthDir = vector3(math.cos(rad), math.sin(rad), 0.0)

    local hl, hw = length / 2, width / 2
    local p1 = center + lengthDir * hl + widthDir * hw
    local p2 = center + lengthDir * hl - widthDir * hw
    local p3 = center - lengthDir * hl - widthDir * hw
    local p4 = center - lengthDir * hl + widthDir * hw

    local r, g, b = 210, 75, 58
    if correct then r, g, b = 47, 199, 114 end

    DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, 220)
    DrawLine(p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, r, g, b, 220)
    DrawLine(p3.x, p3.y, p3.z, p4.x, p4.y, p4.z, r, g, b, 220)
    DrawLine(p4.x, p4.y, p4.z, p1.x, p1.y, p1.z, r, g, b, 220)
end

-- Display-only preview of the server's own isWithinDropoffZone (server/modules/missions.lua)
-- — mission.dropoff_heading_tolerance is sent down at accept time so this never drifts out
-- of sync with the authoritative server config value (client_scripts can't require() a
-- server_scripts-only config file, see Phase 7's judgment-call note on that exact limitation).
local function isAligned(mission, coords, heading)
    local d = mission.dropoff
    local rad = math.rad(d.heading or 0.0)
    local lengthDir = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local widthDir = vector3(math.cos(rad), math.sin(rad), 0.0)
    local center = vector3(d.x, d.y, d.z)

    local delta = coords - center
    local projLength = delta.x * lengthDir.x + delta.y * lengthDir.y
    local projWidth = delta.x * widthDir.x + delta.y * widthDir.y

    if math.abs(projLength) > (mission.dropoff_length or 10.0) / 2 then return false end
    if math.abs(projWidth) > (mission.dropoff_width or 6.0) / 2 then return false end

    local headingDiff = (heading - (d.heading or 0.0)) % 360.0
    if headingDiff > 180.0 then headingDiff = 360.0 - headingDiff end

    return headingDiff <= (mission.dropoff_heading_tolerance or 25.0)
end

local function canComplete()
    local delivery = Vehicle.GetCurrentDelivery()
    if not delivery or delivery.state ~= "found" then return false end
    if not DoesEntityExist(delivery.targetVehicle) then return false end

    return isAligned(delivery.mission, GetEntityCoords(delivery.targetVehicle), GetEntityHeading(delivery.targetVehicle))
end

local function attemptComplete()
    local delivery = Vehicle.GetCurrentDelivery()
    if not delivery or not canComplete() then return end

    local result = lib.callback.await("polarix_towjob:completeDelivery", false, delivery.deliveryId)
    if result and result.ok then
        Vehicle.EndDelivery("completed")
    else
        Framework.Notify(Locale("notify.delivery_not_confirmable"), "error")
    end
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

-- Renders the red/green ground outline near the dropoff and drives the [E] confirm. The
-- rectangle checks the *towed vehicle's* position/heading, never the player's/tow truck's.
CreateThread(function()
    local promptShown = false

    local function hidePromptIfShown()
        if promptShown then
            promptShown = false
            lib.hideTextUI()
        end
    end

    while true do
        local delivery = Vehicle.GetCurrentDelivery()

        if delivery and delivery.state == "found" then
            local d = delivery.mission.dropoff
            local outlineCenter = vector3(d.x, d.y, d.z - GROUND_OFFSET)
            local nearDropoff = #(GetEntityCoords(PlayerPedId()) - outlineCenter) < DROPOFF_RENDER_DISTANCE

            if nearDropoff then
                local aligned = canComplete()
                DrawOutlineRectangle(outlineCenter, d.heading or 0.0, delivery.mission.dropoff_length or 10.0, delivery.mission.dropoff_width or 6.0, aligned)

                if aligned then
                    if not promptShown then
                        promptShown = true
                        lib.showTextUI(Locale("ui.confirm_delivery"))
                    end
                    if IsControlJustReleased(0, 38) then
                        attemptComplete()
                    end
                else
                    hidePromptIfShown()
                end

                Wait(0)
            else
                hidePromptIfShown()
                Wait(clientConfig.DeliveryZoneCheckIntervalMs)
            end
        else
            hidePromptIfShown()
            Wait(clientConfig.DeliveryZoneCheckIntervalMs)
        end
    end
end)
