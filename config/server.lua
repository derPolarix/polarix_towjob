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

    -- Police "mark for tow": an officer marks a player-owned vehicle and it becomes a
    -- priority job that queue-jumps the on-call pager (server/modules/priority.lua).
    -- Job name -> minimum grade allowed to mark.
    PoliceJobs = { police = 0, sheriff = 2 },
    RequireOnDuty = false,
    PoliceMarkCommand = "towrequest", -- raycast fallback, registered only when ox_target isn't running
    PoliceMarkDistance = 12.0, -- max raycast/target reach to the vehicle being marked

    MaxPriorityJobs = 5,      -- global cap on unclaimed priority jobs
    MaxMarksPerOfficer = 2,   -- concurrent unclaimed marks one officer may hold
    MarkCooldownSeconds = 30, -- per-officer cooldown between marks

    PriorityExpiryMinutes = 15,      -- unclaimed marks die after this
    PriorityMoveTolerance = 10.0,    -- unclaimed: moved further than this from the marked spot -> dropped
    PriorityAbandonDistance = 150.0, -- claimed: moved further than this -> delivery cancelled, no penalty
    -- An idle on-call player's next page is pulled in to at most this far out when a mark
    -- lands, so a police call reaches somebody without waiting out the full pager interval.
    PriorityMaxWaitSeconds = 45,
    -- Deliberately tighter than SearchHintRadius: dispatch gave a location, it just isn't exact.
    PrioritySearchRadius = 25.0,

    -- reward/xp = base + perMeter * (marked spot -> dropoff distance), clamped to max. Feeds
    -- reward_base/xp_base, so the area/settings multipliers and skill bonuses still apply on top.
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

    -- Heading tolerance (degrees) for the delivery-zone placement check — the position bound
    -- is already the mission's own dropoff_width/dropoff_length rectangle, this only gates how
    -- closely the towed vehicle's heading must match dropoff_heading. Ground rule 3 names this
    -- as a future Admin Settings (Phase 13) runtime-editable value; static here until then.
    DeliveryHeadingTolerance = 25.0,
}
