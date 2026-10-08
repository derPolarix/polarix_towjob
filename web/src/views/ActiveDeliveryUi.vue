<template>
	<div v-if="data" class="hud-anchor">
		<div class="hud-card">
			<div class="hud-stripe" />

			<div class="hud-label">
				<span v-if="data.isPriority" class="hud-chip">{{ t("hud.priority") }}</span>
				<span class="hud-mission">{{ data.missionName }}</span>
			</div>

			<div class="hud-objective">
				{{ data.state === "searching" ? t("hud.find_vehicle") : t("hud.tow_to_dropoff") }}
			</div>

			<div v-if="data.state === 'searching'" class="hud-vehicle">
				{{ data.vehicleLabel }}
				<span v-if="colorLabel"> · {{ colorLabel }}</span>
			</div>

			<div class="hud-distance">{{ t("hud.distance_away", { distance: data.distance }) }}</div>

			<div v-if="data.damagePercent !== undefined" class="hud-damage">
				<div class="hud-damage-fill" :style="{ width: data.damagePercent + '%' }" />
			</div>

			<div v-if="formattedTime" class="hud-time" :class="{ 'hud-time-low': isTimeLow }">{{ formattedTime }}</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useActiveDeliveryStore } from "@/stores/activeDeliveryStore";
import { vehicleColorName } from "@/utils/vehicleColors";

const LOW_TIME_SECONDS = 60;

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

const isTimeLow = computed(() => {
	const seconds = data.value?.secondsRemaining;
	return seconds !== undefined && seconds <= LOW_TIME_SECONDS;
});
</script>

<style scoped>
.hud-anchor {
	--accent: #22c55e;
	position: absolute;
	top: 24px;
	left: 50%;
	transform: translateX(-50%);
	font-family: 'Archivo', system-ui, sans-serif;
}

.hud-card {
	position: relative;
	min-width: 280px;
	max-width: 420px;
	padding: 16px 18px 12px;
	border-radius: 14px;
	border: 1px solid #353b45;
	background: rgba(34, 38, 45, 0.92);
	box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
	overflow: hidden;
	text-align: center;
}

.hud-stripe {
	position: absolute;
	left: 0;
	right: 0;
	top: 0;
	height: 3px;
	background: repeating-linear-gradient(45deg, var(--accent) 0 8px, #2e333b 8px 16px);
	opacity: 0.55;
}

.hud-label {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 6px;
	font-family: 'IBM Plex Mono', monospace;
	font-size: 10px;
	letter-spacing: 0.12em;
	text-transform: uppercase;
	color: #7a818c;
}

.hud-chip {
	padding: 2px 6px;
	border-radius: 5px;
	background: rgba(59, 130, 246, 0.18);
	color: #60a5fa;
	font-weight: 600;
	letter-spacing: 0.08em;
}

.hud-objective {
	margin-top: 6px;
	font-size: 15px;
	font-weight: 700;
	color: #fff;
}

.hud-vehicle {
	margin-top: 4px;
	font-size: 12px;
	color: #c9ced6;
}

.hud-distance {
	margin-top: 4px;
	font-family: 'IBM Plex Mono', monospace;
	font-size: 11px;
	color: #9aa1ab;
}

.hud-damage {
	margin-top: 10px;
	height: 5px;
	border-radius: 3px;
	overflow: hidden;
	background: #3a414b;
}

.hud-damage-fill {
	height: 100%;
	background: #d24b3a;
}

.hud-time {
	margin-top: 8px;
	font-family: 'IBM Plex Mono', monospace;
	font-size: 12px;
	font-weight: 600;
	color: var(--accent);
}

.hud-time-low {
	color: #d24b3a;
}
</style>
