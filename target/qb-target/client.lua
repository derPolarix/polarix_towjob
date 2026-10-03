-- qb-target keys options by label (removal too), calls action(entity) instead of
-- onSelect, and takes distance per call rather than per option (largest wins).
local DEFAULT_DISTANCE = 2.5

local labelsByName = {}

local function toQbOptions(options)
    local qbOptions = {}
    local maxDistance = 0

    for i, opt in ipairs(options) do
        labelsByName[opt.name] = opt.label
        qbOptions[i] = {
            icon = opt.icon,
            label = opt.label,
            canInteract = opt.canInteract,
            action = opt.onSelect,
        }
        if opt.distance and opt.distance > maxDistance then
            maxDistance = opt.distance
        end
    end

    return qbOptions, maxDistance > 0 and maxDistance or DEFAULT_DISTANCE
end

local function toLabels(names)
    if type(names) ~= "table" then names = { names } end

    local labels = {}
    for i, name in ipairs(names) do
        labels[i] = labelsByName[name] or name
    end
    return labels
end

return {
    IsAvailable = function()
        return GetResourceState("qb-target") == "started"
    end,

    AddLocalEntity = function(entity, options)
        local qbOptions, distance = toQbOptions(options)
        exports["qb-target"]:AddTargetEntity(entity, { options = qbOptions, distance = distance })
    end,

    RemoveLocalEntity = function(entity, names)
        exports["qb-target"]:RemoveTargetEntity(entity, toLabels(names))
    end,

    AddSphereZone = function(name, coords, radius, options)
        local qbOptions, distance = toQbOptions(options)
        exports["qb-target"]:AddCircleZone(name, vector3(coords.x, coords.y, coords.z), radius,
            { name = name, useZ = true, debugPoly = false },
            { options = qbOptions, distance = distance })
        return name
    end,

    RemoveZone = function(handle)
        exports["qb-target"]:RemoveZone(handle)
    end,

    AddGlobalVehicle = function(options)
        local qbOptions, distance = toQbOptions(options)
        exports["qb-target"]:AddGlobalVehicle({ options = qbOptions, distance = distance })
    end,

    RemoveGlobalVehicle = function(names)
        exports["qb-target"]:RemoveGlobalVehicle(toLabels(names))
    end,
}
