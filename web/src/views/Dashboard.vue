<template>
	<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;font-family:var(--font-sans)">
		<div style="width:1366px;height:1024px;display:flex;background:#e7e9ec;border-radius:22px;overflow:hidden;box-shadow:0 40px 120px rgba(0,0,0,0.55),0 0 0 1px rgba(255,255,255,0.04);font-size:14px;color:var(--ink)">

			<!-- SIDEBAR -->
			<aside style="width:242px;flex-shrink:0;background:var(--sidebar);display:flex;flex-direction:column;color:#c9ced6">
				<div style="padding:18px 18px 13px;display:flex;align-items:center;gap:12px">
					<div style="width:40px;height:40px;border-radius:12px;background:var(--accent);display:flex;align-items:center;justify-content:center;flex-shrink:0">
						<iconify-icon icon="tabler:truck" width="23" style="color:var(--sidebar)"></iconify-icon>
					</div>
					<div style="flex:1;min-width:0">
						<div style="font-weight:700;font-size:16px;color:#fff;line-height:1.05">Polarix</div>
						<div style="font-family:var(--font-mono);font-size:9px;letter-spacing:0.16em;text-transform:uppercase;color:var(--sidebar-muted);margin-top:2px">{{ t("dashboard.tow_ops") }}</div>
					</div>
				</div>
				<div style="height:3px;margin:2px 18px 0;border-radius:2px;background:repeating-linear-gradient(45deg,var(--accent) 0 8px,#2e333b 8px 16px);opacity:0.55"></div>

				<nav style="flex:1;overflow-y:auto;padding:16px 12px;display:flex;flex-direction:column;gap:3px">
					<div style="font-family:var(--font-mono);font-size:9px;letter-spacing:0.16em;text-transform:uppercase;color:#5b626c;padding:0 10px 8px">{{ t("dashboard.menu") }}</div>
					<button
						v-for="item in navItems"
						:key="item.key"
						type="button"
						style="position:relative;display:flex;align-items:center;gap:12px;width:100%;padding:10px 13px;border:none;border-radius:10px;cursor:pointer;font-family:inherit;font-size:14px;text-align:left"
						:style="{ background: dashboardStore.activeTab === item.key ? 'rgba(34,197,94,0.12)' : 'transparent', color: dashboardStore.activeTab === item.key ? '#ffffff' : '#9aa1ab' }"
						@click="dashboardStore.setActiveTab(item.key)"
					>
						<span style="position:absolute;left:-12px;top:9px;bottom:9px;width:3px;border-radius:0 3px 3px 0;background:var(--accent)" :style="{ opacity: dashboardStore.activeTab === item.key ? '1' : '0' }"></span>
						<iconify-icon :icon="item.icon" width="19" :style="{ color: dashboardStore.activeTab === item.key ? '#22c55e' : '#7a818c', flexShrink: '0' }"></iconify-icon>
						<span style="flex:1" :style="{ fontWeight: dashboardStore.activeTab === item.key ? '600' : '500' }">{{ item.label }}</span>
						<span v-if="item.badge" style="font-family:var(--font-mono);font-size:10px;font-weight:600;min-width:18px;text-align:center;padding:1px 6px;border-radius:8px;background:var(--accent);color:var(--sidebar)">{{ item.badge }}</span>
					</button>
				</nav>

				<div style="padding:0 12px 6px">
					<div style="padding:12px;border-radius:14px;background:#2b3039;border:1px solid #353b45">
						<div style="display:flex;align-items:center;gap:10px">
							<div style="width:38px;height:38px;border-radius:11px;background:var(--accent);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:16px;color:var(--sidebar);flex-shrink:0">{{ initial }}</div>
							<div style="flex:1;min-width:0">
								<div style="font-weight:600;font-size:13px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ player?.name ?? '—' }}</div>
								<div style="font-family:var(--font-mono);font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:var(--sidebar-muted);margin-top:1px">{{ dashboardStore.levelTitle }} · {{ t("common.level_short", { level: player?.level ?? 1 }) }}</div>
							</div>
						</div>
						<div style="margin-top:11px;display:flex;align-items:center;gap:8px">
							<div style="flex:1;height:5px;border-radius:3px;background:#3a414b;overflow:hidden">
								<div style="height:100%;background:var(--accent)" :style="{ width: dashboardStore.xpProgress.percent + '%' }"></div>
							</div>
							<span style="font-family:var(--font-mono);font-size:10px;color:var(--sidebar-muted)">{{ player?.xp ?? 0 }} XP</span>
						</div>
					</div>
				</div>
				<button style="margin:6px 12px 14px;display:flex;align-items:center;gap:10px;padding:10px 13px;border:none;background:transparent;color:var(--sidebar-muted);font-family:inherit;font-size:13px;cursor:pointer;border-radius:10px" @click="closeNui">
					<iconify-icon icon="tabler:logout" width="18"></iconify-icon> {{ t("dashboard.exit") }}
				</button>
			</aside>

			<!-- MAIN -->
			<main class="px-main" style="flex:1;display:flex;flex-direction:column;min-width:0;background:#e7e9ec">
				<header style="height:62px;flex-shrink:0;display:flex;align-items:center;gap:14px;padding:0 22px;background:#fff;border-bottom:1px solid var(--border)">
					<div style="flex:1"></div>
					<div style="display:flex;align-items:center;gap:7px;padding:6px 8px 6px 12px;border-radius:20px;background:var(--surface-muted);border:1px solid var(--border-soft)">
						<iconify-icon icon="tabler:bolt" width="15" style="color:var(--accent)"></iconify-icon>
						<span style="font-size:12px;color:var(--muted);font-weight:500">{{ t("dashboard.skill_points") }}</span>
						<span style="font-family:var(--font-mono);font-size:12px;font-weight:600;color:var(--ink);background:#fff;border:1px solid var(--border-soft);border-radius:10px;padding:1px 8px">{{ player?.skill_points ?? 0 }}</span>
					</div>
					<div style="text-align:right;line-height:1.15;padding:0 4px">
						<div style="font-family:var(--font-mono);font-size:13px;font-weight:600;color:var(--ink)">{{ time }}</div>
						<div style="font-size:10px;color:var(--faint)">{{ date }}</div>
					</div>
					<button style="width:36px;height:36px;border-radius:10px;border:1px solid var(--border-soft);background:#fff;display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--muted)" @click="closeNui"><iconify-icon icon="tabler:x" width="18"></iconify-icon></button>
				</header>

				<div style="flex:1;overflow-y:auto;padding:24px;display:flex;flex-direction:column;gap:16px">
					<div
						v-if="dashboardStore.activeDelivery"
						style="display:flex;align-items:center;justify-content:space-between;gap:16px;border-radius:14px;background:#fff;border:1px solid #fecaca;padding:14px 18px"
					>
						<div style="display:flex;align-items:center;gap:12px">
							<div style="width:36px;height:36px;border-radius:10px;background:rgba(239,68,68,0.12);display:flex;align-items:center;justify-content:center;flex-shrink:0">
								<iconify-icon icon="tabler:truck" width="18" style="color:var(--danger)"></iconify-icon>
							</div>
							<div>
								<div style="font-family:var(--font-mono);font-size:9px;letter-spacing:0.1em;text-transform:uppercase;color:var(--danger)">{{ t("dashboard.active_delivery") }}</div>
								<div style="font-size:14px;font-weight:700;color:var(--ink);margin-top:2px">{{ dashboardStore.activeDelivery.missionName }}</div>
							</div>
						</div>
						<button
							type="button"
							:disabled="abortingDelivery"
							style="background:var(--danger);color:#fff;border:none;border-radius:10px;padding:9px 16px;font-family:inherit;font-weight:600;font-size:12px;cursor:pointer"
							:style="{ opacity: abortingDelivery ? 0.5 : 1, cursor: abortingDelivery ? 'not-allowed' : 'pointer' }"
							@click="abortDelivery"
						>
							{{ t("dashboard.abort_delivery") }}
						</button>
					</div>

					<component :is="activeTabComponent" />
				</div>
			</main>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance, onMounted, onUnmounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useDashboardStore } from "@/stores/dashboardStore";
import { useConfirmStore } from "@/stores/confirmStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AbortDeliveryResult, TabKey } from "@/types/dashboard";

import OverviewTab from "@/components/dashboard/tabs/OverviewTab.vue";
import AreasTab from "@/components/dashboard/tabs/AreasTab.vue";
import VehiclesTab from "@/components/dashboard/tabs/VehiclesTab.vue";
import LeaderboardTab from "@/components/dashboard/tabs/LeaderboardTab.vue";
import SkilltreeTab from "@/components/dashboard/tabs/SkilltreeTab.vue";
import HistoryTab from "@/components/dashboard/tabs/HistoryTab.vue";

const { t } = useI18n();
const proxy = getCurrentInstance()!.proxy!;
const persistantStore = proxy.$persistantStore;
const dashboardStore = useDashboardStore();
const confirmStore = useConfirmStore();

const player = computed(() => dashboardStore.player);
const initial = computed(() => (player.value?.name?.[0] ?? "?").toUpperCase());

const now = ref(new Date());
let timer: ReturnType<typeof setInterval>;
onMounted(() => { timer = setInterval(() => { now.value = new Date(); }, 1000); });
onUnmounted(() => clearInterval(timer));

const time = computed(() => now.value.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }));
const date = computed(() => now.value.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" }));

const navItems = computed(() => [
	{ key: "overview" as TabKey, label: t("dashboard.nav_dashboard"), icon: "tabler:layout-dashboard", badge: "" },
	{ key: "areas" as TabKey, label: t("dashboard.nav_areas"), icon: "tabler:map", badge: "" },
	{ key: "vehicles" as TabKey, label: t("dashboard.nav_vehicles"), icon: "tabler:truck", badge: String(dashboardStore.payload?.vehicles.length ?? 0) },
	{ key: "leaderboard" as TabKey, label: t("dashboard.nav_leaderboard"), icon: "tabler:trophy", badge: "" },
	{ key: "skilltree" as TabKey, label: t("dashboard.nav_skilltree"), icon: "tabler:bolt", badge: "" },
	{ key: "history" as TabKey, label: t("dashboard.nav_history"), icon: "tabler:history", badge: "" },
]);

const tabComponents: Record<TabKey, unknown> = {
	overview: OverviewTab,
	areas: AreasTab,
	vehicles: VehiclesTab,
	leaderboard: LeaderboardTab,
	skilltree: SkilltreeTab,
	history: HistoryTab,
};

const activeTabComponent = computed(() => tabComponents[dashboardStore.activeTab]);

const abortingDelivery = ref(false);

async function abortDelivery() {
	const delivery = dashboardStore.activeDelivery;
	if (!delivery) return;

	const confirmed = await confirmStore.ask({
		title: t("confirm.abort_title"),
		body: t("confirm.abort_body"),
		confirmLabel: t("dashboard.abort_delivery"),
		danger: true,
	});
	if (!confirmed) return;

	abortingDelivery.value = true;

	try {
		const result = await nuiCallbackAsync<AbortDeliveryResult>("abortDelivery", { deliveryId: delivery.deliveryId });
		if (result?.ok) {
			dashboardStore.clearActiveDelivery();
		}
	} catch (error) {
		console.error("abortDelivery failed:", error);
	} finally {
		abortingDelivery.value = false;
	}
}

async function closeNui() {
	try {
		await persistantStore.closeNui();
	} catch (error) {
		console.error("closeNui failed:", error);
	}
}
</script>

<style>
iconify-icon { display: inline-flex; }

.px-main ::-webkit-scrollbar { width: 9px; height: 9px; }
.px-main ::-webkit-scrollbar-thumb { background: #c9cdd3; border-radius: 8px; }
.px-main ::-webkit-scrollbar-track { background: transparent; }
</style>
