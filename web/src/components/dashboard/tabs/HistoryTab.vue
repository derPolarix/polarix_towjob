<template>
	<div class="flex flex-col gap-4 text-white">
		<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">Delivery History</h3>

		<div v-if="loading" class="text-white/60 text-sm">Loading…</div>
		<div v-else-if="entries.length === 0" class="text-white/60 text-sm">No deliveries yet.</div>

		<div class="flex flex-col gap-2 overflow-y-auto max-h-[420px]">
			<div
				v-for="job in entries"
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
						<div class="text-white/50">
							{{ job.xpPaid }} XP<span v-if="job.damagePenalty > 0"> · -${{ job.damagePenalty }} damage</span>
						</div>
					</div>
				</div>
			</div>
		</div>

		<div v-if="total > pageSize" class="flex items-center justify-between text-sm text-white/60">
			<button
				type="button"
				:disabled="offset === 0 || loading"
				class="rounded-md bg-white/10 hover:bg-white/20 disabled:opacity-40 disabled:cursor-not-allowed px-3 py-1.5"
				@click="goToPage(offset - pageSize)"
			>
				Previous
			</button>
			<span>{{ rangeLabel }}</span>
			<button
				type="button"
				:disabled="offset + pageSize >= total || loading"
				class="rounded-md bg-white/10 hover:bg-white/20 disabled:opacity-40 disabled:cursor-not-allowed px-3 py-1.5"
				@click="goToPage(offset + pageSize)"
			>
				Next
			</button>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { DeliveryHistoryEntry, DeliveryHistoryResult, DeliveryStatus } from "@/types/dashboard";

const entries = ref<DeliveryHistoryEntry[]>([]);
const total = ref(0);
const offset = ref(0);
const pageSize = ref(20);
const loading = ref(true);

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

const rangeLabel = computed(() => {
	if (total.value === 0) return "";
	const from = offset.value + 1;
	const to = Math.min(offset.value + entries.value.length, total.value);
	return `${from}-${to} of ${total.value}`;
});

async function fetchPage(nextOffset: number) {
	loading.value = true;

	try {
		const result = await nuiCallbackAsync<DeliveryHistoryResult>("getDeliveryHistory", { offset: nextOffset });
		if (result) {
			entries.value = Array.isArray(result.entries) ? result.entries : [];
			total.value = result.total ?? 0;
			offset.value = result.offset ?? nextOffset;
			pageSize.value = result.pageSize ?? pageSize.value;
		}
	} catch (error) {
		console.error("getDeliveryHistory failed:", error);
	} finally {
		loading.value = false;
	}
}

function goToPage(nextOffset: number) {
	fetchPage(Math.max(0, nextOffset));
}

onMounted(() => fetchPage(0));
</script>
