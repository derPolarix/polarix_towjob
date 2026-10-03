<template>
	<div style="height:100%;display:flex">
		<aside style="width:230px;flex-shrink:0;border-right:1px solid #dfe2e6;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:6px;background:#f6f7f8">
			<button type="button" class="accent-btn" style="width:100%;padding:10px;font-size:12px;justify-content:center;margin-bottom:4px" @click="startNew">
				<iconify-icon icon="tabler:plus" width="15"></iconify-icon> {{ t("admin.new_mission") }}
			</button>

			<template v-if="adminStore.missions.length">
				<button
					v-for="mission in adminStore.missions"
					:key="mission.id"
					type="button"
					style="width:100%;text-align:left;border-radius:10px;padding:10px 12px;border:1px solid transparent;cursor:pointer;font-family:inherit"
					:style="editingId === mission.id ? 'background:#22262d;border-color:#22262d' : 'background:#fff;border-color:#dfe2e6'"
					@click="selectMission(mission)"
				>
					<div style="font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" :style="{ color: editingId === mission.id ? '#fff' : '#1b1f24' }">{{ mission.name }}</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:9px;margin-top:3px" :style="{ color: editingId === mission.id ? '#9aa1ab' : '#9aa1ab' }">{{ mission.area_name ?? t("admin.no_area") }} · {{ mission.is_active ? t("admin.active") : t("admin.inactive") }}</div>
				</button>
			</template>

			<div v-else style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:16px 8px;text-align:center">
				<iconify-icon icon="tabler:package-import" width="26" style="color:#9aa1ab"></iconify-icon>
				<p style="margin:0;font-size:11px;line-height:1.5;color:#6b7280">{{ t("admin.no_missions_hint") }}</p>
				<button type="button" class="accent-btn" style="padding:9px 12px;font-size:11px;justify-content:center" :disabled="importing" :style="{ opacity: importing ? 0.4 : 1 }" @click="importSeed">
					{{ importing ? t("admin.importing") : t("admin.import_seed_missions") }}
				</button>
			</div>
		</aside>

		<div style="flex:1;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:16px">
			<p v-if="errorMessage" style="margin:0;font-size:12px;color:#d24b3a">{{ errorMessage }}</p>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:18px;display:grid;grid-template-columns:1fr 1fr;gap:14px">
				<label style="grid-column:span 2;display:flex;flex-direction:column;gap:6px;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.08em;text-transform:uppercase;color:#9aa1ab">
					{{ t("admin.field_name") }}
					<input v-model="form.name" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_area") }}
					<select v-model="form.area_id" class="admin-input">
						<option v-for="area in adminStore.areas" :key="area.id" :value="area.id">{{ area.name }}</option>
					</select>
				</label>

				<label class="admin-label">
					{{ t("admin.field_difficulty") }}
					<select v-model="form.difficulty" class="admin-input">
						<option value="easy">{{ t("admin.difficulty_easy") }}</option>
						<option value="medium">{{ t("admin.difficulty_medium") }}</option>
						<option value="hard">{{ t("admin.difficulty_hard") }}</option>
					</select>
				</label>

				<label class="admin-label">
					{{ t("admin.field_vehicle_model") }}
					<input v-model="form.vehicle_model" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_vehicle_label") }}
					<input v-model="form.vehicle_label" type="text" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_vehicle_color_primary") }}
					<input v-model.number="form.vehicle_colors.primary" type="number" min="0" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_vehicle_color_secondary") }}
					<input v-model.number="form.vehicle_colors.secondary" type="number" min="0" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_reward") }}
					<input v-model.number="form.reward_base" type="number" min="1" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_xp") }}
					<input v-model.number="form.xp_base" type="number" min="1" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_reward_per_km") }}
					<input v-model.number="form.reward_per_km" type="number" min="0" class="admin-input" :title="t('admin.payout_per_km_hint')" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_xp_per_km") }}
					<input v-model.number="form.xp_per_km" type="number" min="0" class="admin-input" :title="t('admin.payout_per_km_hint')" />
				</label>

				<div style="grid-column:span 2;font-size:11px;color:#6b7280">{{ payoutRangeText }}</div>

				<label class="admin-label">
					{{ t("admin.field_level_required") }}
					<input v-model.number="form.level_required" type="number" min="1" class="admin-input" />
				</label>

				<label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:500;color:#3c424b;margin-top:18px">
					<input type="checkbox" :checked="form.time_limit_minutes !== null" @change="toggleTimed" />
					{{ t("admin.field_timed_mission") }}
				</label>

				<label v-if="form.time_limit_minutes !== null" class="admin-label">
					{{ t("admin.field_time_limit") }}
					<input v-model.number="form.time_limit_minutes" type="number" min="1" class="admin-input" />
				</label>
			</div>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px">
				<div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
					<span style="font-size:13px;font-weight:700;color:#1b1f24">{{ t("admin.spawn_points_heading") }}</span>
					<button type="button" class="spawn-btn" :disabled="form.spawn_points.length >= MAX_SPAWN_POINTS" @click="addSpawnPoint">
						<iconify-icon icon="tabler:plus" width="13"></iconify-icon> {{ t("admin.spawn_point_add") }}
					</button>
				</div>

				<div style="font-size:11px;font-weight:600;color:#6b7280">{{ t("admin.spawn_points_count", { count: form.spawn_points.length }) }}</div>

				<div v-for="(point, index) in form.spawn_points" :key="index" style="display:flex;align-items:center;gap:8px">
					<div style="flex:1;font-size:11px;color:#3c424b;background:#f6f7f8;border:1px solid #eef0f2;border-radius:7px;padding:6px 9px">
						#{{ index + 1 }} — {{ point.x.toFixed(1) }}, {{ point.y.toFixed(1) }}, {{ point.z.toFixed(1) }} ({{ point.heading.toFixed(0) }}°)
					</div>
					<button type="button" class="spawn-icon-btn" :title="t('admin.spawn_point_capture')" @click="captureSpawnPoint(index)">
						<iconify-icon icon="tabler:crosshair" width="15"></iconify-icon>
					</button>
					<button type="button" class="spawn-btn" :title="t('admin.spawn_point_confirm_tooltip')" @click="confirmSpawnPoint(index)">
						{{ t("admin.spawn_point_confirm") }}
					</button>
					<button type="button" class="spawn-btn danger" :title="t('admin.spawn_point_remove')" @click="removeSpawnPoint(index)">✕</button>
				</div>

				<div style="font-size:11px;color:#9aa1ab">{{ t("admin.spawn_points_hint") }}</div>
			</div>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px">
				<div style="display:flex;align-items:center;justify-content:space-between">
					<span style="font-size:13px;font-weight:700;color:#1b1f24">{{ t("admin.dropoff_zone_heading") }}</span>
					<button type="button" style="font-size:11px;font-weight:600;border-radius:8px;background:#f1f2f4;border:1px solid #dfe2e6;color:#3c424b;padding:6px 10px;cursor:pointer" @click="useCurrentPosition()">
						{{ t("admin.use_current_position") }}
					</button>
				</div>
				<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px">
					<label class="admin-label">{{ t("admin.axis_x") }} <input v-model.number="form.dropoff_x" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_y") }} <input v-model.number="form.dropoff_y" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_z") }} <input v-model.number="form.dropoff_z" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_heading") }} <input v-model.number="form.dropoff_heading" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_width") }} <input v-model.number="form.dropoff_width" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_length") }} <input v-model.number="form.dropoff_length" type="number" step="any" class="admin-input" /></label>
				</div>
				<label style="display:flex;align-items:center;gap:8px;font-size:12px;color:#6b7280">
					<input v-model="dropoffPreviewOn" type="checkbox" @change="pushDropoffPreview" />
					{{ t("admin.dropoff_preview_toggle") }}
				</label>
			</div>

			<div style="display:flex;flex-wrap:wrap;align-items:center;gap:8px">
				<button type="button" class="accent-btn" style="padding:10px 18px;font-size:13px" :disabled="saving" @click="save">
					{{ saving ? t("common.saving") : editingId ? t("admin.save_changes") : t("admin.create_mission") }}
				</button>

				<template v-if="editingId">
					<button type="button" style="border-radius:10px;background:#fff;border:1px solid #dfe2e6;color:#3c424b;font-family:inherit;font-weight:600;font-size:13px;padding:10px 16px;cursor:pointer" :disabled="togglingActive" :style="{ opacity: togglingActive ? 0.5 : 1 }" @click="toggleActive">
						{{ selectedIsActive ? t("admin.deactivate") : t("admin.activate") }}
					</button>

					<button
						type="button"
						style="border-radius:10px;background:#fff;border:1px solid #f3c8c2;color:#dc2626;font-family:inherit;font-weight:600;font-size:13px;padding:10px 16px;cursor:pointer"
						:disabled="deleting || selectedDeliveryCount > 0"
						:title="selectedDeliveryCount > 0 ? t('admin.delete_blocked_history') : ''"
						:style="{ opacity: (deleting || selectedDeliveryCount > 0) ? 0.4 : 1 }"
						@click="remove"
					>
						{{ deleting ? t("admin.deleting") : t("admin.delete") }}
					</button>

					<button
						type="button"
						style="margin-left:auto;border-radius:10px;background:#3b82f6;border:none;color:#fff;font-family:inherit;font-weight:600;font-size:13px;padding:10px 16px;cursor:pointer"
						:disabled="testing || (!adminStore.testActive && !selectedIsActive)"
						:title="adminStore.testActive ? '' : (!selectedIsActive ? t('admin.test_needs_active') : t('admin.test_qa_hint'))"
						:style="{ opacity: (testing || (!adminStore.testActive && !selectedIsActive)) ? 0.4 : 1 }"
						@click="adminStore.testActive ? endTest() : testRun()"
					>
						{{ adminStore.testActive ? (testing ? t("admin.ending") : t("admin.end_test")) : (testing ? t("admin.starting") : t("admin.test_mission")) }}
					</button>
				</template>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance, reactive, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import { formatMoney } from "@/lib/uiConfig";
import type { AdminActionResult, AdminCurrentPosition, AdminMission, AdminSpawnPoint } from "@/types/admin";

// Mirrors config.server.lua's MaxSpawnPointsPerMission — the server re-validates it anyway.
const MAX_SPAWN_POINTS = 20;

const { t } = useI18n();
const proxy = getCurrentInstance()!.proxy!;
const persistantStore = proxy.$persistantStore;
const adminStore = useAdminStore();

const editingId = ref<string | null>(null);
const selectedIsActive = ref(true);
const selectedDeliveryCount = ref(0);
const saving = ref(false);
const togglingActive = ref(false);
const deleting = ref(false);
const testing = ref(false);
const errorMessage = ref("");
const importing = ref(false);
const dropoffPreviewOn = ref(false);

const form = reactive({
	name: "",
	area_id: "",
	vehicle_model: "",
	vehicle_label: "",
	vehicle_colors: { primary: 0, secondary: 0 },
	spawn_points: [] as AdminSpawnPoint[],
	dropoff_x: 0,
	dropoff_y: 0,
	dropoff_z: 0,
	dropoff_heading: 0,
	dropoff_width: 6,
	dropoff_length: 10,
	reward_base: 100,
	xp_base: 20,
	reward_per_km: 0,
	xp_per_km: 0,
	time_limit_minutes: null as number | null,
	difficulty: "easy" as "easy" | "medium" | "hard",
	level_required: 1,
});

// Same formula as the server's payoutRange (missions.lua): base + per-km * spawn->dropoff km.
const payoutRangeText = computed(() => {
	const bonus = (perKm: number, point: AdminSpawnPoint) => {
		const km = Math.hypot(point.x - form.dropoff_x, point.y - form.dropoff_y, point.z - form.dropoff_z) / 1000;
		return Math.floor((perKm || 0) * km + 0.5);
	};
	const rewards = form.spawn_points.map((p) => form.reward_base + bonus(form.reward_per_km, p));
	const xps = form.spawn_points.map((p) => form.xp_base + bonus(form.xp_per_km, p));
	if (!rewards.length) {
		rewards.push(form.reward_base);
		xps.push(form.xp_base);
	}
	const range = (values: number[], format: (n: number) => string) => {
		const lo = Math.min(...values);
		const hi = Math.max(...values);
		return lo === hi ? format(lo) : `${format(lo)}–${format(hi)}`;
	};
	return t("admin.payout_range", { reward: range(rewards, formatMoney), xp: range(xps, String) });
});

function toggleTimed(event: Event) {
	const checked = (event.target as HTMLInputElement).checked;
	form.time_limit_minutes = checked ? 10 : null;
}

function startNew() {
	editingId.value = null;
	selectedIsActive.value = true;
	selectedDeliveryCount.value = 0;
	errorMessage.value = "";
	Object.assign(form, {
		name: "",
		area_id: adminStore.areas[0]?.id ?? "",
		vehicle_model: "",
		vehicle_label: "",
		vehicle_colors: { primary: 0, secondary: 0 },
		spawn_points: [],
		dropoff_x: 0,
		dropoff_y: 0,
		dropoff_z: 0,
		dropoff_heading: 0,
		dropoff_width: 6,
		dropoff_length: 10,
		reward_base: 100,
		xp_base: 20,
		reward_per_km: 0,
		xp_per_km: 0,
		time_limit_minutes: null,
		difficulty: "easy",
		level_required: 1,
	});
	clearPreviews();
}

function selectMission(mission: AdminMission) {
	editingId.value = mission.id;
	selectedIsActive.value = mission.is_active;
	selectedDeliveryCount.value = mission.delivery_count;
	errorMessage.value = "";
	Object.assign(form, {
		name: mission.name,
		area_id: mission.area_id,
		vehicle_model: mission.vehicle_model,
		vehicle_label: mission.vehicle_label,
		vehicle_colors: { ...mission.vehicle_colors },
		spawn_points: mission.spawn_points.map((point) => ({ ...point })),
		dropoff_x: mission.dropoff_x,
		dropoff_y: mission.dropoff_y,
		dropoff_z: mission.dropoff_z,
		dropoff_heading: mission.dropoff_heading,
		dropoff_width: mission.dropoff_width,
		dropoff_length: mission.dropoff_length,
		reward_base: mission.reward_base,
		xp_base: mission.xp_base,
		reward_per_km: mission.reward_per_km ?? 0,
		xp_per_km: mission.xp_per_km ?? 0,
		time_limit_minutes: mission.time_limit_minutes,
		difficulty: mission.difficulty,
		level_required: mission.level_required,
	});
	clearPreviews();
}

async function useCurrentPosition() {
	try {
		const pos = await nuiCallbackAsync<AdminCurrentPosition>("adminGetCurrentPosition");
		if (!pos) return;

		form.dropoff_x = pos.x;
		form.dropoff_y = pos.y;
		form.dropoff_z = pos.z;
		form.dropoff_heading = pos.heading;
	} catch (error) {
		console.error("adminGetCurrentPosition failed:", error);
	}
}

// Each row previews as a ghost copy of the mission's own vehicle model at that coordinate,
// so the admin can see whether the car actually fits before saving.
function previewSpawnPoint(index: number) {
	const point = form.spawn_points[index];
	if (!point) return;

	nuiCallbackAsync("adminPreviewSpawnPoint", {
		index,
		model: form.vehicle_model,
		x: point.x,
		y: point.y,
		z: point.z,
		heading: point.heading,
	}).catch((error) => console.error("adminPreviewSpawnPoint failed:", error));
}

async function captureSpawnPoint(index: number) {
	try {
		const pos = await nuiCallbackAsync<AdminCurrentPosition>("adminGetCurrentPosition");
		if (!pos) return;

		form.spawn_points[index] = { x: pos.x, y: pos.y, z: pos.z, heading: pos.heading };
		previewSpawnPoint(index);
	} catch (error) {
		console.error("adminGetCurrentPosition failed:", error);
	}
}

function addSpawnPoint() {
	if (form.spawn_points.length >= MAX_SPAWN_POINTS) return;

	form.spawn_points.push({ x: 0, y: 0, z: 0, heading: 0 });
	captureSpawnPoint(form.spawn_points.length - 1);
}

function confirmSpawnPoint(index: number) {
	nuiCallbackAsync("adminConfirmSpawnPoint", { index }).catch((error) => console.error("adminConfirmSpawnPoint failed:", error));
}

function clearSpawnPointGhosts() {
	nuiCallbackAsync("adminClearSpawnPointGhosts", {}).catch((error) => console.error("adminClearSpawnPointGhosts failed:", error));
}

// Removing a row shifts every later index, so the ghosts are cleared wholesale rather than
// left pointing at coordinates that have moved under them.
function removeSpawnPoint(index: number) {
	form.spawn_points.splice(index, 1);
	clearSpawnPointGhosts();
}

function pushDropoffPreview() {
	nuiCallbackAsync("adminSetDropoffPreview", {
		active: dropoffPreviewOn.value,
		x: form.dropoff_x,
		y: form.dropoff_y,
		z: form.dropoff_z,
		heading: form.dropoff_heading,
		length: form.dropoff_length,
		width: form.dropoff_width,
	}).catch((error) => console.error("adminSetDropoffPreview failed:", error));
}

function clearPreviews() {
	clearSpawnPointGhosts();
	if (dropoffPreviewOn.value) {
		dropoffPreviewOn.value = false;
		pushDropoffPreview();
	}
}

const reasonMessages: Record<string, string> = {
	not_admin: "admin.err_not_admin",
	invalid_name: "admin.err_name_required",
	invalid_area: "admin.err_invalid_area",
	invalid_vehicle_model: "admin.err_invalid_vehicle_model",
	invalid_reward: "admin.err_invalid_reward",
	invalid_field: "admin.err_invalid_field",
	invalid_position: "admin.err_invalid_position_mission",
	no_spawn_points: "admin.err_no_spawn_points",
	too_many_spawn_points: "admin.err_too_many_spawn_points",
	invalid_spawn_point: "admin.err_invalid_spawn_point",
	not_found: "admin.err_mission_gone",
	not_empty: "admin.err_import_not_empty",
	has_delivery_history: "admin.err_has_delivery_history",
	active_delivery_exists: "admin.err_test_active_delivery",
};

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
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_import_seed");
		}
	} catch (error) {
		console.error("adminImportSeedData failed:", error);
		errorMessage.value = t("admin.err_import_seed");
	} finally {
		importing.value = false;
	}
}

async function save() {
	saving.value = true;
	errorMessage.value = "";

	try {
		const result = editingId.value
			? await nuiCallbackAsync<AdminActionResult>("adminUpdateMission", { missionId: editingId.value, mission: { ...form } })
			: await nuiCallbackAsync<AdminActionResult>("adminCreateMission", { ...form });

		if (result?.ok) {
			await adminStore.fetchMissions();
			if (result.missionId) {
				const created = adminStore.missions.find((m) => m.id === result.missionId);
				if (created) selectMission(created);
			}
		} else {
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_save_mission");
		}
	} catch (error) {
		console.error("adminCreateMission/adminUpdateMission failed:", error);
		errorMessage.value = t("admin.err_save_mission");
	} finally {
		saving.value = false;
	}
}

async function toggleActive() {
	if (!editingId.value) return;

	togglingActive.value = true;
	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminSetMissionActive", {
			missionId: editingId.value,
			isActive: !selectedIsActive.value,
		});
		if (result?.ok) {
			selectedIsActive.value = !selectedIsActive.value;
			await adminStore.fetchMissions();
		} else {
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_update_mission");
		}
	} catch (error) {
		console.error("adminSetMissionActive failed:", error);
		errorMessage.value = t("admin.err_update_mission");
	} finally {
		togglingActive.value = false;
	}
}

async function remove() {
	if (!editingId.value) return;

	deleting.value = true;
	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminDeleteMission", { missionId: editingId.value });
		if (result?.ok) {
			await adminStore.fetchMissions();
			startNew();
		} else {
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_delete_mission");
		}
	} catch (error) {
		console.error("adminDeleteMission failed:", error);
		errorMessage.value = t("admin.err_delete_mission");
	} finally {
		deleting.value = false;
	}
}

// Step 13.3's "clearly labeled as a test action": closes the Admin UI so the admin
// immediately sees the same find/attach/tow/deliver loop a normal player gets, same
// precedent trucker job's own admin editor established for its "Mission testen" button.
async function testRun() {
	if (!editingId.value) return;

	testing.value = true;
	errorMessage.value = "";
	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminTestRunMission", { missionId: editingId.value });
		if (result?.ok) {
			clearPreviews();
			await persistantStore.closeNui();
		} else {
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "admin.err_test_run");
		}
	} catch (error) {
		console.error("adminTestRunMission failed:", error);
		errorMessage.value = t("admin.err_test_run");
	} finally {
		testing.value = false;
	}
}

async function endTest() {
	testing.value = true;
	errorMessage.value = "";
	try {
		const result = await nuiCallbackAsync<AdminActionResult>("adminEndTestMission");
		if (result?.ok || result?.reason === "no_active_test") {
			adminStore.testActive = false;
		} else {
			errorMessage.value = t("admin.err_end_test");
		}
	} catch (error) {
		console.error("adminEndTestMission failed:", error);
		errorMessage.value = t("admin.err_end_test");
	} finally {
		testing.value = false;
	}
}

startNew();
</script>

<style scoped>
.spawn-btn {
	font-family: inherit;
	font-size: 11px;
	font-weight: 600;
	border-radius: 8px;
	background: #f1f2f4;
	border: 1px solid #dfe2e6;
	color: #3c424b;
	padding: 6px 10px;
	cursor: pointer;
	display: inline-flex;
	align-items: center;
	gap: 5px;
}
.spawn-btn:hover:not(:disabled) {
	background: #e8eaed;
}
.spawn-btn:disabled {
	opacity: 0.4;
	cursor: not-allowed;
}
.spawn-btn.danger {
	color: #dc2626;
	border-color: #f3c8c2;
}
.spawn-icon-btn {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 8px;
	background: #f1f2f4;
	border: 1px solid #dfe2e6;
	color: #3c424b;
	padding: 6px 8px;
	cursor: pointer;
}
.spawn-icon-btn:hover {
	background: #e8eaed;
}
</style>
