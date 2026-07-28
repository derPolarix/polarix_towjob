<template>
	<div class="flex flex-col gap-6 text-white">
		<div class="grid grid-cols-2 gap-3 md:grid-cols-4">
			<div class="rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3">
				<div class="text-xs text-white/50 uppercase tracking-wide">Total Earnings</div>
				<div class="text-lg font-semibold text-emerald-400">${{ player?.total_earnings ?? 0 }}</div>
			</div>
			<div class="rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3">
				<div class="text-xs text-white/50 uppercase tracking-wide">Level</div>
				<div class="text-lg font-semibold">{{ player?.level ?? 1 }} · {{ dashboardStore.levelTitle }}</div>
			</div>
			<div class="rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3">
				<div class="text-xs text-white/50 uppercase tracking-wide">Deliveries</div>
				<div class="text-lg font-semibold">{{ player?.total_deliveries ?? 0 }}</div>
			</div>
			<div class="rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3">
				<div class="text-xs text-white/50 uppercase tracking-wide">Failed / Aborted</div>
				<div class="text-lg font-semibold text-white/70">{{ player?.failed_deliveries ?? 0 }} / {{ player?.aborted_deliveries ?? 0 }}</div>
			</div>
		</div>

		<div v-if="dashboardStore.activeDelivery" class="rounded-md bg-amber-900/30 border border-amber-500/30 px-4 py-3">
			<div class="text-xs text-amber-300/80 uppercase tracking-wide">Active Delivery</div>
			<div class="text-sm font-medium">{{ dashboardStore.activeDelivery.missionName }}</div>
		</div>
		<div v-else class="rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3 text-sm text-white/50">
			No active delivery right now.
		</div>

		<div class="flex flex-col gap-2">
			<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">Recent Jobs</h3>

			<div v-if="recentJobs.length === 0" class="text-white/60 text-sm">No deliveries yet.</div>

			<div
				v-for="job in recentJobs"
				:key="job.id"
				class="flex items-center justify-between gap-4 rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3"
			>
				<div class="flex flex-col gap-1">
					<span class="font-medium">{{ job.missionName }}</span>
					<span class="text-xs text-white/50">{{ formatDate(job.startedAt) }}</span>
				</div>

				<div class="flex items-center gap-4">
					<span class="rounded text-xs px-2 py-0.5 capitalize" :class="statusClass(job.status)">{{ job.status }}</span>
					<div class="text-right text-sm">
						<div class="text-emerald-400 font-semibold">${{ job.rewardPaid }}</div>
						<div class="text-white/50">{{ job.xpPaid }} XP</div>
					</div>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { DeliveryHistoryEntry, DeliveryStatus, RecentDeliveriesResult } from "@/types/dashboard";

const RECENT_LIMIT = 5;

const dashboardStore = useDashboardStore();
const player = computed(() => dashboardStore.player);

const recentJobs = ref<DeliveryHistoryEntry[]>([]);

const statusClasses: Record<DeliveryStatus, string> = {
	active: "bg-amber-500/20 text-amber-300",
	completed: "bg-emerald-500/20 text-emerald-300",
	failed: "bg-red-500/20 text-red-300",
	aborted: "bg-white/10 text-white/60",
};

function statusClass(status: DeliveryStatus): string {
	return statusClasses[status] ?? "bg-white/10 text-white/60";
}

function formatDate(value: string): string {
	const date = new Date(value);
	return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

onMounted(async () => {
	try {
		const result = await nuiCallbackAsync<RecentDeliveriesResult>("getRecentDeliveries", { limit: RECENT_LIMIT });
		if (result && Array.isArray(result.entries)) recentJobs.value = result.entries;
	} catch (error) {
		console.error("getRecentDeliveries failed:", error);
	}
});
</script>
