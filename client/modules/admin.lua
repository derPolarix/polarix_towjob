Admin = {}

RegisterNetEvent("polarix_towjob:openAdminUi", function()
    SetFocus(true)
    SendMessage("openAdminSettings", {})
end)

function Admin.GetCurrentPosition()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
end

-- Live dropoff-rectangle preview while an admin edits a mission's dropoff fields, reusing
-- the exact DrawOutlineRectangle primitive the real in-game delivery flow already draws
-- (client/modules/delivery.lua, kept global there specifically for this reuse — see that
-- file's own comment). Always red (`correct=false`) — there's no "aligned" concept in the
-- editor, it's just a position/size/heading preview.
local dropoffPreview = { active = false, x = 0.0, y = 0.0, z = 0.0, heading = 0.0, length = 10.0, width = 6.0 }

function Admin.SetDropoffPreview(data)
    if data and data.active then
        dropoffPreview.active = true
        dropoffPreview.x, dropoffPreview.y, dropoffPreview.z = data.x, data.y, data.z
        dropoffPreview.heading = data.heading or 0.0
        dropoffPreview.length = data.length or 10.0
        dropoffPreview.width = data.width or 6.0
    else
        dropoffPreview.active = false
    end
end

CreateThread(function()
    while true do
        if dropoffPreview.active then
            DrawOutlineRectangle(vector3(dropoffPreview.x, dropoffPreview.y, dropoffPreview.z), dropoffPreview.heading, dropoffPreview.length, dropoffPreview.width, false)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Semi-transparent radius blip while an admin edits a mission's search-center/radius,
-- same AddBlipForRadius primitive the live search-circle blip uses (client/modules/vehicle.lua).
local searchPreviewBlip = nil

function Admin.SetSearchPreview(data)
    if searchPreviewBlip then
        RemoveBlip(searchPreviewBlip)
        searchPreviewBlip = nil
    end

    if data and data.active then
        searchPreviewBlip = AddBlipForRadius(data.x, data.y, data.z, data.radius or 60.0)
        SetBlipColour(searchPreviewBlip, 5)
        SetBlipAlpha(searchPreviewBlip, 128)
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if searchPreviewBlip then RemoveBlip(searchPreviewBlip) end
end)
