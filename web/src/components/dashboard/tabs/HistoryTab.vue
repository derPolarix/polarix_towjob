<template>
	<div class="flex flex-col gap-[16px]">
		<div>
			<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("history.title") }}</div>
			<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("history.runs_total", { count: total }) }}</div>
		</div>

		<div class="bg-white border border-line rounded-[15px] overflow-hidden">
			<div class="grid grid-cols-[2.2fr_1fr_1fr_1.4fr] gap-[12px] py-[11px] px-[20px] bg-surface-subtle border-b border-b-surface-sunken font-mono text-[9px] tracking-[0.08em] uppercase text-faint">
				<span>{{ t("history.col_mission") }}</span><span>{{ t("history.col_status") }}</span><span>{{ t("history.col_reward") }}</span><span>{{ t("history.col_when") }}</span>
			</div>

			<div v-if="loading" class="py-[32px] px-[20px] text-center text-[13px] text-faint">{{ t("common.loading") }}</div>
			<div v-else-if="entries.length === 0" class="py-[32px] px-[20px] text-center text-[13px] text-faint">{{ t("common.no_deliveries_yet") }}</div>

			<div
				v-for="job in entries"
				:key="job.id"
				class="grid grid-cols-[2.2fr_1fr_1fr_1.4fr] gap-[12px] py-[13px] px-[20px] border-b border-b-surface-muted items-center"
			>
				<div class="flex items-center gap-[10px] min-w-0">
					<div class="w-[32px] h-[32px] rounded-[9px] bg-[#f3f4f6] flex items-center justify-center shrink-0">
						<iconify-icon :icon="statusIcon(job.status)" width="16" class="text-muted"></iconify-icon>
					</div>
					<div class="min-w-0">
						<div class="text-[13px] font-semibold text-ink whitespace-nowrap overflow-hidden text-ellipsis">{{ job.missionName }}</div>
						<div class="font-mono text-[9px] text-faint">#DEL-{{ job.id }}</div>
					</div>
				</div>
				<span class="font-mono text-[10px] tracking-[0.06em] uppercase" :style="{ color: statusColor(job.status) }">{{ t("status." + job.status) }}</span>
				<span class="text-[13px] font-bold" :style="{ color: job.status === 'failed' ? '#d24b3a' : '#1b1f24' }">{{ formatMoney(job.rewardPaid) }}</span>
				<span class="font-mono text-[11px] text-faint">{{ formatDate(job.startedAt) }}</span>
			</div>
		</div>

		<div v-if="total > pageSize" class="flex items-center justify-between text-[13px] text-muted">
			<button
				type="button"
				:disabled="offset === 0 || loading"
				class="rounded-[10px] border border-line bg-white py-[9px] px-[16px] font-[inherit] font-semibold cursor-pointer"
				:style="{ opacity: (offset === 0 || loading) ? 0.4 : 1, cursor: (offset === 0 || loading) ? 'not-allowed' : 'pointer' }"
				@click="goToPage(offset - pageSize)"
			>
				{{ t("common.previous") }}
			</button>
			<span class="font-mono text-[11px] text-faint">{{ rangeLabel }}</span>
			<button
				type="button"
				:disabled="offset + pageSize >= total || loading"
				class="rounded-[10px] border border-line bg-white py-[9px] px-[16px] font-[inherit] font-semibold cursor-pointer"
				:style="{ opacity: (offset + pageSize >= total || loading) ? 0.4 : 1, cursor: (offset + pageSize >= total || loading) ? 'not-allowed' : 'pointer' }"
				@click="goToPage(offset + pageSize)"
			>
				{{ t("common.next") }}
			</button>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { formatMoney } from "@/lib/uiConfig";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { DeliveryHistoryEntry, DeliveryHistoryResult, DeliveryStatus } from "@/types/dashboard";

const { t } = useI18n();

const entries = ref<DeliveryHistoryEntry[]>([]);
const total = ref(0);
const offset = ref(0);
const pageSize = ref(20);
const loading = ref(true);

const statusColors: Record<DeliveryStatus, string> = {
	active: "#3b82f6",
	completed: "#22c55e",
	failed: "#d24b3a",
	aborted: "#9aa1ab",
};

const statusIcons: Record<DeliveryStatus, string> = {
	active: "tabler:road",
	completed: "tabler:circle-check",
	failed: "tabler:alert-triangle",
	aborted: "tabler:circle-x",
};

function statusColor(status: DeliveryStatus): string {
	return statusColors[status] ?? "#9aa1ab";
}

function statusIcon(status: DeliveryStatus): string {
	return statusIcons[status] ?? "tabler:circle-check";
}

function formatDate(value: string): string {
	const date = new Date(value);
	return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

const rangeLabel = computed(() => {
	if (total.value === 0) return "";
	const from = offset.value + 1;
	const to = Math.min(offset.value + entries.value.length, total.value);
	return t("history.range", { from, to, total: total.value });
});

async function fetchPage(nextOffset: number) {
	loading.value = true;

	try {
		const result = await nuiCallbackAsync<DeliveryHistoryResult>("getDeliveryHistory", { offset: nextOffset });
		if (result) {
			entries.value = Array.isArray(result.entries) ? result.entries : [];
			total.value = result.total ?? 0;
			offset.value = result.offset ?? nextOffset;
			pageSize.value = result.pageSize ?? pageSize.value;
		}
	} catch (error) {
		console.error("getDeliveryHistory failed:", error);
	} finally {
		loading.value = false;
	}
}

function goToPage(nextOffset: number) {
	fetchPage(Math.max(0, nextOffset));
}

onMounted(() => fetchPage(0));
</script>
