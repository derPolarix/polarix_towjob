-- Import with: local config = require("config.shared")
return {
    Debug = false,
    PrintDebug = true,

    Framework = "qbox", -- "qbox" | "qb-core" | "esx"

    XPThresholds = { 0, 150, 400, 800, 1400, 2200, 3200, 4500, 6200, 8500, 11500 }, -- index = level
    SkillPointsPerLevel = 1,
    LevelTitles = { "Trainee", "Junior Operator", "Operator", "Senior Operator", "Recovery Specialist",
                    "Expert", "Master Operator", "Elite", "Legend", "Grand Master", "Titan" },

    Skills = {
        branches = {
            { name = "Precision", icon = "tabler:target", skills = {
                { id = "p1", name = "Steady Rigging", desc = "Reduces damage penalty on towed vehicles.", cost = 1, requires = nil, effects = { damage_penalty_reduction = 0.15 } },
                { id = "p2", name = "Firm Grip", desc = "Further reduces towed-vehicle damage accrual.", cost = 2, requires = "p1", effects = { damage_penalty_reduction = 0.30 } },
            }},
            { name = "Economy", icon = "tabler:coin", skills = {
                { id = "e1", name = "Fair Rates", desc = "Increases delivery payout.", cost = 1, requires = nil, effects = { payout_bonus = 0.10 } },
                { id = "e2", name = "Bulk Discount", desc = "Reduces vehicle purchase and repair costs.", cost = 2, requires = "e1", effects = { purchase_discount = 0.15, repair_discount = 0.15 } },
            }},
            { name = "Access", icon = "tabler:map-pin", skills = {
                { id = "a1", name = "Field Certified", desc = "Unlocks timed/harder missions at a lower level than the base requirement.", cost = 1, requires = nil, effects = { level_requirement_reduction = 2 } },
                { id = "a2", name = "Local Rates", desc = "Reduces area unlock costs.", cost = 2, requires = "a1", effects = { area_unlock_discount = 0.20 } },
            }},
        }
    },
}