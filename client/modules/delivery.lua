local clientConfig = require("config.client")

local HUD_UPDATE_INTERVAL_MS = 500
local DROPOFF_RENDER_DISTANCE = 30.0

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
        damagePercent = delivery.state == "found" and delivery.damagePercent or nil,
        secondsRemaining = secondsRemaining,
    }
end

-- Global (not local): a generic heading-aligned-rectangle outline, reusable as-is by the
-- Phase 13 admin mission editor for dropoff preview — same rationale trucker job's own
-- copy of this function documents.
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
        Framework.Notify("Could not complete the delivery yet — check the vehicle is fully inside the outline.", "error")
    end
end

local dropoffZoneMissionId = nil
local dropoffZoneId = nil

-- Captures/reuses ox_target's own returned zone id for removal rather than a name-based
-- lookup — the box zone's dropoff coords move per mission, so (unlike npc.lua's static
-- entity target or garage.lua's permanent parking sphere) this one must be torn down and
-- recreated for each new delivery instead of registered once at resource start.
local function removeDropoffZone()
    if dropoffZoneId and GetResourceState("ox_target") == "started" then
        exports.ox_target:removeZone(dropoffZoneId)
    end
    dropoffZoneId = nil
    dropoffZoneMissionId = nil
end

local function ensureDropoffZone(delivery)
    if dropoffZoneMissionId == delivery.mission.id then return end
    removeDropoffZone()

    if GetResourceState("ox_target") ~= "started" then return end

    local d = delivery.mission.dropoff
    dropoffZoneId = exports.ox_target:addBoxZone({
        coords = vector3(d.x, d.y, d.z),
        size = vector3(delivery.mission.dropoff_width or 6.0, delivery.mission.dropoff_length or 10.0, 4.0),
        rotation = d.heading or 0.0,
        options = {
            {
                name = "polarix_towjob:dropoffzone",
                icon = "fa-solid fa-flag-checkered",
                label = "Confirm Delivery",
                canInteract = canComplete,
                onSelect = attemptComplete,
            },
        },
    })
    dropoffZoneMissionId = delivery.mission.id
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

-- Step 10.2: renders the red/green dropoff outline once near it, and drives the confirm
-- interaction (ground rule 5: ox_target box zone + native marker/[E] fallback). Rectangle
-- checks the *towed vehicle's* position/heading, never the player's/tow truck's own.
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
            ensureDropoffZone(delivery)

            local d = delivery.mission.dropoff
            local dropoffCenter = vector3(d.x, d.y, d.z)
            local nearDropoff = #(GetEntityCoords(PlayerPedId()) - dropoffCenter) < DROPOFF_RENDER_DISTANCE

            if nearDropoff then
                local aligned = canComplete()
                DrawOutlineRectangle(dropoffCenter, d.heading or 0.0, delivery.mission.dropoff_length or 10.0, delivery.mission.dropoff_width or 6.0, aligned)

                if GetResourceState("ox_target") ~= "started" then
                    if aligned then
                        if not promptShown then
                            promptShown = true
                            lib.showTextUI("[E] Confirm Delivery")
                        end
                        if IsControlJustReleased(0, 38) then
                            attemptComplete()
                        end
                    else
                        hidePromptIfShown()
                    end
                end

                Wait(0)
            else
                hidePromptIfShown()
                Wait(clientConfig.DeliveryZoneCheckIntervalMs)
            end
        else
            removeDropoffZone()
            hidePromptIfShown()
            Wait(clientConfig.DeliveryZoneCheckIntervalMs)
        end
    end
end)
