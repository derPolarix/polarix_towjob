<template>
	<div style="height:100%;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:12px">
		<p style="margin:0;font-size:12px;color:#6b7280;background:#fff;border:1px solid #dfe2e6;border-radius:11px;padding:12px 14px">
			Runtime-editable tunables. Changes apply immediately — no resource restart needed. Blank/default values fall back to <code>config/server.lua</code>.
		</p>

		<div
			v-for="setting in adminStore.settings"
			:key="setting.key"
			style="display:flex;align-items:center;justify-content:space-between;gap:16px;background:#fff;border:1px solid #dfe2e6;border-radius:12px;padding:13px 16px"
		>
			<div style="min-width:0">
				<div style="font-size:13px;font-weight:700;color:#1b1f24">{{ setting.label }}</div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#9aa1ab;margin-top:2px">key: {{ setting.key }} · default: {{ setting.default }}</div>
			</div>

			<div style="display:flex;align-items:center;gap:8px;flex-shrink:0">
				<input
					v-model.number="drafts[setting.key]"
					type="number"
					step="any"
					style="width:110px;text-align:right;font-family:'IBM Plex Mono',monospace;font-size:13px;color:#1b1f24;background:#f6f7f8;border:1px solid #e4e6e9;border-radius:9px;padding:8px 10px;outline:none"
				/>
				<button type="button" class="accent-btn" style="padding:8px 14px;font-size:12px" :disabled="saving === setting.key" @click="save(setting)">
					{{ saving === setting.key ? "Saving…" : "Save" }}
				</button>
			</div>
		</div>

		<p v-if="errorMessage" style="margin:0;font-size:12px;color:#d24b3a">{{ errorMessage }}</p>
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
