<template>
	<div
		v-if="confirmStore.options"
		class="fixed inset-0 bg-[rgba(15,17,21,0.55)] flex items-center justify-center z-[9999] font-ui"
		@click.self="confirmStore.answer(false)"
	>
		<div class="bg-white rounded-[16px] py-[26px] px-[28px] max-w-[420px] w-[90%] [box-shadow:0_20px_60px_rgba(0,0,0,0.25)]">
			<div
				class="w-[52px] h-[52px] rounded-[14px] flex items-center justify-center mb-[16px]"
				:style="{ background: danger ? 'rgba(239,68,68,0.12)' : 'rgba(34,197,94,0.14)' }"
			>
				<iconify-icon :icon="danger ? 'tabler:alert-triangle' : 'tabler:help-circle'" width="26" :style="{ color: danger ? 'var(--danger)' : 'var(--accent)' }"></iconify-icon>
			</div>
			<div class="text-[17px] font-extrabold text-ink">{{ confirmStore.options.title }}</div>
			<div class="text-[13px] text-muted mt-[8px] leading-[1.6]">{{ confirmStore.options.body }}</div>
			<div class="flex gap-[10px] mt-[20px]">
				<button
					type="button"
					:class="{ 'accent-btn': !danger }"
					:style="danger
						? 'flex:1;background:var(--danger);color:#fff;border:none;border-radius:11px;padding:12px;font-family:inherit;font-weight:700;font-size:13px;cursor:pointer'
						: 'flex:1;padding:12px;font-size:13px;justify-content:center'"
					@click="confirmStore.answer(true)"
				>
					{{ confirmStore.options.confirmLabel }}
				</button>
				<button
					type="button"
					class="flex-1 bg-white text-muted border border-line-soft rounded-[11px] p-[12px] font-[inherit] font-semibold text-[13px] cursor-pointer"
					@click="confirmStore.answer(false)"
				>
					{{ t("app.cancel") }}
				</button>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useConfirmStore } from "@/stores/confirmStore";

const { t } = useI18n();
const confirmStore = useConfirmStore();
const danger = computed(() => confirmStore.options?.danger ?? false);
</script>
