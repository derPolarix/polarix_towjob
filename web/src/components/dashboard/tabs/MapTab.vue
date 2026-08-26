<template>
	<div style="display:flex;flex-direction:column;gap:14px;height:100%">
		<div style="display:flex;align-items:center;justify-content:space-between;gap:16px">
			<div>
				<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">Area map</div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">Click a pin to unlock a new operating area</div>
			</div>
			<div style="display:flex;align-items:center;gap:16px">
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:#6b7280"><span style="width:11px;height:11px;border-radius:50%;background:var(--accent)"></span>Unlocked</div>
				<div style="display:inline-flex;align-items:center;gap:7px;font-size:12px;color:#6b7280"><span style="width:11px;height:11px;border-radius:50%;background:#9aa1ab"></span>Locked</div>
			</div>
		</div>

		<div style="position:relative;flex:1;border-radius:16px;overflow:hidden;border:1px solid #dfe2e6">
			<div ref="mapContainer" style="width:100%;height:100%" />

			<div
				v-if="selectedArea"
				style="position:absolute;top:16px;right:16px;width:280px;border-radius:14px;background:#fff;border:1px solid #dfe2e6;box-shadow:0 14px 34px rgba(0,0,0,0.18);padding:16px"
			>
				<div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
					<span style="font-size:15px;font-weight:700;color:#1b1f24">{{ selectedArea.name }}</span>
					<button type="button" style="background:transparent;border:none;cursor:pointer;color:#9aa1ab;font-size:16px;line-height:1;padding:0" @click="selectedArea = null">✕</button>
				</div>
				<div style="font-size:12px;color:#9aa1ab;margin-top:2px">{{ selectedArea.region }}</div>

				<div style="margin-top:14px;display:flex;flex-direction:column;gap:8px;font-size:13px">
					<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Unlock cost</span><span style="color:var(--accent);font-weight:700">${{ selectedArea.unlock_cost }}</span></div>
					<div style="display:flex;justify-content:space-between"><span style="color:#9aa1ab">Level required</span><span style="color:#1b1f24;font-weight:600">Lvl {{ selectedArea.level_required }}</span></div>
				</div>

				<p v-if="unlockError" style="margin:10px 0 0;font-size:12px;color:#d24b3a">{{ unlockError }}</p>

				<button
					class="accent-btn"
					type="button"
					:disabled="unlocking"
					style="margin-top:14px;width:100%;padding:11px;font-size:13px;justify-content:center"
					@click="confirmUnlock"
				>
					{{ unlocking ? "Unlocking…" : "Unlock area" }}
				</button>
			</div>
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
		html: `<div class="area-marker-pin" style="background:${unlocked ? "#22c55e" : "#9aa1ab"};"></div>`,
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
