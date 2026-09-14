-- Import with: local config = require("config.server")
return {
    Tables = {
        players      = "polarix_towjob_players",
        areas        = "polarix_towjob_areas",
        player_areas = "polarix_towjob_player_areas",
        missions     = "polarix_towjob_missions",
        deliveries   = "polarix_towjob_deliveries",
        vehicles     = "polarix_towjob_vehicles",
        settings     = "polarix_towjob_settings",
    },

    -- TEMPORARY: seeds `missions`/`areas` on first boot if empty. Remove once Phase 13
    -- Admin UI is the sole source of truth for mission/area content.
    -- Launch seed: one default area, 3-4 missions (easy/medium mix, at least one
    -- with time_limit_minutes set to exercise the timed-mission path).
    -- Coordinates below are placeholders (not tied to any real world position) —
    -- replace with real spawn/dropoff spots before go-live, same as config/client.lua's NPC/parking placeholders.
    -- Each mission's `spawn_points` are hand-placed parked-car spots inside one small area;
    -- the server picks one per delivery, so every entry must be somewhere a car can actually stand.
    SeedAreas = {
        {
            id = "area_default",
            name = "Los Santos Central",
            region = "Los Santos",
            -- placeholder GTA world-coord polygon (rectangle) around central Los Santos
            points = { { x = -600.0, y = -1200.0 }, { x = 900.0, y = -1200.0 }, { x = 900.0, y = 400.0 }, { x = -600.0, y = 400.0 } },
            unlock_cost = 0,
            level_required = 1,
            is_default = true,
        },
        {
            id = "area_paleto",
            name = "Paleto Bay",
            region = "Blaine County",
            -- placeholder GTA world-coord polygon (rectangle) around Paleto Bay
            points = { { x = -900.0, y = 5900.0 }, { x = 100.0, y = 5900.0 }, { x = 100.0, y = 6700.0 }, { x = -900.0, y = 6700.0 } },
            unlock_cost = 750,
            level_required = 2,
            is_default = false,
        },
    },

    SeedMissions = {
        {
            id = "mission_stalled_sedan",
            area_id = "area_default",
            name = "Stalled Sedan on Innocence Blvd",
            vehicle_model = "asea",
            vehicle_label = "Declasse Asea",
            vehicle_colors = { primary = 0, secondary = 0 },
            spawn_points = {
                { x = 215.0, y = -810.0, z = 30.7, heading = 160.0 },
                { x = 236.0, y = -845.0, z = 30.5, heading = 250.0 },
                { x = 190.0, y = -782.0, z = 31.0, heading = 70.0 },
            },
            dropoff = { x = 398.0, y = -1631.0, z = 29.8, heading = 320.0 },
            dropoff_width = 6.0,
            dropoff_length = 10.0,
            reward_base = 350,
            xp_base = 40,
            time_limit_minutes = nil,
            difficulty = "easy",
            level_required = 1,
        },
        {
            id = "mission_ditched_pickup",
            area_id = "area_default",
            name = "Ditched Pickup Near the Docks",
            vehicle_model = "bison",
            vehicle_label = "Bravado Bison",
            vehicle_colors = { primary = 27, secondary = 27 },
            spawn_points = {
                { x = 100.0, y = -2790.0, z = 6.0, heading = 90.0 },
                { x = 132.0, y = -2812.0, z = 6.0, heading = 180.0 },
                { x = 74.0, y = -2764.0, z = 6.0, heading = 355.0 },
            },
            dropoff = { x = 393.0, y = -1636.0, z = 29.8, heading = 320.0 },
            dropoff_width = 6.0,
            dropoff_length = 10.0,
            reward_base = 400,
            xp_base = 50,
            time_limit_minutes = nil,
            difficulty = "easy",
            level_required = 1,
        },
        {
            id = "mission_abandoned_sultan",
            area_id = "area_default",
            name = "Abandoned Sports Car",
            vehicle_model = "sultan",
            vehicle_label = "Karin Sultan",
            vehicle_colors = { primary = 111, secondary = 0 },
            spawn_points = {
                { x = -1230.0, y = -1500.0, z = 4.3, heading = 125.0 },
                { x = -1258.0, y = -1471.0, z = 4.3, heading = 215.0 },
                { x = -1205.0, y = -1523.0, z = 4.3, heading = 35.0 },
            },
            dropoff = { x = 388.0, y = -1641.0, z = 29.8, heading = 320.0 },
            dropoff_width = 6.0,
            dropoff_length = 10.0,
            reward_base = 650,
            xp_base = 90,
            time_limit_minutes = nil,
            difficulty = "medium",
            level_required = 3,
        },
        {
            id = "mission_rush_hour_recovery",
            area_id = "area_default",
            name = "Rush Hour Recovery",
            vehicle_model = "issi2",
            vehicle_label = "Weeny Issi",
            vehicle_colors = { primary = 3, secondary = 3 },
            spawn_points = {
                { x = 780.0, y = -1290.0, z = 26.0, heading = 275.0 },
                { x = 812.0, y = -1322.0, z = 26.0, heading = 5.0 },
                { x = 748.0, y = -1258.0, z = 26.2, heading = 95.0 },
            },
            dropoff = { x = 405.0, y = -1626.0, z = 29.8, heading = 320.0 },
            dropoff_width = 6.0,
            dropoff_length = 10.0,
            reward_base = 800,
            xp_base = 110,
            time_limit_minutes = 8, -- Timed mission, exercises the countdown path (Phase 9.3)
            difficulty = "medium",
            level_required = 3,
        },
        {
            id = "mission_paleto_flatbed",
            area_id = "area_paleto",
            name = "Flooded Flatbed Recovery",
            vehicle_model = "burrito3",
            vehicle_label = "Vapid Burrito",
            vehicle_colors = { primary = 1, secondary = 1 },
            spawn_points = {
                { x = -160.0, y = 6350.0, z = 31.0, heading = 45.0 },
                { x = -192.0, y = 6378.0, z = 31.0, heading = 135.0 },
                { x = -128.0, y = 6322.0, z = 31.2, heading = 315.0 },
            },
            dropoff = { x = -460.0, y = 6015.0, z = 31.5, heading = 45.0 },
            dropoff_width = 6.0,
            dropoff_length = 10.0,
            reward_base = 500,
            xp_base = 70,
            time_limit_minutes = nil,
            difficulty = "medium",
            level_required = 2,
        },
    },

    AdminPermission = "admin",
    AdminGroups = { "admin", "superadmin" }, -- esx group allowlist
    AdminAceSuffix = "towjob_admin", -- ACE fallback: command.towjob_admin

    -- Tow truck ownership catalog — 2 tiers for v1, both models confirmed to carry
    -- GTA's native tow-arm rig. Do not add further models without first verifying
    -- in-game that AttachVehicleToTowTruck behaves correctly on them.
    VehicleTiers = {
        { id = "standard", model = "towtruck2", label = "Tow Truck", price = 45000, damage_resistance = 0.0, level_required = 1 },
        { id = "heavy",    model = "towtruck",  label = "Heavy Duty Tow",   price = 95000, damage_resistance = 0.20, level_required = 5 },
    },

    RentalTruck = { model = "towtruck2", label = "Rental Flatbed" },
    RentalPricePerCharge = 150,
    RentalIntervalMinutes = 15,
    RentalWarningMinutesBefore = { 5, 1 }, -- notify at 5min and 1min before a missed charge repossesses

    -- On-call pager (replaces the old browsable Available Jobs list): while on-call with no
    -- active delivery, the server waits a random delay in this range, then pages a randomly
    -- picked eligible mission. Declining/timing out doesn't reduce/penalize the player
    -- economically — it just multiplies this same random-delay wait by the player's current
    -- consecutive-decline streak (reset to 0 on any accept), so repeatedly re-rolling for a
    -- better job costs increasingly more real time instead of money/XP.
    PagerMinIntervalMinutes = 2,
    PagerMaxIntervalMinutes = 8,
    PagerOfferTimeoutSeconds = 30,
    PagerDeclineCooldownMinutes = 5,

    -- The first page after going on-call or finishing a job uses this short delay; every page after reverts to the interval above.
    PagerPostAcceptMinSeconds = 20,
    PagerPostAcceptMaxSeconds = 40,

    -- Scaled by missing health: cost = perHealthPoint * (maxHealth - currentHealth), summed body+engine
    RepairCost = { mode = "scaled", perHealthPoint = 0.6 },

    -- Converts accrued towed-vehicle body+engine health loss (0-1000 each, from the moment the
    -- player reaches the vehicle to placement) into a dollar penalty, before the
    -- DamagePenaltyCapPercent cap is applied.
    DamagePenaltyPerHealthPoint = 0.5,

    -- Server re-check of a "vehicle found" claim — client's VehicleFoundRadius plus slack for
    -- movement/latency.
    VehicleFoundMaxDistance = 25.0,

    -- Default for the runtime-editable `search_hint_radius` setting: the circle drawn on the
    -- player's map while searching. The circle's center is offset server-side so the spawn
    -- point never sits dead-center, which is what keeps the search phase a search.
    SearchHintRadius = 60.0,

    -- Two spawn points closer than this to each other are treated as the same spot when
    -- reserving, so two concurrent deliveries never stack their target vehicles.
    SpawnPointReservationDistance = 8.0,

    -- Candidates handed to the client per delivery: it walks them in order and falls through
    -- to the next one when a spot is physically blocked (see client/modules/vehicle.lua).
    SpawnPointCandidates = 3,

    MaxSpawnPointsPerMission = 20,

    DamagePenaltyCapPercent = 0.30,

    -- Heading tolerance (degrees) for the delivery-zone placement check — the position bound
    -- is already the mission's own dropoff_width/dropoff_length rectangle, this only gates how
    -- closely the towed vehicle's heading must match dropoff_heading. Ground rule 3 names this
    -- as a future Admin Settings (Phase 13) runtime-editable value; static here until then.
    DeliveryHeadingTolerance = 25.0,
}
