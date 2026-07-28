<template>
	<div class="flex flex-col gap-4 text-white">
		<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">Top Earners</h3>

		<div v-if="loading" class="text-white/60 text-sm">Loading leaderboard…</div>
		<div v-else-if="entries.length === 0" class="text-white/60 text-sm">No deliveries completed yet.</div>

		<div class="flex flex-col gap-1">
			<div
				v-for="entry in entries"
				:key="entry.rank"
				class="flex items-center justify-between gap-4 rounded-md border px-4 py-2"
				:class="isOwnRow(entry) ? 'bg-emerald-900/30 border-emerald-500/40' : 'bg-neutral-900/70 border-white/10'"
			>
				<div class="flex items-center gap-3">
					<span class="w-6 text-right text-white/50 font-mono">#{{ entry.rank }}</span>
					<span class="font-medium">{{ entry.name }}</span>
					<span class="text-xs text-white/50">Lvl {{ entry.level }}</span>
				</div>
				<span class="text-emerald-400 font-semibold">${{ entry.total_earnings }}</span>
			</div>

			<div
				v-if="own && !isOwnRowVisible"
				class="mt-2 flex items-center justify-between gap-4 rounded-md bg-emerald-900/30 border border-emerald-500/40 px-4 py-2"
			>
				<div class="flex items-center gap-3">
					<span class="w-6 text-right text-white/50 font-mono">#{{ own.rank }}</span>
					<span class="font-medium">{{ own.name }}</span>
					<span class="text-xs text-white/50">Lvl {{ own.level }}</span>
				</div>
				<span class="text-emerald-400 font-semibold">${{ own.total_earnings }}</span>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { LeaderboardEntry, LeaderboardResult } from "@/types/dashboard";

const entries = ref<LeaderboardEntry[]>([]);
const own = ref<LeaderboardEntry | null>(null);
const loading = ref(true);

const isOwnRowVisible = computed(() => own.value !== null && entries.value.some((entry) => entry.rank === own.value?.rank));

function isOwnRow(entry: LeaderboardEntry): boolean {
	return own.value !== null && entry.rank === own.value.rank;
}

onMounted(async () => {
	try {
		const result = await nuiCallbackAsync<LeaderboardResult>("getLeaderboard");
		if (result) {
			entries.value = Array.isArray(result.entries) ? result.entries : [];
			own.value = result.own ?? null;
		}
	} catch (error) {
		console.error("getLeaderboard failed:", error);
	} finally {
		loading.value = false;
	}
});
</script>
