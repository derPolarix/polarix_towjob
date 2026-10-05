<template>
	<div
		v-if="dashboardStore.rentalPromptOpen"
		class="fixed inset-0 bg-[rgba(15,17,21,0.55)] flex items-center justify-center z-[9999] font-ui"
		@click.self="closeModal"
	>
		<div class="bg-white rounded-[16px] py-[26px] px-[28px] max-w-[420px] w-[90%] [box-shadow:0_20px_60px_rgba(0,0,0,0.25)]">
			<div class="w-[52px] h-[52px] rounded-[14px] bg-[rgba(34,197,94,0.14)] flex items-center justify-center mb-[16px]">
				<iconify-icon icon="tabler:truck" width="26" class="text-accent"></iconify-icon>
			</div>
			<div class="text-[17px] font-extrabold text-ink">{{ t("rental.prompt_title") }}</div>
			<div class="text-[13px] text-muted mt-[8px] leading-[1.6]">
				<i18n-t keypath="rental.prompt_body" tag="span">
					<template #price><strong>{{ formatMoney(dashboardStore.payload?.rentalPricePerCharge) }}</strong></template>
					<template #minutes><strong>{{ dashboardStore.payload?.rentalIntervalMinutes ?? 0 }}</strong></template>
				</i18n-t>
			</div>
			<p v-if="errorMessage" class="mt-[14px] mx-0 mb-0 text-[12px] text-danger-text">{{ errorMessage }}</p>
			<div class="flex gap-[10px] mt-[20px]">
				<button
					class="accent-btn flex-1 p-[12px] text-[13px] justify-center"
					type="button"
					:disabled="isRenting"
					@click="confirmRent"
				>
					{{ isRenting ? t("rental.renting") : t("rental.rent_now") }}
				</button>
				<button
					type="button"
					class="flex-1 bg-white text-muted border border-line-soft rounded-[11px] p-[12px] font-[inherit] font-semibold text-[13px] cursor-pointer"
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
