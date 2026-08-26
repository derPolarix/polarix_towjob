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
				<div style="font-size:13px;font-weight:700;color:#1b1f24">
					Map pin — click the map to set this area's position ({{ form.map_x.toFixed(1) }}, {{ form.map_y.toFixed(1) }})
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

// Same CRS.Simple/gta_map.jpg setup as ../components/dashboard/tabs/MapTab.vue (Phase 6) —
// duplicated rather than shared, since MapTab.vue is tightly coupled to the player-facing
// unlock flow (its own store/panel logic) and this component additionally needs
// click-to-place-pin, which MapTab.vue intentionally doesn't have. Same asset, same
// IMG_WIDTH/IMG_HEIGHT, same map_x/map_y = Leaflet coord-space convention either way.
const IMG_WIDTH = 4096;
const IMG_HEIGHT = 6144;

const adminStore = useAdminStore();

const mapContainer = ref<HTMLDivElement>();
let map: L.Map | null = null;
let pinMarker: L.Marker | null = null;

const editingId = ref<string | null>(null);
const selectedIsActive = ref(true);
const saving = ref(false);
const togglingActive = ref(false);
const errorMessage = ref("");

const form = reactive({
	name: "",
	region: "",
	map_x: 0,
	map_y: 0,
	unlock_cost: 0,
	level_required: 1,
	is_default: false,
});

function placePin(x: number, y: number) {
	form.map_x = x;
	form.map_y = y;
	if (!map) return;

	const latlng: L.LatLngExpression = [y, x];
	if (pinMarker) {
		pinMarker.setLatLng(latlng);
	} else {
		pinMarker = L.marker(latlng).addTo(map);
	}
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
	placePin(IMG_WIDTH / 2, IMG_HEIGHT / 2);
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
	placePin(area.map_x, area.map_y);
}

async function save() {
	if (!form.name.trim()) {
		errorMessage.value = "Name is required.";
		return;
	}

	saving.value = true;
	errorMessage.value = "";

	try {
		const payload = {
			name: form.name,
			region: form.region,
			map_x: form.map_x,
			map_y: form.map_y,
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

		map.on("click", (event: L.LeafletMouseEvent) => {
			placePin(event.latlng.lng, event.latlng.lat);
		});
	}

	startNew();
});

onBeforeUnmount(() => {
	if (map) {
		map.remove();
		map = null;
		pinMarker = null;
	}
});
</script>
