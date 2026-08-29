<template>
	<div style="width:100%;height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;--accent:#22c55e;font-family:'Archivo',system-ui,sans-serif">
		<div style="width:1100px;height:760px;max-width:100%;max-height:100%;display:flex;flex-direction:column;background:#e7e9ec;border-radius:22px;overflow:hidden;box-shadow:0 40px 120px rgba(0,0,0,0.55),0 0 0 1px rgba(255,255,255,0.04);font-size:14px;color:#1b1f24">
			<header style="flex-shrink:0;background:#22262d;padding:18px 22px;display:flex;align-items:center;gap:16px">
				<div style="width:36px;height:36px;border-radius:10px;background:var(--accent);display:flex;align-items:center;justify-content:center;flex-shrink:0">
					<iconify-icon icon="tabler:truck" width="19" style="color:#22262d"></iconify-icon>
				</div>
				<div style="flex:1;min-width:0">
					<div style="font-weight:700;font-size:15px;color:#fff">{{ t("admin.header_title") }}</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.12em;text-transform:uppercase;color:#7a818c;margin-top:2px">{{ t("admin.header_subtitle") }}</div>
				</div>
				<nav style="display:flex;gap:4px">
					<button
						v-for="s in sections"
						:key="s.key"
						type="button"
						style="position:relative;display:inline-flex;align-items:center;gap:7px;background:transparent;border:none;cursor:pointer;font-family:inherit;font-size:13px;padding:10px 14px;border-radius:9px"
						:style="{ background: adminStore.section === s.key ? 'rgba(34,197,94,0.14)' : 'transparent', color: adminStore.section === s.key ? '#ffffff' : '#9aa1ab', fontWeight: adminStore.section === s.key ? '600' : '500' }"
						@click="adminStore.setSection(s.key)"
					>
						<iconify-icon :icon="s.icon" width="16" :style="{ color: adminStore.section === s.key ? '#22c55e' : '#7a818c' }"></iconify-icon>{{ s.label }}
					</button>
				</nav>
				<button type="button" style="width:32px;height:32px;border-radius:9px;border:none;background:rgba(255,255,255,0.08);color:#c9ced6;display:flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0" @click="close">
					<iconify-icon icon="tabler:x" width="17"></iconify-icon>
				</button>
			</header>

			<p v-if="adminStore.error" style="flex-shrink:0;margin:0;padding:10px 22px;font-size:12px;color:#d24b3a;background:#fff;border-bottom:1px solid #dfe2e6">{{ adminStore.error }}</p>

			<main style="flex:1;overflow:hidden;background:#e7e9ec">
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

.accent-btn {
	background: var(--accent);
	color: #0f2417;
	border: none;
	border-radius: 10px;
	font-family: inherit;
	font-weight: 700;
	cursor: pointer;
	display: inline-flex;
	align-items: center;
	gap: 8px;
}
.accent-btn:hover {
	filter: brightness(0.92);
}
.accent-btn:disabled {
	opacity: 0.5;
	cursor: not-allowed;
}

.admin-label {
	display: flex;
	flex-direction: column;
	gap: 6px;
	font-family: 'IBM Plex Mono', monospace;
	font-size: 9px;
	letter-spacing: 0.08em;
	text-transform: uppercase;
	color: #9aa1ab;
}
.admin-input {
	font-family: 'Archivo', system-ui, sans-serif;
	font-size: 13px;
	font-weight: 500;
	text-transform: none;
	letter-spacing: normal;
	color: #1b1f24;
	background: #f6f7f8;
	border: 1px solid #e4e6e9;
	border-radius: 9px;
	padding: 9px 11px;
	outline: none;
}
.admin-input:focus {
	border-color: var(--accent);
}
</style>
