<template>
	<div class="h-full flex">
		<aside class="w-56 shrink-0 border-r border-white/10 overflow-y-auto p-2 space-y-1">
			<button
				type="button"
				class="w-full text-left rounded-md bg-emerald-600 hover:bg-emerald-500 text-xs font-medium px-3 py-2 mb-2"
				@click="startNew"
			>
				+ New Area
			</button>

			<button
				v-for="area in adminStore.areas"
				:key="area.id"
				type="button"
				class="w-full text-left rounded-md px-3 py-2 text-sm transition-colors"
				:class="editingId === area.id ? 'bg-neutral-700' : 'bg-neutral-800/50 hover:bg-neutral-800'"
				@click="selectArea(area)"
			>
				<div class="font-medium truncate">{{ area.name }}</div>
				<div class="text-xs text-white/40">{{ area.is_active ? "active" : "inactive" }}{{ area.is_default ? " · default" : "" }}</div>
			</button>
		</aside>

		<div class="flex-1 overflow-y-auto p-4 space-y-3">
			<p v-if="errorMessage" class="text-xs text-red-400">{{ errorMessage }}</p>

			<div class="grid grid-cols-2 gap-3">
				<label class="text-xs text-white/60 col-span-2">
					Name
					<input v-model="form.name" type="text" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Region
					<input v-model="form.region" type="text" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Level required
					<input v-model.number="form.level_required" type="number" min="1" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Unlock cost
					<input v-model.number="form.unlock_cost" type="number" min="0" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60 flex items-center gap-2 mt-5">
					<input v-model="form.is_default" type="checkbox" />
					Default area (free, pre-unlocked for everyone)
				</label>
			</div>

			<div>
				<div class="text-xs text-white/60 mb-1">
					Map pin — click the map to set this area's position ({{ form.map_x.toFixed(1) }}, {{ form.map_y.toFixed(1) }})
				</div>
				<div ref="mapContainer" class="w-full h-64 rounded-md overflow-hidden border border-white/10" />
			</div>

			<div class="flex flex-wrap items-center gap-2 pt-2">
				<button
					type="button"
					:disabled="saving"
					class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
					@click="save"
				>
					{{ saving ? "Saving..." : editingId ? "Save changes" : "Create area" }}
				</button>

				<button
					v-if="editingId"
					type="button"
					:disabled="togglingActive"
					class="rounded-md bg-neutral-700 hover:bg-neutral-600 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
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
