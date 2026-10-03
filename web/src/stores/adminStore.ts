import { defineStore } from "pinia";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type {
	AdminArea,
	AdminGetSettingsResult,
	AdminListAreasResult,
	AdminListMissionsResult,
	AdminMission,
	AdminSection,
	AdminSetting,
} from "@/types/admin";

type AdminState = {
	section: AdminSection;
	missions: AdminMission[];
	testActive: boolean;
	areas: AdminArea[];
	settings: AdminSetting[];
	loading: boolean;
	error: string;
};

export const useAdminStore = defineStore("admin", {
	state: (): AdminState => ({
		section: "missions",
		missions: [],
		testActive: false,
		areas: [],
		settings: [],
		loading: false,
		error: "",
	}),
	actions: {
		setSection(section: AdminSection) {
			this.section = section;
		},
		async fetchMissions() {
			this.loading = true;
			this.error = "";
			try {
				const result = await nuiCallbackAsync<AdminListMissionsResult>("adminListMissions");
				if (result?.ok && result.missions) {
					this.missions = result.missions;
					this.testActive = result.testActive === true;
				} else {
					this.error = result?.reason ?? "Failed to load missions.";
				}
			} catch (error) {
				console.error("adminListMissions failed:", error);
				this.error = "Failed to load missions.";
			} finally {
				this.loading = false;
			}
		},
		async fetchAreas() {
			this.loading = true;
			this.error = "";
			try {
				const result = await nuiCallbackAsync<AdminListAreasResult>("adminListAreas");
				if (result?.ok && result.areas) {
					this.areas = result.areas;
				} else {
					this.error = result?.reason ?? "Failed to load areas.";
				}
			} catch (error) {
				console.error("adminListAreas failed:", error);
				this.error = "Failed to load areas.";
			} finally {
				this.loading = false;
			}
		},
		async fetchSettings() {
			this.loading = true;
			this.error = "";
			try {
				const result = await nuiCallbackAsync<AdminGetSettingsResult>("adminGetSettings");
				if (result?.ok && result.settings) {
					this.settings = result.settings;
				} else {
					this.error = result?.reason ?? "Failed to load settings.";
				}
			} catch (error) {
				console.error("adminGetSettings failed:", error);
				this.error = "Failed to load settings.";
			} finally {
				this.loading = false;
			}
		},
	},
});

export type AdminStore = ReturnType<typeof useAdminStore>;
