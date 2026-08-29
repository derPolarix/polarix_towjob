<template>
	<div style="display:flex;flex-direction:column;gap:16px">
		<div>
			<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">{{ t("history.title") }}</div>
			<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">{{ t("history.runs_total", { count: total }) }}</div>
		</div>

		<div style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;overflow:hidden">
			<div style="display:grid;grid-template-columns:2.2fr 1fr 1fr 1.4fr;gap:12px;padding:11px 20px;background:#f6f7f8;border-bottom:1px solid #eef0f2;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">
				<span>{{ t("history.col_mission") }}</span><span>{{ t("history.col_status") }}</span><span>{{ t("history.col_reward") }}</span><span>{{ t("history.col_when") }}</span>
			</div>

			<div v-if="loading" style="padding:32px 20px;text-align:center;font-size:13px;color:#9aa1ab">{{ t("common.loading") }}</div>
			<div v-else-if="entries.length === 0" style="padding:32px 20px;text-align:center;font-size:13px;color:#9aa1ab">{{ t("common.no_deliveries_yet") }}</div>

			<div
				v-for="job in entries"
				:key="job.id"
				style="display:grid;grid-template-columns:2.2fr 1fr 1fr 1.4fr;gap:12px;padding:13px 20px;border-bottom:1px solid #f1f2f4;align-items:center"
			>
				<div style="display:flex;align-items:center;gap:10px;min-width:0">
					<div style="width:32px;height:32px;border-radius:9px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;flex-shrink:0">
						<iconify-icon :icon="statusIcon(job.status)" width="16" style="color:#6b7280"></iconify-icon>
					</div>
					<div style="min-width:0">
						<div style="font-size:13px;font-weight:600;color:#1b1f24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ job.missionName }}</div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;color:#9aa1ab">#DEL-{{ job.id }}</div>
					</div>
				</div>
				<span style="font-family:'IBM Plex Mono',monospace;font-size:10px;letter-spacing:0.06em;text-transform:uppercase" :style="{ color: statusColor(job.status) }">{{ t("status." + job.status) }}</span>
				<span style="font-size:13px;font-weight:700" :style="{ color: job.status === 'failed' ? '#d24b3a' : '#1b1f24' }">${{ job.rewardPaid }}</span>
				<span style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab">{{ formatDate(job.startedAt) }}</span>
			</div>
		</div>

		<div v-if="total > pageSize" style="display:flex;align-items:center;justify-content:space-between;font-size:13px;color:#6b7280">
			<button
				type="button"
				:disabled="offset === 0 || loading"
				style="border-radius:10px;border:1px solid #dfe2e6;background:#fff;padding:9px 16px;font-family:inherit;font-weight:600;cursor:pointer"
				:style="{ opacity: (offset === 0 || loading) ? 0.4 : 1, cursor: (offset === 0 || loading) ? 'not-allowed' : 'pointer' }"
				@click="goToPage(offset - pageSize)"
			>
				{{ t("common.previous") }}
			</button>
			<span style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab">{{ rangeLabel }}</span>
			<button
				type="button"
				:disabled="offset + pageSize >= total || loading"
				style="border-radius:10px;border:1px solid #dfe2e6;background:#fff;padding:9px 16px;font-family:inherit;font-weight:600;cursor:pointer"
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
