local debug = require("shared.debug")
local Locale = require("shared.locale")

Police = {}

-- Convenience only; Priority.Mark decides everything server-side. Config comes from the server since config/server.lua isn't loadable from client_scripts.
local markConfig = { canMark = false, distance = 12.0 }
local blips = {} -- [jobId] = blip handle
local busy = false

local function refreshConfig()
    local result = lib.callback.await("polarix_towjob:getPoliceMarkConfig", false)
    if not result then return end

    markConfig = result
    return result
end

local function clearBlips()
    for id, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[id] = nil
    end
end

local function addBlip(job)
    if blips[job.id] then RemoveBlip(blips[job.id]) end

    local blip = AddBlipForCoord(job.coords.x, job.coords.y, job.coords.z)
    SetBlipSprite(blip, 68) -- tow truck
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Locale("blip.tow_request"):format(job.label or ""))
    EndTextCommandSetBlipName(blip)

    blips[job.id] = blip
end

RegisterNetEvent("polarix_towjob:priorityJobAdded", function(job)
    addBlip(job)
end)

RegisterNetEvent("polarix_towjob:priorityJobRemoved", function(jobId)
    if not blips[jobId] then return end
    RemoveBlip(blips[jobId])
    blips[jobId] = nil
end)

-- Label and colours are display-only hints; the server reads plate, model, ownership and position itself.
local function requestMark(vehicle)
    if busy or not DoesEntityExist(vehicle) then return end
    busy = true

    local colors = nil
    local primary, secondary = GetVehicleColours(vehicle)
    if primary then colors = { primary = primary, secondary = secondary } end

    local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    if not label or label == "NULL" then label = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    lib.callback.await("polarix_towjob:markForTow", false, netId, label, colors)

    busy = false
end

-- Pre-filter only; "is a registered player vehicle" needs the framework table, checked server-side.
local function looksMarkable(vehicle)
    if not markConfig.canMark then return false end
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if vehicle == GetVehiclePedIsIn(PlayerPedId(), false) then return false end

    return IsVehicleSeatFree(vehicle, -1)
end

local function raycastVehicle()
    local ped = PlayerPedId()
    local from = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local to = from + direction * (markConfig.distance or 12.0)

    -- Synchronous: the command needs the result in the same frame.
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 2, ped, 4)
    local _, hit, _, _, entity = GetShapeTestResult(handle)

    if hit ~= 0 and entity and entity ~= 0 and IsEntityAVehicle(entity) then return entity end
end

CreateThread(function()
    -- Wait for the framework to assign the job first, otherwise a connecting officer is told they can't mark.
    Wait(5000)

    local config = refreshConfig()
    if not config then return end

    for _, job in ipairs(config.blips or {}) do
        addBlip(job)
    end

    if Target.IsAvailable() then
        Target.AddGlobalVehicle({
            {
                name = "polarix_towjob:markForTow",
                icon = "fa-solid fa-truck-ramp-box",
                label = Locale("target.mark_for_tow"),
                distance = markConfig.distance or 12.0,
                canInteract = function(entity) return looksMarkable(entity) end,
                onSelect = requestMark,
            },
        })

        debug.DebugPrint("Police: registered target mark-for-tow option")
    else
        RegisterCommand(config.command or "towrequest", function()
            if not markConfig.canMark then
                Framework.Notify(Locale("notify.mark_not_authorized"), "error")
                return
            end

            local vehicle = raycastVehicle()
            if not vehicle then
                Framework.Notify(Locale("notify.mark_vehicle_not_found"), "error")
                return
            end

            requestMark(vehicle)
        end, false)

        debug.DebugPrint("Police: no target system available, registered /" .. (config.command or "towrequest"))
    end

    -- No shared job-change event across frameworks, so the officer flag is re-read periodically.
    while true do
        Wait(60000)
        local previous = markConfig.canMark
        refreshConfig()

        if previous and not markConfig.canMark then clearBlips() end
        if not previous and markConfig.canMark then
            for _, job in ipairs(markConfig.blips or {}) do addBlip(job) end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
end)
