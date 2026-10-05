<template>
	<div class="flex flex-col gap-[16px]">
		<div>
			<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("dashboard.nav_leaderboard") }}</div>
			<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("leaderboard.subtitle") }}</div>
		</div>

		<div class="bg-white border border-line rounded-[15px] overflow-hidden">
			<div class="pt-[16px] px-[20px] pb-[12px] flex items-center gap-[9px]">
				<iconify-icon icon="tabler:trophy" width="18" class="text-accent"></iconify-icon>
				<div class="text-[15px] font-bold text-ink">{{ t("leaderboard.top_earners") }}</div>
			</div>
			<div class="grid grid-cols-[0.5fr_2fr_0.8fr_1fr] gap-[12px] py-[11px] px-[20px] bg-surface-subtle border-b border-b-surface-sunken font-mono text-[9px] tracking-[0.08em] uppercase text-faint">
				<span>{{ t("leaderboard.col_rank") }}</span><span>{{ t("leaderboard.col_driver") }}</span><span>{{ t("leaderboard.col_lvl") }}</span><span>{{ t("leaderboard.col_earned") }}</span>
			</div>

			<div v-if="loading" class="py-[32px] px-[20px] text-center text-[13px] text-faint">{{ t("leaderboard.loading") }}</div>
			<div v-else-if="entries.length === 0" class="py-[32px] px-[20px] text-center text-[13px] text-faint">{{ t("leaderboard.empty") }}</div>

			<template v-else>
				<div
					v-for="entry in entries"
					:key="entry.rank"
					class="grid grid-cols-[0.5fr_2fr_0.8fr_1fr] gap-[12px] py-[13px] px-[20px] border-b border-b-surface-muted items-center"
					:style="{ background: isOwnRow(entry) ? 'rgba(34,197,94,0.06)' : '#ffffff' }"
				>
					<span class="font-mono text-[13px] font-bold" :style="{ color: rankColor(entry.rank) }">{{ entry.rank }}</span>
					<div class="flex items-center gap-[10px] min-w-0">
						<div class="w-[30px] h-[30px] rounded-[9px] bg-surface-muted flex items-center justify-center font-bold text-[13px] text-muted shrink-0">{{ entry.name[0] }}</div>
						<span class="text-[13px] font-semibold text-ink whitespace-nowrap overflow-hidden text-ellipsis">{{ entry.name }}</span>
					</div>
					<span class="text-[13px] text-ink-soft">{{ entry.level }}</span>
					<span class="text-[13px] font-semibold text-ink">{{ formatMoney(entry.total_earnings) }}</span>
				</div>

				<div
					v-if="own && !isOwnRowVisible"
					class="grid grid-cols-[0.5fr_2fr_0.8fr_1fr] gap-[12px] py-[13px] px-[20px] border-t-2 border-t-surface-sunken items-center bg-[rgba(34,197,94,0.06)]"
				>
					<span class="font-mono text-[13px] font-bold text-[#c9cdd3]">{{ own.rank }}</span>
					<div class="flex items-center gap-[10px] min-w-0">
						<div class="w-[30px] h-[30px] rounded-[9px] bg-surface-muted flex items-center justify-center font-bold text-[13px] text-muted shrink-0">{{ own.name[0] }}</div>
						<span class="text-[13px] font-semibold text-ink whitespace-nowrap overflow-hidden text-ellipsis">{{ own.name }}</span>
					</div>
					<span class="text-[13px] text-ink-soft">{{ own.level }}</span>
					<span class="text-[13px] font-semibold text-ink">{{ formatMoney(own.total_earnings) }}</span>
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
	if (rank === 1) return "var(--accent)";
	if (rank === 2) return "var(--faint)";
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
