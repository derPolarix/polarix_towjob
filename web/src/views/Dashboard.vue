<template>
	<div class="relative w-full h-full flex flex-col text-white">
		<nav class="flex gap-1 px-4 pt-4">
			<button
				v-for="tab in tabs"
				:key="tab.key"
				type="button"
				class="px-3 py-2 rounded-t-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/20"
				:class="
					dashboardStore.activeTab === tab.key
						? 'bg-neutral-800 text-white'
						: 'bg-neutral-900/60 text-white/60 hover:text-white'
				"
				@click="dashboardStore.setActiveTab(tab.key)"
			>
				{{ tab.label }}
			</button>
		</nav>

		<main class="flex-1 overflow-y-auto bg-neutral-800/90 p-4">
			<component :is="activeTabComponent" />
		</main>

		<div class="absolute bottom-4 left-4 min-w-[220px] rounded-md bg-neutral-900/80 px-4 py-3">
			<div class="flex items-center justify-between gap-4">
				<span class="font-semibold">{{ dashboardStore.player?.name }}</span>
				<span class="text-sm text-white/70">Lvl {{ dashboardStore.player?.level }} · {{ dashboardStore.levelTitle }}</span>
			</div>
			<div class="mt-2 h-2 overflow-hidden rounded-full bg-neutral-700">
				<div class="h-full bg-emerald-500" :style="{ width: dashboardStore.xpProgress.percent + '%' }" />
			</div>
			<div class="mt-1 text-xs text-white/60">
				{{ dashboardStore.player?.xp }} XP · {{ dashboardStore.player?.skill_points }} skill points available
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import type { TabKey } from "@/types/dashboard";

import OverviewTab from "@/components/dashboard/tabs/OverviewTab.vue";
import AvailableJobsTab from "@/components/dashboard/tabs/AvailableJobsTab.vue";
import MapTab from "@/components/dashboard/tabs/MapTab.vue";
import VehiclesTab from "@/components/dashboard/tabs/VehiclesTab.vue";
import LeaderboardTab from "@/components/dashboard/tabs/LeaderboardTab.vue";
import SkilltreeTab from "@/components/dashboard/tabs/SkilltreeTab.vue";
import HistoryTab from "@/components/dashboard/tabs/HistoryTab.vue";

const dashboardStore = useDashboardStore();

const tabs: { key: TabKey; label: string }[] = [
	{ key: "overview", label: "Overview" },
	{ key: "jobs", label: "Available Jobs" },
	{ key: "map", label: "Map" },
	{ key: "vehicles", label: "Vehicles" },
	{ key: "leaderboard", label: "Leaderboard" },
	{ key: "skilltree", label: "Skilltree" },
	{ key: "history", label: "History" },
];

const tabComponents: Record<TabKey, unknown> = {
	overview: OverviewTab,
	jobs: AvailableJobsTab,
	map: MapTab,
	vehicles: VehiclesTab,
	leaderboard: LeaderboardTab,
	skilltree: SkilltreeTab,
	history: HistoryTab,
};

const activeTabComponent = computed(() => tabComponents[dashboardStore.activeTab]);
</script>
