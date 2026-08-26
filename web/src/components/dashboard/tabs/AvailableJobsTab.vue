<template>
	<!-- List -->
	<div v-if="!selectedMissionId" style="display:flex;flex-direction:column;gap:16px">
		<div style="display:flex;align-items:flex-end;justify-content:space-between;gap:16px">
			<div>
				<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">Available jobs</div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">{{ totalCount }} job{{ totalCount === 1 ? '' : 's' }} open</div>
			</div>
			<div style="display:flex;align-items:center;gap:8px">
				<select v-model="sortKey" style="font-size:12px;font-weight:600;padding:8px 12px;border-radius:9px;background:#fff;border:1px solid #dfe2e6;color:#3c424b;font-family:inherit">
					<option value="distance">Sort: Distance</option>
					<option value="reward">Sort: Reward</option>
					<option value="xp">Sort: XP</option>
					<option value="difficulty">Sort: Difficulty</option>
				</select>
				<button type="button" style="font-size:12px;font-weight:600;padding:8px 14px;border-radius:9px;background:#22262d;color:#fff;border:none;cursor:pointer;display:inline-flex;align-items:center;gap:6px" @click="sortDir = sortDir === 'asc' ? 'desc' : 'asc'">
					<iconify-icon :icon="sortDir === 'asc' ? 'tabler:sort-ascending' : 'tabler:sort-descending'" width="14"></iconify-icon>
					{{ sortDir === 'asc' ? 'Ascending' : 'Descending' }}
				</button>
			</div>
		</div>

		<p v-if="infoMessage" style="font-size:12px;color:#22c55e;margin:0">{{ infoMessage }}</p>
		<p v-if="errorMessage" style="font-size:12px;color:#d24b3a;margin:0">{{ errorMessage }}</p>

		<div v-if="sortedGroups.length === 0" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:40px;text-align:center;color:#9aa1ab;font-size:13px">
			No available jobs right now. Check back later or unlock more areas on the Map tab.
		</div>

		<div v-for="group in sortedGroups" :key="group.area_id" style="display:flex;flex-direction:column;gap:10px">
			<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;letter-spacing:0.1em;text-transform:uppercase;color:#9aa1ab">
				{{ group.area_name }} <span style="color:#c2c7ce">· {{ group.region }}</span>
			</div>

			<button
				v-for="mission in group.missions"
				:key="mission.id"
				class="job-row"
				type="button"
				style="display:flex;align-items:center;gap:18px;width:100%;text-align:left;background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:16px 18px;cursor:pointer;font-family:inherit"
				@click="selectedMissionId = mission.id"
			>
				<div style="width:52px;height:52px;border-radius:13px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;flex-shrink:0">
					<iconify-icon icon="tabler:truck" width="26" style="color:#5b626c"></iconify-icon>
				</div>
				<div style="width:220px;flex-shrink:0">
					<div style="display:flex;align-items:center;gap:9px;flex-wrap:wrap">
						<span style="font-size:16px;font-weight:700;color:#1b1f24">{{ mission.name }}</span>
						<span v-if="mission.time_limit_minutes" style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.06em;padding:2px 7px;border-radius:6px;background:rgba(232,180,8,0.16);color:#b58a05">TIMED · {{ mission.time_limit_minutes }}M</span>
						<span style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.06em;padding:2px 7px;border-radius:6px;text-transform:uppercase" :style="{ background: difficultyMeta(mission.difficulty).bg, color: difficultyMeta(mission.difficulty).color }">{{ mission.difficulty }}</span>
					</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#9aa1ab;margin-top:5px">Lvl {{ mission.level_required }} required</div>
				</div>
				<div style="flex:1;display:grid;grid-template-columns:repeat(3,1fr);gap:14px">
					<div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">Reward</div>
						<div style="font-size:14px;font-weight:700;color:var(--accent);margin-top:3px">${{ mission.reward_base }}</div>
					</div>
					<div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">XP</div>
						<div style="font-size:14px;font-weight:600;color:#3c424b;margin-top:3px">+{{ mission.xp_base }}</div>
					</div>
					<div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">Distance</div>
						<div style="font-size:14px;font-weight:600;color:#3c424b;margin-top:3px">{{ mission.distance }}m</div>
					</div>
				</div>
				<iconify-icon icon="tabler:chevron-right" width="22" style="color:#c2c7ce;flex-shrink:0"></iconify-icon>
			</button>
		</div>
	</div>

	<!-- Detail -->
	<div v-else style="display:grid;grid-template-columns:7fr 3fr;gap:16px">
		<div style="background:#fff;border:1px solid #dfe2e6;border-radius:16px;padding:20px 22px;display:flex;flex-direction:column">
			<button type="button" style="align-self:flex-start;display:inline-flex;align-items:center;gap:7px;background:transparent;border:none;cursor:pointer;font-family:inherit;font-size:13px;font-weight:600;color:#6b7280;padding:0;margin-bottom:16px" @click="selectedMissionId = null">
				<iconify-icon icon="tabler:arrow-left" width="17"></iconify-icon> Back to list
			</button>

			<div style="position:relative;height:150px;border-radius:13px;overflow:hidden;background:repeating-linear-gradient(135deg,#eef0f2 0 12px,#e7e9ec 12px 24px);display:flex;align-items:center;justify-content:center">
				<span v-if="selectedMission.time_limit_minutes" style="position:absolute;top:12px;left:12px;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;padding:3px 8px;border-radius:6px;background:rgba(232,180,8,0.16);color:#b58a05">TIMED · {{ selectedMission.time_limit_minutes }} MIN</span>
				<span style="position:absolute;top:12px;right:12px;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;padding:3px 8px;border-radius:6px;text-transform:uppercase" :style="{ background: difficultyMeta(selectedMission.difficulty).bg, color: difficultyMeta(selectedMission.difficulty).color }">{{ selectedMission.difficulty }}</span>
				<div style="text-align:center">
					<iconify-icon icon="tabler:truck" width="44" style="color:#aab0b8"></iconify-icon>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:#aab0b8;margin-top:8px">vehicle pending recovery</div>
				</div>
			</div>

			<div style="display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-top:18px">
				<div style="font-size:24px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">{{ selectedMission.name }}</div>
				<span style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#9aa1ab;white-space:nowrap;margin-top:6px">Lvl {{ selectedMission.level_required }} required</span>
			</div>
			<div style="display:flex;align-items:center;gap:20px;margin-top:10px;color:#6b7280;font-size:13px;flex-wrap:wrap">
				<span style="display:inline-flex;align-items:center;gap:7px"><iconify-icon icon="tabler:route" width="16" style="color:#9aa1ab"></iconify-icon>{{ selectedMission.distance }}m to target</span>
				<span style="display:inline-flex;align-items:center;gap:7px"><iconify-icon icon="tabler:car" width="16" style="color:#9aa1ab"></iconify-icon>{{ selectedMission.vehicle_label }}</span>
				<span v-if="selectedMission.vehicle_colors" style="display:inline-flex;align-items:center;gap:7px"><iconify-icon icon="tabler:palette" width="16" style="color:#9aa1ab"></iconify-icon>#{{ selectedMission.vehicle_colors.primary }} / #{{ selectedMission.vehicle_colors.secondary }}</span>
			</div>

			<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;letter-spacing:0.1em;text-transform:uppercase;color:#9aa1ab;margin:22px 0 8px">Job info</div>
			<div style="font-size:13px;color:#3c424b;background:#f6f7f8;border:1px solid #eef0f2;border-radius:11px;padding:13px 15px;display:flex;align-items:center;gap:10px">
				<iconify-icon icon="tabler:map-pin-off" width="18" style="color:var(--accent);flex-shrink:0"></iconify-icon>
				Exact pickup point stays hidden until you accept — track it live from the on-screen HUD once you're underway.
			</div>

			<div style="margin-top:auto;padding-top:22px;display:flex;align-items:center;gap:16px">
				<div style="flex:1">
					<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:#9aa1ab">Reward</div>
					<div style="display:flex;align-items:baseline;gap:10px;margin-top:2px">
						<span style="font-size:26px;font-weight:800;letter-spacing:-0.02em;color:#1b1f24">${{ selectedMission.reward_base }}</span>
					</div>
				</div>
				<div style="text-align:center;padding-right:4px">
					<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:#9aa1ab">XP</div>
					<div style="display:inline-flex;align-items:center;gap:5px;margin-top:3px;font-size:16px;font-weight:700;color:#8b5cf6">
						<iconify-icon icon="tabler:star-filled" width="15"></iconify-icon>+{{ selectedMission.xp_base }}
					</div>
				</div>
			</div>
			<button
				class="accent-btn"
				type="button"
				style="margin-top:14px;width:100%;padding:15px;font-size:15px;justify-content:center"
				:disabled="acceptingMissionId === selectedMission.id"
				@click="accept(selectedMission)"
			>
				{{ acceptingMissionId === selectedMission.id ? 'Accepting…' : 'Accept job' }} <iconify-icon icon="tabler:chevron-right" width="19"></iconify-icon>
			</button>
		</div>

		<!-- Area & rules -->
		<div style="background:#fff;border:1px solid #dfe2e6;border-radius:16px;padding:18px;display:flex;flex-direction:column;gap:14px">
			<div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:#9aa1ab">Area</div>
				<div style="font-size:18px;font-weight:800;color:#1b1f24;margin-top:4px">{{ selectedGroup?.area_name }}</div>
				<div style="font-size:12px;color:#9aa1ab;margin-top:2px">{{ selectedGroup?.region }}</div>
			</div>
			<div style="height:1px;background:#eef0f2"></div>
			<div style="display:flex;flex-direction:column;gap:10px;font-size:13px">
				<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Difficulty</span><span style="font-weight:600;text-transform:capitalize;color:#1b1f24">{{ selectedMission.difficulty }}</span></div>
				<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Level required</span><span style="font-weight:600;color:#1b1f24">Lvl {{ selectedMission.level_required }}</span></div>
				<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Time limit</span><span style="font-weight:600;color:#1b1f24">{{ selectedMission.time_limit_minutes ? `${selectedMission.time_limit_minutes} min` : 'None' }}</span></div>
				<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Search distance</span><span style="font-weight:600;color:#1b1f24">{{ selectedMission.distance }}m</span></div>
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
const selectedMissionId = ref<string | null>(null);

const acceptingMissionId = ref<string | null>(null);
const infoMessage = ref("");
const errorMessage = ref("");

const totalCount = computed(() => groups.value.reduce((sum, g) => sum + g.missions.length, 0));

const selectedGroup = computed(() => groups.value.find((g) => g.missions.some((m) => m.id === selectedMissionId.value)) ?? null);
const selectedMission = computed<Mission>(
	() => selectedGroup.value?.missions.find((m) => m.id === selectedMissionId.value) ?? ({} as Mission),
);

const difficultyPalette: Record<MissionDifficulty, { bg: string; color: string }> = {
	easy: { bg: "rgba(34,197,94,0.14)", color: "#15803d" },
	medium: { bg: "rgba(232,180,8,0.16)", color: "#b58a05" },
	hard: { bg: "rgba(210,75,58,0.13)", color: "#d24b3a" },
};

function difficultyMeta(difficulty: MissionDifficulty) {
	return difficultyPalette[difficulty] ?? difficultyPalette.easy;
}

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
			selectedMissionId.value = null;
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

<style scoped>
.job-row:hover {
	border-color: var(--accent) !important;
}
</style>
