-- Import with: local config = require("config.shared")
return {
    Debug = false,
    PrintDebug = false,

    Framework = "qbox", -- "qbox" | "qb-core" | "esx"

    -- Language for locales/<Language>.json — the SSOT for every user-facing string
    -- (Lua notifications + NUI). Ships: de, en, es, fr, it, nl, pl, pt-br, tr.
    Language = "en",

    XPThresholds = { 0, 150, 400, 800, 1400, 2200, 3200, 4500, 6200, 8500, 11500 }, -- index = level

    SkillPointsPerLevel = 1,

    -- locales/*.json keys, not display text — resolved via Locale() before they reach the NUI
    -- (server/callback.lua, server/modules/player.lua).
    LevelTitles = { "level.trainee", "level.junior_operator", "level.operator", "level.senior_operator",
                    "level.recovery_specialist", "level.expert", "level.master_operator", "level.elite",
                    "level.legend", "level.grand_master", "level.titan" },

    Skills = {
        -- name/desc are locales/*.json keys, not display text — resolved via Locale()
        -- in Skills.ResolveBranches (server/modules/skills.lua).
        branches = {
            { name = "skill.branch_precision", icon = "tabler:target", skills = {
                { id = "p1", name = "skill.steady_rigging", desc = "skill.steady_rigging_desc", cost = 1, requires = nil, effects = { damage_penalty_reduction = 0.15 } },
                { id = "p2", name = "skill.firm_grip", desc = "skill.firm_grip_desc", cost = 2, requires = "p1", effects = { damage_penalty_reduction = 0.30 } },
            }},
            { name = "skill.branch_economy", icon = "tabler:coin", skills = {
                { id = "e1", name = "skill.fair_rates", desc = "skill.fair_rates_desc", cost = 1, requires = nil, effects = { payout_bonus = 0.10 } },
                { id = "e2", name = "skill.bulk_discount", desc = "skill.bulk_discount_desc", cost = 2, requires = "e1", effects = { purchase_discount = 0.15, repair_discount = 0.15 } },
            }},
            { name = "skill.branch_access", icon = "tabler:map-pin", skills = {
                { id = "a1", name = "skill.field_certified", desc = "skill.field_certified_desc", cost = 1, requires = nil, effects = { level_requirement_reduction = 2 } },
                { id = "a2", name = "skill.local_rates", desc = "skill.local_rates_desc", cost = 2, requires = "a1", effects = { area_unlock_discount = 0.20 } },
            }},
        }
    },
}
