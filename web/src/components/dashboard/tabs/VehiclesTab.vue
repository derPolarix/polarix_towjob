<template>
	<div class="flex flex-col gap-6 text-white">
		<p v-if="actionError" class="text-xs text-red-400">{{ actionError }}</p>

		<div class="flex flex-col gap-2">
			<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">Your Tow Trucks</h3>

			<div v-if="vehicles.length === 0" class="text-white/60 text-sm">
				You don't own any tow trucks yet — purchase one below.
			</div>

			<div
				v-for="vehicle in vehicles"
				:key="vehicle.id"
				class="flex items-center justify-between gap-4 rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3"
			>
				<div class="flex flex-col gap-1">
					<div class="flex items-center gap-2">
						<span class="font-medium">{{ vehicle.label }}</span>
						<span class="rounded bg-white/10 text-xs px-2 py-0.5 uppercase">{{ vehicle.state }}</span>
					</div>
					<div class="text-xs text-white/60">Plate: {{ vehicle.plate }}</div>
					<div class="flex gap-4 text-xs text-white/60">
						<span>Body: {{ Math.round(vehicle.body_health / 10) }}%</span>
						<span>Engine: {{ Math.round(vehicle.engine_health / 10) }}%</span>
					</div>
				</div>

				<div class="flex items-center gap-2">
					<button
						type="button"
						:disabled="busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)"
						class="rounded-md bg-white/10 hover:bg-white/20 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-3 py-2"
						@click="repair(vehicle)"
					>
						Repair (~${{ estimateRepairCost(vehicle) }})
					</button>
					<button
						v-if="vehicle.state === 'stored'"
						type="button"
						:disabled="busyVehicleId === vehicle.id"
						class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-3 py-2"
						@click="parkOut(vehicle)"
					>
						Park Out
					</button>
				</div>
			</div>
		</div>

		<div class="flex flex-col gap-2">
			<h3 class="text-sm font-semibold uppercase tracking-wide text-white/50">Purchase</h3>

			<div
				v-for="tier in vehicleTiers"
				:key="tier.id"
				class="flex items-center justify-between gap-4 rounded-md bg-neutral-900/70 border border-white/10 px-4 py-3"
			>
				<div class="flex flex-col gap-1">
					<span class="font-medium">{{ tier.label }}</span>
					<div class="text-xs text-white/60">
						Level {{ tier.level_required }}+
						<span v-if="tier.damage_resistance > 0">· -{{ Math.round(tier.damage_resistance * 100) }}% damage</span>
					</div>
				</div>

				<div class="flex items-center gap-4">
					<div class="text-emerald-400 font-semibold text-sm">${{ tier.price }}</div>
					<button
						type="button"
						:disabled="purchasingTierId === tier.id"
						class="rounded-md bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed text-sm font-medium px-3 py-2"
						@click="purchase(tier)"
					>
						Buy
					</button>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useDashboardStore } from "@/stores/dashboardStore";
import { usePersistantStore } from "@/stores/persistantStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { OwnedVehicle, VehicleActionResult, VehicleTier } from "@/types/dashboard";

const dashboardStore = useDashboardStore();
const persistantStore = usePersistantStore();

const vehicles = ref<OwnedVehicle[]>(dashboardStore.payload?.vehicles ?? []);
const vehicleTiers = ref<VehicleTier[]>(dashboardStore.payload?.vehicleTiers ?? []);
const repairCostPerHealthPoint = ref(dashboardStore.payload?.repairCostPerHealthPoint ?? 0.6);

const busyVehicleId = ref<number | null>(null);
const purchasingTierId = ref<string | null>(null);
const actionError = ref("");

const reasonMessages: Record<string, string> = {
	invalid_tier: "That tier no longer exists.",
	level_too_low: "You do not meet the level requirement for this tier.",
	insufficient_funds: "You cannot afford this right now.",
	not_owned: "You don't own this vehicle.",
	not_stored: "This vehicle isn't stored.",
	not_deployed: "This vehicle isn't deployed.",
	already_full_health: "This vehicle is already at full health.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
};

function estimateRepairCost(vehicle: OwnedVehicle): number {
	const missing = 1000 - vehicle.body_health + (1000 - vehicle.engine_health);
	return Math.max(0, Math.round(missing * repairCostPerHealthPoint.value));
}

function applyVehicles(list: OwnedVehicle[] | undefined) {
	if (!list) return;
	vehicles.value = list;
	dashboardStore.setVehicles(list);
}

async function repair(vehicle: OwnedVehicle) {
	busyVehicleId.value = vehicle.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<VehicleActionResult>("repairVehicle", { vehicleId: vehicle.id });
		if (result?.ok) {
			applyVehicles(result.vehicles);
		} else {
			actionError.value = reasonMessages[result?.reason ?? ""] ?? "Repair failed.";
		}
	} catch (error) {
		console.error("repairVehicle failed:", error);
		actionError.value = "Repair failed.";
	} finally {
		busyVehicleId.value = null;
	}
}

async function parkOut(vehicle: OwnedVehicle) {
	busyVehicleId.value = vehicle.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<VehicleActionResult>("parkOutVehicle", { vehicleId: vehicle.id });
		if (result?.ok) {
			applyVehicles(result.vehicles);
			if (result.missionStarted) {
				await persistantStore.closeNui();
			}
		} else {
			actionError.value = reasonMessages[result?.reason ?? ""] ?? "Could not park out this vehicle.";
		}
	} catch (error) {
		console.error("parkOutVehicle failed:", error);
		actionError.value = "Could not park out this vehicle.";
	} finally {
		busyVehicleId.value = null;
	}
}

async function purchase(tier: VehicleTier) {
	purchasingTierId.value = tier.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<VehicleActionResult>("purchaseVehicle", { tierId: tier.id });
		if (result?.ok) {
			applyVehicles(result.vehicles);
		} else {
			actionError.value = reasonMessages[result?.reason ?? ""] ?? "Purchase failed.";
		}
	} catch (error) {
		console.error("purchaseVehicle failed:", error);
		actionError.value = "Purchase failed.";
	} finally {
		purchasingTierId.value = null;
	}
}

onMounted(async () => {
	try {
		const fresh = await nuiCallbackAsync<{ vehicles: OwnedVehicle[]; vehicleTiers: VehicleTier[]; repairCostPerHealthPoint: number }>(
			"getOwnedVehicles",
		);
		if (fresh) {
			if (Array.isArray(fresh.vehicles)) applyVehicles(fresh.vehicles);
			if (Array.isArray(fresh.vehicleTiers)) vehicleTiers.value = fresh.vehicleTiers;
			if (typeof fresh.repairCostPerHealthPoint === "number") repairCostPerHealthPoint.value = fresh.repairCostPerHealthPoint;
		}
	} catch (error) {
		console.error("getOwnedVehicles failed:", error);
	}
});
</script>
