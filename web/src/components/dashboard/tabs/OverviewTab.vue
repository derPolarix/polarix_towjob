<template>
	<div style="display:flex;flex-direction:column;gap:18px">
		<!-- Hero banner -->
		<div style="position:relative;border-radius:18px;overflow:hidden;background:var(--sidebar);padding:26px 30px;display:flex;align-items:center;gap:24px">
			<div style="position:absolute;left:0;top:0;right:0;height:4px;background:repeating-linear-gradient(45deg,var(--accent) 0 11px,var(--ink) 11px 22px)"></div>
			<div style="flex:1;min-width:0">
				<div style="font-family:var(--font-mono);font-size:11px;letter-spacing:0.16em;text-transform:uppercase;color:var(--accent);margin-bottom:9px">{{ t("dashboard.nav_dashboard") }}</div>
				<div style="font-size:30px;font-weight:800;color:#fff;letter-spacing:-0.02em;line-height:1.05">{{ t("overview.welcome_back", { name: player?.name ?? t("overview.driver_fallback") }) }}</div>
				<div style="margin-top:9px;font-size:13px;color:var(--faint);display:flex;align-items:center;gap:14px">
					<span>{{ t("common.level_short", { level: player?.level ?? 1 }) }}</span>
					<span style="color:#454c56">·</span>
					<span style="display:inline-flex;align-items:center;gap:6px">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.onCall ? '#22c55e' : '#6b7280' }"></span>
						{{ dashboardStore.onCall ? t("overview.status_on_call") : t("overview.status_off_call") }}
					</span>
					<span style="color:#454c56">·</span>
					<span style="display:inline-flex;align-items:center;gap:6px">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.activeDelivery ? '#22c55e' : '#6b7280' }"></span>
						{{ dashboardStore.activeDelivery ? t("overview.status_towing", { name: dashboardStore.activeDelivery.missionName }) : t("overview.status_no_delivery") }}
					</span>
				</div>
			</div>
			<button
				class="accent-btn"
				type="button"
				:disabled="togglingOnCall"
				:style="dashboardStore.onCall ? 'padding:13px 20px;font-size:14px;background:#dc2626;color:#fff' : 'padding:13px 20px;font-size:14px'"
				@click="toggleOnCall"
			>
				{{ togglingOnCall ? t("overview.working") : dashboardStore.onCall ? t("overview.go_off_call") : t("overview.go_on_call") }}
				<iconify-icon :icon="dashboardStore.onCall ? 'tabler:phone-off' : 'tabler:phone-ringing'" width="18"></iconify-icon>
			</button>
		</div>

		<p v-if="onCallError" style="margin:0;font-size:12px;color:var(--danger-text)">{{ onCallError }}</p>
		<p style="margin:0;font-size:12px;color:var(--faint)">
			<i18n-t keypath="overview.on_call_help" tag="span">
				<template #accept><b>{{ uiConfig.keybinds.pagerAccept }}</b></template>
				<template #decline><b>{{ uiConfig.keybinds.pagerDecline }}</b></template>
			</i18n-t>
		</p>

		<!-- Stat cards -->
		<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px">
			<div v-for="stat in stats" :key="stat.label" style="background:#fff;border:1px solid var(--border);border-radius:15px;padding:18px">
				<div style="width:40px;height:40px;border-radius:11px;display:flex;align-items:center;justify-content:center" :style="{ background: stat.tileBg }">
					<iconify-icon :icon="stat.icon" width="21" :style="{ color: stat.color }"></iconify-icon>
				</div>
				<div style="font-size:26px;font-weight:800;letter-spacing:-0.02em;color:var(--ink);margin-top:16px">{{ stat.value }}</div>
				<div style="font-size:13px;font-weight:600;color:var(--ink-soft);margin-top:2px">{{ stat.label }}</div>
			</div>
		</div>

		<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;align-items:start">
			<!-- Active delivery -->
			<div style="background:#fff;border:1px solid var(--border);border-radius:15px;padding:18px 18px 0;min-height:330px;display:flex;flex-direction:column">
				<div style="display:flex;align-items:center;justify-content:space-between">
					<div style="font-size:15px;font-weight:700;color:var(--ink)">{{ t("dashboard.active_delivery") }}</div>
					<span style="font-family:var(--font-mono);font-size:10px;letter-spacing:0.06em;color:var(--faint);text-transform:uppercase">{{ dashboardStore.activeDelivery ? t("overview.towing") : t("overview.idle") }}</span>
				</div>
				<div v-if="dashboardStore.activeDelivery" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px 24px 30px">
					<div style="width:64px;height:64px;border-radius:18px;background:rgba(34,197,94,0.14);display:flex;align-items:center;justify-content:center">
						<iconify-icon icon="tabler:truck" width="32" style="color:var(--accent)"></iconify-icon>
					</div>
					<div style="font-size:15px;font-weight:700;color:var(--ink);margin-top:16px">{{ dashboardStore.activeDelivery.missionName }}</div>
					<div style="font-size:13px;color:var(--faint);margin-top:4px">{{ t("overview.in_progress_hud") }}</div>
				</div>
				<div v-else style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px 24px 30px">
					<div style="width:64px;height:64px;border-radius:18px;background:var(--surface-muted);display:flex;align-items:center;justify-content:center">
						<iconify-icon icon="tabler:truck" width="32" style="color:#aab0b8"></iconify-icon>
					</div>
					<div style="font-size:15px;font-weight:600;color:var(--ink-soft);margin-top:16px">{{ t("overview.status_no_delivery") }}</div>
					<div style="font-size:13px;color:var(--faint);margin-top:4px">
						{{ dashboardStore.onCall ? t("overview.no_delivery_on_call") : t("overview.no_delivery_off_call") }}
					</div>
				</div>
			</div>

			<!-- Recent runs -->
			<div style="background:#fff;border:1px solid var(--border);border-radius:15px;padding:18px">
				<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px">
					<div style="font-size:15px;font-weight:700;color:var(--ink)">{{ t("overview.recent_jobs") }}</div>
					<button style="background:transparent;border:none;cursor:pointer;font-family:inherit;font-size:12px;font-weight:600;color:var(--accent);display:inline-flex;align-items:center;gap:4px" @click="dashboardStore.setActiveTab('history')">
						{{ t("overview.view_all") }} <iconify-icon icon="tabler:chevron-right" width="14"></iconify-icon>
					</button>
				</div>
				<div v-if="recentJobs.length === 0" style="padding:24px 2px;font-size:13px;color:var(--faint)">{{ t("common.no_deliveries_yet") }}</div>
				<div v-for="job in recentJobs.slice(0, 4)" :key="job.id" style="display:flex;align-items:center;gap:12px;padding:11px 2px;border-bottom:1px solid var(--surface-sunken)">
					<div style="width:34px;height:34px;border-radius:9px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;flex-shrink:0">
						<iconify-icon :icon="statusMeta(job.status).icon" width="17" style="color:var(--muted)"></iconify-icon>
					</div>
					<div style="flex:1;min-width:0">
						<div style="font-size:13px;font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ job.missionName }}</div>
						<div style="font-family:var(--font-mono);font-size:10px;color:var(--faint);margin-top:2px">#DEL-{{ job.id }}</div>
					</div>
					<div style="text-align:right;flex-shrink:0">
						<div style="font-weight:700;font-size:13px" :style="{ color: job.status === 'failed' ? '#d24b3a' : '#1b1f24' }">{{ formatMoney(job.rewardPaid) }}</div>
						<div style="font-family:var(--font-mono);font-size:9px;letter-spacing:0.08em;margin-top:2px;text-transform:uppercase" :style="{ color: statusMeta(job.status).color }">{{ t("status." + job.status) }}</div>
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
	completed: "#22c55e",
	failed: "#d24b3a",
	aborted: "#9aa1ab",
};

function statusMeta(status: DeliveryStatus) {
	return {
		icon: statusIcons[status] ?? "tabler:circle-check",
		color: statusColors[status] ?? "#9aa1ab",
	};
}

const stats = computed(() => [
	{ icon: "tabler:cash-banknote", value: formatMoney(player.value?.total_earnings), label: t("overview.stat_total_earnings"), color: "#b58a05", tileBg: "rgba(232,180,8,0.16)" },
	{ icon: "tabler:medal", value: `${player.value?.level ?? 1} · ${dashboardStore.levelTitle}`, label: t("overview.stat_level"), color: "#3b82f6", tileBg: "rgba(59,130,246,0.14)" },
	{ icon: "tabler:checks", value: String(player.value?.total_deliveries ?? 0), label: t("overview.stat_deliveries"), color: "#22c55e", tileBg: "rgba(34,197,94,0.14)" },
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
