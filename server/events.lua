local debug = require("shared.debug")
local server = require("config.server")
local shared = require("shared.debug")

-- Bridge for qbox: qbx_vehiclekeys is server-only, client triggers this to request keys.
-- No-op on qb-core/esx since their Framework.GiveVehicleKeys server implementations are stubs.
RegisterNetEvent("polarix_towjob:giveVehicleKeys", function(vehicleNetId)
    local src = source

    if not Vehicles.AwaitOwnTruck(src, vehicleNetId) then
        debug.Warn(("giveVehicleKeys: refused keys for netId %s to source %s"):format(tostring(vehicleNetId), src))
        return
    end

    Framework.GiveVehicleKeys(src, vehicleNetId)
end)
