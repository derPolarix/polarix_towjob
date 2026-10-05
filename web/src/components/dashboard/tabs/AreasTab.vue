<template>
	<div style="display:flex;flex-direction:column;gap:14px;height:100%">
		<div style="display:flex;align-items:center;justify-content:space-between;gap:16px">
			<div>
				<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">{{ t("areas.title") }}</div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">{{ t("areas.subtitle") }}</div>
			</div>
			<div style="display:flex;align-items:center;gap:16px">
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:#6b7280"><span style="width:11px;height:11px;border-radius:50%;background:var(--accent)"></span>{{ t("areas.unlocked") }}</div>
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:#6b7280"><span style="width:11px;height:11px;border-radius:50%;background:#9aa1ab"></span>{{ t("areas.locked") }}</div>
			</div>
		</div>

		<div style="display:flex;flex:1;gap:14px;min-height:0">
			<aside style="width:40%;flex-shrink:0;border-radius:16px;border:1px solid #dfe2e6;background:#fff;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:6px">
				<button
					v-for="area in sortedAreas"
					:key="area.id"
					type="button"
					style="width:100%;text-align:left;border-radius:12px;padding:12px 14px;border:1px solid transparent;cursor:pointer;font-family:inherit;background:#f6f7f8"
					:style="selectedArea?.id === area.id ? 'background:rgba(34,197,94,0.1);border-color:var(--accent)' : ''"
					@click="selectAreaRow(area)"
				>
					<div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
						<span style="display:flex;align-items:center;gap:8px;font-size:14px;font-weight:700;color:#1b1f24">
							<span style="width:9px;height:9px;border-radius:50%;flex-shrink:0" :style="{ background: area.unlocked ? 'var(--accent)' : '#9aa1ab' }"></span>
							{{ area.name }}
						</span>
						<span v-if="area.unlocked" style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:var(--accent);font-weight:700">{{ t("areas.unlocked_badge") }}</span>
					</div>
					<div style="font-size:11px;color:#9aa1ab;margin-top:2px;margin-left:17px">{{ area.region }}</div>

					<div v-if="area.reward_multiplier !== 1 || area.xp_multiplier !== 1" style="display:flex;flex-wrap:wrap;gap:6px;margin-top:8px;margin-left:17px">
						<span v-if="area.reward_multiplier !== 1" style="display:inline-flex;align-items:center;gap:3px;font-family:'IBM Plex Mono',monospace;font-size:10px;font-weight:700;color:var(--accent);background:rgba(34,197,94,0.12);border-radius:6px;padding:2px 6px"><iconify-icon icon="tabler:coin" width="11"></iconify-icon>{{ t("areas.reward_mult", { mult: area.reward_multiplier }) }}</span>
						<span v-if="area.xp_multiplier !== 1" style="display:inline-flex;align-items:center;gap:3px;font-family:'IBM Plex Mono',monospace;font-size:10px;font-weight:700;color:#6b7280;background:#eef0f2;border-radius:6px;padding:2px 6px"><iconify-icon icon="tabler:bolt" width="11"></iconify-icon>{{ t("areas.xp_mult", { mult: area.xp_multiplier }) }}</span>
					</div>

					<div v-if="area.note" style="font-size:11px;color:#6b7280;font-style:italic;margin-top:6px;margin-left:17px">{{ area.note }}</div>

					<div v-if="!area.unlocked" style="display:flex;gap:14px;margin-top:8px;margin-left:17px;font-size:11px">
						<span style="color:#9aa1ab">{{ t("areas.cost") }} <strong style="color:#1b1f24">{{ formatMoney(area.unlock_cost) }}</strong></span>
						<span style="color:#9aa1ab">{{ t("areas.level") }} <strong style="color:#1b1f24">{{ area.level_required }}</strong></span>
					</div>
				</button>
			</aside>

			<div style="position:relative;flex:1;border-radius:16px;overflow:hidden;border:1px solid #dfe2e6">
				<div ref="mapContainer" style="width:100%;height:100%" />

				<div
					v-if="selectedArea"
					style="position:absolute;top:16px;right:16px;z-index:1100;width:280px;border-radius:14px;background:#fff;border:1px solid #dfe2e6;box-shadow:0 14px 34px rgba(0,0,0,0.18);padding:16px"
				>
					<div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
						<span style="font-size:15px;font-weight:700;color:#1b1f24">{{ selectedArea.name }}</span>
						<button type="button" style="background:transparent;border:none;cursor:pointer;color:#9aa1ab;font-size:16px;line-height:1;padding:0" @click="selectedArea = null">✕</button>
					</div>
					<div style="font-size:12px;color:#9aa1ab;margin-top:2px">{{ selectedArea.region }}</div>

					<div v-if="selectedArea.reward_multiplier !== 1 || selectedArea.xp_multiplier !== 1" style="display:flex;flex-wrap:wrap;gap:6px;margin-top:12px">
						<span v-if="selectedArea.reward_multiplier !== 1" style="display:inline-flex;align-items:center;gap:3px;font-family:'IBM Plex Mono',monospace;font-size:10px;font-weight:700;color:var(--accent);background:rgba(34,197,94,0.12);border-radius:6px;padding:2px 6px"><iconify-icon icon="tabler:coin" width="11"></iconify-icon>{{ t("areas.reward_mult", { mult: selectedArea.reward_multiplier }) }}</span>
						<span v-if="selectedArea.xp_multiplier !== 1" style="display:inline-flex;align-items:center;gap:3px;font-family:'IBM Plex Mono',monospace;font-size:10px;font-weight:700;color:#6b7280;background:#eef0f2;border-radius:6px;padding:2px 6px"><iconify-icon icon="tabler:bolt" width="11"></iconify-icon>{{ t("areas.xp_mult", { mult: selectedArea.xp_multiplier }) }}</span>
					</div>

					<div v-if="selectedArea.note" style="font-size:12px;color:#6b7280;font-style:italic;margin-top:10px">{{ selectedArea.note }}</div>

					<div v-if="selectedArea.unlocked" style="margin-top:14px;display:inline-flex;align-items:center;gap:7px;font-family:'IBM Plex Mono',monospace;font-size:11px;font-weight:700;color:var(--accent)">
						<span style="width:9px;height:9px;border-radius:50%;background:var(--accent)"></span>{{ t("areas.unlocked_badge") }}
					</div>

					<template v-else>
						<div style="margin-top:14px;display:flex;flex-direction:column;gap:8px;font-size:13px">
							<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">{{ t("areas.unlock_cost") }}</span><span style="color:var(--accent);font-weight:700">{{ formatMoney(selectedArea.unlock_cost) }}</span></div>
							<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">{{ t("areas.level_required") }}</span><span style="color:#1b1f24;font-weight:600">{{ t("common.level_short", { level: selectedArea.level_required }) }}</span></div>
						</div>

						<p v-if="unlockError" style="margin:10px 0 0;font-size:12px;color:#d24b3a">{{ unlockError }}</p>

						<button
							class="accent-btn"
							type="button"
							:disabled="unlocking"
							style="margin-top:14px;width:100%;padding:11px;font-size:13px;justify-content:center"
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

// Unlocked areas surface first (most relevant for active play), locked areas below
// sorted by level_required ascending (natural progression order).
const sortedAreas = computed(() => {
	return [...areas.value].sort((a, b) => {
		if (a.unlocked !== b.unlocked) return a.unlocked ? -1 : 1;
		return a.level_required - b.level_required;
	});
});

function areaLatLngs(area: MapArea): L.LatLngExpression[] {
	return area.points.map((point) => gtaToLatLng(point.x, point.y));
}

// Frame the map on the areas themselves rather than the whole state — polygons are small
// relative to the full image, so a full-image fit leaves them near-invisible.
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

// Shared by both the map polygon click and the list row click — always opens the info
// card; locked areas additionally get the unlock action inside it.
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

		// The flex container often reports its final height a frame or two after mount;
		// without this, Leaflet's vector pane desyncs from the image pane and polygon
		// hitboxes land offset from where they render.
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
