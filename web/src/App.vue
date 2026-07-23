<!-- This is a Vue 3 single-file component -->
<template>
	<div class="w-full h-screen relative overflow-hidden">
		<div v-if="isDev" class="absolute inset-y-0 left-0 z-50">
			<Sidebar />
		</div>

		<main class="w-full h-full">
			<router-view />
		</main>
	</div>
</template>

<script setup lang="ts">
import { getCurrentInstance, onMounted } from "vue";
import type { NuiMessage } from "./type";
import type { DashboardPayload } from "@/types/dashboard";
import { isDev } from "./main";
import Sidebar from "@/components/app/Sidebar.vue";
import { useDashboardStore } from "@/stores/dashboardStore";

const proxy = getCurrentInstance()!.proxy!;
const router = proxy.$router;
const persistantStore = proxy.$persistantStore;
const dashboardStore = useDashboardStore();

// Only place allowed to handle NUI messages, so the compiled build always keeps a single message handler.
const handleMessage = (event: MessageEvent) => {
	const raw = event.data as any;
	const action = (raw?.action ?? "") as NuiMessage["action"];

	switch (action) {
		case "openNui":
			persistantStore.IsNuiOpen = true;
			router.push("/defaultpage");
			break;
		case "updateMessage":
			persistantStore.MessageData = raw.data?.message ?? null;
			break;
		case "openDashboard":
			dashboardStore.setPayload(raw.data as DashboardPayload);
			persistantStore.IsNuiOpen = true;
			router.push("/dashboard");
			break;
		default:
			break;
	}
};

const handleEscape = async (event: KeyboardEvent) => {
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
});
</script>
