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
    SeedAreas = { --[[ single entry, is_default = true ]] },
    SeedMissions = { --[[ 3-4 entries for the default area, one with time_limit_minutes set ]] },

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

    -- Scaled by missing health: cost = perHealthPoint * (maxHealth - currentHealth), summed body+engine
    RepairCost = { mode = "scaled", perHealthPoint = 0.6 },

    DamagePenaltyCapPercent = 0.30,
}
