<template>
	<div v-if="data" class="absolute top-6 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 text-white">
		<div class="rounded-md bg-neutral-900/80 border border-white/10 px-4 py-2 min-w-[260px] text-center">
			<div class="flex items-center justify-center gap-1.5 text-xs uppercase tracking-wide text-white/50">
				<span
					v-if="data.isPriority"
					class="rounded-sm bg-blue-500/20 px-1.5 py-0.5 text-[10px] font-semibold tracking-wider text-blue-300"
				>
					{{ t("hud.priority") }}
				</span>
				<span>{{ data.missionName }}</span>
			</div>

			<div class="mt-1 text-sm font-medium">
				{{ data.state === "searching" ? t("hud.find_vehicle") : t("hud.tow_to_dropoff") }}
			</div>

			<div v-if="data.state === 'searching'" class="mt-1 text-xs text-white/70">
				{{ data.vehicleLabel }}
				<span v-if="colorLabel"> · {{ colorLabel }}</span>
			</div>

			<div class="mt-1 text-xs text-white/60">{{ t("hud.distance_away", { distance: data.distance }) }}</div>

			<div v-if="data.damagePercent !== undefined" class="mt-2 h-1.5 overflow-hidden rounded-full bg-neutral-700">
				<div class="h-full bg-red-500" :style="{ width: data.damagePercent + '%' }" />
			</div>

			<div v-if="formattedTime" class="mt-1 text-xs font-semibold text-amber-300">{{ formattedTime }}</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useActiveDeliveryStore } from "@/stores/activeDeliveryStore";
import { vehicleColorName } from "@/utils/vehicleColors";

const { t } = useI18n();
const activeDeliveryStore = useActiveDeliveryStore();

const data = computed(() => activeDeliveryStore.data);

const colorLabel = computed(() => {
	const colors = data.value?.vehicleColors;
	if (!colors) return "";
	const primary = vehicleColorName(colors.primary);
	if (colors.primary === colors.secondary) return primary;
	return `${primary} / ${vehicleColorName(colors.secondary)}`;
});

const formattedTime = computed(() => {
	const seconds = data.value?.secondsRemaining;
	if (seconds === undefined) return "";

	const minutes = Math.floor(seconds / 60);
	const rest = seconds % 60;
	return t("hud.time_remaining", { time: `${minutes}:${rest.toString().padStart(2, "0")}` });
});
</script>
