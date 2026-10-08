import { reactive } from "vue";

// Keybinds and currency arrive with every NUI message (client/nui/nui_messages.lua).
export const uiConfig = reactive({
	keybinds: {
		pagerAccept: "Enter",
		pagerDecline: "Backspace",
	},
	currency: {
		symbol: "$",
		position: "prefix" as "prefix" | "suffix",
	},
});

type UiConfigMessage = {
	keybinds?: Partial<typeof uiConfig.keybinds>;
	currency?: Partial<typeof uiConfig.currency>;
};

const KEY_ICONS: Record<string, string> = {
	Enter: "tabler:corner-down-left",
	Backspace: "tabler:backspace",
};

export function keyIcon(key: string): string | undefined {
	return KEY_ICONS[key];
}

export function setUiConfig(data: UiConfigMessage | undefined) {
	if (data?.keybinds) Object.assign(uiConfig.keybinds, data.keybinds);
	if (data?.currency) Object.assign(uiConfig.currency, data.currency);
}

// Mirrors shared/currency.lua.
export function formatMoney(amount: number | null | undefined): string {
	const grouped = String(Math.floor(Number(amount) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
	const { symbol, position } = uiConfig.currency;
	return position === "suffix" ? `${grouped} ${symbol}` : `${symbol}${grouped}`;
}
