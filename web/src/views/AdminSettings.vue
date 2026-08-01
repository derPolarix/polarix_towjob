<template>
	<div class="w-full h-full flex items-center justify-center bg-transparent">
		<div class="w-[960px] h-[680px] max-w-full max-h-full rounded-lg bg-neutral-900/95 border border-white/10 text-white flex flex-col overflow-hidden shadow-2xl">
			<header class="flex items-center justify-between px-4 py-3 border-b border-white/10 shrink-0">
				<div class="flex items-center gap-4">
					<h1 class="font-semibold text-lg">Tow Job — Admin</h1>
					<nav class="flex gap-1">
						<button
							v-for="s in sections"
							:key="s.key"
							type="button"
							class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
							:class="adminStore.section === s.key ? 'bg-neutral-700 text-white' : 'bg-neutral-800/50 text-white/60 hover:text-white'"
							@click="adminStore.setSection(s.key)"
						>
							{{ s.label }}
						</button>
					</nav>
				</div>
				<button type="button" class="text-white/50 hover:text-white text-xl leading-none" @click="close">✕</button>
			</header>

			<p v-if="adminStore.error" class="mx-4 mt-2 text-xs text-red-400 shrink-0">{{ adminStore.error }}</p>

			<main class="flex-1 overflow-hidden">
				<component :is="activeSectionComponent" />
			</main>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance, onMounted } from "vue";
import { useAdminStore } from "@/stores/adminStore";
import type { AdminSection } from "@/types/admin";
import MissionsSection from "@/components/admin/MissionsSection.vue";
import AreasSection from "@/components/admin/AreasSection.vue";
import SettingsSection from "@/components/admin/SettingsSection.vue";

const proxy = getCurrentInstance()!.proxy!;
const persistantStore = proxy.$persistantStore;
const adminStore = useAdminStore();

const sections: { key: AdminSection; label: string }[] = [
	{ key: "missions", label: "Missions" },
	{ key: "areas", label: "Areas" },
	{ key: "settings", label: "Settings" },
];

const sectionComponents: Record<AdminSection, unknown> = {
	missions: MissionsSection,
	areas: AreasSection,
	settings: SettingsSection,
};

const activeSectionComponent = computed(() => sectionComponents[adminStore.section]);

function close() {
	persistantStore.closeNui();
}

onMounted(() => {
	adminStore.fetchAreas();
	adminStore.fetchMissions();
	adminStore.fetchSettings();
});
</script>
