<template>
	<div style="height:100%;display:flex">
		<aside style="width:230px;flex-shrink:0;border-right:1px solid #dfe2e6;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:6px;background:#f6f7f8">
			<button type="button" class="accent-btn" style="width:100%;padding:10px;font-size:12px;justify-content:center;margin-bottom:4px" @click="startNew">
				<iconify-icon icon="tabler:plus" width="15"></iconify-icon> {{ t("admin.new_mission") }}
			</button>

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
					<input v-model.number="form.reward_base" type="number" min="0" class="admin-input" />
				</label>

				<label class="admin-label">
					{{ t("admin.field_xp") }}
					<input v-model.number="form.xp_base" type="number" min="0" class="admin-input" />
				</label>

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
				<div style="display:flex;align-items:center;justify-content:space-between">
					<span style="font-size:13px;font-weight:700;color:#1b1f24">{{ t("admin.search_area_heading") }}</span>
					<button type="button" style="font-size:11px;font-weight:600;border-radius:8px;background:#f1f2f4;border:1px solid #dfe2e6;color:#3c424b;padding:6px 10px;cursor:pointer" @click="useCurrentPosition('search')">
						{{ t("admin.use_current_position") }}
					</button>
				</div>
				<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:10px">
					<label class="admin-label">{{ t("admin.axis_x") }} <input v-model.number="form.search_center_x" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_y") }} <input v-model.number="form.search_center_y" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_z") }} <input v-model.number="form.search_center_z" type="number" step="any" class="admin-input" /></label>
					<label class="admin-label">{{ t("admin.axis_radius") }} <input v-model.number="form.search_radius" type="number" step="any" class="admin-input" /></label>
				</div>
				<label style="display:flex;align-items:center;gap:8px;font-size:12px;color:#6b7280">
					<input v-model="searchPreviewOn" type="checkbox" @change="pushSearchPreview" />
					{{ t("admin.search_preview_toggle") }}
				</label>
			</div>

			<div style="background:#fff;border:1px solid #dfe2e6;border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px">
				<div style="display:flex;align-items:center;justify-content:space-between">
					<span style="font-size:13px;font-weight:700;color:#1b1f24">{{ t("admin.dropoff_zone_heading") }}</span>
					<button type="button" style="font-size:11px;font-weight:600;border-radius:8px;background:#f1f2f4;border:1px solid #dfe2e6;color:#3c424b;padding:6px 10px;cursor:pointer" @click="useCurrentPosition('dropoff')">
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
						:disabled="testing || !selectedIsActive"
						:title="!selectedIsActive ? t('admin.test_needs_active') : t('admin.test_qa_hint')"
						:style="{ opacity: (testing || !selectedIsActive) ? 0.4 : 1 }"
						@click="testRun"
					>
						{{ testing ? t("admin.starting") : t("admin.test_mission") }}
					</button>
				</template>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { getCurrentInstance, reactive, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminCurrentPosition, AdminMission } from "@/types/admin";

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
const searchPreviewOn = ref(false);
const dropoffPreviewOn = ref(false);

const form = reactive({
	name: "",
	area_id: "",
	vehicle_model: "",
	vehicle_label: "",
	vehicle_colors: { primary: 0, secondary: 0 },
	search_center_x: 0,
	search_center_y: 0,
	search_center_z: 0,
	search_radius: 60,
	dropoff_x: 0,
	dropoff_y: 0,
	dropoff_z: 0,
	dropoff_heading: 0,
	dropoff_width: 6,
	dropoff_length: 10,
	reward_base: 100,
	xp_base: 20,
	time_limit_minutes: null as number | null,
	difficulty: "easy" as "easy" | "medium" | "hard",
	level_required: 1,
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
		search_center_x: 0,
		search_center_y: 0,
		search_center_z: 0,
		search_radius: 60,
		dropoff_x: 0,
		dropoff_y: 0,
		dropoff_z: 0,
		dropoff_heading: 0,
		dropoff_width: 6,
		dropoff_length: 10,
		reward_base: 100,
		xp_base: 20,
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
		search_center_x: mission.search_center_x,
		search_center_y: mission.search_center_y,
		search_center_z: mission.search_center_z,
		search_radius: mission.search_radius,
		dropoff_x: mission.dropoff_x,
		dropoff_y: mission.dropoff_y,
		dropoff_z: mission.dropoff_z,
		dropoff_heading: mission.dropoff_heading,
		dropoff_width: mission.dropoff_width,
		dropoff_length: mission.dropoff_length,
		reward_base: mission.reward_base,
		xp_base: mission.xp_base,
		time_limit_minutes: mission.time_limit_minutes,
		difficulty: mission.difficulty,
		level_required: mission.level_required,
	});
	clearPreviews();
}

async function useCurrentPosition(target: "search" | "dropoff") {
	try {
		const pos = await nuiCallbackAsync<AdminCurrentPosition>("adminGetCurrentPosition");
		if (!pos) return;

		if (target === "search") {
			form.search_center_x = pos.x;
			form.search_center_y = pos.y;
			form.search_center_z = pos.z;
		} else {
			form.dropoff_x = pos.x;
			form.dropoff_y = pos.y;
			form.dropoff_z = pos.z;
			form.dropoff_heading = pos.heading;
		}
	} catch (error) {
		console.error("adminGetCurrentPosition failed:", error);
	}
}

function pushSearchPreview() {
	nuiCallbackAsync("adminSetSearchPreview", {
		active: searchPreviewOn.value,
		x: form.search_center_x,
		y: form.search_center_y,
		z: form.search_center_z,
		radius: form.search_radius,
	}).catch((error) => console.error("adminSetSearchPreview failed:", error));
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
	if (searchPreviewOn.value) {
		searchPreviewOn.value = false;
		pushSearchPreview();
	}
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
	invalid_position: "admin.err_invalid_position_mission",
	not_found: "admin.err_mission_gone",
	has_delivery_history: "admin.err_has_delivery_history",
};

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

startNew();
</script>
