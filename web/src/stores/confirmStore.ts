import { defineStore } from "pinia";

export interface ConfirmOptions {
	title: string;
	body: string;
	confirmLabel: string;
	danger?: boolean;
}

export const useConfirmStore = defineStore("confirm", {
	state: () => ({
		options: null as ConfirmOptions | null,
		resolver: null as ((confirmed: boolean) => void) | null,
	}),
	actions: {
		ask(options: ConfirmOptions): Promise<boolean> {
			this.resolver?.(false);
			this.options = options;
			return new Promise<boolean>((resolve) => {
				this.resolver = resolve;
			});
		},
		answer(confirmed: boolean) {
			const resolve = this.resolver;
			this.options = null;
			this.resolver = null;
			resolve?.(confirmed);
		},
	},
});
