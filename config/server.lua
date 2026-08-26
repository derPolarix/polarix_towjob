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
    -- replace with real search/dropoff spots before go-live, same as config/client.lua's NPC/parking placeholders.
    SeedAreas = {
        {
            id = "area_default",
            name = "Los Santos Central",
            region = "Los Santos",
            map_x = 50.0, map_y = 50.0, -- placeholder Leaflet pin position
            unlock_cost = 0,
            level_required = 1,
            is_default = true,
        },
        {
            id = "area_paleto",
            name = "Paleto Bay",
            region = "Blaine County",
            map_x = 30.0, map_y = 120.0, -- placeholder Leaflet pin position
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
            search_center = { x = 120.0, y = 80.0, z = 30.0 },
            search_radius = 60.0,
            dropoff = { x = 200.0, y = 80.0, z = 30.0, heading = 90.0 },
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
            search_center = { x = -150.0, y = 60.0, z = 25.0 },
            search_radius = 70.0,
            dropoff = { x = -80.0, y = 60.0, z = 25.0, heading = 180.0 },
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
            search_center = { x = 300.0, y = -50.0, z = 40.0 },
            search_radius = 55.0,
            dropoff = { x = 350.0, y = -50.0, z = 40.0, heading = 270.0 },
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
            search_center = { x = 60.0, y = -200.0, z = 35.0 },
            search_radius = 80.0,
            dropoff = { x = 10.0, y = -200.0, z = 35.0, heading = 0.0 },
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
            search_center = { x = -100.0, y = 6300.0, z = 30.0 },
            search_radius = 65.0,
            dropoff = { x = -50.0, y = 6300.0, z = 30.0, heading = 90.0 },
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
        { id = "standard", model = "towtruck2", label = "Standard Flatbed", price = 45000, damage_resistance = 0.0, level_required = 1 },
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

    -- Scaled by missing health: cost = perHealthPoint * (maxHealth - currentHealth), summed body+engine
    RepairCost = { mode = "scaled", perHealthPoint = 0.6 },

    -- Converts accrued towed-vehicle body+engine health loss (0-1000 each, from attach to
    -- placement) into a dollar penalty, before the DamagePenaltyCapPercent cap is applied.
    DamagePenaltyPerHealthPoint = 0.5,

    DamagePenaltyCapPercent = 0.30,

    -- Heading tolerance (degrees) for the delivery-zone placement check — the position bound
    -- is already the mission's own dropoff_width/dropoff_length rectangle, this only gates how
    -- closely the towed vehicle's heading must match dropoff_heading. Ground rule 3 names this
    -- as a future Admin Settings (Phase 13) runtime-editable value; static here until then.
    DeliveryHeadingTolerance = 25.0,
}
