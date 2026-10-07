<template>
	<div class="h-full overflow-y-auto p-[20px] flex flex-col gap-[12px]">
		<p class="m-0 text-[12px] text-muted bg-white border border-line rounded-[11px] py-[12px] px-[14px]">
			{{ t("admin.settings_intro") }}
		</p>

		<div
			v-for="setting in adminStore.settings"
			:key="setting.key"
			class="flex items-center justify-between gap-[16px] bg-white border border-line rounded-[12px] py-[13px] px-[16px]"
		>
			<div class="min-w-0">
				<div class="text-[13px] font-bold text-ink">{{ setting.label }}</div>
				<div class="font-mono text-[10px] text-faint mt-[2px]">{{ t("admin.setting_key_default", { key: setting.key, default: setting.default }) }}</div>
			</div>

			<div class="flex items-center gap-[8px] shrink-0">
				<input
					v-model.number="drafts[setting.key]"
					type="number"
					step="any"
					class="w-[110px] text-right font-mono text-[13px] text-ink bg-surface-subtle border border-line-soft rounded-[9px] py-[8px] px-[10px] [outline:none]"
				/>
				<button type="button" class="accent-btn py-[8px] px-[14px] text-[12px]" :disabled="saving === setting.key" @click="save(setting)">
					{{ saving === setting.key ? t("common.saving") : t("common.save") }}
				</button>
			</div>
		</div>

		<p v-if="errorMessage" class="m-0 text-[12px] text-danger-text">{{ errorMessage }}</p>
	</div>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminSetting } from "@/types/admin";

const { t } = useI18n();
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
	not_admin: "admin.err_not_admin",
	invalid_key: "admin.err_invalid_key",
	invalid_value: "admin.err_invalid_value",
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
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_save_setting");
		}
	} catch (error) {
		console.error("adminSetSetting failed:", error);
		errorMessage.value = t("admin.err_save_setting");
	} finally {
		saving.value = "";
	}
}
</script>
