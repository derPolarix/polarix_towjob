import { defineStore } from "pinia";
import type { DashboardPayload, OwnedVehicle, PagerOffer, PlayerData, TabKey } from "@/types/dashboard";

type DashboardState = {
	payload: DashboardPayload | null;
	activeTab: TabKey;
	pagerOffer: PagerOffer | null;
	rentalPromptOpen: boolean;
};
type DashboardGetters = {
	player: (state: DashboardState) => DashboardPayload["player"] | null;
	levelTitle: (state: DashboardState) => string;
	xpProgress: (state: DashboardState) => { current: number; span: number; percent: number };
	activeDelivery: (state: DashboardState) => DashboardPayload["activeDelivery"];
	onCall: (state: DashboardState) => boolean;
};
type DashboardActions = {
	setPayload(payload: DashboardPayload): void;
	setActiveTab(tab: TabKey): void;
	addUnlockedArea(areaId: string): void;
	setVehicles(vehicles: OwnedVehicle[]): void;
	setPlayer(player: PlayerData): void;
	clearActiveDelivery(): void;
	setOnCall(onCall: boolean): void;
	setRentalActive(active: boolean): void;
	setPagerOffer(offer: PagerOffer): void;
	clearPagerOffer(): void;
	openRentalPrompt(): void;
	closeRentalPrompt(): void;
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
		pagerOffer: null,
		rentalPromptOpen: false,
	}),
	getters: {
		player: (state) => state.payload?.player ?? null,
		onCall: (state) => state.payload?.onCall ?? false,
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
		activeDelivery: (state) => state.payload?.activeDelivery ?? null,
	},
	actions: {
		setPayload(payload) {
			this.payload = payload;
		},
		setActiveTab(tab) {
			this.activeTab = tab;
		},
		addUnlockedArea(areaId) {
			if (!this.payload) return;
			if (!this.payload.unlockedAreaIds.includes(areaId)) {
				this.payload.unlockedAreaIds.push(areaId);
			}
		},
		setVehicles(vehicles) {
			if (!this.payload) return;
			this.payload.vehicles = vehicles;
		},
		setPlayer(player) {
			if (!this.payload) return;
			this.payload.player = player;
		},
		clearActiveDelivery() {
			if (!this.payload) return;
			this.payload.activeDelivery = null;
		},
		setOnCall(onCall) {
			if (!this.payload) return;
			this.payload.onCall = onCall;
		},
		setRentalActive(active) {
			if (!this.payload) return;
			this.payload.rentalActive = active;
		},
		setPagerOffer(offer) {
			this.pagerOffer = offer;
		},
		clearPagerOffer() {
			this.pagerOffer = null;
		},
		openRentalPrompt() {
			this.rentalPromptOpen = true;
		},
		closeRentalPrompt() {
			this.rentalPromptOpen = false;
		},
	},
});

export type DashboardStore = ReturnType<typeof useDashboardStore>;
