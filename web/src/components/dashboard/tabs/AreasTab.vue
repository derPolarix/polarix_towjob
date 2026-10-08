<template>
	<div class="flex flex-col gap-[14px] h-full">
		<div class="flex items-center justify-between gap-[16px]">
			<div>
				<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("areas.title") }}</div>
				<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("areas.subtitle") }}</div>
			</div>
			<div class="flex items-center gap-[16px]">
				<div class="inline-flex items-center gap-[7px] text-[12px] text-muted"><span class="w-[11px] h-[11px] rounded-[50%] bg-accent"></span>{{ t("areas.unlocked") }}</div>
				<div class="inline-flex items-center gap-[7px] text-[12px] text-muted"><span class="w-[11px] h-[11px] rounded-[50%] bg-faint"></span>{{ t("areas.locked") }}</div>
			</div>
		</div>

		<div class="flex flex-1 gap-[14px] min-h-0">
			<aside class="w-[40%] shrink-0 rounded-[16px] border border-line bg-white overflow-y-auto p-[12px] flex flex-col gap-[6px]">
				<button
					v-for="area in sortedAreas"
					:key="area.id"
					type="button"
					class="w-full text-left rounded-[12px] py-[12px] px-[14px] border border-transparent cursor-pointer font-[inherit] bg-surface-subtle"
					:style="selectedArea?.id === area.id ? 'background:rgba(34,197,94,0.1);border-color:var(--accent)' : ''"
					@click="selectAreaRow(area)"
				>
					<div class="flex items-center justify-between gap-[8px]">
						<span class="flex items-center gap-[8px] text-[14px] font-bold text-ink">
							<span class="w-[9px] h-[9px] rounded-[50%] shrink-0" :style="{ background: area.unlocked ? 'var(--accent)' : 'var(--faint)' }"></span>
							{{ area.name }}
						</span>
						<span v-if="area.unlocked" class="font-mono text-[10px] text-accent font-bold">{{ t("areas.unlocked_badge") }}</span>
					</div>
					<div class="text-[11px] text-faint mt-[2px] ml-[17px]">{{ area.region }}</div>

					<div v-if="area.reward_multiplier !== 1 || area.xp_multiplier !== 1" class="flex flex-wrap gap-[6px] mt-[8px] ml-[17px]">
						<span v-if="area.reward_multiplier !== 1" class="inline-flex items-center gap-[3px] font-mono text-[10px] font-bold text-accent bg-[rgba(34,197,94,0.12)] rounded-[6px] py-[2px] px-[6px]"><iconify-icon icon="tabler:coin" width="11"></iconify-icon>{{ t("areas.reward_mult", { mult: area.reward_multiplier }) }}</span>
						<span v-if="area.xp_multiplier !== 1" class="inline-flex items-center gap-[3px] font-mono text-[10px] font-bold text-muted bg-surface-sunken rounded-[6px] py-[2px] px-[6px]"><iconify-icon icon="tabler:bolt" width="11"></iconify-icon>{{ t("areas.xp_mult", { mult: area.xp_multiplier }) }}</span>
					</div>

					<div v-if="area.note" class="text-[11px] text-muted italic mt-[6px] ml-[17px]">{{ area.note }}</div>

					<div v-if="!area.unlocked" class="flex gap-[14px] mt-[8px] ml-[17px] text-[11px]">
						<span class="text-faint">{{ t("areas.cost") }} <strong class="text-ink">{{ formatMoney(area.unlock_cost) }}</strong></span>
						<span class="text-faint">{{ t("areas.level") }} <strong class="text-ink">{{ area.level_required }}</strong></span>
					</div>
				</button>
			</aside>

			<div class="relative flex-1 rounded-[16px] overflow-hidden border border-line">
				<div ref="mapContainer" class="w-full h-full" />

				<div
					v-if="selectedArea"
					class="absolute top-[16px] right-[16px] z-[1100] w-[280px] rounded-[14px] bg-white border border-line [box-shadow:0_14px_34px_rgba(0,0,0,0.18)] p-[16px]"
				>
					<div class="flex items-center justify-between gap-[8px]">
						<span class="text-[15px] font-bold text-ink">{{ selectedArea.name }}</span>
						<button type="button" class="bg-transparent border-none cursor-pointer text-faint text-[16px] leading-[1] p-0" @click="selectedArea = null">✕</button>
					</div>
					<div class="text-[12px] text-faint mt-[2px]">{{ selectedArea.region }}</div>

					<div v-if="selectedArea.reward_multiplier !== 1 || selectedArea.xp_multiplier !== 1" class="flex flex-wrap gap-[6px] mt-[12px]">
						<span v-if="selectedArea.reward_multiplier !== 1" class="inline-flex items-center gap-[3px] font-mono text-[10px] font-bold text-accent bg-[rgba(34,197,94,0.12)] rounded-[6px] py-[2px] px-[6px]"><iconify-icon icon="tabler:coin" width="11"></iconify-icon>{{ t("areas.reward_mult", { mult: selectedArea.reward_multiplier }) }}</span>
						<span v-if="selectedArea.xp_multiplier !== 1" class="inline-flex items-center gap-[3px] font-mono text-[10px] font-bold text-muted bg-surface-sunken rounded-[6px] py-[2px] px-[6px]"><iconify-icon icon="tabler:bolt" width="11"></iconify-icon>{{ t("areas.xp_mult", { mult: selectedArea.xp_multiplier }) }}</span>
					</div>

					<div v-if="selectedArea.note" class="text-[12px] text-muted italic mt-[10px]">{{ selectedArea.note }}</div>

					<div v-if="selectedArea.unlocked" class="mt-[14px] inline-flex items-center gap-[7px] font-mono text-[11px] font-bold text-accent">
						<span class="w-[9px] h-[9px] rounded-[50%] bg-accent"></span>{{ t("areas.unlocked_badge") }}
					</div>

					<template v-else>
						<div class="mt-[14px] flex flex-col gap-[8px] text-[13px]">
							<div class="flex justify-between"><span class="text-faint">{{ t("areas.unlock_cost") }}</span><span class="text-accent font-bold">{{ formatMoney(selectedArea.unlock_cost) }}</span></div>
							<div class="flex justify-between"><span class="text-faint">{{ t("areas.level_required") }}</span><span class="text-ink font-semibold">{{ t("common.level_short", { level: selectedArea.level_required }) }}</span></div>
						</div>

						<p v-if="unlockError" class="mt-[10px] mx-0 mb-0 text-[12px] text-danger-text">{{ unlockError }}</p>

						<button
							class="accent-btn mt-[14px] w-full p-[11px] text-[13px] justify-center"
							type="button"
							:disabled="unlocking"
							@click="confirmUnlock"
						>
							{{ unlocking ? t("areas.unlocking") : t("areas.unlock_area") }}
						</button>
					</template>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { formatMoney } from "@/lib/uiConfig";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import gtaMapUrl from "@/assets/maps/gta_map.jpg";
import { gtaToLatLng, MAP_IMAGE_BOUNDS } from "@/lib/gtaMap";
import { useDashboardStore } from "@/stores/dashboardStore";
import { useConfirmStore } from "@/stores/confirmStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { MapArea, UnlockAreaResult } from "@/types/dashboard";

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const confirmStore = useConfirmStore();

const mapContainer = ref<HTMLDivElement>();
let map: L.Map | null = null;
let areaLayer: L.LayerGroup | null = null;
let resizeObserver: ResizeObserver | null = null;

const areas = ref<MapArea[]>(dashboardStore.payload?.areas ?? []);
const selectedArea = ref<MapArea | null>(null);
const unlocking = ref(false);
const unlockError = ref("");

const reasonMessages: Record<string, string> = {
	already_unlocked: "error.area_already_unlocked",
	level_too_low: "error.area_level_too_low",
	insufficient_funds: "error.area_insufficient_funds",
	area_not_found: "error.area_gone",
	no_player: "error.no_player",
};

const sortedAreas = computed(() => {
	return [...areas.value].sort((a, b) => {
		if (a.unlocked !== b.unlocked) return a.unlocked ? -1 : 1;
		return a.level_required - b.level_required;
	});
});

function areaLatLngs(area: MapArea): L.LatLngExpression[] {
	return area.points.map((point) => gtaToLatLng(point.x, point.y));
}

// Frame the areas rather than the whole map; the polygons are small relative to the image.
function fitToAreas() {
	if (!map) return;
	const latlngs = areas.value
		.filter((area) => area.points.length >= 3)
		.flatMap((area) => areaLatLngs(area));
	if (latlngs.length > 0) {
		map.fitBounds(L.latLngBounds(latlngs as L.LatLngExpression[]), { padding: [48, 48], maxZoom: 0, animate: false });
	} else {
		map.fitBounds(MAP_IMAGE_BOUNDS, { animate: false });
	}
}

function selectAreaRow(area: MapArea) {
	unlockError.value = "";
	selectedArea.value = area;
}

function renderAreas() {
	if (!map || !areaLayer) return;
	areaLayer.clearLayers();

	for (const area of areas.value) {
		if (area.points.length < 3) continue;

		const color = area.unlocked ? "#22c55e" : "#9aa1ab";
		const polygon = L.polygon(areaLatLngs(area), {
			color,
			weight: 2,
			fillColor: color,
			fillOpacity: area.unlocked ? 0.25 : 0.15,
		}).addTo(areaLayer);
		polygon.bindTooltip(`${area.name} (${area.region})`, { direction: "center" });
		polygon.on("click", () => selectAreaRow(area));
	}
}

async function confirmUnlock() {
	if (!selectedArea.value) return;

	const confirmed = await confirmStore.ask({
		title: t("confirm.unlock_area_title"),
		body: t("confirm.unlock_area_body", { name: selectedArea.value.name, price: formatMoney(selectedArea.value.unlock_cost) }),
		confirmLabel: t("areas.unlock_area"),
	});
	if (!confirmed || !selectedArea.value) return;

	unlocking.value = true;
	unlockError.value = "";

	try {
		const result = await nuiCallbackAsync<UnlockAreaResult>("unlockArea", { areaId: selectedArea.value.id });

		if (result?.ok) {
			const unlockedId = selectedArea.value.id;
			const area = areas.value.find((a) => a.id === unlockedId);
			if (area) area.unlocked = true;
			dashboardStore.addUnlockedArea(unlockedId);
			renderAreas();
			selectedArea.value = area ?? null;
		} else {
			unlockError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.unlock_failed");
		}
	} catch (error) {
		console.error("unlockArea failed:", error);
		unlockError.value = t("error.unlock_failed");
	} finally {
		unlocking.value = false;
	}
}

onMounted(async () => {
	if (mapContainer.value) {
		map = L.map(mapContainer.value, {
			crs: L.CRS.Simple,
			minZoom: -3,
			maxZoom: 2,
			attributionControl: false,
		});

		L.imageOverlay(gtaMapUrl, MAP_IMAGE_BOUNDS).addTo(map);

		areaLayer = L.layerGroup().addTo(map);
		renderAreas();
		fitToAreas();

		// Flex height settles after mount; without a recalc the vector pane desyncs and polygon hitboxes are offset.
		resizeObserver = new ResizeObserver(() => {
			map?.invalidateSize();
			fitToAreas();
		});
		resizeObserver.observe(mapContainer.value);
	}

	try {
		const fresh = await nuiCallbackAsync<MapArea[]>("getMapAreas");
		if (Array.isArray(fresh)) {
			areas.value = fresh;
			renderAreas();
			fitToAreas();
		}
	} catch (error) {
		console.error("getMapAreas failed:", error);
	}
});

onBeforeUnmount(() => {
	resizeObserver?.disconnect();
	resizeObserver = null;
	if (map) {
		map.remove();
		map = null;
		areaLayer = null;
	}
});
</script>

<style>
.leaflet-container {
	background: #1c1917 !important;
}
</style>
