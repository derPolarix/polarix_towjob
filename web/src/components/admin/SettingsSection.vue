<template>
	<div class="h-full overflow-y-auto p-4 space-y-3">
		<p class="text-xs text-white/50">
			Runtime-editable tunables. Changes apply immediately — no resource restart needed.
			Blank/default values fall back to <code>config/server.lua</code>.
		</p>

		<div
			v-for="setting in adminStore.settings"
			:key="setting.key"
			class="flex items-center justify-between gap-4 rounded-md bg-neutral-800/60 border border-white/10 px-3 py-2"
		>
			<div class="min-w-0">
				<div class="text-sm font-medium">{{ setting.label }}</div>
				<div class="text-xs text-white/40">key: {{ setting.key }} · default: {{ setting.default }}</div>
			</div>

			<div class="flex items-center gap-2 shrink-0">
				<input
					v-model.number="drafts[setting.key]"
					type="number"
					step="any"
					class="w-28 rounded-md bg-neutral-900 border border-white/10 px-2 py-1 text-sm text-right focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/20"
				/>
				<button
					type="button"
					:disabled="saving === setting.key"
					class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium px-3 py-1.5"
					@click="save(setting)"
				>
					{{ saving === setting.key ? "Saving..." : "Save" }}
				</button>
			</div>
		</div>

		<p v-if="errorMessage" class="text-xs text-red-400">{{ errorMessage }}</p>
	</div>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from "vue";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminSetting } from "@/types/admin";

const adminStore = useAdminStore();

const drafts = reactive<Record<string, number>>({});
const saving = ref("");
const errorMessage = ref("");

watch(
	() => adminStore.settings,
	(settings) => {
		for (const setting of settings) {
			if (drafts[setting.key] === undefined) {
				drafts[setting.key] = setting.value;
			}
		}
	},
	{ immediate: true },
);

const reasonMessages: Record<string, string> = {
	not_admin: "You are not an admin.",
	invalid_key: "Unknown setting.",
	invalid_value: "That value is out of range for this setting.",
};

async function save(setting: AdminSetting) {
	errorMessage.value = "";
	saving.value = setting.key;

	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminSetSetting", {
			key: setting.key,
			value: drafts[setting.key],
		});

		if (result?.ok && result.settings) {
			adminStore.settings = result.settings;
		} else {
			errorMessage.value = reasonMessages[result?.reason ?? ""] ?? "Failed to save setting.";
		}
	} catch (error) {
		console.error("adminSetSetting failed:", error);
		errorMessage.value = "Failed to save setting.";
	} finally {
		saving.value = "";
	}
}
</script>
