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
            -- ground offset, same as the live delivery outline
            DrawOutlineRectangle(vector3(dropoffPreview.x, dropoffPreview.y, dropoffPreview.z - 0.8), dropoffPreview.heading, dropoffPreview.length, dropoffPreview.width, false)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Local-only (networked=false) ghost of the real model, to show whether the car fits the gap.
local spawnPointGhosts = {}

local function deleteGhost(index)
    local entity = spawnPointGhosts[index]
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    spawnPointGhosts[index] = nil
end

function Admin.ClearSpawnPointGhosts()
    for index in pairs(spawnPointGhosts) do deleteGhost(index) end
    spawnPointGhosts = {}
end

function Admin.PreviewSpawnPoint(data)
    if not data or not data.index then return { ok = false } end

    deleteGhost(data.index)

    local model = data.model
    if not model or model == "" then return { ok = false, reason = "invalid_model" } end

    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return { ok = false, reason = "invalid_model" }
    end

    lib.requestModel(hash)

    local entity = CreateVehicle(hash, data.x, data.y, data.z, data.heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    SetEntityAlpha(entity, 150, false)
    SetEntityCollision(entity, false, false)
    SetEntityInvincible(entity, true)
    SetVehicleOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)

    spawnPointGhosts[data.index] = entity

    return { ok = true }
end

function Admin.ConfirmSpawnPoint(data)
    if data and data.index then deleteGhost(data.index) end
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Admin.ClearSpawnPointGhosts()
end)
