local debug = require("shared.debug")
local clientConfig = require("config.client")
local Locale = require("shared.locale")

Vehicle = {}

local VEHICLE_FOUND_RADIUS = clientConfig.VehicleFoundRadius or 12.0
local SPAWN_POINT_CLEARANCE = clientConfig.SpawnPointClearance or 4.0

-- Set once Accept returns `needsParkOut` (2+ owned tow trucks) — the delivery row
-- already exists server-side at this point, we're just waiting for the player to
-- Park Out a truck (Phase 7's VehiclesTab action) before spawning the target vehicle.
local pendingMission = nil

-- Anything with someone in it, or flagged as a mission entity (framework garage vehicles,
-- another delivery's target), makes a spot unusable rather than being deleted. The player's
-- own tow truck is spawned with a plain CreateVehicle (client/modules/garage.lua) so it isn't
-- mission-flagged — hence the explicit guard on the vehicle they're in or just stepped out of.
local function isProtectedVehicle(vehicle)
    if IsEntityAMissionEntity(vehicle) then return true end
    if not IsVehicleSeatFree(vehicle, -1) or GetVehicleNumberOfPassengers(vehicle) > 0 then return true end

    return vehicle == GetVehiclePedIsIn(PlayerPedId(), true)
end

-- Ambient traffic sitting in a hand-placed spot is deleted to make room; a protected vehicle
-- means the spot is unusable and the caller falls through to the next candidate.
local function tryClearSpawnPoint(point)
    local coords = vector3(point.x, point.y, point.z)
    local blocking = {}

    -- Collected first, deleted only once the whole spot is known to be usable — otherwise a
    -- spot rejected on its last vehicle would already have had the earlier ones destroyed.
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - coords) <= SPAWN_POINT_CLEARANCE then
            if isProtectedVehicle(vehicle) then return false end

            blocking[#blocking + 1] = vehicle
        end
    end

    for _, vehicle in ipairs(blocking) do
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteEntity(vehicle)
    end

    return true
end

-- Walks the candidates the server handed down (already shuffled and reservation-filtered) and
-- takes the first spot that can be cleared. If every one is blocked the last is used anyway —
-- a job that can't spawn its vehicle at all is worse than one spawned in a tight spot.
-- Returns the entity plus the candidate index, which the caller reports back so the server can
-- free the reservations on the spots this delivery didn't take.
local function spawnTargetVehicle(mission)
    local candidates = mission.spawn_candidates or {}
    if #candidates == 0 then
        debug.Warn("Vehicle.spawnTargetVehicle: mission", mission.id, "has no spawn candidates")
        return nil
    end

    local chosenIndex = #candidates
    for index, candidate in ipairs(candidates) do
        if tryClearSpawnPoint(candidate.point) then
            chosenIndex = index
            break
        end
    end

    local chosen = candidates[chosenIndex]
    local point = chosen.point

    lib.requestModel(mission.vehicle_model)

    local entity = CreateVehicle(mission.vehicle_model, point.x, point.y, point.z, point.heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(mission.vehicle_model)
    SetVehicleOnGroundProperly(entity)

    if mission.vehicle_colors then
        SetVehicleColours(entity, mission.vehicle_colors.primary, mission.vehicle_colors.secondary)
    end

    debug.DebugPrint("Vehicle.spawnTargetVehicle: spawned", mission.vehicle_model, "at", point.x, point.y, point.z)

    return entity, chosenIndex, chosen.hint
end

local function createSearchBlip(center, radius)
    local area = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipColour(area, 5)
    SetBlipAlpha(area, 128)

    local route = AddBlipForCoord(center.x, center.y, center.z)
    SetBlipSprite(route, 1)
    SetBlipColour(route, 5)
    SetBlipRoute(route, true)
    SetBlipRouteColour(route, 5)

    return area, route
end

local function createDropoffBlip(dropoff)
    local id = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
    SetBlipSprite(id, 477)
    SetBlipColour(id, 5)
    SetBlipRoute(id, true)
    SetBlipRouteColour(id, 5)
    return id
end

-- `state` is "searching" or "found". The player rigs and tows the vehicle with GTA's native
-- tow mechanics — reaching it is all the job tracks, there is no attach step.
local currentDelivery = nil

local function setupFoundDetection(entity)
    CreateThread(function()
        while currentDelivery and currentDelivery.targetVehicle == entity and DoesEntityExist(entity)
            and currentDelivery.state == "searching" do
            if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity)) <= VEHICLE_FOUND_RADIUS then
                currentDelivery.state = "found"

                if currentDelivery.blip then
                    RemoveBlip(currentDelivery.blip)
                    currentDelivery.blip = nil
                end
                if currentDelivery.searchRouteBlip then
                    RemoveBlip(currentDelivery.searchRouteBlip)
                    currentDelivery.searchRouteBlip = nil
                end
                currentDelivery.dropoffBlip = createDropoffBlip(currentDelivery.mission.dropoff)

                TriggerServerEvent("polarix_towjob:vehicleFound", currentDelivery.deliveryId)
                Framework.Notify(Locale("notify.vehicle_located"), "success")
                return
            end

            Wait(500)
        end
    end)
end

-- Detaches/despawns the target vehicle and clears delivery state. Called directly for
-- the in-world completion confirm, and via the `polarix_towjob:deliveryEnded` net event
-- below for every server-driven end (complete/fail/abort/cancel).
function Vehicle.EndDelivery(reason)
    -- A delivery that ends while the player is still choosing a truck to park out (abort, timeout,
    -- rental repossession) must not be resumed by the next park-out.
    pendingMission = nil

    if not currentDelivery then return end

    local target = currentDelivery.targetVehicle
    if target and DoesEntityExist(target) then
        DetachVehicleFromAnyTowTruck(target)

        -- A priority job's target is a real, player-owned car that was never spawned by this
        -- resource: only an actual impound removes it. Every other ending leaves it standing.
        if not currentDelivery.isPriority or reason == "completed" then
            DeleteEntity(target)
        end
    end

    if currentDelivery.blip then
        RemoveBlip(currentDelivery.blip)
    end
    if currentDelivery.searchRouteBlip then
        RemoveBlip(currentDelivery.searchRouteBlip)
    end
    if currentDelivery.dropoffBlip then
        RemoveBlip(currentDelivery.dropoffBlip)
    end

    currentDelivery = nil
end

RegisterNetEvent("polarix_towjob:deliveryEnded", function(reason)
    Vehicle.EndDelivery(reason)
end)

-- Read-only accessor for client/modules/delivery.lua's periodic Active Delivery UI push.
function Vehicle.GetCurrentDelivery()
    return currentDelivery
end

-- A priority job's target already exists in the world, so there is nothing to spawn — but
-- the entity only resolves once the player has streamed it in, which won't be true at accept
-- time. The delivery therefore starts with no entity and picks it up on arrival; if it never
-- resolves (cleaned up while nobody was near it), the server's sweep cancels the job without
-- a failure on the operator's record.
local function adoptTargetVehicle(delivery)
    CreateThread(function()
        while currentDelivery == delivery and delivery.state == "searching" do
            local entity = NetworkDoesEntityExistWithNetworkId(delivery.targetNetId)
                and NetworkGetEntityFromNetworkId(delivery.targetNetId) or nil

            if entity and entity ~= 0 and DoesEntityExist(entity) then
                delivery.targetVehicle = entity
                setupFoundDetection(entity)
                return
            end

            Wait(1000)
        end
    end)
end

local function beginDelivery(deliveryId, mission, deadlineAt)
    -- The server only hands out a new delivery once the old one has ended, so anything still here
    -- is left over; its target vehicle and blips would otherwise leak.
    if currentDelivery then Vehicle.EndDelivery("cancelled") end

    local isPriority = mission.is_priority == true
    local targetVehicle, netId, searchHint

    if isPriority then
        netId = mission.target_net_id
        searchHint = mission.search_hint
    else
        local pointIndex
        targetVehicle, pointIndex, searchHint = spawnTargetVehicle(mission)
        if not targetVehicle then
            Framework.Notify(Locale("notify.spawn_failed"), "error")
            return
        end

        netId = NetworkGetNetworkIdFromEntity(targetVehicle)
        TriggerServerEvent("polarix_towjob:setTargetVehicle", deliveryId, netId, pointIndex)
    end

    -- The circle is drawn around the server's pre-rolled hint center, not the vehicle itself,
    -- so the exact spot still has to be found on the ground.
    local blip, searchRouteBlip = createSearchBlip(searchHint, mission.search_hint_radius or 60.0)

    currentDelivery = {
        deliveryId = deliveryId,
        mission = mission,
        targetVehicle = targetVehicle,
        targetNetId = netId,
        searchHint = searchHint,
        blip = blip,
        searchRouteBlip = searchRouteBlip,
        state = "searching",
        deadlineAt = deadlineAt,
        isPriority = isPriority,
    }

    if mission.is_test then
        currentDelivery.dropoffBlip = createDropoffBlip(mission.dropoff)
    end

    if isPriority then
        adoptTargetVehicle(currentDelivery)
    else
        setupFoundDetection(targetVehicle)
    end

    Framework.Notify(Locale("notify.new_tow_job"):format(mission.name), "info")
end

-- Turns a Missions.Accept response into the right client action: spawn a rental / owned
-- truck when the server provisioned one, stash the mission for Vehicle.ContinueAfterParkOut
-- when the player has 2+ trucks to pick from, otherwise just start the find loop (a truck
-- is already out). `result.usedRental` without `result.rental` = rental already spawned.
local function handleAcceptResult(result)
    if not result then
        return { ok = false, reason = "no_response" }
    end

    if not result.ok then
        return result
    end

    if result.needsParkOut then
        pendingMission = { deliveryId = result.deliveryId, mission = result.mission, deadlineAt = result.deadlineAt }
        return result
    end

    if result.usedRental and result.rental then
        Garage.SpawnRental(result.rental)
    elseif result.vehicle then
        Garage.SpawnVehicle(result.vehicle)
    end

    beginDelivery(result.deliveryId, result.mission, result.deadlineAt)

    return result
end

-- On-call pager accept.
function Vehicle.AcceptPagerOffer()
    local result = handleAcceptResult(lib.callback.await("polarix_towjob:acceptPage", false))

    if result.ok and result.needsParkOut then
        Framework.Notify(Locale("notify.park_out_to_start"), "info")
    end

    return result
end

-- QA test-run button — same client orchestration as a pager accept.
function Vehicle.AdminTestRunMission(missionId)
    return handleAcceptResult(lib.callback.await("polarix_towjob:adminTestRunMission", false, missionId))
end

-- Called after a successful `parkOutVehicle` NUI callback (client/nui/nui_callbacks.lua)
-- to pick the delivery back up once the player has parked out a truck themselves.
-- Returns true if a pending mission was actually resumed, so the caller knows
-- whether to close the Dashboard.
function Vehicle.ContinueAfterParkOut()
    if not pendingMission then return false end

    local mission = pendingMission
    pendingMission = nil
    beginDelivery(mission.deliveryId, mission.mission, mission.deadlineAt)

    return true
end
