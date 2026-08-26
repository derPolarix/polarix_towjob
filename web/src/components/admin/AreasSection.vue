<template>
	<div style="height:100%;display:flex">
		<aside style="width:230px;flex-shrink:0;border-right:1px solid #dfe2e6;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:6px;background:#f6f7f8">
			<button type="button" class="accent-btn" style="width:100%;padding:10px;font-size:12px;justify-content:center;margin-bottom:4px" @click="startNew">
				<iconify-icon icon="tabler:plus" width="15"></iconify-icon> New area
			</button>

			<button
				v-for="area in adminStore.areas"
				:key="area.id"
				type="button"
				style="width:100%;text-align:left;border-radius:10px;padding:10px 12px;border:1px solid transparent;cursor:pointer;font-family:inherit"
				:style="editingId === area.id ? 'background:#22262d;border-color:#22262d' : 'background:#fff;border-color:#dfe2e6'"
				@click="selectArea(area)"
			>
				<div style="font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" :style="{ color: editingId === area.id ? '#fff' : '#1b1f24' }">{{ area.name }}</div>
				<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;margin-top:3px;color:#9aa1ab">{{ area.is_active ? "active" : "inactive" }}{{ area.is_default ? " · default" : "" }}</div>
			</button>
		</aside>

		<div style="flex:1;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:14px">
			<p v-if="errorMessage" style="margin:0;font-size:12px;color:#d24b3a">{{ errorMessage }}</p>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:18px;display:grid;grid-template-columns:1fr 1fr;gap:14px">
				<label style="grid-column:span 2" class="admin-label">
					Name
					<input v-model="form.name" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					Region
					<input v-model="form.region" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					Level required
					<input v-model.number="form.level_required" type="number" min="1" class="admin-input" />
				</label>

				<label class="admin-label">
					Unlock cost
					<input v-model.number="form.unlock_cost" type="number" min="0" class="admin-input" />
				</label>

				<label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:500;color:#3c424b;margin-top:18px">
					<input v-model="form.is_default" type="checkbox" />
					Default area (free, pre-unlocked for everyone)
				</label>
			</div>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px">
				<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap">
					<div style="font-size:13px;font-weight:700;color:#1b1f24">
						Area shape — click the map to add vertices ({{ form.points.length }} point{{ form.points.length === 1 ? "" : "s" }}, min 3)
					</div>
					<div style="display:flex;gap:6px">
						<button type="button" style="border-radius:8px;background:#fff;border:1px solid #dfe2e6;color:#3c424b;font-family:inherit;font-weight:600;font-size:12px;padding:6px 10px;cursor:pointer" :disabled="form.points.length === 0" @click="undoPoint">
							Undo point
						</button>
						<button type="button" style="border-radius:8px;background:#fff;border:1px solid #dfe2e6;color:#3c424b;font-family:inherit;font-weight:600;font-size:12px;padding:6px 10px;cursor:pointer" :disabled="form.points.length === 0" @click="clearPoints">
							Clear
						</button>
					</div>
				</div>
				<div ref="mapContainer" style="width:100%;height:260px;border-radius:11px;overflow:hidden;border:1px solid #dfe2e6" />
			</div>

			<div style="display:flex;flex-wrap:wrap;align-items:center;gap:8px">
				<button type="button" class="accent-btn" style="padding:10px 18px;font-size:13px" :disabled="saving" @click="save">
					{{ saving ? "Saving…" : editingId ? "Save changes" : "Create area" }}
				</button>

				<button
					v-if="editingId"
					type="button"
					style="border-radius:10px;background:#fff;border:1px solid #dfe2e6;color:#3c424b;font-family:inherit;font-weight:600;font-size:13px;padding:10px 16px;cursor:pointer"
					:disabled="togglingActive"
					:style="{ opacity: togglingActive ? 0.5 : 1 }"
					@click="toggleActive"
				>
					{{ selectedIsActive ? "Deactivate" : "Activate" }}
				</button>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, reactive, ref } from "vue";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import gtaMapUrl from "@/assets/maps/gta_map.jpg";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminArea } from "@/types/admin";

// Same CRS.Simple/gta_map.jpg setup as ../components/dashboard/tabs/AreasTab.vue (Phase 6) —
// duplicated rather than shared, since AreasTab.vue is tightly coupled to the player-facing
// unlock flow (its own store/panel logic) and this component additionally needs
// click-to-add-vertex polygon drawing, which AreasTab.vue intentionally doesn't have. Same
// asset, same IMG_WIDTH/IMG_HEIGHT, same points = Leaflet coord-space convention either way.
const IMG_WIDTH = 4096;
const IMG_HEIGHT = 6144;

const adminStore = useAdminStore();

const mapContainer = ref<HTMLDivElement>();
let map: L.Map | null = null;
let areaPolygon: L.Polygon | L.Polyline | null = null;
let vertexLayer: L.LayerGroup | null = null;

const editingId = ref<string | null>(null);
const selectedIsActive = ref(true);
const saving = ref(false);
const togglingActive = ref(false);
const errorMessage = ref("");

const form = reactive({
	name: "",
	region: "",
	points: [] as { x: number; y: number }[],
	unlock_cost: 0,
	level_required: 1,
	is_default: false,
});

function renderShape() {
	if (!map || !vertexLayer) return;

	vertexLayer.clearLayers();
	if (areaPolygon) {
		map.removeLayer(areaPolygon);
		areaPolygon = null;
	}

	if (form.points.length === 0) return;

	const latlngs: L.LatLngExpression[] = form.points.map((point) => [point.y, point.x]);

	areaPolygon =
		form.points.length >= 3
			? L.polygon(latlngs, { color: "#22c55e", weight: 2, fillColor: "#22c55e", fillOpacity: 0.2 }).addTo(map)
			: L.polyline(latlngs, { color: "#22c55e", weight: 2, dashArray: "4 4" }).addTo(map);

	for (const latlng of latlngs) {
		L.circleMarker(latlng, { radius: 5, color: "#22c55e", weight: 2, fillColor: "#fff", fillOpacity: 1 }).addTo(vertexLayer);
	}
}

function addPoint(x: number, y: number) {
	form.points.push({ x, y });
	renderShape();
}

function undoPoint() {
	form.points.pop();
	renderShape();
}

function clearPoints() {
	form.points = [];
	renderShape();
}

function startNew() {
	editingId.value = null;
	selectedIsActive.value = true;
	errorMessage.value = "";
	form.name = "";
	form.region = "";
	form.unlock_cost = 0;
	form.level_required = 1;
	form.is_default = false;
	form.points = [];
	renderShape();
}

function selectArea(area: AdminArea) {
	editingId.value = area.id;
	selectedIsActive.value = area.is_active;
	errorMessage.value = "";
	form.name = area.name;
	form.region = area.region;
	form.unlock_cost = area.unlock_cost;
	form.level_required = area.level_required;
	form.is_default = area.is_default;
	form.points = area.points.map((point) => ({ x: point.x, y: point.y }));
	renderShape();
	if (map && form.points.length > 0) {
		const bounds: L.LatLngTuple[] = form.points.map((point) => [point.y, point.x]);
		map.fitBounds(bounds, { maxZoom: 0, padding: [20, 20] });
	}
}

async function save() {
	if (!form.name.trim()) {
		errorMessage.value = "Name is required.";
		return;
	}

	if (form.points.length < 3) {
		errorMessage.value = "Area needs at least 3 points.";
		return;
	}

	saving.value = true;
	errorMessage.value = "";

	try {
		const payload = {
			name: form.name,
			region: form.region,
			points: form.points,
			unlock_cost: form.unlock_cost,
			level_required: form.level_required,
			is_default: form.is_default,
		};

		const result = editingId.value
			? await nuiCallbackAsync<AdminActionResult>("adminUpdateArea", { areaId: editingId.value, area: payload })
			: await nuiCallbackAsync<AdminActionResult>("adminCreateArea", payload);

		if (result?.ok) {
			await adminStore.fetchAreas();
			if (result.areaId) {
				const created = adminStore.areas.find((a) => a.id === result.areaId);
				if (created) selectArea(created);
			}
		} else {
			errorMessage.value = result?.reason ?? "Failed to save area.";
		}
	} catch (error) {
		console.error("adminCreateArea/adminUpdateArea failed:", error);
		errorMessage.value = "Failed to save area.";
	} finally {
		saving.value = false;
	}
}

async function toggleActive() {
	if (!editingId.value) return;

	togglingActive.value = true;
	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminSetAreaActive", {
			areaId: editingId.value,
			isActive: !selectedIsActive.value,
		});
		if (result?.ok) {
			selectedIsActive.value = !selectedIsActive.value;
			await adminStore.fetchAreas();
		} else {
			errorMessage.value = result?.reason ?? "Failed to update area.";
		}
	} catch (error) {
		console.error("adminSetAreaActive failed:", error);
		errorMessage.value = "Failed to update area.";
	} finally {
		togglingActive.value = false;
	}
}

onMounted(() => {
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

		map.fitBounds([
			[0, 0],
			[IMG_HEIGHT, IMG_WIDTH],
		]);

		vertexLayer = L.layerGroup().addTo(map);

		map.on("click", (event: L.LeafletMouseEvent) => {
			addPoint(event.latlng.lng, event.latlng.lat);
		});
	}

	startNew();
});

onBeforeUnmount(() => {
	if (map) {
		map.remove();
		map = null;
		areaPolygon = null;
		vertexLayer = null;
	}
});
</script>
