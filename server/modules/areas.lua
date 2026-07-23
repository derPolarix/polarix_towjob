local serverConfig = require("config.server")
local debug = require("shared.debug")

Areas = {}

function Areas.SeedIfEmpty()
    if (DB.GetAreaCount() or 0) > 0 then return end

    local seeds = serverConfig.SeedAreas
    if not seeds or #seeds == 0 then
        debug.DebugPrint("Areas.SeedIfEmpty: no SeedAreas configured, skipping")
        return
    end

    for _, area in ipairs(seeds) do
        DB.InsertArea(area)
    end

    debug.DebugPrint(("Areas.SeedIfEmpty: seeded %d area(s)"):format(#seeds))
end
