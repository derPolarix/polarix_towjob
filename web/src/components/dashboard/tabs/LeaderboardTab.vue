<template>
	<div style="display:flex;flex-direction:column;gap:16px">
		<div>
			<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:var(--ink)">{{ t("dashboard.nav_leaderboard") }}</div>
			<div style="font-family:var(--font-mono);font-size:11px;color:var(--faint);margin-top:4px">{{ t("leaderboard.subtitle") }}</div>
		</div>

		<div style="background:#fff;border:1px solid var(--border);border-radius:15px;overflow:hidden">
			<div style="padding:16px 20px 12px;display:flex;align-items:center;gap:9px">
				<iconify-icon icon="tabler:trophy" width="18" style="color:var(--accent)"></iconify-icon>
				<div style="font-size:15px;font-weight:700;color:var(--ink)">{{ t("leaderboard.top_earners") }}</div>
			</div>
			<div style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:11px 20px;background:var(--surface-subtle);border-bottom:1px solid var(--surface-sunken);font-family:var(--font-mono);font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:var(--faint)">
				<span>{{ t("leaderboard.col_rank") }}</span><span>{{ t("leaderboard.col_driver") }}</span><span>{{ t("leaderboard.col_lvl") }}</span><span>{{ t("leaderboard.col_earned") }}</span>
			</div>

			<div v-if="loading" style="padding:32px 20px;text-align:center;font-size:13px;color:var(--faint)">{{ t("leaderboard.loading") }}</div>
			<div v-else-if="entries.length === 0" style="padding:32px 20px;text-align:center;font-size:13px;color:var(--faint)">{{ t("leaderboard.empty") }}</div>

			<template v-else>
				<div
					v-for="entry in entries"
					:key="entry.rank"
					style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:13px 20px;border-bottom:1px solid var(--surface-muted);align-items:center"
					:style="{ background: isOwnRow(entry) ? 'rgba(34,197,94,0.06)' : '#ffffff' }"
				>
					<span style="font-family:var(--font-mono);font-size:13px;font-weight:700" :style="{ color: rankColor(entry.rank) }">{{ entry.rank }}</span>
					<div style="display:flex;align-items:center;gap:10px;min-width:0">
						<div style="width:30px;height:30px;border-radius:9px;background:var(--surface-muted);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;color:var(--muted);flex-shrink:0">{{ entry.name[0] }}</div>
						<span style="font-size:13px;font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ entry.name }}</span>
					</div>
					<span style="font-size:13px;color:var(--ink-soft)">{{ entry.level }}</span>
					<span style="font-size:13px;font-weight:600;color:var(--ink)">{{ formatMoney(entry.total_earnings) }}</span>
				</div>

				<div
					v-if="own && !isOwnRowVisible"
					style="display:grid;grid-template-columns:0.5fr 2fr 0.8fr 1fr;gap:12px;padding:13px 20px;border-top:2px solid var(--surface-sunken);align-items:center;background:rgba(34,197,94,0.06)"
				>
					<span style="font-family:var(--font-mono);font-size:13px;font-weight:700;color:#c9cdd3">{{ own.rank }}</span>
					<div style="display:flex;align-items:center;gap:10px;min-width:0">
						<div style="width:30px;height:30px;border-radius:9px;background:var(--surface-muted);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;color:var(--muted);flex-shrink:0">{{ own.name[0] }}</div>
						<span style="font-size:13px;font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ own.name }}</span>
					</div>
					<span style="font-size:13px;color:var(--ink-soft)">{{ own.level }}</span>
					<span style="font-size:13px;font-weight:600;color:var(--ink)">{{ formatMoney(own.total_earnings) }}</span>
				</div>
			</template>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { formatMoney } from "@/lib/uiConfig";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { LeaderboardEntry, LeaderboardResult } from "@/types/dashboard";

const { t } = useI18n();
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
			// Mirrors the server-side $0 filter, for dev sample data.
			entries.value = (Array.isArray(result.entries) ? result.entries : []).filter((entry) => entry.total_earnings > 0);
			own.value = result.own && result.own.total_earnings > 0 ? result.own : null;
		}
	} catch (error) {
		console.error("getLeaderboard failed:", error);
	} finally {
		loading.value = false;
	}
});
</script>
