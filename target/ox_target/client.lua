-- ox_target hands onSelect a response table instead of the entity.
local function toOxOptions(options)
    local oxOptions = {}

    for i, opt in ipairs(options) do
        local onSelect = opt.onSelect
        oxOptions[i] = {
            name = opt.name,
            icon = opt.icon,
            label = opt.label,
            distance = opt.distance,
            canInteract = opt.canInteract,
            onSelect = onSelect and function(data) onSelect(data.entity) end,
        }
    end

    return oxOptions
end

return {
    IsAvailable = function()
        return GetResourceState("ox_target") == "started"
    end,

    AddLocalEntity = function(entity, options)
        exports.ox_target:addLocalEntity(entity, toOxOptions(options))
    end,

    RemoveLocalEntity = function(entity, names)
        exports.ox_target:removeLocalEntity(entity, names)
    end,

    AddSphereZone = function(name, coords, radius, options)
        return exports.ox_target:addSphereZone({
            name = name,
            coords = coords,
            radius = radius,
            options = toOxOptions(options),
        })
    end,

    RemoveZone = function(handle)
        exports.ox_target:removeZone(handle)
    end,

    AddGlobalVehicle = function(options)
        exports.ox_target:addGlobalVehicle(toOxOptions(options))
    end,

    RemoveGlobalVehicle = function(names)
        exports.ox_target:removeGlobalVehicle(names)
    end,
}
