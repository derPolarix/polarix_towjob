<template>
	<div class="flex flex-col gap-6 text-white">
		<p v-if="actionError" class="text-xs text-red-400">{{ actionError }}</p>

		<div class="text-sm text-white/60">
			{{ dashboardStore.player?.skill_points ?? 0 }} skill point(s) available
		</div>

		<div v-for="branch in branches" :key="branch.name" class="flex flex-col gap-2">
			<div class="flex items-center gap-2">
				<Icon :icon="branch.icon" class="w-5 h-5 text-white/70" aria-hidden="true" />
				<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">{{ branch.name }}</h3>
			</div>

			<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
				<div
					v-for="skill in branch.skills"
					:key="skill.id"
					class="flex flex-col gap-2 rounded-md border px-4 py-3"
					:class="stateClass(skillState(skill))"
				>
					<div class="flex items-center justify-between gap-2">
						<span class="font-medium">{{ skill.name }}</span>
						<span class="rounded bg-white/10 text-xs px-2 py-0.5 uppercase">{{ skillState(skill) }}</span>
					</div>

					<p class="text-xs text-white/60">{{ skill.desc }}</p>
					<p class="text-xs text-white/50">{{ formatEffects(skill.effects) }}</p>

					<div class="flex items-center justify-between gap-2 mt-1">
						<span class="text-xs text-white/60">Cost: {{ skill.cost }} pt(s)</span>
						<button
							v-if="skillState(skill) !== 'unlocked'"
							type="button"
							:disabled="skillState(skill) !== 'unlockable' || unlockingId === skill.id"
							class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium px-3 py-1.5"
							@click="unlock(skill)"
						>
							Unlock
						</button>
					</div>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { Icon } from "@iconify/vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { SkillBranch, SkillEffects, SkillNode, UnlockSkillResult } from "@/types/dashboard";

const dashboardStore = useDashboardStore();

const branches = ref<SkillBranch[]>(dashboardStore.payload?.skillBranches ?? []);

const unlockingId = ref<string | null>(null);
const actionError = ref("");

const reasonMessages: Record<string, string> = {
	invalid_skill: "That skill no longer exists.",
	already_unlocked: "You already unlocked this skill.",
	prerequisite_missing: "Unlock the prerequisite skill first.",
	insufficient_points: "You don't have enough skill points.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
};

const unlockedSkills = computed(() => new Set(dashboardStore.player?.skills ?? []));
const skillPoints = computed(() => dashboardStore.player?.skill_points ?? 0);

function skillState(skill: SkillNode): "locked" | "unlockable" | "unlocked" {
	if (unlockedSkills.value.has(skill.id)) return "unlocked";
	if (skill.requires && !unlockedSkills.value.has(skill.requires)) return "locked";
	if (skillPoints.value < skill.cost) return "locked";
	return "unlockable";
}

function stateClass(state: "locked" | "unlockable" | "unlocked"): string {
	if (state === "unlocked") return "bg-emerald-900/30 border-emerald-500/30";
	if (state === "unlockable") return "bg-neutral-900/70 border-white/20";
	return "bg-neutral-900/40 border-white/5 opacity-60";
}

const effectLabels: Record<keyof SkillEffects, string> = {
	damage_penalty_reduction: "damage penalty reduction",
	payout_bonus: "payout bonus",
	purchase_discount: "vehicle purchase discount",
	repair_discount: "repair cost discount",
	level_requirement_reduction: "lower mission level requirement",
	area_unlock_discount: "area unlock cost discount",
};

function formatEffects(effects: SkillEffects): string {
	const parts: string[] = [];
	for (const key of Object.keys(effects) as (keyof SkillEffects)[]) {
		const value = effects[key];
		if (value === undefined) continue;
		const label = effectLabels[key] ?? key;
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

	unlockingId.value = skill.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<UnlockSkillResult>("unlockSkill", { skillId: skill.id });
		if (result?.ok && result.player) {
			dashboardStore.setPlayer(result.player);
		} else {
			actionError.value = reasonMessages[result?.reason ?? ""] ?? "Unlock failed.";
		}
	} catch (error) {
		console.error("unlockSkill failed:", error);
		actionError.value = "Unlock failed.";
	} finally {
		unlockingId.value = null;
	}
}
</script>
