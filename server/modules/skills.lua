local sharedConfig = require("config.shared")
local debug = require("shared.debug")
local Locale = require("shared.locale")

Skills = {}

function Skills.ResolveBranches()
    local out = {}
    for _, branch in ipairs(sharedConfig.Skills.branches) do
        local resolvedBranch = { name = Locale(branch.name), icon = branch.icon, skills = {} }
        for _, skill in ipairs(branch.skills) do
            resolvedBranch.skills[#resolvedBranch.skills + 1] = {
                id = skill.id,
                name = Locale(skill.name),
                desc = Locale(skill.desc),
                cost = skill.cost,
                requires = skill.requires,
                effects = skill.effects,
            }
        end
        out[#out + 1] = resolvedBranch
    end
    return out
end

local function findSkillDef(skillId)
    for _, branch in ipairs(sharedConfig.Skills.branches) do
        for _, skill in ipairs(branch.skills) do
            if skill.id == skillId then return skill end
        end
    end
    return nil
end

-- Tier effects are total values, not additive: the strongest owned skill per effect key wins.
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

function Skills.GetDamageReduction(source)
    return Skills.GetEffectValue(source, "damage_penalty_reduction")
end

function Skills.GetPayoutBonus(source)
    return Skills.GetEffectValue(source, "payout_bonus")
end

function Skills.GetPurchaseDiscount(source)
    return Skills.GetEffectValue(source, "purchase_discount")
end

function Skills.GetRepairDiscount(source)
    return Skills.GetEffectValue(source, "repair_discount")
end

-- Applies to every mission's level_required.
function Skills.GetLevelRequirementReduction(source)
    return Skills.GetEffectValue(source, "level_requirement_reduction")
end

function Skills.GetAreaUnlockDiscount(source)
    return Skills.GetEffectValue(source, "area_unlock_discount")
end

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
