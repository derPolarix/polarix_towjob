<template>
	<div class="h-full flex">
		<aside class="w-[230px] shrink-0 border-r border-r-line overflow-y-auto p-[12px] flex flex-col gap-[6px] bg-surface-subtle">
			<button type="button" class="accent-btn w-full p-[10px] text-[12px] justify-center mb-[4px]" @click="startNew">
				<iconify-icon icon="tabler:plus" width="15"></iconify-icon> {{ t("admin.new_area") }}
			</button>

			<template v-if="adminStore.areas.length">
				<button
					v-for="area in adminStore.areas"
					:key="area.id"
					type="button"
					class="w-full text-left rounded-[10px] py-[10px] px-[12px] border border-transparent cursor-pointer font-[inherit]"
					:style="editingId === area.id ? 'background:var(--sidebar);border-color:var(--sidebar)' : 'background:#fff;border-color:var(--border)'"
					@click="selectArea(area)"
				>
					<div class="text-[13px] font-semibold whitespace-nowrap overflow-hidden text-ellipsis" :style="{ color: editingId === area.id ? '#fff' : 'var(--ink)' }">{{ area.name }}</div>
					<div class="font-mono text-[9px] mt-[3px] text-faint">{{ area.is_active ? t("admin.active") : t("admin.inactive") }}{{ area.is_default ? " · " + t("admin.default") : "" }}</div>
				</button>
			</template>

			<div v-else class="flex-1 flex flex-col items-center justify-center gap-[10px] py-[16px] px-[8px] text-center">
				<iconify-icon icon="tabler:package-import" width="26" class="text-faint"></iconify-icon>
				<p class="m-0 text-[11px] leading-[1.5] text-muted">{{ t("admin.no_areas_hint") }}</p>
				<button type="button" class="accent-btn py-[9px] px-[12px] text-[11px] justify-center" :disabled="importing" :style="{ opacity: importing ? 0.4 : 1 }" @click="importSeed">
					{{ importing ? t("admin.importing") : t("admin.import_seed_missions") }}
				</button>
			</div>
		</aside>

		<div class="flex-1 overflow-y-auto p-[20px] flex flex-col gap-[14px]">
			<p v-if="errorMessage" class="m-0 text-[12px] text-danger-text">{{ errorMessage }}</p>

			<div class="bg-white border border-line rounded-[14px] p-[18px] grid grid-cols-[1fr_1fr] gap-[14px]">
				<label class="admin-label col-span-2">
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

				<label class="admin-label col-span-2">
					{{ t("admin.field_note") }}
					<input v-model="form.note" type="text" maxlength="140" class="admin-input" />
				</label>

				<label class="flex items-center gap-[8px] text-[13px] font-medium text-ink-soft mt-[18px]">
					<input v-model="form.is_default" type="checkbox" />
					{{ t("admin.field_default_area") }}
				</label>
			</div>

			<div class="bg-white border border-line rounded-[14px] p-[16px] flex flex-col gap-[10px]">
				<div class="flex items-center justify-between gap-[12px] flex-wrap">
					<div class="text-[13px] font-bold text-ink">
						{{ t("admin.area_shape_hint", { count: form.points.length }) }}
					</div>
					<div class="flex gap-[6px]">
						<button type="button" class="rounded-[8px] bg-white border border-line text-ink-soft font-[inherit] font-semibold text-[12px] py-[6px] px-[10px] cursor-pointer" :disabled="form.points.length === 0" @click="undoPoint">
							{{ t("admin.undo_point") }}
						</button>
						<button type="button" class="rounded-[8px] bg-white border border-line text-ink-soft font-[inherit] font-semibold text-[12px] py-[6px] px-[10px] cursor-pointer" :disabled="form.points.length === 0" @click="clearPoints">
							{{ t("admin.clear") }}
						</button>
					</div>
				</div>
				<div ref="mapContainer" class="w-full h-[260px] rounded-[11px] overflow-hidden border border-line" />
			</div>

			<div class="flex flex-wrap items-center gap-[8px]">
				<button type="button" class="accent-btn py-[10px] px-[18px] text-[13px]" :disabled="saving" @click="save">
					{{ saving ? t("common.saving") : editingId ? t("admin.save_changes") : t("admin.create_area") }}
				</button>

				<button
					v-if="editingId"
					type="button"
					class="rounded-[10px] bg-white border border-line text-ink-soft font-[inherit] font-semibold text-[13px] py-[10px] px-[16px] cursor-pointer"
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

// Points are stored as GTA world coords; map clicks convert back via latLngToGta (@/lib/gtaMap).
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

// The server refuses the seed import unless both tables are empty, the only state this button renders in.
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

		// Flex height settles after mount; without a recalc Leaflet's click mapping and vertex hitboxes are offset.
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
