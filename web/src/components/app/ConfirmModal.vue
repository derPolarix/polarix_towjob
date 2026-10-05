<template>
	<div
		v-if="confirmStore.options"
		style="position:fixed;inset:0;background:rgba(15,17,21,0.55);display:flex;align-items:center;justify-content:center;z-index:9999;font-family:var(--font-sans)"
		@click.self="confirmStore.answer(false)"
	>
		<div style="background:#fff;border-radius:16px;padding:26px 28px;max-width:420px;width:90%;box-shadow:0 20px 60px rgba(0,0,0,0.25)">
			<div
				style="width:52px;height:52px;border-radius:14px;display:flex;align-items:center;justify-content:center;margin-bottom:16px"
				:style="{ background: danger ? 'rgba(239,68,68,0.12)' : 'rgba(34,197,94,0.14)' }"
			>
				<iconify-icon :icon="danger ? 'tabler:alert-triangle' : 'tabler:help-circle'" width="26" :style="{ color: danger ? '#dc2626' : '#22c55e' }"></iconify-icon>
			</div>
			<div style="font-size:17px;font-weight:800;color:var(--ink)">{{ confirmStore.options.title }}</div>
			<div style="font-size:13px;color:var(--muted);margin-top:8px;line-height:1.6">{{ confirmStore.options.body }}</div>
			<div style="display:flex;gap:10px;margin-top:20px">
				<button
					type="button"
					:class="{ 'accent-btn': !danger }"
					:style="danger
						? 'flex:1;background:#dc2626;color:#fff;border:none;border-radius:11px;padding:12px;font-family:inherit;font-weight:700;font-size:13px;cursor:pointer'
						: 'flex:1;padding:12px;font-size:13px;justify-content:center'"
					@click="confirmStore.answer(true)"
				>
					{{ confirmStore.options.confirmLabel }}
				</button>
				<button
					type="button"
					style="flex:1;background:#fff;color:var(--muted);border:1px solid var(--border-soft);border-radius:11px;padding:12px;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer"
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
