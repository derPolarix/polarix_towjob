<template>
	<div style="display:flex;flex-direction:column;gap:16px">
		<div>
			<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">Leaderboard</div>
			<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">Ranked by total earnings</div>
		</div>

		<div style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;overflow:hidden">
			<div style="padding:16px 20px 12px;display:flex;align-items:center;gap:9px">
				<iconify-icon icon="tabler:trophy" width="18" style="color:var(--accent)"></iconify-icon>
				<div style="font-size:15px;font-weight:700;color:#1b1f24">Top earners</div>
			</div>
			<div style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:11px 20px;background:#f6f7f8;border-bottom:1px solid #eef0f2;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">
				<span>Rank</span><span>Driver</span><span>Lvl</span><span>Earned</span>
			</div>

			<div v-if="loading" style="padding:32px 20px;text-align:center;font-size:13px;color:#9aa1ab">Loading leaderboard…</div>
			<div v-else-if="entries.length === 0" style="padding:32px 20px;text-align:center;font-size:13px;color:#9aa1ab">No deliveries completed yet.</div>

			<template v-else>
				<div
					v-for="entry in entries"
					:key="entry.rank"
					style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:13px 20px;border-bottom:1px solid #f1f2f4;align-items:center"
					:style="{ background: isOwnRow(entry) ? 'rgba(34,197,94,0.06)' : '#ffffff' }"
				>
					<span style="font-family:'IBM Plex Mono',monospace;font-size:13px;font-weight:700" :style="{ color: rankColor(entry.rank) }">{{ entry.rank }}</span>
					<div style="display:flex;align-items:center;gap:10px;min-width:0">
						<div style="width:30px;height:30px;border-radius:9px;background:#f1f2f4;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;color:#6b7280;flex-shrink:0">{{ entry.name[0] }}</div>
						<span style="font-size:13px;font-weight:600;color:#1b1f24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ entry.name }}</span>
					</div>
					<span style="font-size:13px;color:#3c424b">{{ entry.level }}</span>
					<span style="font-size:13px;font-weight:600;color:#1b1f24">${{ entry.total_earnings }}</span>
				</div>

				<div
					v-if="own && !isOwnRowVisible"
					style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:13px 20px;border-top:2px solid #eef0f2;align-items:center;background:rgba(34,197,94,0.06)"
				>
					<span style="font-family:'IBM Plex Mono',monospace;font-size:13px;font-weight:700;color:#c9cdd3">{{ own.rank }}</span>
					<div style="display:flex;align-items:center;gap:10px;min-width:0">
						<div style="width:30px;height:30px;border-radius:9px;background:#f1f2f4;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;color:#6b7280;flex-shrink:0">{{ own.name[0] }}</div>
						<span style="font-size:13px;font-weight:600;color:#1b1f24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ own.name }}</span>
					</div>
					<span style="font-size:13px;color:#3c424b">{{ own.level }}</span>
					<span style="font-size:13px;font-weight:600;color:#1b1f24">${{ own.total_earnings }}</span>
				</div>
			</template>
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

function rankColor(rank: number) {
	if (rank === 1) return "#22c55e";
	if (rank === 2) return "#9aa1ab";
	if (rank === 3) return "#b5651d";
	return "#c9cdd3";
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
