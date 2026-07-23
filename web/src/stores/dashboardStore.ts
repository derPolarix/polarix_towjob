import { defineStore } from "pinia";
import type { DashboardPayload, TabKey } from "@/types/dashboard";

type DashboardState = {
	payload: DashboardPayload | null;
	activeTab: TabKey;
};
type DashboardGetters = {
	player: (state: DashboardState) => DashboardPayload["player"] | null;
	levelTitle: (state: DashboardState) => string;
	xpProgress: (state: DashboardState) => { current: number; span: number; percent: number };
};
type DashboardActions = {
	setPayload(payload: DashboardPayload): void;
	setActiveTab(tab: TabKey): void;
};

export const useDashboardStore = defineStore<
	"dashboard",
	DashboardState,
	DashboardGetters,
	DashboardActions
>("dashboard", {
	state: (): DashboardState => ({
		payload: null,
		activeTab: "overview",
	}),
	getters: {
		player: (state) => state.payload?.player ?? null,
		levelTitle: (state) => {
			const level = state.payload?.player.level ?? 1;
			return state.payload?.levelTitles[level - 1] ?? "";
		},
		xpProgress: (state) => {
			const thresholds = state.payload?.xpThresholds ?? [0];
			const level = state.payload?.player.level ?? 1;
			const xp = state.payload?.player.xp ?? 0;

			const currentThreshold = thresholds[level - 1] ?? 0;
			const nextThreshold = thresholds[level];

			if (nextThreshold === undefined) {
				return { current: xp - currentThreshold, span: 0, percent: 100 };
			}

			const span = nextThreshold - currentThreshold;
			const current = xp - currentThreshold;
			const percent = span > 0 ? Math.min(100, Math.max(0, (current / span) * 100)) : 100;

			return { current, span, percent };
		},
	},
	actions: {
		setPayload(payload) {
			this.payload = payload;
		},
		setActiveTab(tab) {
			this.activeTab = tab;
		},
	},
});

export type DashboardStore = ReturnType<typeof useDashboardStore>;
