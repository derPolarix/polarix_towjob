<template>
	<div
		v-if="dashboardStore.rentalPromptOpen"
		style="position:fixed;inset:0;background:rgba(15,17,21,0.55);display:flex;align-items:center;justify-content:center;z-index:9999;font-family:'Archivo',system-ui,sans-serif"
		@click.self="closeModal"
	>
		<div style="background:#fff;border-radius:16px;padding:26px 28px;max-width:420px;width:90%;box-shadow:0 20px 60px rgba(0,0,0,0.25)">
			<div style="width:52px;height:52px;border-radius:14px;background:rgba(34,197,94,0.14);display:flex;align-items:center;justify-content:center;margin-bottom:16px">
				<iconify-icon icon="tabler:truck" width="26" style="color:#22c55e"></iconify-icon>
			</div>
			<div style="font-size:17px;font-weight:800;color:#1b1f24">{{ t("rental.prompt_title") }}</div>
			<div style="font-size:13px;color:#6b7280;margin-top:8px;line-height:1.6">
				<i18n-t keypath="rental.prompt_body" tag="span">
					<template #price><strong>{{ formatMoney(dashboardStore.payload?.rentalPricePerCharge) }}</strong></template>
					<template #minutes><strong>{{ dashboardStore.payload?.rentalIntervalMinutes ?? 0 }}</strong></template>
				</i18n-t>
			</div>
			<p v-if="errorMessage" style="margin:14px 0 0;font-size:12px;color:#d24b3a">{{ errorMessage }}</p>
			<div style="display:flex;gap:10px;margin-top:20px">
				<button
					class="accent-btn"
					type="button"
					style="flex:1;padding:12px;font-size:13px;justify-content:center"
					:disabled="isRenting"
					@click="confirmRent"
				>
					{{ isRenting ? t("rental.renting") : t("rental.rent_now") }}
				</button>
				<button
					type="button"
					style="flex:1;background:#fff;color:#6b7280;border:1px solid #e4e6e9;border-radius:11px;padding:12px;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer"
					:disabled="isRenting"
					@click="closeModal"
				>
					{{ t("app.cancel") }}
				</button>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { formatMoney } from "@/lib/uiConfig";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { StartStandaloneRentalResult } from "@/types/dashboard";

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const isRenting = ref(false);
const errorMessage = ref("");

const reasonMessages: Record<string, string> = {
	insufficient_funds: "error.rental_insufficient_funds",
	active_delivery_exists: "error.finish_delivery_before_on_call",
	no_missions_configured: "error.no_missions_configured",
	already_renting: "error.rental_already_active",
	owned_vehicle_exists: "error.owned_vehicle_exists",
	no_player: "error.no_player",
};

watch(
	() => dashboardStore.rentalPromptOpen,
	() => {
		errorMessage.value = "";
	},
);

function closeModal() {
	dashboardStore.closeRentalPrompt();
}

async function confirmRent() {
	isRenting.value = true;
	errorMessage.value = "";

	try {
		const result = await nuiCallbackAsync<StartStandaloneRentalResult>("startStandaloneRental");
		if (result?.ok) {
			dashboardStore.setRentalActive(true);
			dashboardStore.setOnCall(result.onCall ?? true);
			closeModal();
		} else {
			errorMessage.value = t(reasonMessages[result?.reason ?? ""] ?? "error.on_call_update_failed");
		}
	} catch (error) {
		console.error("startStandaloneRental failed:", error);
		errorMessage.value = t("error.on_call_update_failed");
	} finally {
		isRenting.value = false;
	}
}
</script>
