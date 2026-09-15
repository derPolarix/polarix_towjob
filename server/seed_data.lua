-- Data for the "Import seed missions" button in the Admin UI's mission/area sections
-- (see server/modules/admin_missions.lua AdminMissions.ImportSeedData). Areas and missions
-- are one set: the missions below reference these area ids, so they import together.
--
-- Coordinates below are placeholders (not tied to any real world position) —
-- replace with real spawn/dropoff spots before go-live, same as config/client.lua's NPC/parking placeholders.
-- Each mission's `spawn_points` are hand-placed parked-car spots inside one small area;
-- the server picks one per delivery, so every entry must be somewhere a car can actually stand.
return {
    areas = {
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

    missions = {
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
            time_limit_minutes = 8, -- Timed mission, exercises the countdown path
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
}
