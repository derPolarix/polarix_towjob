import { defineStore } from "pinia";
import { nuiCallbackAsync, nuiCallback } from "@/nui/nuiCallbacks";

type PersistantState = {
	IsNuiOpen: boolean;
};
type PersistantGetters = {
	isNuiOpen: (state: PersistantState) => boolean;
};
type PersistantActions = {
	setNuiOpen(isOpen: boolean): void;
	closeNui(): Promise<void>;
};

export const usePersistantStore = defineStore<
	"persistant",
	PersistantState,
	PersistantGetters,
	PersistantActions
>(
	"persistant",
	{
		state: (): PersistantState => ({
			IsNuiOpen: true,
		}),
		getters: {
			isNuiOpen: (state) => state.IsNuiOpen,
		},
		actions: {
			setNuiOpen(isOpen: boolean) {
				this.IsNuiOpen = isOpen;
			},
			async closeNui() {
				this.IsNuiOpen = false;
				await nuiCallbackAsync("closeNui");
			},
		},
	},
);

export type PersistantStore = ReturnType<typeof usePersistantStore>;
