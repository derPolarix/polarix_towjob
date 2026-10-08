<template>
	<div class="min-h-screen flex items-center justify-center p-[24px] font-ui">
		<div class="w-[1366px] h-[1024px] flex bg-[#e7e9ec] rounded-[22px] overflow-hidden [box-shadow:0_40px_120px_rgba(0,0,0,0.55),0_0_0_1px_rgba(255,255,255,0.04)] text-[14px] text-ink">

			<aside class="w-[242px] shrink-0 bg-sidebar flex flex-col text-[#c9ced6]">
				<div class="pt-[18px] px-[18px] pb-[13px] flex items-center gap-[12px]">
					<div class="w-[40px] h-[40px] rounded-[12px] bg-accent flex items-center justify-center shrink-0">
						<iconify-icon icon="tabler:truck" width="23" class="text-sidebar"></iconify-icon>
					</div>
					<div class="flex-1 min-w-0">
						<div class="font-bold text-[16px] text-white leading-[1.05]">Polarix</div>
						<div class="font-mono text-[9px] tracking-[0.16em] uppercase text-sidebar-muted mt-[2px]">{{ t("dashboard.tow_ops") }}</div>
					</div>
				</div>
				<div class="h-[3px] mt-[2px] mx-[18px] mb-0 rounded-[2px] bg-[repeating-linear-gradient(45deg,var(--accent)_0_8px,#2e333b_8px_16px)] opacity-[0.55]"></div>

				<nav class="flex-1 overflow-y-auto py-[16px] px-[12px] flex flex-col gap-[3px]">
					<div class="font-mono text-[9px] tracking-[0.16em] uppercase text-[#5b626c] pt-0 px-[10px] pb-[8px]">{{ t("dashboard.menu") }}</div>
					<button
						v-for="item in navItems"
						:key="item.key"
						type="button"
						class="relative flex items-center gap-[12px] w-full py-[10px] px-[13px] border-none rounded-[10px] cursor-pointer font-[inherit] text-[14px] text-left"
						:style="{ background: dashboardStore.activeTab === item.key ? 'rgba(34,197,94,0.12)' : 'transparent', color: dashboardStore.activeTab === item.key ? '#ffffff' : 'var(--faint)' }"
						@click="dashboardStore.setActiveTab(item.key)"
					>
						<span class="absolute left-[-12px] top-[9px] bottom-[9px] w-[3px] rounded-[0_3px_3px_0] bg-accent" :style="{ opacity: dashboardStore.activeTab === item.key ? '1' : '0' }"></span>
						<iconify-icon :icon="item.icon" width="19" :style="{ color: dashboardStore.activeTab === item.key ? 'var(--accent)' : 'var(--sidebar-muted)', flexShrink: '0' }"></iconify-icon>
						<span class="flex-1" :style="{ fontWeight: dashboardStore.activeTab === item.key ? '600' : '500' }">{{ item.label }}</span>
						<span v-if="item.badge" class="font-mono text-[10px] font-semibold min-w-[18px] text-center py-[1px] px-[6px] rounded-[8px] bg-accent text-sidebar">{{ item.badge }}</span>
					</button>
				</nav>

				<div class="pt-0 px-[12px] pb-[6px]">
					<div class="p-[12px] rounded-[14px] bg-[#2b3039] border border-[#353b45]">
						<div class="flex items-center gap-[10px]">
							<div class="w-[38px] h-[38px] rounded-[11px] bg-accent flex items-center justify-center font-bold text-[16px] text-sidebar shrink-0">{{ initial }}</div>
							<div class="flex-1 min-w-0">
								<div class="font-semibold text-[13px] text-white whitespace-nowrap overflow-hidden text-ellipsis">{{ player?.name ?? '—' }}</div>
								<div class="font-mono text-[9px] tracking-[0.1em] uppercase text-sidebar-muted mt-[1px]">{{ dashboardStore.levelTitle }} · {{ t("common.level_short", { level: player?.level ?? 1 }) }}</div>
							</div>
						</div>
						<div class="mt-[11px] flex items-center gap-[8px]">
							<div class="flex-1 h-[5px] rounded-[3px] bg-[#3a414b] overflow-hidden">
								<div class="h-full bg-accent" :style="{ width: dashboardStore.xpProgress.percent + '%' }"></div>
							</div>
							<span class="font-mono text-[10px] text-sidebar-muted">{{ player?.xp ?? 0 }} XP</span>
						</div>
					</div>
				</div>
				<button class="mt-[6px] mx-[12px] mb-[14px] flex items-center gap-[10px] py-[10px] px-[13px] border-none bg-transparent text-sidebar-muted font-[inherit] text-[13px] cursor-pointer rounded-[10px]" @click="closeNui">
					<iconify-icon icon="tabler:logout" width="18"></iconify-icon> {{ t("dashboard.exit") }}
				</button>
			</aside>

			<main class="px-main flex flex-1 flex-col min-w-0 bg-[#e7e9ec]">
				<header class="h-[62px] shrink-0 flex items-center gap-[14px] py-0 px-[22px] bg-white border-b border-b-line">
					<div class="flex-1"></div>
					<div class="flex items-center gap-[7px] pt-[6px] pr-[8px] pb-[6px] pl-[12px] rounded-[20px] bg-surface-muted border border-line-soft">
						<iconify-icon icon="tabler:bolt" width="15" class="text-accent"></iconify-icon>
						<span class="text-[12px] text-muted font-medium">{{ t("dashboard.skill_points") }}</span>
						<span class="font-mono text-[12px] font-semibold text-ink bg-white border border-line-soft rounded-[10px] py-[1px] px-[8px]">{{ player?.skill_points ?? 0 }}</span>
					</div>
					<div class="text-right leading-[1.15] py-0 px-[4px]">
						<div class="font-mono text-[13px] font-semibold text-ink">{{ time }}</div>
						<div class="text-[10px] text-faint">{{ date }}</div>
					</div>
					<button class="w-[36px] h-[36px] rounded-[10px] border border-line-soft bg-white flex items-center justify-center cursor-pointer text-muted" @click="closeNui"><iconify-icon icon="tabler:x" width="18"></iconify-icon></button>
				</header>

				<div class="flex-1 overflow-y-auto p-[24px] flex flex-col gap-[16px]">
					<div
						v-if="dashboardStore.activeDelivery"
						class="flex items-center justify-between gap-[16px] rounded-[14px] bg-white border border-[#fecaca] py-[14px] px-[18px]"
					>
						<div class="flex items-center gap-[12px]">
							<div class="w-[36px] h-[36px] rounded-[10px] bg-[rgba(239,68,68,0.12)] flex items-center justify-center shrink-0">
								<iconify-icon icon="tabler:truck" width="18" class="text-danger"></iconify-icon>
							</div>
							<div>
								<div class="font-mono text-[9px] tracking-[0.1em] uppercase text-danger">{{ t("dashboard.active_delivery") }}</div>
								<div class="text-[14px] font-bold text-ink mt-[2px]">{{ dashboardStore.activeDelivery.missionName }}</div>
							</div>
						</div>
						<button
							type="button"
							:disabled="abortingDelivery"
							class="bg-danger text-white border-none rounded-[10px] py-[9px] px-[16px] font-[inherit] font-semibold text-[12px] cursor-pointer"
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
