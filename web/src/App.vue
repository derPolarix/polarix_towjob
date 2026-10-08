<template>
	<div class="w-full h-screen relative overflow-hidden">
		<div v-if="isDev" class="absolute inset-y-0 left-0 z-50">
			<Sidebar />
		</div>

		<!-- HUD stays visible while driving, so it is never gated by IsNuiOpen -->
		<div v-if="activeDeliveryStore.isActive" class="absolute inset-0 z-40 pointer-events-none">
			<ActiveDeliveryUi />
		</div>

		<!-- Pager and rental prompt interrupt gameplay with or without the Dashboard open, so they are mounted unconditionally -->
		<PagerUi />
		<RentalPromptModal />
		<ConfirmModal />

		<main class="w-full h-full" v-show="persistantStore.IsNuiOpen">
			<router-view />
		</main>
	</div>
</template>

<script setup lang="ts">
import { getCurrentInstance, onMounted } from "vue";
import type { NuiMessage } from "./type";
import type { DashboardPayload, PagerOffer } from "@/types/dashboard";
import type { ActiveDeliveryUpdate } from "@/types/delivery";
import { isDev } from "./main";
import { setLanguage } from "./i18n";
import { setUiConfig } from "./lib/uiConfig";
import Sidebar from "@/components/app/Sidebar.vue";
import ActiveDeliveryUi from "@/views/ActiveDeliveryUi.vue";
import PagerUi from "@/views/PagerUi.vue";
import RentalPromptModal from "@/components/app/RentalPromptModal.vue";
import ConfirmModal from "@/components/app/ConfirmModal.vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import { useActiveDeliveryStore } from "@/stores/activeDeliveryStore";
import { useConfirmStore } from "@/stores/confirmStore";

const proxy = getCurrentInstance()!.proxy!;
const router = proxy.$router;
const persistantStore = proxy.$persistantStore;
const dashboardStore = useDashboardStore();
const activeDeliveryStore = useActiveDeliveryStore();
const confirmStore = useConfirmStore();

const handleMessage = (event: MessageEvent) => {
	const raw = event.data as any;
	const action = (raw?.action ?? "") as NuiMessage["action"];

	setLanguage((raw?.data as { language?: string })?.language);
	setUiConfig(raw?.data);

	switch (action) {
		case "openDashboard":
			dashboardStore.setPayload(raw.data as DashboardPayload);
			persistantStore.IsNuiOpen = true;
			router.push("/dashboard");
			break;
		case "activeDeliveryUpdate":
			activeDeliveryStore.setUpdate(raw.data as ActiveDeliveryUpdate);
			break;
		case "activeDeliveryEnded":
			activeDeliveryStore.clear();
			break;
		case "openAdminSettings":
			persistantStore.IsNuiOpen = true;
			router.push("/admin");
			break;
		case "onCallStateUpdate":
			dashboardStore.setOnCall(Boolean((raw.data as { onCall?: boolean })?.onCall));
			break;
		case "pagerOffer":
			dashboardStore.setPagerOffer(raw.data as PagerOffer);
			break;
		case "pagerOfferCleared":
			dashboardStore.clearPagerOffer();
			break;
		default:
			break;
	}
};

const handleEscape = async (event: KeyboardEvent) => {
	if (event.key === "Escape" && confirmStore.options) {
		confirmStore.answer(false);
		return;
	}
	if (event.key === "Escape" && persistantStore.IsNuiOpen) {
		try {
			await persistantStore.closeNui();
		} catch (error) {
			console.error("closeNUI failed:", error);
		}
	}
};

onMounted(() => {
	window.addEventListener("message", handleMessage);
	window.addEventListener("keydown", handleEscape);

	if (isDev) {
		import("@/dev/sampleData").then(({ sampleDashboardPayload }) => {
			dashboardStore.setPayload(sampleDashboardPayload);
		});
	}
});
</script>
