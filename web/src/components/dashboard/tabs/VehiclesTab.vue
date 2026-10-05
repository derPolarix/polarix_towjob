<template>
	<div style="display:flex;flex-direction:column;gap:20px">
		<p v-if="actionError" style="font-size:12px;color:var(--danger-text);margin:0">{{ actionError }}</p>

		<div v-if="dashboardStore.payload?.rentalActive" style="background:#fff;border:1px solid var(--border);border-radius:15px;padding:16px 18px;display:flex;align-items:center;justify-content:space-between;gap:16px">
			<div style="display:flex;align-items:center;gap:12px">
				<div style="width:40px;height:40px;border-radius:11px;background:rgba(34,197,94,0.14);display:flex;align-items:center;justify-content:center;flex-shrink:0">
					<iconify-icon icon="tabler:truck" width="20" style="color:var(--accent)"></iconify-icon>
				</div>
				<div>
					<div style="font-size:14px;font-weight:700;color:var(--ink)">{{ t("vehicles.active_rental_label", { label: dashboardStore.payload?.rentalTruckLabel ?? "Rental Flatbed" }) }}</div>
					<div style="font-family:var(--font-mono);font-size:11px;color:var(--faint);margin-top:2px">{{ t("common.rental_interval", { cost: formatMoney(dashboardStore.payload?.rentalPricePerCharge), minutes: dashboardStore.payload?.rentalIntervalMinutes ?? 0 }) }}</div>
				</div>
			</div>
			<button
				type="button"
				style="padding:10px 18px;border-radius:10px;border:1px solid var(--border);background:#fff;color:var(--danger);font-family:inherit;font-weight:600;font-size:13px;cursor:pointer"
				:disabled="returningRental || !!dashboardStore.activeDelivery"
				:title="dashboardStore.activeDelivery ? t('vehicles.finish_delivery_first') : ''"
				@click="returnRental"
			>
				{{ returningRental ? t("vehicles.returning") : t("vehicles.return_rental") }}
			</button>
		</div>

		<!-- Garage -->
		<div>
			<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">
				<div>
					<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:var(--ink)">{{ t("vehicles.your_trucks") }}</div>
					<div style="font-family:var(--font-mono);font-size:11px;color:var(--faint);margin-top:4px">{{ t("vehicles.owned_count", { count: vehicles.length }) }}</div>
				</div>
			</div>

			<div v-if="vehicles.length === 0" style="background:#fff;border:1px solid var(--border);border-radius:15px;padding:32px;text-align:center;color:var(--faint);font-size:13px">
				{{ t("vehicles.no_trucks") }}
			</div>

			<div v-else style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px">
				<div v-for="vehicle in vehicles" :key="vehicle.id" style="background:#fff;border:1px solid var(--border);border-radius:15px;overflow:hidden;display:flex;flex-direction:column">
					<div style="width:100%;height:150px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;position:relative">
						<div
							v-if="vehicleImage(vehicle.model)"
							style="position:absolute;inset:0;background-size:cover;background-position:center"
							:style="{ backgroundImage: `url(${vehicleImage(vehicle.model)})` }"
						/>
						<iconify-icon v-else icon="tabler:truck" width="48" style="color:#aab0b8"></iconify-icon>
						<span style="position:absolute;top:12px;right:12px;font-family:var(--font-mono);font-size:9px;letter-spacing:0.06em;padding:3px 8px;border-radius:6px;text-transform:uppercase" :style="vehicle.state === 'deployed' ? 'background:rgba(34,197,94,0.16);color:#15803d' : 'background:#eef0f2;color:#6b7280'">{{ t("vehicle_state." + vehicle.state) }}</span>
					</div>
					<div style="padding:15px 16px">
						<div style="font-size:15px;font-weight:700;color:var(--ink);line-height:1.2">{{ vehicle.label }}</div>
						<div style="font-family:var(--font-mono);font-size:10px;color:var(--faint);margin-top:5px">{{ t("vehicles.plate", { plate: vehicle.plate }) }}</div>

						<div style="display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-top:14px;padding-top:14px;border-top:1px solid var(--surface-sunken)">
							<div style="text-align:center">
								<iconify-icon icon="tabler:car" width="16" style="color:var(--faint)"></iconify-icon>
								<div style="font-size:13px;font-weight:700;color:var(--ink);margin-top:4px">{{ Math.round(vehicle.body_health / 10) }}%</div>
								<div style="font-family:var(--font-mono);font-size:8px;letter-spacing:0.06em;text-transform:uppercase;color:var(--faint)">{{ t("vehicles.body") }}</div>
							</div>
							<div style="text-align:center">
								<iconify-icon icon="tabler:engine" width="16" style="color:var(--faint)"></iconify-icon>
								<div style="font-size:13px;font-weight:700;color:var(--ink);margin-top:4px">{{ Math.round(vehicle.engine_health / 10) }}%</div>
								<div style="font-family:var(--font-mono);font-size:8px;letter-spacing:0.06em;text-transform:uppercase;color:var(--faint)">{{ t("vehicles.engine") }}</div>
							</div>
						</div>

						<div style="display:flex;gap:8px;margin-top:14px">
							<button
								class="ghost-btn"
								type="button"
								style="flex:1;padding:10px;border-radius:10px;border:1px solid var(--border);background:#fff;color:var(--ink-soft);font-family:inherit;font-weight:600;font-size:12px;cursor:pointer"
								:disabled="busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)"
								:style="{ opacity: (busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)) ? 0.4 : 1 }"
								@click="repair(vehicle)"
							>
								{{ t("vehicles.repair_cost", { cost: formatMoney(estimateRepairCost(vehicle)) }) }}
							</button>
							<button
								v-if="vehicle.state === 'stored'"
								class="accent-btn"
								type="button"
								style="flex-shrink:0;padding:10px 16px;font-size:12px"
								:disabled="busyVehicleId === vehicle.id"
								@click="parkOut(vehicle)"
							>
								{{ t("vehicles.park_out") }}
							</button>
							<button
								v-else-if="vehicle.state === 'deployed'"
								class="accent-btn"
								type="button"
								style="flex-shrink:0;padding:10px 16px;font-size:12px"
								:disabled="busyVehicleId === vehicle.id || !!dashboardStore.activeDelivery"
								:title="dashboardStore.activeDelivery ? t('vehicles.finish_delivery_first') : ''"
								@click="parkIn(vehicle)"
							>
								{{ t("vehicles.park_in") }}
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
					<div style="font-size:20px;font-weight:800;letter-spacing:-0.01em;color:var(--ink)">{{ t("vehicles.purchase_heading") }}</div>
					<div style="font-family:var(--font-mono);font-size:11px;color:var(--faint);margin-top:4px">{{ t("vehicles.purchase_sub") }}</div>
				</div>
			</div>
			<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px">
				<div v-for="tier in vehicleTiers" :key="tier.id" style="background:#fff;border:1px solid var(--border);border-radius:15px;overflow:hidden;display:flex;flex-direction:column">
					<div style="position:relative">
						<div style="width:100%;height:128px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;background-size:cover;background-position:center" :style="vehicleImage(tier.model) ? { backgroundImage: `url(${vehicleImage(tier.model)})` } : {}">
							<iconify-icon v-if="!vehicleImage(tier.model)" icon="tabler:truck" width="40" style="color:#aab0b8"></iconify-icon>
						</div>
						<div v-if="isTierLocked(tier)" style="position:absolute;inset:0;background:rgba(34,38,45,0.55);display:flex;align-items:center;justify-content:center">
							<iconify-icon icon="tabler:lock" width="26" style="color:#fff"></iconify-icon>
						</div>
						<span v-else-if="isTierOwned(tier)" style="position:absolute;top:12px;right:12px;font-family:var(--font-mono);font-size:9px;letter-spacing:0.06em;padding:3px 8px;border-radius:6px;text-transform:uppercase;background:rgba(34,197,94,0.16);color:#15803d">{{ t("vehicles.owned_badge") }}</span>
					</div>
					<div style="padding:14px;display:flex;flex-direction:column;flex:1">
						<div style="font-size:14px;font-weight:700;color:var(--ink);line-height:1.2">{{ tier.label }}</div>
						<div style="display:flex;gap:12px;margin-top:12px;padding-top:12px;border-top:1px solid var(--surface-sunken)">
							<span style="display:inline-flex;align-items:center;gap:4px;font-size:11px;color:var(--muted)"><iconify-icon icon="tabler:star" width="14" style="color:#aab0b8"></iconify-icon>{{ t("vehicles.level_plus", { level: tier.level_required }) }}</span>
							<span v-if="tier.damage_resistance > 0" style="display:inline-flex;align-items:center;gap:4px;font-size:11px;color:var(--muted)"><iconify-icon icon="tabler:shield" width="14" style="color:#aab0b8"></iconify-icon>{{ t("vehicles.damage_resist", { percent: Math.round(tier.damage_resistance * 100) }) }}</span>
						</div>
						<div style="margin-top:14px;display:flex;align-items:center;justify-content:space-between;gap:8px">
							<span style="font-size:15px;font-weight:800;color:var(--ink)">{{ formatMoney(tier.price) }}</span>
							<span v-if="isTierLocked(tier)" style="font-family:var(--font-mono);font-size:10px;padding:7px 11px;border-radius:9px;background:var(--surface-muted);color:var(--faint)">{{ t("common.level_short", { level: tier.level_required }) }}</span>
							<span v-else-if="isTierOwned(tier)" style="font-family:var(--font-mono);font-size:10px;padding:7px 11px;border-radius:9px;background:var(--surface-sunken);color:var(--muted)">{{ t("vehicles.owned_badge") }}</span>
							<button v-else class="accent-btn" type="button" style="padding:8px 15px;font-size:12px" :disabled="purchasingTierId === tier.id" @click="purchase(tier)">
								{{ purchasingTierId === tier.id ? t("vehicles.buying") : t("app.buy") }}
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
import { useI18n } from "vue-i18n";
import { formatMoney } from "@/lib/uiConfig";
import { useDashboardStore } from "@/stores/dashboardStore";
import { useConfirmStore } from "@/stores/confirmStore";
import { usePersistantStore } from "@/stores/persistantStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { OwnedVehicle, ReturnRentalResult, VehicleActionResult, VehicleTier } from "@/types/dashboard";

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const confirmStore = useConfirmStore();
const persistantStore = usePersistantStore();

// model name (config VehicleTiers[].model) -> bundled image url; falls back to a truck icon
const vehicleImages = import.meta.glob("@/assets/vehicles/*.png", { eager: true, import: "default" }) as Record<string, string>;

function vehicleImage(model: string): string | undefined {
	const hit = Object.entries(vehicleImages).find(([path]) => path.endsWith(`/${model}.png`));
	return hit?.[1];
}

const returningRental = ref(false);

async function returnRental() {
	returningRental.value = true;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<ReturnRentalResult>("returnRental");
		if (result?.ok) {
			dashboardStore.setRentalActive(false);
		} else if (result?.reason === "delivery_in_progress") {
			actionError.value = t("error.finish_delivery_before_return_rental");
		} else {
			actionError.value = t("error.return_rental_failed");
		}
	} catch (error) {
		console.error("returnRental failed:", error);
		actionError.value = t("error.return_rental_failed");
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
	invalid_tier: "error.tier_gone",
	level_too_low: "error.tier_level_too_low",
	insufficient_funds: "error.insufficient_funds",
	already_owned: "error.truck_already_owned",
	not_owned: "error.vehicle_not_owned",
	not_stored: "error.vehicle_not_stored",
	not_deployed: "error.vehicle_not_deployed",
	delivery_in_progress: "error.finish_delivery_before_park_in",
	already_full_health: "error.vehicle_full_health",
	truck_unreachable: "error.vehicle_unreachable",
	invalid_vehicle: "error.vehicle_mismatch",
	plate_mismatch: "error.vehicle_mismatch",
	not_in_zone: "error.not_in_parking_zone",
	no_player: "error.no_player",
};

function isTierLocked(tier: VehicleTier): boolean {
	return (dashboardStore.player?.level ?? 1) < tier.level_required;
}

function isTierOwned(tier: VehicleTier): boolean {
	return vehicles.value.some((v) => v.tier_id === tier.id);
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
			actionError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.repair_failed");
		}
	} catch (error) {
		console.error("repairVehicle failed:", error);
		actionError.value = t("error.repair_failed");
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
			actionError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.park_out_failed");
		}
	} catch (error) {
		console.error("parkOutVehicle failed:", error);
		actionError.value = t("error.park_out_failed");
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
			actionError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.park_in_failed");
		}
	} catch (error) {
		console.error("parkInVehicle failed:", error);
		actionError.value = t("error.park_in_failed");
	} finally {
		busyVehicleId.value = null;
	}
}

async function purchase(tier: VehicleTier) {
	const confirmed = await confirmStore.ask({
		title: t("confirm.purchase_title"),
		body: t("confirm.purchase_body", { name: tier.label, price: formatMoney(tier.price) }),
		confirmLabel: t("app.buy"),
	});
	if (!confirmed) return;

	purchasingTierId.value = tier.id;
	actionError.value = "";

	try {
		const result = await nuiCallbackAsync<VehicleActionResult>("purchaseVehicle", { tierId: tier.id });
		if (result?.ok) {
			applyVehicles(result.vehicles);
		} else {
			actionError.value = t(reasonMessages[result?.reason ?? ""] ?? "error.purchase_failed");
		}
	} catch (error) {
		console.error("purchaseVehicle failed:", error);
		actionError.value = t("error.purchase_failed");
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
