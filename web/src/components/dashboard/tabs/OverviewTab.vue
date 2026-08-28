<template>
	<div style="display:flex;flex-direction:column;gap:18px">
		<!-- Hero banner -->
		<div style="position:relative;border-radius:18px;overflow:hidden;background:#22262d;padding:26px 30px;display:flex;align-items:center;gap:24px">
			<div style="position:absolute;left:0;top:0;right:0;height:4px;background:repeating-linear-gradient(45deg,var(--accent) 0 11px,#1b1f24 11px 22px)"></div>
			<div style="flex:1;min-width:0">
				<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;letter-spacing:0.16em;text-transform:uppercase;color:var(--accent);margin-bottom:9px">Dashboard</div>
				<div style="font-size:30px;font-weight:800;color:#fff;letter-spacing:-0.02em;line-height:1.05">Welcome back, {{ player?.name ?? 'Driver' }}</div>
				<div style="margin-top:9px;font-size:13px;color:#9aa1ab;display:flex;align-items:center;gap:14px">
					<span>Lvl {{ player?.level ?? 1 }}</span>
					<span style="color:#454c56">·</span>
					<span style="display:inline-flex;align-items:center;gap:6px">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.onCall ? '#22c55e' : '#6b7280' }"></span>
						{{ dashboardStore.onCall ? 'On-call — receiving pager jobs' : 'Off-call' }}
					</span>
					<span style="color:#454c56">·</span>
					<span style="display:inline-flex;align-items:center;gap:6px">
						<span :style="{ width: '7px', height: '7px', borderRadius: '50%', background: dashboardStore.activeDelivery ? '#22c55e' : '#6b7280' }"></span>
						{{ dashboardStore.activeDelivery ? `Towing: ${dashboardStore.activeDelivery.missionName}` : 'No active delivery' }}
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
				{{ togglingOnCall ? 'Working…' : dashboardStore.onCall ? 'Go off-call' : 'Go on-call' }}
				<iconify-icon :icon="dashboardStore.onCall ? 'tabler:phone-off' : 'tabler:phone-ringing'" width="18"></iconify-icon>
			</button>
		</div>

		<p v-if="onCallError" style="margin:0;font-size:12px;color:#d24b3a">{{ onCallError }}</p>
		<p style="margin:0;font-size:12px;color:#9aa1ab">
			While on-call the pager sends a randomly picked tow job every few minutes — accept it with <b>Enter</b>, decline with <b>Backspace</b>. Go off-call any time to stop.
		</p>

		<!-- Stat cards -->
		<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px">
			<div v-for="stat in stats" :key="stat.label" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:18px">
				<div style="width:40px;height:40px;border-radius:11px;display:flex;align-items:center;justify-content:center" :style="{ background: stat.tileBg }">
					<iconify-icon :icon="stat.icon" width="21" :style="{ color: stat.color }"></iconify-icon>
				</div>
				<div style="font-size:26px;font-weight:800;letter-spacing:-0.02em;color:#1b1f24;margin-top:16px">{{ stat.value }}</div>
				<div style="font-size:13px;font-weight:600;color:#3c424b;margin-top:2px">{{ stat.label }}</div>
			</div>
		</div>

		<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;align-items:start">
			<!-- Active delivery -->
			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:18px 18px 0;min-height:330px;display:flex;flex-direction:column">
				<div style="display:flex;align-items:center;justify-content:space-between">
					<div style="font-size:15px;font-weight:700;color:#1b1f24">Active delivery</div>
					<span style="font-family:'IBM Plex Mono',monospace;font-size:10px;letter-spacing:0.06em;color:#9aa1ab;text-transform:uppercase">{{ dashboardStore.activeDelivery ? 'Towing' : 'Idle' }}</span>
				</div>
				<div v-if="dashboardStore.activeDelivery" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px 24px 30px">
					<div style="width:64px;height:64px;border-radius:18px;background:rgba(34,197,94,0.14);display:flex;align-items:center;justify-content:center">
						<iconify-icon icon="tabler:truck" width="32" style="color:#22c55e"></iconify-icon>
					</div>
					<div style="font-size:15px;font-weight:700;color:#1b1f24;margin-top:16px">{{ dashboardStore.activeDelivery.missionName }}</div>
					<div style="font-size:13px;color:#9aa1ab;margin-top:4px">In progress — see the on-screen HUD for details</div>
				</div>
				<div v-else style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px 24px 30px">
					<div style="width:64px;height:64px;border-radius:18px;background:#f1f2f4;display:flex;align-items:center;justify-content:center">
						<iconify-icon icon="tabler:truck" width="32" style="color:#aab0b8"></iconify-icon>
					</div>
					<div style="font-size:15px;font-weight:600;color:#3c424b;margin-top:16px">No active delivery</div>
					<div style="font-size:13px;color:#9aa1ab;margin-top:4px">
						{{ dashboardStore.onCall ? "You're on-call — the pager will ping a new job every few minutes" : 'Go on-call above to get tow jobs paged to you periodically' }}
					</div>
				</div>
			</div>

			<!-- Recent runs -->
			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:18px">
				<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px">
					<div style="font-size:15px;font-weight:700;color:#1b1f24">Recent jobs</div>
					<button style="background:transparent;border:none;cursor:pointer;font-family:inherit;font-size:12px;font-weight:600;color:var(--accent);display:inline-flex;align-items:center;gap:4px" @click="dashboardStore.setActiveTab('history')">
						View all <iconify-icon icon="tabler:chevron-right" width="14"></iconify-icon>
					</button>
				</div>
				<div v-if="recentJobs.length === 0" style="padding:24px 2px;font-size:13px;color:#9aa1ab">No deliveries yet.</div>
				<div v-for="job in recentJobs.slice(0, 4)" :key="job.id" style="display:flex;align-items:center;gap:12px;padding:11px 2px;border-bottom:1px solid #eef0f2">
					<div style="width:34px;height:34px;border-radius:9px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;flex-shrink:0">
						<iconify-icon :icon="statusMeta(job.status).icon" width="17" style="color:#6b7280"></iconify-icon>
					</div>
					<div style="flex:1;min-width:0">
						<div style="font-size:13px;font-weight:600;color:#1b1f24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ job.missionName }}</div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#9aa1ab;margin-top:2px">#DEL-{{ job.id }}</div>
					</div>
					<div style="text-align:right;flex-shrink:0">
						<div style="font-weight:700;font-size:13px" :style="{ color: job.status === 'failed' ? '#d24b3a' : '#1b1f24' }">${{ job.rewardPaid }}</div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;margin-top:2px;text-transform:uppercase" :style="{ color: statusMeta(job.status).color }">{{ job.status }}</div>
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
import type { DeliveryHistoryEntry, DeliveryStatus, RecentDeliveriesResult, ToggleOnCallResult } from "@/types/dashboard";

const RECENT_LIMIT = 5;

const dashboardStore = useDashboardStore();
const player = computed(() => dashboardStore.player);

const recentJobs = ref<DeliveryHistoryEntry[]>([]);

const togglingOnCall = ref(false);
const onCallError = ref("");

const onCallReasonMessages: Record<string, string> = {
	active_delivery_exists: "Finish your current delivery before going on-call.",
	no_deployed_vehicle: "Park out a tow truck from the Vehicles tab first.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
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

		onCallError.value = onCallReasonMessages[result?.reason ?? ""] ?? "Could not update on-call status.";
	} catch (error) {
		console.error("toggleOnCall failed:", error);
		onCallError.value = "Could not update on-call status.";
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
	{ icon: "tabler:cash-banknote", value: `$${player.value?.total_earnings ?? 0}`, label: "Total earnings", color: "#b58a05", tileBg: "rgba(232,180,8,0.16)" },
	{ icon: "tabler:medal", value: `${player.value?.level ?? 1} · ${dashboardStore.levelTitle}`, label: "Level", color: "#3b82f6", tileBg: "rgba(59,130,246,0.14)" },
	{ icon: "tabler:checks", value: String(player.value?.total_deliveries ?? 0), label: "Deliveries", color: "#22c55e", tileBg: "rgba(34,197,94,0.14)" },
	{ icon: "tabler:alert-triangle", value: `${player.value?.failed_deliveries ?? 0} / ${player.value?.aborted_deliveries ?? 0}`, label: "Failed / Aborted", color: "#8b5cf6", tileBg: "rgba(139,92,246,0.14)" },
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
