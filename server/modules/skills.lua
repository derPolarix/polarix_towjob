local sharedConfig = require("config.shared")
local debug = require("shared.debug")

Skills = {}

local function findSkillDef(skillId)
    for _, branch in ipairs(sharedConfig.Skills.branches) do
        for _, skill in ipairs(branch.skills) do
            if skill.id == skillId then return skill end
        end
    end
    return nil
end

-- Branch progression effects (e.g. p1 -> p2) express the *total* resulting value once
-- that tier is owned, not an additive stack on top of the lower tier (see config/shared.lua
-- Skills.branches comments) — so the strongest owned skill per effect key wins, not a sum.
function Skills.GetEffectValue(source, effectKey)
    local player = Player.GetData(source)
    if not player then return 0 end

    local value = 0
    for _, skillId in ipairs(player.skills) do
        local def = findSkillDef(skillId)
        if def and def.effects and def.effects[effectKey] then
            value = math.max(value, def.effects[effectKey])
        end
    end
    return value
end

-- Used by Missions.Complete (Phase 10.3) to reduce the towed-vehicle damage penalty.
function Skills.GetDamageReduction(source)
    return Skills.GetEffectValue(source, "damage_penalty_reduction")
end

-- Used by Missions.Complete (Phase 10.3) to boost the paid-out reward.
function Skills.GetPayoutBonus(source)
    return Skills.GetEffectValue(source, "payout_bonus")
end

-- Used by Vehicles.Purchase (Phase 7.2).
function Skills.GetPurchaseDiscount(source)
    return Skills.GetEffectValue(source, "purchase_discount")
end

-- Used by Vehicles.Repair (Phase 7.3).
function Skills.GetRepairDiscount(source)
    return Skills.GetEffectValue(source, "repair_discount")
end

-- Used by the on-call pager's eligibility filter and Missions.Accept — confirmed with user:
-- applies uniformly to every mission's level_required, not only timed/hard ones.
function Skills.GetLevelRequirementReduction(source)
    return Skills.GetEffectValue(source, "level_requirement_reduction")
end

-- Used by Areas.Unlock (Phase 6.2).
function Skills.GetAreaUnlockDiscount(source)
    return Skills.GetEffectValue(source, "area_unlock_discount")
end

-- Re-validates prerequisite chain + skill_points balance server-side (ground rule 4) —
-- never trusts that the Skilltree tab only shows an "unlock" button because it already
-- checked these itself; a forged NUI payload must be rejected here regardless.
function Skills.Unlock(source, skillId)
    local player = Player.GetData(source)
    if not player then return { ok = false, reason = "no_player" } end

    local def = findSkillDef(skillId)
    if not def then return { ok = false, reason = "invalid_skill" } end

    if Player.HasSkill(source, skillId) then
        return { ok = false, reason = "already_unlocked" }
    end

    if def.requires and not Player.HasSkill(source, def.requires) then
        return { ok = false, reason = "prerequisite_missing" }
    end

    if player.skill_points < def.cost then
        return { ok = false, reason = "insufficient_points" }
    end

    player.skill_points = player.skill_points - def.cost
    player.skills[#player.skills + 1] = skillId
    Player.Save(source)

    TriggerClientEvent("polarix_towjob:playerUpdate", source, Player.GetData(source))

    debug.DebugPrint(("Skills.Unlock: %s unlocked skill %s"):format(player.identifier, skillId))

    return { ok = true, player = Player.GetData(source) }
end
