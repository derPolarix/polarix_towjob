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

    AdminPermission = "admin",
    AdminGroups = { "admin", "superadmin" }, -- esx group allowlist
    AdminAceSuffix = "towjob_admin", -- ACE fallback: command.towjob_admin

    -- Only models verified in-game to work with AttachVehicleToTowTruck.
    -- Optional per-vehicle look, applied right after spawn (VehicleTiers entries and RentalTruck):
    --   livery = 0,                              -- livery index
    --   extras = { [1] = true, [2] = false },    -- extra id -> shown
    --   colors = { primary = 0, secondary = 0 }, -- GTA colour ids
    --   mods   = { [11] = 2 },                   -- SetVehicleMod type -> index
    VehicleTiers = {
        { id = "standard", model = "towtruck2", label = "Tow Truck", price = 45000, damage_resistance = 0.0, level_required = 1 },
        { id = "heavy",    model = "towtruck",  label = "Heavy Duty Tow",   price = 95000, damage_resistance = 0.20, level_required = 5 },
    },

    RentalTruck = { model = "towtruck2", label = "Rental Flatbed" },
    RentalPricePerCharge = 150,
    RentalIntervalMinutes = 15,
    RentalWarningMinutesBefore = { 5, 1 }, -- notify at 5min and 1min before a missed charge repossesses

    -- Pager delay is random in [Min, Max], multiplied by the consecutive-decline streak (reset on accept).
    PagerMinIntervalMinutes = 2,
    PagerMaxIntervalMinutes = 8,
    PagerOfferTimeoutSeconds = 30,
    PagerDeclineCooldownMinutes = 5,

    -- First page after going on-call or finishing a job uses this shorter delay.
    PagerPostAcceptMinSeconds = 20,
    PagerPostAcceptMaxSeconds = 40,

    -- cost = perHealthPoint * missing health (body + engine)
    RepairCost = { mode = "scaled", perHealthPoint = 0.6 },

    -- Body + engine health lost (0-1000 each) since reaching the vehicle -> dollar penalty, before DamagePenaltyCapPercent.
    DamagePenaltyPerHealthPoint = 0.5,

    -- Server re-check of a "found" claim: VehicleFoundRadius plus latency slack.
    VehicleFoundMaxDistance = 25.0,

    -- Max distance of the target from its reported spawn point, and of the player from the towed vehicle on confirm.
    SpawnPointVerifyDistance = 10.0,
    CompletionMaxDistance = 40.0,

    -- Default for the search_hint_radius setting. The circle is offset server-side so the spawn is never dead-center.
    SearchHintRadius = 60.0,

    -- Spawn points closer than this count as one spot when reserving.
    SpawnPointReservationDistance = 8.0,

    -- Candidates sent to the client, which falls through when a spot is blocked.
    SpawnPointCandidates = 3,

    MaxSpawnPointsPerMission = 20,

    DamagePenaltyCapPercent = 0.30,

    -- Police marks become priority jobs. PoliceJobs: job name -> minimum grade.
    PoliceJobs = { police = 0, sheriff = 2 },
    RequireOnDuty = false,
    PoliceMarkCommand = "towrequest", -- raycast fallback, registered only when no target system is available
    PoliceMarkDistance = 12.0, -- max raycast/target reach to the vehicle being marked

    MaxPriorityJobs = 5,      -- global cap on unclaimed priority jobs
    MaxMarksPerOfficer = 2,   -- concurrent unclaimed marks one officer may hold
    MarkCooldownSeconds = 30, -- per-officer cooldown between marks

    PriorityExpiryMinutes = 15,      -- unclaimed marks die after this
    PriorityMoveTolerance = 10.0,    -- unclaimed: moved further than this from the marked spot -> dropped
    PriorityAbandonDistance = 150.0, -- claimed: moved further than this -> delivery cancelled, no penalty
    -- Cap on how far out an idle on-call player's next page is pulled when a mark lands.
    PriorityMaxWaitSeconds = 45,
    -- Deliberately tighter than SearchHintRadius: dispatch gave a location, it just isn't exact.
    PrioritySearchRadius = 25.0,

    -- reward/xp = base + perMeter * (mark -> dropoff distance), clamped to max; multipliers apply on top.
    PriorityTimeLimitMinutes = nil, -- priority jobs are untimed by default; set a number to time them
    PriorityReward = { base = 400, perMeter = 0.15, max = 2500 },
    PriorityXp = { base = 45, perMeter = 0.01, max = 200 },
    PoliceCutPercent = 0.0, -- share of the payout paid to the marking officer (0 = off)

    -- What towing a marked vehicle to the impound actually does:
    --   "none"      -> the entity is deleted, nothing else
    --   "event"     -> also emits polarix_towjob:vehicleImpounded for your own impound script
    --   "framework" -> additionally writes the framework's own vehicle table (Framework.ImpoundVehicle)
    -- The event fires in "event" and "framework" mode alike.
    ImpoundMode = "event",
    ImpoundGarage = "impound", -- qbox/qb-core: garage column written in "framework" mode
    ImpoundFee = 500,          -- qbox/qb-core: depotprice column written in "framework" mode

    -- Max heading deviation (degrees) from dropoff_heading; position is bound by the mission's dropoff rectangle.
    DeliveryHeadingTolerance = 25.0,
}
