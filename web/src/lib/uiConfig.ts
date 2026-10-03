import { reactive } from "vue";

// Lua sends the resolved keybinds with every NUI message (client/nui/nui_messages.lua),
// so prompts always show the key the player actually has bound.
export const uiConfig = reactive({
	keybinds: {
		pagerAccept: "Enter",
		pagerDecline: "Backspace",
	},
});

const KEY_ICONS: Record<string, string> = {
	Enter: "tabler:corner-down-left",
	Backspace: "tabler:backspace",
};

export function keyIcon(key: string): string | undefined {
	return KEY_ICONS[key];
}

export function setUiConfig(data: { keybinds?: Partial<typeof uiConfig.keybinds> } | undefined) {
	if (data?.keybinds) {
		Object.assign(uiConfig.keybinds, data.keybinds);
	}
}
