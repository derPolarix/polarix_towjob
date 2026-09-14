local serverConfig = require("config.server")
local debug = require("shared.debug")
local Locale = require("shared.locale")

Settings = {}

-- Step 13.5: generic key/value runtime tunables. Each definition names its config.server.lua
-- fallback default (used whenever the key is absent from polarix_towjob_settings, e.g. first
-- boot) and a validator, so Settings.Set can never persist a value that would break the
-- consuming code path (ground rule 4 — re-validated here, not just trusted from the NUI form).
-- `delivery_heading_tolerance` isn't named in Step 13.5's own list, but ground rule 3 and
-- Phase 10's implementation notes both explicitly flag DeliveryHeadingTolerance as a future
-- Phase 13 Admin Settings value — included here to close that already-flagged gap.
-- `label` is a locales/*.json key — resolved to display text in Settings.GetAllForAdmin.
local DEFINITIONS = {
    {
        key = "reward_multiplier",
        label = "admin.setting_reward_multiplier",
        default = 1.0,
        validate = function(v) return type(v) == "number" and v > 0 and v <= 10 end,
    },
    {
        key = "xp_multiplier",
        label = "admin.setting_xp_multiplier",
        default = 1.0,
        validate = function(v) return type(v) == "number" and v > 0 and v <= 10 end,
    },
    {
        key = "damage_penalty_cap_percent",
        label = "admin.setting_damage_penalty_cap",
        default = serverConfig.DamagePenaltyCapPercent or 0.30,
        validate = function(v) return type(v) == "number" and v >= 0 and v <= 1 end,
    },
    {
        key = "default_area_unlock_cost",
        label = "admin.setting_default_area_unlock_cost",
        default = 500,
        validate = function(v) return type(v) == "number" and v >= 0 end,
    },
    {
        key = "rental_price_per_charge",
        label = "admin.setting_rental_price_per_charge",
        default = serverConfig.RentalPricePerCharge,
        validate = function(v) return type(v) == "number" and v >= 0 end,
    },
    {
        key = "rental_interval_minutes",
        label = "admin.setting_rental_interval_minutes",
        default = serverConfig.RentalIntervalMinutes,
        validate = function(v) return type(v) == "number" and v > 0 end,
    },
    {
        key = "repair_cost_per_health_point",
        label = "admin.setting_repair_cost_per_health_point",
        default = serverConfig.RepairCost.perHealthPoint or 0.6,
        validate = function(v) return type(v) == "number" and v >= 0 end,
    },
    {
        key = "delivery_heading_tolerance",
        label = "admin.setting_delivery_heading_tolerance",
        default = serverConfig.DeliveryHeadingTolerance or 25.0,
        validate = function(v) return type(v) == "number" and v >= 0 and v <= 180 end,
    },
    {
        key = "search_hint_radius",
        label = "admin.setting_search_hint_radius",
        default = serverConfig.SearchHintRadius or 60.0,
        validate = function(v) return type(v) == "number" and v >= 10 and v <= 500 end,
    },
}

local definitionByKey = {}
for _, def in ipairs(DEFINITIONS) do
    definitionByKey[def.key] = def
end

local cache = {}
local loaded = false

function Settings.Load()
    cache = {}
    local rows = DB.GetAllSettings() or {}
    for _, row in ipairs(rows) do
        cache[row.setting_key] = json.decode(row.setting_value)
    end
    loaded = true
    debug.DebugPrint("Settings.Load: loaded", #rows, "override(s) from polarix_towjob_settings")
end

local function get(key)
    if not loaded then Settings.Load() end
    local value = cache[key]
    if value ~= nil then return value end
    local def = definitionByKey[key]
    return def and def.default
end

function Settings.GetRewardMultiplier() return get("reward_multiplier") end
function Settings.GetXpMultiplier() return get("xp_multiplier") end
function Settings.GetDamagePenaltyCapPercent() return get("damage_penalty_cap_percent") end
function Settings.GetDefaultAreaUnlockCost() return get("default_area_unlock_cost") end
function Settings.GetRentalPricePerCharge() return get("rental_price_per_charge") end
function Settings.GetRentalIntervalMinutes() return get("rental_interval_minutes") end
function Settings.GetRepairCostPerHealthPoint() return get("repair_cost_per_health_point") end
function Settings.GetDeliveryHeadingTolerance() return get("delivery_heading_tolerance") end
function Settings.GetSearchHintRadius() return get("search_hint_radius") end

-- Admin UI list: current effective value (DB override or config default) plus the
-- shipped default, so the editor can show "currently X, default Y" and offer a reset.
function Settings.GetAllForAdmin()
    if not loaded then Settings.Load() end

    local list = {}
    for _, def in ipairs(DEFINITIONS) do
        list[#list + 1] = { key = def.key, label = Locale(def.label), value = get(def.key), default = def.default }
    end
    return list
end

-- Re-checks admin status and re-validates the value itself (ground rule 4) — never trusts
-- that the NUI form only shows this because /towjobadmin already gated it once.
function Settings.Set(source, key, value)
    if not Framework.IsAdmin(source) then return { ok = false, reason = "not_admin" } end

    local def = definitionByKey[key]
    if not def then return { ok = false, reason = "invalid_key" } end
    if not def.validate(value) then return { ok = false, reason = "invalid_value" } end

    local player = Player.GetData(source)
    DB.UpsertSetting(key, value, player and player.identifier)
    cache[key] = value

    debug.DebugPrint(("Settings.Set: %s set %s = %s"):format(player and player.identifier or tostring(source), key, tostring(value)))

    return { ok = true, settings = Settings.GetAllForAdmin() }
end

lib.callback.register("polarix_towjob:adminGetSettings", function(source)
    if not Framework.IsAdmin(source) then return { ok = false, reason = "not_admin" } end
    return { ok = true, settings = Settings.GetAllForAdmin() }
end)

lib.callback.register("polarix_towjob:adminSetSetting", function(source, key, value)
    return Settings.Set(source, key, value)
end)
