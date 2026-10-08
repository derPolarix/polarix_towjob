<template>
	<div class="flex flex-col gap-[18px]">
		<div class="relative rounded-[18px] overflow-hidden bg-sidebar py-[26px] px-[30px] flex items-center gap-[24px]">
			<div class="absolute left-0 top-0 right-0 h-[4px] bg-[repeating-linear-gradient(45deg,var(--accent)_0_11px,var(--ink)_11px_22px)]"></div>
			<div class="flex-1 min-w-0">
				<div class="font-mono text-[11px] tracking-[0.16em] uppercase text-accent mb-[9px]">{{ t("dashboard.nav_dashboard") }}</div>
				<div class="text-[30px] font-extrabold text-white tracking-[-0.02em] leading-[1.05]">{{ t("overview.welcome_back", { name: player?.name ?? t("overview.driver_fallback") }) }}</div>
				<div class="mt-[9px] text-[13px] text-faint flex items-center gap-[14px]">
					<span>{{ t("common.level_short", { level: player?.level ?? 1 }) }}</span>
					<span class="text-[#454c56]">·</span>
					<span class="inline-flex items-center gap-[6px]">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.onCall ? 'var(--accent)' : 'var(--muted)' }"></span>
						{{ dashboardStore.onCall ? t("overview.status_on_call") : t("overview.status_off_call") }}
					</span>
					<span class="text-[#454c56]">·</span>
					<span class="inline-flex items-center gap-[6px]">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.activeDelivery ? 'var(--accent)' : 'var(--muted)' }"></span>
						{{ dashboardStore.activeDelivery ? t("overview.status_towing", { name: dashboardStore.activeDelivery.missionName }) : t("overview.status_no_delivery") }}
					</span>
				</div>
			</div>
			<button
				class="accent-btn"
				type="button"
				:disabled="togglingOnCall"
				:style="dashboardStore.onCall ? 'padding:13px 20px;font-size:14px;background:var(--danger);color:#fff' : 'padding:13px 20px;font-size:14px'"
				@click="toggleOnCall"
			>
				{{ togglingOnCall ? t("overview.working") : dashboardStore.onCall ? t("overview.go_off_call") : t("overview.go_on_call") }}
				<iconify-icon :icon="dashboardStore.onCall ? 'tabler:phone-off' : 'tabler:phone-ringing'" width="18"></iconify-icon>
			</button>
		</div>

		<p v-if="onCallError" class="m-0 text-[12px] text-danger-text">{{ onCallError }}</p>
		<p class="m-0 text-[12px] text-faint">
			<i18n-t keypath="overview.on_call_help" tag="span">
				<template #accept><b>{{ uiConfig.keybinds.pagerAccept }}</b></template>
				<template #decline><b>{{ uiConfig.keybinds.pagerDecline }}</b></template>
			</i18n-t>
		</p>

		<div class="grid grid-cols-[repeat(4,1fr)] gap-[14px]">
			<div v-for="stat in stats" :key="stat.label" class="bg-white border border-line rounded-[15px] p-[18px]">
				<div class="w-[40px] h-[40px] rounded-[11px] flex items-center justify-center" :style="{ background: stat.tileBg }">
					<iconify-icon :icon="stat.icon" width="21" :style="{ color: stat.color }"></iconify-icon>
				</div>
				<div class="text-[26px] font-extrabold tracking-[-0.02em] text-ink mt-[16px]">{{ stat.value }}</div>
				<div class="text-[13px] font-semibold text-ink-soft mt-[2px]">{{ stat.label }}</div>
			</div>
		</div>

		<div class="grid grid-cols-[1fr_1fr] gap-[14px] [align-items:start]">
			<div class="bg-white border border-line rounded-[15px] pt-[18px] px-[18px] pb-0 min-h-[330px] flex flex-col">
				<div class="flex items-center justify-between">
					<div class="text-[15px] font-bold text-ink">{{ t("dashboard.active_delivery") }}</div>
					<span class="font-mono text-[10px] tracking-[0.06em] text-faint uppercase">{{ dashboardStore.activeDelivery ? t("overview.towing") : t("overview.idle") }}</span>
				</div>
				<div v-if="dashboardStore.activeDelivery" class="flex-1 flex flex-col items-center justify-center text-center pt-[24px] px-[24px] pb-[30px]">
					<div class="w-[64px] h-[64px] rounded-[18px] bg-[rgba(34,197,94,0.14)] flex items-center justify-center">
						<iconify-icon icon="tabler:truck" width="32" class="text-accent"></iconify-icon>
					</div>
					<div class="text-[15px] font-bold text-ink mt-[16px]">{{ dashboardStore.activeDelivery.missionName }}</div>
					<div class="text-[13px] text-faint mt-[4px]">{{ t("overview.in_progress_hud") }}</div>
				</div>
				<div v-else class="flex-1 flex flex-col items-center justify-center text-center pt-[24px] px-[24px] pb-[30px]">
					<div class="w-[64px] h-[64px] rounded-[18px] bg-surface-muted flex items-center justify-center">
						<iconify-icon icon="tabler:truck" width="32" class="text-[#aab0b8]"></iconify-icon>
					</div>
					<div class="text-[15px] font-semibold text-ink-soft mt-[16px]">{{ t("overview.status_no_delivery") }}</div>
					<div class="text-[13px] text-faint mt-[4px]">
						{{ dashboardStore.onCall ? t("overview.no_delivery_on_call") : t("overview.no_delivery_off_call") }}
					</div>
				</div>
			</div>

			<div class="bg-white border border-line rounded-[15px] p-[18px]">
				<div class="flex items-center justify-between mb-[6px]">
					<div class="text-[15px] font-bold text-ink">{{ t("overview.recent_jobs") }}</div>
					<button class="bg-transparent border-none cursor-pointer font-[inherit] text-[12px] font-semibold text-accent inline-flex items-center gap-[4px]" @click="dashboardStore.setActiveTab('history')">
						{{ t("overview.view_all") }} <iconify-icon icon="tabler:chevron-right" width="14"></iconify-icon>
					</button>
				</div>
				<div v-if="recentJobs.length === 0" class="py-[24px] px-[2px] text-[13px] text-faint">{{ t("common.no_deliveries_yet") }}</div>
				<div v-for="job in recentJobs.slice(0, 4)" :key="job.id" class="flex items-center gap-[12px] py-[11px] px-[2px] border-b border-b-surface-sunken">
					<div class="w-[34px] h-[34px] rounded-[9px] bg-[#f3f4f6] flex items-center justify-center shrink-0">
						<iconify-icon :icon="statusMeta(job.status).icon" width="17" class="text-muted"></iconify-icon>
					</div>
					<div class="flex-1 min-w-0">
						<div class="text-[13px] font-semibold text-ink whitespace-nowrap overflow-hidden text-ellipsis">{{ job.missionName }}</div>
						<div class="font-mono text-[10px] text-faint mt-[2px]">#DEL-{{ job.id }}</div>
					</div>
					<div class="text-right shrink-0">
						<div class="font-bold text-[13px]" :style="{ color: job.status === 'failed' ? 'var(--danger-text)' : 'var(--ink)' }">{{ formatMoney(job.rewardPaid) }}</div>
						<div class="font-mono text-[9px] tracking-[0.08em] mt-[2px] uppercase" :style="{ color: statusMeta(job.status).color }">{{ t("status." + job.status) }}</div>
					</div>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import { formatMoney, uiConfig } from "@/lib/uiConfig";
import type { DeliveryHistoryEntry, DeliveryStatus, RecentDeliveriesResult, ToggleOnCallResult } from "@/types/dashboard";

const RECENT_LIMIT = 5;

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const player = computed(() => dashboardStore.player);

const recentJobs = ref<DeliveryHistoryEntry[]>([]);

const togglingOnCall = ref(false);
const onCallError = ref("");

const onCallReasonMessages: Record<string, string> = {
	active_delivery_exists: "error.finish_delivery_before_on_call",
	no_missions_configured: "error.no_missions_configured",
	no_player: "error.no_player",
};

async function toggleOnCall() {
	togglingOnCall.value = true;
	onCallError.value = "";

	try {
		const result = await nuiCallbackAsync<ToggleOnCallResult>("toggleOnCall", { onCall: !dashboardStore.onCall });

		if (result?.ok) {
			dashboardStore.setOnCall(result.onCall ?? !dashboardStore.onCall);
			return;
		}

		if (result?.reason === "needs_rental") {
			dashboardStore.openRentalPrompt();
			return;
		}

		onCallError.value = t(onCallReasonMessages[result?.reason ?? ""] ?? "error.on_call_update_failed");
	} catch (error) {
		console.error("toggleOnCall failed:", error);
		onCallError.value = t("error.on_call_update_failed");
	} finally {
		togglingOnCall.value = false;
	}
}

const statusIcons: Record<DeliveryStatus, string> = {
	active: "tabler:road",
	completed: "tabler:circle-check",
	failed: "tabler:alert-triangle",
	aborted: "tabler:circle-x",
};

const statusColors: Record<DeliveryStatus, string> = {
	active: "#3b82f6",
	completed: "var(--accent)",
	failed: "var(--danger-text)",
	aborted: "var(--faint)",
};

function statusMeta(status: DeliveryStatus) {
	return {
		icon: statusIcons[status] ?? "tabler:circle-check",
		color: statusColors[status] ?? "var(--faint)",
	};
}

const stats = computed(() => [
	{ icon: "tabler:cash-banknote", value: formatMoney(player.value?.total_earnings), label: t("overview.stat_total_earnings"), color: "#b58a05", tileBg: "rgba(232,180,8,0.16)" },
	{ icon: "tabler:medal", value: `${player.value?.level ?? 1} · ${dashboardStore.levelTitle}`, label: t("overview.stat_level"), color: "#3b82f6", tileBg: "rgba(59,130,246,0.14)" },
	{ icon: "tabler:checks", value: String(player.value?.total_deliveries ?? 0), label: t("overview.stat_deliveries"), color: "var(--accent)", tileBg: "rgba(34,197,94,0.14)" },
	{ icon: "tabler:alert-triangle", value: `${player.value?.failed_deliveries ?? 0} / ${player.value?.aborted_deliveries ?? 0}`, label: t("overview.stat_failed_aborted"), color: "#8b5cf6", tileBg: "rgba(139,92,246,0.14)" },
]);

onMounted(async () => {
	try {
		const result = await nuiCallbackAsync<RecentDeliveriesResult>("getRecentDeliveries", { limit: RECENT_LIMIT });
		if (result && Array.isArray(result.entries)) recentJobs.value = result.entries;
	} catch (error) {
		console.error("getRecentDeliveries failed:", error);
	}
});
</script>
