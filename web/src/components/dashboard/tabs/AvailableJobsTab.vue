<template>
	<div class="flex flex-col gap-4 text-white">
		<div class="flex items-center gap-2 text-sm">
			<span class="text-white/60">Sort by</span>
			<select
				v-model="sortKey"
				class="rounded-md bg-neutral-900/80 border border-white/10 px-2 py-1 text-white"
			>
				<option value="distance">Distance</option>
				<option value="reward">Reward</option>
				<option value="xp">XP</option>
				<option value="difficulty">Difficulty</option>
			</select>
			<button
				type="button"
				class="rounded-md bg-neutral-900/80 border border-white/10 px-2 py-1 hover:text-white text-white/70"
				@click="sortDir = sortDir === 'asc' ? 'desc' : 'asc'"
			>
				{{ sortDir === "asc" ? "Ascending" : "Descending" }}
			</button>
		</div>

		<p v-if="infoMessage" class="text-xs text-emerald-400">{{ infoMessage }}</p>
		<p v-if="errorMessage" class="text-xs text-red-400">{{ errorMessage }}</p>

		<div v-if="groups.length === 0" class="text-white/60 text-sm">
			No available jobs right now. Check back later or unlock more areas on the Map tab.
		</div>

		<div v-for="group in sortedGroups" :key="group.area_id" class="flex flex-col gap-2">
			<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">
				{{ group.area_name }} <span class="text-white/30">· {{ group.region }}</span>
			</h3>

			<div
				v-for="mission in group.missions"
				:key="mission.id"
				class="flex items-center justify-between gap-4 rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3"
			>
				<div class="flex flex-col gap-1">
					<div class="flex items-center gap-2">
						<span class="font-medium">{{ mission.name }}</span>
						<span
							v-if="mission.time_limit_minutes"
							class="rounded bg-amber-500/20 text-amber-300 text-xs px-2 py-0.5 font-semibold"
						>
							Timed · {{ mission.time_limit_minutes }} min
						</span>
						<span class="rounded bg-white/10 text-xs px-2 py-0.5 capitalize">{{ mission.difficulty }}</span>
					</div>
					<div class="text-xs text-white/60">
						{{ mission.vehicle_label }}
						<span v-if="mission.vehicle_colors">
							· Color: #{{ mission.vehicle_colors.primary }}/#{{ mission.vehicle_colors.secondary }}
						</span>
						· {{ mission.distance }}m away
					</div>
				</div>

				<div class="flex items-center gap-4">
					<div class="text-right text-sm">
						<div class="text-emerald-400 font-semibold">${{ mission.reward_base }}</div>
						<div class="text-white/50">{{ mission.xp_base }} XP</div>
					</div>
					<button
						type="button"
						:disabled="acceptingMissionId === mission.id"
						class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-3 py-2"
						@click="accept(mission)"
					>
						Accept
					</button>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import { usePersistantStore } from "@/stores/persistantStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AcceptMissionResult, Mission, MissionAreaGroup, MissionDifficulty } from "@/types/dashboard";

const dashboardStore = useDashboardStore();
const persistantStore = usePersistantStore();

const groups = ref<MissionAreaGroup[]>(dashboardStore.payload?.missions ?? []);

const acceptingMissionId = ref<string | null>(null);
const infoMessage = ref("");
const errorMessage = ref("");

const acceptReasonMessages: Record<string, string> = {
	active_delivery_exists: "You already have an active delivery.",
	mission_not_found: "This mission is no longer available.",
	level_too_low: "You do not meet the level requirement for this mission.",
	area_locked: "This area is not unlocked.",
	no_stored_vehicle: "All your tow trucks are currently deployed — store one at the depot first.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
};

async function accept(mission: Mission) {
	acceptingMissionId.value = mission.id;
	infoMessage.value = "";
	errorMessage.value = "";

	try {
		const result = await nuiCallbackAsync<AcceptMissionResult>("acceptMission", { missionId: mission.id });

		if (!result?.ok) {
			errorMessage.value = acceptReasonMessages[result?.reason ?? ""] ?? "Could not accept this mission.";
			return;
		}

		if (result.needsParkOut) {
			infoMessage.value = "Mission accepted. You own multiple tow trucks — open the Vehicles tab and Park Out one to begin.";
			return;
		}

		await persistantStore.closeNui();
	} catch (error) {
		console.error("acceptMission failed:", error);
		errorMessage.value = "Could not accept this mission.";
	} finally {
		acceptingMissionId.value = null;
	}
}

const sortKey = ref<"distance" | "reward" | "xp" | "difficulty">("distance");
const sortDir = ref<"asc" | "desc">("asc");

const difficultyRank: Record<MissionDifficulty, number> = { easy: 0, medium: 1, hard: 2 };

const compareMissions = (a: Mission, b: Mission) => {
	let diff = 0;
	if (sortKey.value === "distance") diff = a.distance - b.distance;
	else if (sortKey.value === "reward") diff = a.reward_base - b.reward_base;
	else if (sortKey.value === "xp") diff = a.xp_base - b.xp_base;
	else diff = difficultyRank[a.difficulty] - difficultyRank[b.difficulty];

	return sortDir.value === "asc" ? diff : -diff;
};

const sortedGroups = computed(() =>
	groups.value.map((group) => ({
		...group,
		missions: [...group.missions].sort(compareMissions),
	})),
);

onMounted(async () => {
	try {
		const fresh = await nuiCallbackAsync<MissionAreaGroup[]>("getAvailableJobs");
		if (Array.isArray(fresh)) groups.value = fresh;
	} catch (error) {
		console.error("getAvailableJobs failed:", error);
	}
});
</script>
