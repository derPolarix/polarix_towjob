<template>
	<div style="display:flex;flex-direction:column;gap:20px">
		<p v-if="actionError" style="font-size:12px;color:#d24b3a;margin:0">{{ actionError }}</p>

		<div v-if="dashboardStore.payload?.rentalActive" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:16px 18px;display:flex;align-items:center;justify-content:space-between;gap:16px">
			<div style="display:flex;align-items:center;gap:12px">
				<div style="width:40px;height:40px;border-radius:11px;background:rgba(34,197,94,0.14);display:flex;align-items:center;justify-content:center;flex-shrink:0">
					<iconify-icon icon="tabler:truck" width="20" style="color:#22c55e"></iconify-icon>
				</div>
				<div>
					<div style="font-size:14px;font-weight:700;color:#1b1f24">Active rental — {{ dashboardStore.payload?.rentalTruckLabel ?? 'Rental Flatbed' }}</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:2px">${{ dashboardStore.payload?.rentalPricePerCharge ?? 0 }} every {{ dashboardStore.payload?.rentalIntervalMinutes ?? 0 }} min</div>
				</div>
			</div>
			<button
				type="button"
				style="padding:10px 18px;border-radius:10px;border:1px solid #dfe2e6;background:#fff;color:#dc2626;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer"
				:disabled="returningRental || !!dashboardStore.activeDelivery"
				:title="dashboardStore.activeDelivery ? 'Finish your current delivery first' : ''"
				@click="returnRental"
			>
				{{ returningRental ? 'Returning…' : 'Return rental' }}
			</button>
		</div>

		<!-- Garage -->
		<div>
			<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">
				<div>
					<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">Your tow trucks</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">{{ vehicles.length }} owned</div>
				</div>
			</div>

			<div v-if="vehicles.length === 0" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;padding:32px;text-align:center;color:#9aa1ab;font-size:13px">
				You don't own any tow trucks yet — purchase one below.
			</div>

			<div v-else style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px">
				<div v-for="vehicle in vehicles" :key="vehicle.id" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;overflow:hidden;display:flex;flex-direction:column">
					<div style="width:100%;height:150px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;position:relative">
						<iconify-icon icon="tabler:truck" width="48" style="color:#aab0b8"></iconify-icon>
						<span style="position:absolute;top:12px;right:12px;font-family:'IBM Plex Mono',monospace;font-size:9px;letter-spacing:0.06em;padding:3px 8px;border-radius:6px;text-transform:uppercase" :style="vehicle.state === 'deployed' ? 'background:rgba(34,197,94,0.16);color:#15803d' : 'background:#eef0f2;color:#6b7280'">{{ vehicle.state }}</span>
					</div>
					<div style="padding:15px 16px">
						<div style="font-size:15px;font-weight:700;color:#1b1f24;line-height:1.2">{{ vehicle.label }}</div>
						<div style="font-family:'IBM Plex Mono',monospace;font-size:10px;color:#9aa1ab;margin-top:5px">Plate {{ vehicle.plate }}</div>

						<div style="display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-top:14px;padding-top:14px;border-top:1px solid #eef0f2">
							<div style="text-align:center">
								<iconify-icon icon="tabler:car" width="16" style="color:#9aa1ab"></iconify-icon>
								<div style="font-size:13px;font-weight:700;color:#1b1f24;margin-top:4px">{{ Math.round(vehicle.body_health / 10) }}%</div>
								<div style="font-family:'IBM Plex Mono',monospace;font-size:8px;letter-spacing:0.06em;text-transform:uppercase;color:#9aa1ab">body</div>
							</div>
							<div style="text-align:center">
								<iconify-icon icon="tabler:engine" width="16" style="color:#9aa1ab"></iconify-icon>
								<div style="font-size:13px;font-weight:700;color:#1b1f24;margin-top:4px">{{ Math.round(vehicle.engine_health / 10) }}%</div>
								<div style="font-family:'IBM Plex Mono',monospace;font-size:8px;letter-spacing:0.06em;text-transform:uppercase;color:#9aa1ab">engine</div>
							</div>
						</div>

						<div style="display:flex;gap:8px;margin-top:14px">
							<button
								class="ghost-btn"
								type="button"
								style="flex:1;padding:10px;border-radius:10px;border:1px solid #dfe2e6;background:#fff;color:#3c424b;font-family:inherit;font-weight:600;font-size:12px;cursor:pointer"
								:disabled="busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)"
								:style="{ opacity: (busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)) ? 0.4 : 1 }"
								@click="repair(vehicle)"
							>
								Repair (~${{ estimateRepairCost(vehicle) }})
							</button>
							<button
								v-if="vehicle.state === 'stored'"
								class="accent-btn"
								type="button"
								style="flex-shrink:0;padding:10px 16px;font-size:12px"
								:disabled="busyVehicleId === vehicle.id"
								@click="parkOut(vehicle)"
							>
								Park out
							</button>
							<button
								v-else-if="vehicle.state === 'deployed'"
								class="accent-btn"
								type="button"
								style="flex-shrink:0;padding:10px 16px;font-size:12px"
								:disabled="busyVehicleId === vehicle.id || !!dashboardStore.activeDelivery"
								:title="dashboardStore.activeDelivery ? 'Finish your current delivery first' : ''"
								@click="parkIn(vehicle)"
							>
								Park in
							</button>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Shop -->
		<div>
			<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">
				<div>
					<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:#1b1f24">Purchase</div>
					<div style="font-family:'IBM Plex Mono',monospace;font-size:11px;color:#9aa1ab;margin-top:4px">Permanent tow trucks — used automatically once purchased</div>
				</div>
			</div>
			<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px">
				<div v-for="tier in vehicleTiers" :key="tier.id" style="background:#fff;border:1px solid #dfe2e6;border-radius:15px;overflow:hidden;display:flex;flex-direction:column">
					<div style="position:relative">
						<div style="width:100%;height:128px;background:#f3f4f6;display:flex;align-items:center;justify-content:center">
							<iconify-icon icon="tabler:truck" width="40" style="color:#aab0b8"></iconify-icon>
						</div>
						<div v-if="isTierLocked(tier)" style="position:absolute;inset:0;background:rgba(34,38,45,0.55);display:flex;align-items:center;justify-content:center">
							<iconify-icon icon="tabler:lock" width="26" style="color:#fff"></iconify-icon>
						</div>
					</div>
					<div style="padding:14px;display:flex;flex-direction:column;flex:1">
						<div style="font-size:14px;font-weight:700;color:#1b1f24;line-height:1.2">{{ tier.label }}</div>
						<div style="display:flex;gap:12px;margin-top:12px;padding-top:12px;border-top:1px solid #eef0f2">
							<span style="display:inline-flex;align-items:center;gap:4px;font-size:11px;color:#6b7280"><iconify-icon icon="tabler:star" width="14" style="color:#aab0b8"></iconify-icon>Lvl {{ tier.level_required }}+</span>
							<span v-if="tier.damage_resistance > 0" style="display:inline-flex;align-items:center;gap:4px;font-size:11px;color:#6b7280"><iconify-icon icon="tabler:shield" width="14" style="color:#aab0b8"></iconify-icon>-{{ Math.round(tier.damage_resistance * 100) }}% dmg</span>
						</div>
						<div style="margin-top:14px;display:flex;align-items:center;justify-content:space-between;gap:8px">
							<span style="font-size:15px;font-weight:800;color:#1b1f24">${{ tier.price }}</span>
							<span v-if="isTierLocked(tier)" style="font-family:'IBM Plex Mono',monospace;font-size:10px;padding:7px 11px;border-radius:9px;background:#f1f2f4;color:#9aa1ab">Lvl {{ tier.level_required }}</span>
							<button v-else class="accent-btn" type="button" style="padding:8px 15px;font-size:12px" :disabled="purchasingTierId === tier.id" @click="purchase(tier)">
								{{ purchasingTierId === tier.id ? 'Buying…' : 'Buy' }}
							</button>
						</div>
					</div>
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
import type { OwnedVehicle, ReturnRentalResult, VehicleActionResult, VehicleTier } from "@/types/dashboard";

const dashboardStore = useDashboardStore();
const persistantStore = usePersistantStore();

const returningRental = ref(false);

async function returnRental() {
	returningRental.value = true;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<ReturnRentalResult>("returnRental");
		if (result?.ok) {
			dashboardStore.setRentalActive(false);
		} else if (result?.reason === "delivery_in_progress") {
			actionError.value = "Finish your current delivery before returning the rental.";
		} else {
			actionError.value = "Could not return the rental.";
		}
	} catch (error) {
		console.error("returnRental failed:", error);
		actionError.value = "Could not return the rental.";
	} finally {
		returningRental.value = false;
	}
}

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
	delivery_in_progress: "Finish your current delivery before parking this truck in.",
	already_full_health: "This vehicle is already at full health.",
	no_player: "Player data unavailable, try reopening the Dashboard.",
};

function isTierLocked(tier: VehicleTier): boolean {
	return (dashboardStore.player?.level ?? 1) < tier.level_required;
}

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

async function parkIn(vehicle: OwnedVehicle) {
	busyVehicleId.value = vehicle.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<VehicleActionResult>("parkInVehicle", { vehicleId: vehicle.id });
		if (result?.ok) {
			applyVehicles(result.vehicles);
		} else {
			actionError.value = reasonMessages[result?.reason ?? ""] ?? "Could not park in this vehicle.";
		}
	} catch (error) {
		console.error("parkInVehicle failed:", error);
		actionError.value = "Could not park in this vehicle.";
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

<style scoped>
.ghost-btn:hover:not(:disabled) {
	border-color: var(--accent) !important;
}
</style>
