<template>
	<div class="w-full h-screen flex items-center justify-center p-[24px] font-ui">
		<div class="w-[1100px] h-[760px] max-w-full max-h-full flex flex-col bg-[#e7e9ec] rounded-[22px] overflow-hidden [box-shadow:0_40px_120px_rgba(0,0,0,0.55),0_0_0_1px_rgba(255,255,255,0.04)] text-[14px] text-ink">
			<header class="shrink-0 bg-sidebar py-[18px] px-[22px] flex items-center gap-[16px]">
				<div class="w-[36px] h-[36px] rounded-[10px] bg-accent flex items-center justify-center shrink-0">
					<iconify-icon icon="tabler:truck" width="19" class="text-sidebar"></iconify-icon>
				</div>
				<div class="flex-1 min-w-0">
					<div class="font-bold text-[15px] text-white">{{ t("admin.header_title") }}</div>
					<div class="font-mono text-[9px] tracking-[0.12em] uppercase text-sidebar-muted mt-[2px]">{{ t("admin.header_subtitle") }}</div>
				</div>
				<nav class="flex gap-[4px]">
					<button
						v-for="s in sections"
						:key="s.key"
						type="button"
						class="relative inline-flex items-center gap-[7px] bg-transparent border-none cursor-pointer font-[inherit] text-[13px] py-[10px] px-[14px] rounded-[9px]"
						:style="{ background: adminStore.section === s.key ? 'rgba(34,197,94,0.14)' : 'transparent', color: adminStore.section === s.key ? '#ffffff' : '#9aa1ab', fontWeight: adminStore.section === s.key ? '600' : '500' }"
						@click="adminStore.setSection(s.key)"
					>
						<iconify-icon :icon="s.icon" width="16" :style="{ color: adminStore.section === s.key ? '#22c55e' : '#7a818c' }"></iconify-icon>{{ s.label }}
					</button>
				</nav>
				<button type="button" class="w-[32px] h-[32px] rounded-[9px] border-none bg-[rgba(255,255,255,0.08)] text-[#c9ced6] flex items-center justify-center cursor-pointer shrink-0" @click="close">
					<iconify-icon icon="tabler:x" width="17"></iconify-icon>
				</button>
			</header>

			<p v-if="adminStore.error" class="shrink-0 m-0 py-[10px] px-[22px] text-[12px] text-danger-text bg-white border-b border-b-line">{{ adminStore.error }}</p>

			<main class="flex-1 overflow-hidden bg-[#e7e9ec]">
				<component :is="activeSectionComponent" />
			</main>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useAdminStore } from "@/stores/adminStore";
import type { AdminSection } from "@/types/admin";
import { isDev } from "@/main";
import MissionsSection from "@/components/admin/MissionsSection.vue";
import AreasSection from "@/components/admin/AreasSection.vue";
import SettingsSection from "@/components/admin/SettingsSection.vue";

const { t } = useI18n();
const proxy = getCurrentInstance()!.proxy!;
const persistantStore = proxy.$persistantStore;
const adminStore = useAdminStore();

const sections: { key: AdminSection; label: string; icon: string }[] = [
	{ key: "missions", label: t("admin.section_missions"), icon: "tabler:package" },
	{ key: "areas", label: t("admin.section_areas"), icon: "tabler:map" },
	{ key: "settings", label: t("admin.section_settings"), icon: "tabler:settings" },
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
	if (isDev) {
		import("@/dev/sampleData").then(({ sampleAdminAreas, sampleAdminMissions, sampleAdminSettings }) => {
			adminStore.areas = sampleAdminAreas;
			adminStore.missions = sampleAdminMissions;
			adminStore.settings = sampleAdminSettings;
		});
		return;
	}

	adminStore.fetchAreas();
	adminStore.fetchMissions();
	adminStore.fetchSettings();
});
</script>

<style>
iconify-icon { display: inline-flex; }

.admin-label {
	display: flex;
	flex-direction: column;
	gap: 6px;
	font-family:var(--font-mono);
	font-size: 9px;
	letter-spacing: 0.08em;
	text-transform: uppercase;
	color: var(--faint);
}
.admin-input {
	font-family:var(--font-sans);
	font-size: 13px;
	font-weight: 500;
	text-transform: none;
	letter-spacing: normal;
	color: var(--ink);
	background: var(--surface-subtle);
	border: 1px solid var(--border-soft);
	border-radius: 9px;
	padding: 9px 11px;
	outline: none;
}
.admin-input:focus {
	border-color: var(--accent);
}
</style>
