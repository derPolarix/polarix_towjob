-- sleepless_interact wants bare icon names ("clipboard-list", not "fa-solid fa-clipboard-list"),
-- hands onSelect a response table, and has no zones: a sphere zone becomes a coords point
-- whose option distance is the zone radius.
local function toInteractOptions(options, distanceOverride)
    local interactOptions = {}

    for i, opt in ipairs(options) do
        local onSelect = opt.onSelect
        interactOptions[i] = {
            name = opt.name,
            icon = opt.icon and opt.icon:gsub("^fa%-%a+ fa%-", ""):gsub("^fas fa%-", ""),
            label = opt.label,
            distance = distanceOverride or opt.distance,
            canInteract = opt.canInteract,
            onSelect = onSelect and function(data) onSelect(data.entity) end,
        }
    end

    return interactOptions
end

return {
    IsAvailable = function()
        return GetResourceState("sleepless_interact") == "started"
    end,

    AddLocalEntity = function(entity, options)
        exports.sleepless_interact:addLocalEntity(entity, toInteractOptions(options))
    end,

    RemoveLocalEntity = function(entity, names)
        exports.sleepless_interact:removeLocalEntity(entity, names)
    end,

    AddSphereZone = function(_, coords, radius, options)
        return exports.sleepless_interact:addCoords(vector3(coords.x, coords.y, coords.z), toInteractOptions(options, radius))
    end,

    RemoveZone = function(handle)
        exports.sleepless_interact:removeCoords(handle)
    end,

    AddGlobalVehicle = function(options)
        exports.sleepless_interact:addGlobalVehicle(toInteractOptions(options))
    end,

    RemoveGlobalVehicle = function(names)
        exports.sleepless_interact:removeGlobalVehicle(names)
    end,
}
