<template>
	<div class="relative w-full h-full">
		<div ref="mapContainer" class="w-full h-full rounded-md overflow-hidden" />

		<div
			v-if="selectedArea"
			class="absolute top-4 right-4 w-72 rounded-md bg-neutral-900/90 border border-white/10 p-4 text-white"
		>
			<div class="flex items-center justify-between">
				<h3 class="font-semibold">{{ selectedArea.name }}</h3>
				<button type="button" class="text-white/50 hover:text-white" @click="selectedArea = null">✕</button>
			</div>
			<div class="mt-1 text-xs text-white/60">{{ selectedArea.region }}</div>

			<div class="mt-3 text-sm space-y-1">
				<div>Unlock cost: <span class="text-emerald-400 font-semibold">${{ selectedArea.unlock_cost }}</span></div>
				<div>Level required: {{ selectedArea.level_required }}</div>
			</div>

			<p v-if="unlockError" class="mt-2 text-xs text-red-400">{{ unlockError }}</p>

			<button
				type="button"
				:disabled="unlocking"
				class="mt-3 w-full rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed px-3 py-2 text-sm font-medium"
				@click="confirmUnlock"
			>
				{{ unlocking ? "Unlocking..." : "Unlock area" }}
			</button>
		</div>
	</div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import gtaMapUrl from "@/assets/maps/gta_map.jpg";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { MapArea, UnlockAreaResult } from "@/types/dashboard";

const dashboardStore = useDashboardStore();

// Same gta_map.jpg asset + CRS.Simple setup as ../polarix_truckerjob's OrderRouteMap.vue.
// Unlike that component, `map_x`/`map_y` here are already stored in Leaflet coord-space
// (see polarix_towjob_areas schema comment) — no GTA-world-to-pixel conversion needed,
// the same pin position is reused verbatim on read as was captured on write (Phase 13).
const IMG_WIDTH = 4096;
const IMG_HEIGHT = 6144;

const mapContainer = ref<HTMLDivElement>();
let map: L.Map | null = null;
let pinLayer: L.LayerGroup | null = null;

const areas = ref<MapArea[]>(dashboardStore.payload?.areas ?? []);
const selectedArea = ref<MapArea | null>(null);
const unlocking = ref(false);
const unlockError = ref("");

const reasonMessages: Record<string, string> = {
	already_unlocked: "This area is already unlocked.",
	level_too_low: "You do not meet the level requirement for this area.",
	insufficient_funds: "You cannot afford this area's unlock cost.",
	area_not_found: "This area no longer exists.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
};

function areaLatLng(area: MapArea): L.LatLngExpression {
	return [area.map_y, area.map_x];
}

function pinIcon(unlocked: boolean): L.DivIcon {
	return L.divIcon({
		className: "area-marker",
		html: `<div class="area-marker-pin" style="background:${unlocked ? "#059669" : "#57534e"};"></div>`,
		iconSize: [20, 20],
		iconAnchor: [10, 10],
	});
}

function renderPins() {
	if (!map || !pinLayer) return;
	pinLayer.clearLayers();

	for (const area of areas.value) {
		const marker = L.marker(areaLatLng(area), { icon: pinIcon(area.unlocked) }).addTo(pinLayer);
		marker.bindTooltip(`${area.name} (${area.region})`, { direction: "top", offset: [0, -12] });
		marker.on("click", () => {
			unlockError.value = "";
			selectedArea.value = area.unlocked ? null : area;
		});
	}
}

async function confirmUnlock() {
	if (!selectedArea.value) return;

	unlocking.value = true;
	unlockError.value = "";

	try {
		const result = await nuiCallbackAsync<UnlockAreaResult>("unlockArea", { areaId: selectedArea.value.id });

		if (result?.ok) {
			const unlockedId = selectedArea.value.id;
			const area = areas.value.find((a) => a.id === unlockedId);
			if (area) area.unlocked = true;
			dashboardStore.addUnlockedArea(unlockedId);
			renderPins();
			selectedArea.value = null;
		} else {
			unlockError.value = reasonMessages[result?.reason ?? ""] ?? "Unlock failed.";
		}
	} catch (error) {
		console.error("unlockArea failed:", error);
		unlockError.value = "Unlock failed.";
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

		L.imageOverlay(gtaMapUrl, [
			[0, 0],
			[IMG_HEIGHT, IMG_WIDTH],
		]).addTo(map);

		pinLayer = L.layerGroup().addTo(map);
		map.fitBounds([
			[0, 0],
			[IMG_HEIGHT, IMG_WIDTH],
		]);

		renderPins();
	}

	try {
		const fresh = await nuiCallbackAsync<MapArea[]>("getMapAreas");
		if (Array.isArray(fresh)) {
			areas.value = fresh;
			renderPins();
		}
	} catch (error) {
		console.error("getMapAreas failed:", error);
	}
});

onBeforeUnmount(() => {
	if (map) {
		map.remove();
		map = null;
		pinLayer = null;
	}
});
</script>

<style>
.area-marker {
	background: transparent !important;
	border: none !important;
}

.area-marker-pin {
	width: 16px;
	height: 16px;
	border-radius: 50%;
	border: 2px solid rgba(255, 255, 255, 0.85);
	box-shadow: 0 2px 6px rgba(0, 0, 0, 0.35);
}

.leaflet-container {
	background: #1c1917 !important;
}
</style>
