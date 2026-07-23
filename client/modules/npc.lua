local clientConfig = require("config.client")

local npc = nil

local function onInteract()
    Dashboard.Open()
end

local function createBlip(coords, blip)
    local id = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(id, blip.sprite)
    SetBlipColour(id, blip.color)
    SetBlipScale(id, blip.scale)
    SetBlipAsShortRange(id, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blip.label)
    EndTextCommandSetBlipName(id)
end

local function setupInteraction()
    if GetResourceState("ox_target") == "started" then
        exports.ox_target:addLocalEntity(npc, {
            {
                name = "polarix_towjob:npc",
                icon = "fa-solid fa-clipboard-list",
                label = "Open Tow Job Dashboard",
                onSelect = onInteract,
            },
        })
        return
    end

    CreateThread(function()
        local textUIShown = false

        while DoesEntityExist(npc) do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local npcCoords = GetEntityCoords(npc)
            local dist = #(playerCoords - npcCoords)
            local sleep = 1000

            if dist < 5.0 then
                sleep = 0
                DrawMarker(2, npcCoords.x, npcCoords.y, npcCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 90, 200, 255, 150, false, true, 2, false, nil, nil, false)

                if dist < 1.5 then
                    if not textUIShown then
                        textUIShown = true
                        lib.showTextUI("[E] Open Tow Job Dashboard")
                    end

                    if IsControlJustReleased(0, 38) then
                        onInteract()
                    end
                elseif textUIShown then
                    textUIShown = false
                    lib.hideTextUI()
                end
            elseif textUIShown then
                textUIShown = false
                lib.hideTextUI()
            end

            Wait(sleep)
        end
    end)
end

local function spawnNpc()
    local cfg = clientConfig.NPC

    lib.requestModel(cfg.model)
    npc = CreatePed(4, cfg.model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    SetModelAsNoLongerNeeded(cfg.model)

    if cfg.scenario then
        TaskStartScenarioInPlace(npc, cfg.scenario, 0, true)
    elseif cfg.animation then
        lib.requestAnimDict(cfg.animation.dict)
        TaskPlayAnim(npc, cfg.animation.dict, cfg.animation.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    if cfg.blip then
        createBlip(cfg.coords, cfg.blip)
    end

    setupInteraction()
end

CreateThread(spawnNpc)
