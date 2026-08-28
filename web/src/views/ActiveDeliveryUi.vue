<template>
	<div v-if="data" class="absolute top-6 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 text-white">
		<div class="rounded-md bg-neutral-900/80 border border-white/10 px-4 py-2 min-w-[260px] text-center">
			<div class="text-xs uppercase tracking-wide text-white/50">{{ data.missionName }}</div>

			<div class="mt-1 text-sm font-medium">
				{{ data.state === "searching" ? "Find the vehicle" : "Deliver to drop-off" }}
			</div>

			<div v-if="data.state === 'searching'" class="mt-1 text-xs text-white/70">
				{{ data.vehicleLabel }}
				<span v-if="colorLabel"> · {{ colorLabel }}</span>
			</div>

			<div class="mt-1 text-xs text-white/60">{{ data.distance }}m away</div>

			<div v-if="data.damagePercent !== undefined" class="mt-2 h-1.5 overflow-hidden rounded-full bg-neutral-700">
				<div class="h-full bg-red-500" :style="{ width: data.damagePercent + '%' }" />
			</div>

			<div v-if="formattedTime" class="mt-1 text-xs font-semibold text-amber-300">{{ formattedTime }}</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useActiveDeliveryStore } from "@/stores/activeDeliveryStore";
import { vehicleColorName } from "@/utils/vehicleColors";

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
	return `${minutes}:${rest.toString().padStart(2, "0")} remaining`;
});
</script>
