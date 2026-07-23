import { defineStore } from "pinia";
import { nuiCallbackAsync, nuiCallback } from "@/nui/nuiCallbacks";

type PersistantState = {
	IsNuiOpen: boolean;
  MessageData: string | null;
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
      MessageData: null,
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
				await nuiCallbackAsync("closeNui", {message: this.MessageData});
			},
		},
	},
);

export type PersistantStore = ReturnType<typeof usePersistantStore>;
