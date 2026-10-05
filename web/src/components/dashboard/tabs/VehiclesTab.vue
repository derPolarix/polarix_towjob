<template>
	<div class="flex flex-col gap-[20px]">
		<p v-if="actionError" class="text-[12px] text-danger-text m-0">{{ actionError }}</p>

		<div v-if="dashboardStore.payload?.rentalActive" class="bg-white border border-line rounded-[15px] py-[16px] px-[18px] flex items-center justify-between gap-[16px]">
			<div class="flex items-center gap-[12px]">
				<div class="w-[40px] h-[40px] rounded-[11px] bg-[rgba(34,197,94,0.14)] flex items-center justify-center shrink-0">
					<iconify-icon icon="tabler:truck" width="20" class="text-accent"></iconify-icon>
				</div>
				<div>
					<div class="text-[14px] font-bold text-ink">{{ t("vehicles.active_rental_label", { label: dashboardStore.payload?.rentalTruckLabel ?? "Rental Flatbed" }) }}</div>
					<div class="font-mono text-[11px] text-faint mt-[2px]">{{ t("common.rental_interval", { cost: formatMoney(dashboardStore.payload?.rentalPricePerCharge), minutes: dashboardStore.payload?.rentalIntervalMinutes ?? 0 }) }}</div>
				</div>
			</div>
			<button
				type="button"
				class="py-[10px] px-[18px] rounded-[10px] border border-line bg-white text-danger font-[inherit] font-semibold text-[13px] cursor-pointer"
				:disabled="returningRental || !!dashboardStore.activeDelivery"
				:title="dashboardStore.activeDelivery ? t('vehicles.finish_delivery_first') : ''"
				@click="returnRental"
			>
				{{ returningRental ? t("vehicles.returning") : t("vehicles.return_rental") }}
			</button>
		</div>

		<!-- Garage -->
		<div>
			<div class="flex items-center justify-between mb-[14px]">
				<div>
					<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("vehicles.your_trucks") }}</div>
					<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("vehicles.owned_count", { count: vehicles.length }) }}</div>
				</div>
			</div>

			<div v-if="vehicles.length === 0" class="bg-white border border-line rounded-[15px] p-[32px] text-center text-faint text-[13px]">
				{{ t("vehicles.no_trucks") }}
			</div>

			<div v-else class="grid grid-cols-[repeat(3,1fr)] gap-[14px]">
				<div v-for="vehicle in vehicles" :key="vehicle.id" class="bg-white border border-line rounded-[15px] overflow-hidden flex flex-col">
					<div class="w-full h-[150px] bg-[#f3f4f6] flex items-center justify-center relative">
						<div
							v-if="vehicleImage(vehicle.model)"
							class="absolute inset-0 bg-cover bg-center"
							:style="{ backgroundImage: `url(${vehicleImage(vehicle.model)})` }"
						/>
						<iconify-icon v-else icon="tabler:truck" width="48" class="text-[#aab0b8]"></iconify-icon>
						<span class="absolute top-[12px] right-[12px] font-mono text-[9px] tracking-[0.06em] py-[3px] px-[8px] rounded-[6px] uppercase" :style="vehicle.state === 'deployed' ? 'background:rgba(34,197,94,0.16);color:#15803d' : 'background:#eef0f2;color:var(--muted)'">{{ t("vehicle_state." + vehicle.state) }}</span>
					</div>
					<div class="py-[15px] px-[16px]">
						<div class="text-[15px] font-bold text-ink leading-[1.2]">{{ vehicle.label }}</div>
						<div class="font-mono text-[10px] text-faint mt-[5px]">{{ t("vehicles.plate", { plate: vehicle.plate }) }}</div>

						<div class="grid grid-cols-[repeat(2,1fr)] gap-[8px] mt-[14px] pt-[14px] border-t border-t-surface-sunken">
							<div class="text-center">
								<iconify-icon icon="tabler:car" width="16" class="text-faint"></iconify-icon>
								<div class="text-[13px] font-bold text-ink mt-[4px]">{{ Math.round(vehicle.body_health / 10) }}%</div>
								<div class="font-mono text-[8px] tracking-[0.06em] uppercase text-faint">{{ t("vehicles.body") }}</div>
							</div>
							<div class="text-center">
								<iconify-icon icon="tabler:engine" width="16" class="text-faint"></iconify-icon>
								<div class="text-[13px] font-bold text-ink mt-[4px]">{{ Math.round(vehicle.engine_health / 10) }}%</div>
								<div class="font-mono text-[8px] tracking-[0.06em] uppercase text-faint">{{ t("vehicles.engine") }}</div>
							</div>
						</div>

						<div class="flex gap-[8px] mt-[14px]">
							<button
								class="ghost-btn"
								type="button"
								:disabled="busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)"
								:style="{ opacity: (busyVehicleId === vehicle.id || (vehicle.body_health >= 1000 && vehicle.engine_health >= 1000)) ? 0.4 : 1 }"
								@click="repair(vehicle)"
							>
								{{ t("vehicles.repair_cost", { cost: formatMoney(estimateRepairCost(vehicle)) }) }}
							</button>
							<button
								v-if="vehicle.state === 'stored'"
								class="accent-btn shrink-0 py-[10px] px-[16px] text-[12px]"
								type="button"
								:disabled="busyVehicleId === vehicle.id"
								@click="parkOut(vehicle)"
							>
								{{ t("vehicles.park_out") }}
							</button>
							<button
								v-else-if="vehicle.state === 'deployed'"
								class="accent-btn shrink-0 py-[10px] px-[16px] text-[12px]"
								type="button"
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
			<div class="flex items-center justify-between mb-[14px]">
				<div>
					<div class="text-[20px] font-extrabold tracking-[-0.01em] text-ink">{{ t("vehicles.purchase_heading") }}</div>
					<div class="font-mono text-[11px] text-faint mt-[4px]">{{ t("vehicles.purchase_sub") }}</div>
				</div>
			</div>
			<div class="grid grid-cols-[repeat(4,1fr)] gap-[14px]">
				<div v-for="tier in vehicleTiers" :key="tier.id" class="bg-white border border-line rounded-[15px] overflow-hidden flex flex-col">
					<div class="relative">
						<div class="w-full h-[128px] bg-[#f3f4f6] flex items-center justify-center bg-cover bg-center" :style="vehicleImage(tier.model) ? { backgroundImage: `url(${vehicleImage(tier.model)})` } : {}">
							<iconify-icon v-if="!vehicleImage(tier.model)" icon="tabler:truck" width="40" class="text-[#aab0b8]"></iconify-icon>
						</div>
						<div v-if="isTierLocked(tier)" class="absolute inset-0 bg-[rgba(34,38,45,0.55)] flex items-center justify-center">
							<iconify-icon icon="tabler:lock" width="26" class="text-white"></iconify-icon>
						</div>
						<span v-else-if="isTierOwned(tier)" class="absolute top-[12px] right-[12px] font-mono text-[9px] tracking-[0.06em] py-[3px] px-[8px] rounded-[6px] uppercase bg-[rgba(34,197,94,0.16)] text-[#15803d]">{{ t("vehicles.owned_badge") }}</span>
					</div>
					<div class="p-[14px] flex flex-col flex-1">
						<div class="text-[14px] font-bold text-ink leading-[1.2]">{{ tier.label }}</div>
						<div class="flex gap-[12px] mt-[12px] pt-[12px] border-t border-t-surface-sunken">
							<span class="inline-flex items-center gap-[4px] text-[11px] text-muted"><iconify-icon icon="tabler:star" width="14" class="text-[#aab0b8]"></iconify-icon>{{ t("vehicles.level_plus", { level: tier.level_required }) }}</span>
							<span v-if="tier.damage_resistance > 0" class="inline-flex items-center gap-[4px] text-[11px] text-muted"><iconify-icon icon="tabler:shield" width="14" class="text-[#aab0b8]"></iconify-icon>{{ t("vehicles.damage_resist", { percent: Math.round(tier.damage_resistance * 100) }) }}</span>
						</div>
						<div class="mt-[14px] flex items-center justify-between gap-[8px]">
							<span class="text-[15px] font-extrabold text-ink">{{ formatMoney(tier.price) }}</span>
							<span v-if="isTierLocked(tier)" class="font-mono text-[10px] py-[7px] px-[11px] rounded-[9px] bg-surface-muted text-faint">{{ t("common.level_short", { level: tier.level_required }) }}</span>
							<span v-else-if="isTierOwned(tier)" class="font-mono text-[10px] py-[7px] px-[11px] rounded-[9px] bg-surface-sunken text-muted">{{ t("vehicles.owned_badge") }}</span>
							<button v-else class="accent-btn py-[8px] px-[15px] text-[12px]" type="button" :disabled="purchasingTierId === tier.id" @click="purchase(tier)">
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
.ghost-btn {
	flex: 1;
	padding: 10px;
	border-radius: 10px;
	border: 1px solid var(--border);
	background: #fff;
	color: var(--ink-soft);
	font-family: inherit;
	font-weight: 600;
	font-size: 12px;
	cursor: pointer;
}
.ghost-btn:hover:not(:disabled) {
	border-color: var(--accent);
}
</style>
