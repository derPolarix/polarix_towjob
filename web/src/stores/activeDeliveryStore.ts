import { defineStore } from "pinia";
import type { ActiveDeliveryUpdate } from "@/types/delivery";

type ActiveDeliveryState = {
	data: ActiveDeliveryUpdate | null;
};
type ActiveDeliveryGetters = {
	isActive: (state: ActiveDeliveryState) => boolean;
};
type ActiveDeliveryActions = {
	setUpdate(update: ActiveDeliveryUpdate): void;
	clear(): void;
};

export const useActiveDeliveryStore = defineStore<
	"activeDelivery",
	ActiveDeliveryState,
	ActiveDeliveryGetters,
	ActiveDeliveryActions
>("activeDelivery", {
	state: (): ActiveDeliveryState => ({
		data: null,
	}),
	getters: {
		isActive: (state) => state.data !== null,
	},
	actions: {
		setUpdate(update) {
			this.data = update;
		},
		clear() {
			this.data = null;
		},
	},
});

export type ActiveDeliveryStore = ReturnType<typeof useActiveDeliveryStore>;
