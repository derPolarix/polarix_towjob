-- Import with: local config = require("config.client")
return {
    NPC = {
        model = "s_m_y_construct_01", -- placeholder, confirm final model with user
        coords = vector4(0.0, 0.0, 0.0, 0.0), -- placeholder, needs real depot coords
        scenario = nil, -- e.g. "WORLD_HUMAN_CLIPBOARD", mutually exclusive with `animation`
        animation = nil, -- { dict = "...", clip = "..." }, used if scenario is nil
        blip = { sprite = 67, color = 5, scale = 0.8, label = "Tow Job" },
    },

    TowTruckSpawnCoords = vector4(0.0, 0.0, 0.0, 0.0), -- depot spawn/retrieve point, placeholder
    AutoEnterTowTruck = true, -- teleport player into driver seat vs. player walks to it

    ParkingZone = { coords = vector3(0.0, 0.0, 0.0), radius = 8.0 }, -- store/retrieve zone near NPC, placeholder coords

    DeliveryZoneCheckIntervalMs = 500,
    DamageCheckIntervalMs = 2000,
}