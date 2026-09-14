-- Import with: local config = require("config.client")
return {
    NPC = {
        model = "s_m_y_construct_01",
        coords = vector4(409.3668, -1623.0425, 29.2919, 234.0580),
        scenario = "WORLD_HUMAN_CLIPBOARD", -- mutually exclusive with `animation`
        animation = nil, -- { dict = "...", clip = "..." }, used if scenario is nil
        blip = { sprite = 67, color = 5, scale = 0.8, label = "Tow Job" },
    },

    TowTruckSpawnCoords = vector4(408.7518, -1638.8171, 28.8186, 229.6331), -- depot spawn/retrieve point
    AutoEnterTowTruck = true, -- teleport player into driver seat vs. player walks to it

    ParkingZone = { coords = vector3(403.5785, -1633.3020, 29.2920), radius = 8.0 }, -- store/retrieve zone near NPC

    VehicleFoundRadius = 12.0, -- reaching this range of the target vehicle flips the job to "found"

    -- How close another vehicle has to be to a mission spawn point to count as standing in it:
    -- ambient traffic that close is deleted, anything protected makes the spot fall through to
    -- the next candidate (client/modules/vehicle.lua).
    SpawnPointClearance = 4.0,

    DeliveryZoneCheckIntervalMs = 500,
    DamageCheckIntervalMs = 2000,
}