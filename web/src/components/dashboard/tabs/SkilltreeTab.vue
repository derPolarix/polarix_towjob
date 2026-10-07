<template>
	<div class="flex flex-col gap-[18px]">
		<div class="flex items-end justify-between gap-[16px]">
			<div>
				<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("skills.title") }}</div>
				<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("skills.subtitle") }}</div>
			</div>
			<div class="flex items-center gap-[18px]">
				<div class="inline-flex items-center gap-[7px] text-[12px] text-muted">
					<span class="w-[13px] h-[13px] rounded-[50%] bg-accent"></span>{{ t("skills.legend_unlocked") }}
				</div>
				<div class="inline-flex items-center gap-[7px] text-[12px] text-muted">
					<span class="w-[13px] h-[13px] rounded-[50%] bg-white border-2 border-accent"></span>{{ t("skills.legend_unlockable") }}
				</div>
				<div class="inline-flex items-center gap-[7px] text-[12px] text-muted">
					<span class="w-[13px] h-[13px] rounded-[50%] bg-[#e9ebee] border border-[#d2d6db]"></span>{{ t("skills.legend_locked") }}
				</div>
				<div class="inline-flex items-center gap-[7px] py-[7px] px-[13px] rounded-[20px] bg-sidebar text-white text-[12px] font-semibold">
					<iconify-icon icon="tabler:bolt" width="15" class="text-accent"></iconify-icon>
					{{ t("skills.points", { count: skillPoints }) }}
				</div>
			</div>
		</div>

		<p v-if="actionError" class="text-[12px] text-danger-text m-0">{{ actionError }}</p>

		<div v-for="branch in branches" :key="branch.name" class="bg-white border border-line rounded-[16px] py-[22px] px-[26px]">
			<div class="flex items-center gap-[10px] mb-[8px]">
				<div class="w-[30px] h-[30px] rounded-[9px] bg-surface-muted flex items-center justify-center">
					<iconify-icon :icon="branch.icon" width="17" class="text-ink-soft"></iconify-icon>
				</div>
				<span class="text-[14px] font-bold text-ink">{{ branch.name }}</span>
			</div>
			<div class="flex items-center pt-[14px] px-0 pb-[6px] flex-wrap">
				<div v-for="(skill, i) in branch.skills" :key="skill.id" class="flex items-center [flex:0_0_auto]">
					<div
						class="relative flex flex-col items-center w-[104px]"
						@mouseenter="hoverSkillId = skill.id"
						@mouseleave="hoverSkillId = null"
					>
						<div
							class="w-[50px] h-[50px] rounded-[14px] flex items-center justify-center [border-width:2px] [border-style:solid]"
							:style="nodeStyle(skillState(skill))"
							:class="{ 'skill-clickable': skillState(skill) === 'unlockable' }"
							@click="unlock(skill)"
						>
							<iconify-icon :icon="nodeIcon(skillState(skill))" width="22" :style="{ color: nodeIconColor(skillState(skill)) }"></iconify-icon>
						</div>
						<div class="text-[11px] font-semibold text-ink-soft mt-[8px] text-center leading-[1.2]">{{ skill.name }}</div>

						<div
							v-if="hoverSkillId === skill.id"
							class="absolute bottom-[64px] left-[50%] [transform:translateX(-50%)] w-[216px] bg-sidebar text-white rounded-[12px] py-[13px] px-[15px] [box-shadow:0_14px_34px_rgba(0,0,0,0.3)] z-[20] pointer-events-none"
						>
							<div class="flex items-center justify-between gap-[8px]">
								<span class="text-[13px] font-bold">{{ skill.name }}</span>
								<span class="font-mono text-[8px] tracking-[0.08em] py-[2px] px-[6px] rounded-[5px]" :style="tagStyle(skillState(skill))">{{ stateLabel(skillState(skill)) }}</span>
							</div>
							<div class="text-[12px] text-[#aeb4bd] mt-[7px] leading-[1.45]">{{ skill.desc }}</div>
							<div class="font-mono text-[10px] text-[#7ee2a8] mt-[8px]">{{ formatEffects(skill.effects) }}</div>
							<div class="font-mono text-[10px] text-faint mt-[4px]">{{ t("skills.cost", { count: skill.cost }) }}</div>
							<div class="absolute top-[100%] left-[50%] [transform:translateX(-50%)] w-0 h-0 border-l-[7px] border-l-transparent border-r-[7px] border-r-transparent border-t-[7px] border-t-sidebar"></div>
						</div>
					</div>

					<div
						v-if="i < branch.skills.length - 1"
						class="w-[44px] h-[3px] rounded-[2px] mx-[2px] self-start mt-[24px]"
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
	if (state === "unlocked") return { background: "var(--accent)", borderColor: "var(--accent)" };
	if (state === "unlockable") return { background: "#ffffff", borderColor: "var(--accent)" };
	return { background: "#e9ebee", borderColor: "#cdd2d8" };
}

function nodeIcon(state: SkillState) {
	if (state === "unlocked") return "tabler:check";
	if (state === "unlockable") return "tabler:plus";
	return "tabler:lock";
}

function nodeIconColor(state: SkillState) {
	if (state === "unlocked") return "#0f2417";
	if (state === "unlockable") return "var(--accent)";
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
	return skills[i + 1] && skillState(skills[i + 1]) === "unlocked" ? "var(--accent)" : "#cdd2d8";
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
