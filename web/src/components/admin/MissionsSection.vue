<template>
	<div class="h-full flex">
		<aside class="w-56 shrink-0 border-r border-white/10 overflow-y-auto p-2 space-y-1">
			<button
				type="button"
				class="w-full text-left rounded-md bg-emerald-600 hover:bg-emerald-500 text-xs font-medium px-3 py-2 mb-2"
				@click="startNew"
			>
				+ New Mission
			</button>

			<button
				v-for="mission in adminStore.missions"
				:key="mission.id"
				type="button"
				class="w-full text-left rounded-md px-3 py-2 text-sm transition-colors"
				:class="editingId === mission.id ? 'bg-neutral-700' : 'bg-neutral-800/50 hover:bg-neutral-800'"
				@click="selectMission(mission)"
			>
				<div class="font-medium truncate">{{ mission.name }}</div>
				<div class="text-xs text-white/40">{{ mission.area_name ?? "no area" }} · {{ mission.is_active ? "active" : "inactive" }}</div>
			</button>
		</aside>

		<div class="flex-1 overflow-y-auto p-4 space-y-4">
			<p v-if="errorMessage" class="text-xs text-red-400">{{ errorMessage }}</p>

			<div class="grid grid-cols-2 gap-3">
				<label class="text-xs text-white/60 col-span-2">
					Name
					<input v-model="form.name" type="text" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Area
					<select v-model="form.area_id" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm">
						<option v-for="area in adminStore.areas" :key="area.id" :value="area.id">{{ area.name }}</option>
					</select>
				</label>

				<label class="text-xs text-white/60">
					Difficulty
					<select v-model="form.difficulty" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm">
						<option value="easy">Easy</option>
						<option value="medium">Medium</option>
						<option value="hard">Hard</option>
					</select>
				</label>

				<label class="text-xs text-white/60">
					Vehicle model (spawn code)
					<input v-model="form.vehicle_model" type="text" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Vehicle label (display name)
					<input v-model="form.vehicle_label" type="text" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Vehicle color — primary
					<input v-model.number="form.vehicle_colors.primary" type="number" min="0" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Vehicle color — secondary
					<input v-model.number="form.vehicle_colors.secondary" type="number" min="0" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Reward ($)
					<input v-model.number="form.reward_base" type="number" min="0" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					XP
					<input v-model.number="form.xp_base" type="number" min="0" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60">
					Level required
					<input v-model.number="form.level_required" type="number" min="1" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>

				<label class="text-xs text-white/60 flex items-center gap-2 mt-5">
					<input type="checkbox" :checked="form.time_limit_minutes !== null" @change="toggleTimed" />
					Timed mission
				</label>

				<label v-if="form.time_limit_minutes !== null" class="text-xs text-white/60">
					Time limit (minutes)
					<input v-model.number="form.time_limit_minutes" type="number" min="1" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1.5 text-sm" />
				</label>
			</div>

			<div class="rounded-md bg-neutral-800/40 border border-white/10 p-3 space-y-2">
				<div class="flex items-center justify-between">
					<span class="text-xs font-medium text-white/70">Search area (where the vehicle spawns)</span>
					<button type="button" class="text-xs rounded-md bg-neutral-700 hover:bg-neutral-600 px-2 py-1" @click="useCurrentPosition('search')">
						Use current position
					</button>
				</div>
				<div class="grid grid-cols-4 gap-2">
					<label class="text-xs text-white/60">X <input v-model.number="form.search_center_x" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Y <input v-model.number="form.search_center_y" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Z <input v-model.number="form.search_center_z" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Radius <input v-model.number="form.search_radius" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
				</div>
				<label class="text-xs text-white/50 flex items-center gap-2">
					<input v-model="searchPreviewOn" type="checkbox" @change="pushSearchPreview" />
					Show live blip preview in-game
				</label>
			</div>

			<div class="rounded-md bg-neutral-800/40 border border-white/10 p-3 space-y-2">
				<div class="flex items-center justify-between">
					<span class="text-xs font-medium text-white/70">Dropoff zone</span>
					<button type="button" class="text-xs rounded-md bg-neutral-700 hover:bg-neutral-600 px-2 py-1" @click="useCurrentPosition('dropoff')">
						Use current position
					</button>
				</div>
				<div class="grid grid-cols-4 gap-2">
					<label class="text-xs text-white/60">X <input v-model.number="form.dropoff_x" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Y <input v-model.number="form.dropoff_y" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Z <input v-model.number="form.dropoff_z" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Heading <input v-model.number="form.dropoff_heading" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Width <input v-model.number="form.dropoff_width" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
					<label class="text-xs text-white/60">Length <input v-model.number="form.dropoff_length" type="number" step="any" class="mt-1 w-full rounded-md bg-neutral-800 border border-white/10 px-2 py-1 text-sm" /></label>
				</div>
				<label class="text-xs text-white/50 flex items-center gap-2">
					<input v-model="dropoffPreviewOn" type="checkbox" @change="pushDropoffPreview" />
					Show live red outline preview in-game (same outline the real delivery uses)
				</label>
			</div>

			<div class="flex flex-wrap items-center gap-2 pt-2">
				<button
					type="button"
					:disabled="saving"
					class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
					@click="save"
				>
					{{ saving ? "Saving..." : editingId ? "Save changes" : "Create mission" }}
				</button>

				<template v-if="editingId">
					<button
						type="button"
						:disabled="togglingActive"
						class="rounded-md bg-neutral-700 hover:bg-neutral-600 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
						@click="toggleActive"
					>
						{{ selectedIsActive ? "Deactivate" : "Activate" }}
					</button>

					<button
						type="button"
						:disabled="deleting || selectedDeliveryCount > 0"
						:title="selectedDeliveryCount > 0 ? 'Has delivery history — deactivate instead' : ''"
						class="rounded-md bg-red-700 hover:bg-red-600 disabled:opacity-30 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
						@click="remove"
					>
						{{ deleting ? "Deleting..." : "Delete" }}
					</button>

					<button
						type="button"
						:disabled="testing || !selectedIsActive"
						:title="!selectedIsActive ? 'Activate this mission first to test it' : 'QA only — bypasses your own level/area-lock requirements'"
						class="ml-auto rounded-md bg-amber-600 hover:bg-amber-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-4 py-2"
						@click="testRun"
					>
						{{ testing ? "Starting..." : "Test mission" }}
					</button>
				</template>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { getCurrentInstance, reactive, ref } from "vue";
import { useAdminStore } from "@/stores/adminStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AdminActionResult, AdminCurrentPosition, AdminMission } from "@/types/admin";

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
	not_admin: "You are not an admin.",
	invalid_name: "Name is required.",
	invalid_area: "Select a valid area.",
	invalid_vehicle_model: "Vehicle model is required.",
	invalid_reward: "Reward and XP must be numbers.",
	invalid_position: "Search center and dropoff position are required.",
	not_found: "This mission no longer exists.",
	has_delivery_history: "This mission has delivery history — deactivate it instead of deleting.",
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
			errorMessage.value = reasonMessages[result?.reason ?? ""] ?? "Failed to save mission.";
		}
	} catch (error) {
		console.error("adminCreateMission/adminUpdateMission failed:", error);
		errorMessage.value = "Failed to save mission.";
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
			errorMessage.value = reasonMessages[result?.reason ?? ""] ?? "Failed to update mission.";
		}
	} catch (error) {
		console.error("adminSetMissionActive failed:", error);
		errorMessage.value = "Failed to update mission.";
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
			errorMessage.value = reasonMessages[result?.reason ?? ""] ?? "Failed to delete mission.";
		}
	} catch (error) {
		console.error("adminDeleteMission failed:", error);
		errorMessage.value = "Failed to delete mission.";
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
			errorMessage.value = reasonMessages[result?.reason ?? ""] ?? "Failed to start test run.";
		}
	} catch (error) {
		console.error("adminTestRunMission failed:", error);
		errorMessage.value = "Failed to start test run.";
	} finally {
		testing.value = false;
	}
}

startNew();
</script>
