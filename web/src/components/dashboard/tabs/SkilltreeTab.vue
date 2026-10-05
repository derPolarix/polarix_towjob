<template>
	<div style="display:flex;flex-direction:column;gap:18px">
		<div style="display:flex;align-items:flex-end;justify-content:space-between;gap:16px">
			<div>
				<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:var(--ink)">{{ t("skills.title") }}</div>
				<div style="font-family:var(--font-mono);font-size:11px;color:var(--faint);margin-top:4px">{{ t("skills.subtitle") }}</div>
			</div>
			<div style="display:flex;align-items:center;gap:18px">
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:var(--muted)">
					<span style="width:13px;height:13px;border-radius:50%;background:var(--accent)"></span>{{ t("skills.legend_unlocked") }}
				</div>
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:var(--muted)">
					<span style="width:13px;height:13px;border-radius:50%;background:#fff;border:2px solid var(--accent)"></span>{{ t("skills.legend_unlockable") }}
				</div>
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:var(--muted)">
					<span style="width:13px;height:13px;border-radius:50%;background:#e9ebee;border:1px solid #d2d6db"></span>{{ t("skills.legend_locked") }}
				</div>
				<div style="display:inline-flex;align-items:center;gap:7px;padding:7px 13px;border-radius:20px;background:var(--sidebar);color:#fff;font-size:12px;font-weight:600">
					<iconify-icon icon="tabler:bolt" width="15" style="color:var(--accent)"></iconify-icon>
					{{ t("skills.points", { count: skillPoints }) }}
				</div>
			</div>
		</div>

		<p v-if="actionError" style="font-size:12px;color:var(--danger-text);margin:0">{{ actionError }}</p>

		<div v-for="branch in branches" :key="branch.name" style="background:#fff;border:1px solid var(--border);border-radius:16px;padding:22px 26px">
			<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px">
				<div style="width:30px;height:30px;border-radius:9px;background:var(--surface-muted);display:flex;align-items:center;justify-content:center">
					<iconify-icon :icon="branch.icon" width="17" style="color:var(--ink-soft)"></iconify-icon>
				</div>
				<span style="font-size:14px;font-weight:700;color:var(--ink)">{{ branch.name }}</span>
			</div>
			<div style="display:flex;align-items:center;padding:14px 0 6px;flex-wrap:wrap">
				<div v-for="(skill, i) in branch.skills" :key="skill.id" style="display:flex;align-items:center;flex:0 0 auto">
					<div
						style="position:relative;display:flex;flex-direction:column;align-items:center;width:104px"
						@mouseenter="hoverSkillId = skill.id"
						@mouseleave="hoverSkillId = null"
					>
						<div
							style="width:50px;height:50px;border-radius:14px;display:flex;align-items:center;justify-content:center;border-width:2px;border-style:solid"
							:style="nodeStyle(skillState(skill))"
							:class="{ 'skill-clickable': skillState(skill) === 'unlockable' }"
							@click="unlock(skill)"
						>
							<iconify-icon :icon="nodeIcon(skillState(skill))" width="22" :style="{ color: nodeIconColor(skillState(skill)) }"></iconify-icon>
						</div>
						<div style="font-size:11px;font-weight:600;color:var(--ink-soft);margin-top:8px;text-align:center;line-height:1.2">{{ skill.name }}</div>

						<div
							v-if="hoverSkillId === skill.id"
							style="position:absolute;bottom:64px;left:50%;transform:translateX(-50%);width:216px;background:var(--sidebar);color:#fff;border-radius:12px;padding:13px 15px;box-shadow:0 14px 34px rgba(0,0,0,0.3);z-index:20;pointer-events:none"
						>
							<div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
								<span style="font-size:13px;font-weight:700">{{ skill.name }}</span>
								<span style="font-family:var(--font-mono);font-size:8px;letter-spacing:0.08em;padding:2px 6px;border-radius:5px" :style="tagStyle(skillState(skill))">{{ stateLabel(skillState(skill)) }}</span>
							</div>
							<div style="font-size:12px;color:#aeb4bd;margin-top:7px;line-height:1.45">{{ skill.desc }}</div>
							<div style="font-family:var(--font-mono);font-size:10px;color:#7ee2a8;margin-top:8px">{{ formatEffects(skill.effects) }}</div>
							<div style="font-family:var(--font-mono);font-size:10px;color:var(--faint);margin-top:4px">{{ t("skills.cost", { count: skill.cost }) }}</div>
							<div style="position:absolute;top:100%;left:50%;transform:translateX(-50%);width:0;height:0;border-left:7px solid transparent;border-right:7px solid transparent;border-top:7px solid var(--sidebar)"></div>
						</div>
					</div>

					<div
						v-if="i < branch.skills.length - 1"
						style="width:44px;height:3px;border-radius:2px;margin:0 2px;align-self:flex-start;margin-top:24px"
						:style="{ background: lineColor(branch.skills, i) }"
					></div>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useDashboardStore } from "@/stores/dashboardStore";
import { useConfirmStore } from "@/stores/confirmStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { SkillBranch, SkillEffects, SkillNode, UnlockSkillResult } from "@/types/dashboard";

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const confirmStore = useConfirmStore();

const branches = ref<SkillBranch[]>(dashboardStore.payload?.skillBranches ?? []);
const hoverSkillId = ref<string | null>(null);

const unlockingId = ref<string | null>(null);
const actionError = ref("");

const reasonMessages: Record<string, string> = {
	invalid_skill: "error.skill_gone",
	already_unlocked: "error.skill_already_unlocked",
	prerequisite_missing: "error.skill_prerequisite_missing",
	insufficient_points: "error.skill_insufficient_points",
	no_player: "error.no_player",
};

const unlockedSkills = computed(() => new Set(dashboardStore.player?.skills ?? []));
const skillPoints = computed(() => dashboardStore.player?.skill_points ?? 0);

type SkillState = "locked" | "unlockable" | "unlocked";

function skillState(skill: SkillNode): SkillState {
	if (unlockedSkills.value.has(skill.id)) return "unlocked";
	if (skill.requires && !unlockedSkills.value.has(skill.requires)) return "locked";
	if (skillPoints.value < skill.cost) return "locked";
	return "unlockable";
}

function nodeStyle(state: SkillState): Record<string, string> {
	if (state === "unlocked") return { background: "#22c55e", borderColor: "#22c55e" };
	if (state === "unlockable") return { background: "#ffffff", borderColor: "#22c55e" };
	return { background: "#e9ebee", borderColor: "#cdd2d8" };
}

function nodeIcon(state: SkillState) {
	if (state === "unlocked") return "tabler:check";
	if (state === "unlockable") return "tabler:plus";
	return "tabler:lock";
}

function nodeIconColor(state: SkillState) {
	if (state === "unlocked") return "#0f2417";
	if (state === "unlockable") return "#22c55e";
	return "#aab0b8";
}

function stateLabel(state: SkillState): string {
	if (state === "unlocked") return t("skills.state_unlocked");
	if (state === "unlockable") return t("skills.state_available");
	return t("skills.state_locked");
}

function tagStyle(state: SkillState): Record<string, string> {
	if (state === "unlocked") return { background: "rgba(34,197,94,0.22)", color: "#7ee2a8" };
	if (state === "unlockable") return { background: "rgba(34,197,94,0.14)", color: "#4ade80" };
	return { background: "rgba(255,255,255,0.1)", color: "#aeb4bd" };
}

function lineColor(skills: SkillNode[], i: number): string {
	return skills[i + 1] && skillState(skills[i + 1]) === "unlocked" ? "#22c55e" : "#cdd2d8";
}

const effectLabelKeys: Record<keyof SkillEffects, string> = {
	damage_penalty_reduction: "skills.effect_damage_penalty_reduction",
	payout_bonus: "skills.effect_payout_bonus",
	purchase_discount: "skills.effect_purchase_discount",
	repair_discount: "skills.effect_repair_discount",
	level_requirement_reduction: "skills.effect_level_requirement_reduction",
	area_unlock_discount: "skills.effect_area_unlock_discount",
};

function formatEffects(effects: SkillEffects): string {
	const parts: string[] = [];
	for (const key of Object.keys(effects) as (keyof SkillEffects)[]) {
		const value = effects[key];
		if (value === undefined) continue;
		const label = effectLabelKeys[key] ? t(effectLabelKeys[key]) : key;
		if (key === "level_requirement_reduction") {
			parts.push(`-${value} ${label}`);
		} else {
			parts.push(`+${Math.round(value * 100)}% ${label}`);
		}
	}
	return parts.join(" · ");
}

async function unlock(skill: SkillNode) {
	if (skillState(skill) !== "unlockable") return;

	const confirmed = await confirmStore.ask({
		title: t("confirm.unlock_skill_title"),
		body: t("confirm.unlock_skill_body", { name: skill.name, count: skill.cost }),
		confirmLabel: t("confirm.unlock"),
	});
	if (!confirmed) return;

	unlockingId.value = skill.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<UnlockSkillResult>("unlockSkill", { skillId: skill.id });
		if (result?.ok && result.player) {
			dashboardStore.setPlayer(result.player);
		} else {
			actionError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.unlock_failed");
		}
	} catch (error) {
		console.error("unlockSkill failed:", error);
		actionError.value = t("error.unlock_failed");
	} finally {
		unlockingId.value = null;
	}
}
</script>

<style scoped>
.skill-clickable {
	cursor: pointer;
}
</style>
