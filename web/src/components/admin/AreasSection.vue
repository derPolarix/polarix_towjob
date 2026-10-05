<template>
	<div style="height:100%;display:flex">
		<aside style="width:230px;flex-shrink:0;border-right:1px solid var(--border);overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:6px;background:var(--surface-subtle)">
			<button type="button" class="accent-btn" style="width:100%;padding:10px;font-size:12px;justify-content:center;margin-bottom:4px" @click="startNew">
				<iconify-icon icon="tabler:plus" width="15"></iconify-icon> {{ t("admin.new_area") }}
			</button>

			<template v-if="adminStore.areas.length">
				<button
					v-for="area in adminStore.areas"
					:key="area.id"
					type="button"
					style="width:100%;text-align:left;border-radius:10px;padding:10px 12px;border:1px solid transparent;cursor:pointer;font-family:inherit"
					:style="editingId === area.id ? 'background:#22262d;border-color:#22262d' : 'background:#fff;border-color:#dfe2e6'"
					@click="selectArea(area)"
				>
					<div style="font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" :style="{ color: editingId === area.id ? '#fff' : '#1b1f24' }">{{ area.name }}</div>
					<div style="font-family:var(--font-mono);font-size:9px;margin-top:3px;color:var(--faint)">{{ area.is_active ? t("admin.active") : t("admin.inactive") }}{{ area.is_default ? " · " + t("admin.default") : "" }}</div>
				</button>
			</template>

			<div v-else style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:16px 8px;text-align:center">
				<iconify-icon icon="tabler:package-import" width="26" style="color:var(--faint)"></iconify-icon>
				<p style="margin:0;font-size:11px;line-height:1.5;color:var(--muted)">{{ t("admin.no_areas_hint") }}</p>
				<button type="button" class="accent-btn" style="padding:9px 12px;font-size:11px;justify-content:center" :disabled="importing" :style="{ opacity: importing ? 0.4 : 1 }" @click="importSeed">
					{{ importing ? t("admin.importing") : t("admin.import_seed_missions") }}
				</button>
			</div>
		</aside>

		<div style="flex:1;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:14px">
			<p v-if="errorMessage" style="margin:0;font-size:12px;color:var(--danger-text)">{{ errorMessage }}</p>

			<div style="background:#fff;border:1px solid var(--border);border-radius:14px;padding:18px;display:grid;grid-template-columns:1fr 1fr;gap:14px">
				<label style="grid-column:span 2" class="admin-label">
					{{ t("admin.field_name") }}
					<input v-model="form.name" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_region") }}
					<input v-model="form.region" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_level_required") }}
					<input v-model.number="form.level_required" type="number" min="1" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_unlock_cost") }}
					<input v-model.number="form.unlock_cost" type="number" min="0" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_reward_multiplier") }}
					<input v-model.number="form.reward_multiplier" type="number" min="0" max="10" step="0.1" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_xp_multiplier") }}
					<input v-model.number="form.xp_multiplier" type="number" min="0" max="10" step="0.1" class="admin-input" />
				</label>

				<label style="grid-column:span 2" class="admin-label">
					{{ t("admin.field_note") }}
					<input v-model="form.note" type="text" maxlength="140" class="admin-input" />
				</label>

				<label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:500;color:var(--ink-soft);margin-top:18px">
					<input v-model="form.is_default" type="checkbox" />
					{{ t("admin.field_default_area") }}
				</label>
			</div>

			<div style="background:#fff;border:1px solid var(--border);border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px">
				<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap">
					<div style="font-size:13px;font-weight:700;color:var(--ink)">
						{{ t("admin.area_shape_hint", { count: form.points.length }) }}
					</div>
					<div style="display:flex;gap:6px">
						<button type="button" style="border-radius:8px;background:#fff;border:1px solid var(--border);color:var(--ink-soft);font-family:inherit;font-weight:600;font-size:12px;padding:6px 10px;cursor:pointer" :disabled="form.points.length === 0" @click="undoPoint">
							{{ t("admin.undo_point") }}
						</button>
						<button type="button" style="border-radius:8px;background:#fff;border:1px solid var(--border);color:var(--ink-soft);font-family:inherit;font-weight:600;font-size:12px;padding:6px 10px;cursor:pointer" :disabled="form.points.length === 0" @click="clearPoints">
							{{ t("admin.clear") }}
						</button>
					</div>
				</div>
				<div ref="mapContainer" style="width:100%;height:260px;border-radius:11px;overflow:hidden;border:1px solid var(--border)" />
			</div>

			<div style="display:flex;flex-wrap:wrap;align-items:center;gap:8px">
				<button type="button" class="accent-btn" style="padding:10px 18px;font-size:13px" :disabled="saving" @click="save">
					{{ saving ? t("common.saving") : editingId ? t("admin.save_changes") : t("admin.create_area") }}
				</button>

				<button
					v-if="editingId"
					type="button"
					style="border-radius:10px;background:#fff;border:1px solid var(--border);color:var(--ink-soft);font-family:inherit;font-weight:600;font-size:13px;padding:10px 16px;cursor:pointer"
					:disabled="togglingActive"
					:style="{ opacity: togglingActive ? 0.5 : 1 }"
					@click="toggleActive"
				>
					{{ selectedIsActive ? t("admin.deactivate") : t("admin.activate") }}
				</button>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { useI18n } from "vue-i18n";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import gtaMapUrl from "@/assets/maps/gta_map.jpg";
import { gtaToLatLng, latLngToGta, MAP_IMAGE_BOUNDS } from "@/lib/gtaMap";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminArea } from "@/types/admin";

// Points are stored/sent as GTA world coords and converted to the Leaflet image via
// @/lib/gtaMap — map clicks here are captured the reverse way (latLngToGta).
const { t } = useI18n();
const adminStore = useAdminStore();

const mapContainer = ref<HTMLDivElement>();
let map: L.Map | null = null;
let areaPolygon: L.Polygon | L.Polyline | null = null;
let vertexLayer: L.LayerGroup | null = null;
let resizeObserver: ResizeObserver | null = null;

const areaReasonKeys: Record<string, string> = {
	invalid_name: "admin.err_name_required",
	invalid_position: "admin.err_invalid_position",
	invalid_multiplier: "admin.err_invalid_multiplier",
	name_taken: "admin.err_name_taken",
	not_found: "admin.err_area_gone",
	not_empty: "admin.err_import_not_empty",
};
function areaReasonKey(reason: string | undefined): string | undefined {
	return reason ? areaReasonKeys[reason] : undefined;
}

const editingId = ref<string | null>(null);
const selectedIsActive = ref(true);
const saving = ref(false);
const togglingActive = ref(false);
const errorMessage = ref("");
const importing = ref(false);

const form = reactive({
	name: "",
	region: "",
	points: [] as { x: number; y: number }[],
	unlock_cost: 0,
	level_required: 1,
	reward_multiplier: 1.0,
	xp_multiplier: 1.0,
	note: "",
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

	const latlngs: L.LatLngExpression[] = form.points.map((point) => gtaToLatLng(point.x, point.y));

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
	form.reward_multiplier = 1.0;
	form.xp_multiplier = 1.0;
	form.note = "";
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
	form.reward_multiplier = area.reward_multiplier;
	form.xp_multiplier = area.xp_multiplier;
	form.note = area.note ?? "";
	form.is_default = area.is_default;
	form.points = area.points.map((point) => ({ x: point.x, y: point.y }));
	renderShape();
	if (map && form.points.length > 0) {
		const bounds = form.points.map((point) => gtaToLatLng(point.x, point.y));
		map.fitBounds(bounds, { maxZoom: 0, padding: [20, 20] });
	}
}

// Seed content ships with the resource (server/seed_data.lua) and covers areas + missions in
// one go; the server refuses the import unless both tables are empty, which is also the only
// state this button renders in.
async function importSeed() {
	if (importing.value) return;
	importing.value = true;
	errorMessage.value = "";

	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminImportSeedData");
		if (result?.ok) {
			await adminStore.fetchAreas();
			await adminStore.fetchMissions();
		} else {
			errorMessage.value = t(areaReasonKey(result?.reason) ?? "admin.err_import_seed");
		}
	} catch (error) {
		console.error("adminImportSeedData failed:", error);
		errorMessage.value = t("admin.err_import_seed");
	} finally {
		importing.value = false;
	}
}

async function save() {
	if (!form.name.trim()) {
		errorMessage.value = t("admin.err_name_required");
		return;
	}

	if (form.points.length < 3) {
		errorMessage.value = t("admin.err_area_min_points");
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
			reward_multiplier: form.reward_multiplier,
			xp_multiplier: form.xp_multiplier,
			note: form.note.trim() || null,
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
			errorMessage.value = t(areaReasonKey(result?.reason) ?? "admin.err_save_area");
		}
	} catch (error) {
		console.error("adminCreateArea/adminUpdateArea failed:", error);
		errorMessage.value = t("admin.err_save_area");
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
			errorMessage.value = t(areaReasonKey(result?.reason) ?? "admin.err_update_area");
		}
	} catch (error) {
		console.error("adminSetAreaActive failed:", error);
		errorMessage.value = t("admin.err_update_area");
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

		L.imageOverlay(gtaMapUrl, MAP_IMAGE_BOUNDS).addTo(map);
		map.fitBounds(MAP_IMAGE_BOUNDS);

		vertexLayer = L.layerGroup().addTo(map);

		map.on("click", (event: L.LeafletMouseEvent) => {
			const gta = latLngToGta(event.latlng.lat, event.latlng.lng);
			addPoint(gta.x, gta.y);
		});

		// The panel's flex layout settles its height after mount; without recalculating,
		// Leaflet's click→latlng mapping and vertex hitboxes land offset.
		resizeObserver = new ResizeObserver(() => map?.invalidateSize());
		resizeObserver.observe(mapContainer.value);
	}

	startNew();
});

onBeforeUnmount(() => {
	resizeObserver?.disconnect();
	resizeObserver = null;
	if (map) {
		map.remove();
		map = null;
		areaPolygon = null;
		vertexLayer = null;
	}
});
</script>
