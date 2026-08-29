<template>
	<div class="pager-view">
		<Transition name="pager-slide">
			<div v-if="offer" class="pager-anchor">
				<div class="pager-root">
					<div class="pager-image" :style="{ backgroundImage: `url(${pagerImageUrl})` }" />
					<div class="pager-screen">
						<div class="pager-text">
							<div class="pager-title">{{ t("pager.incoming_job") }} · {{ offer.area_name }}</div>
							<div class="pager-name">{{ offer.name }}</div>
							<div class="pager-meta">
								${{ offer.reward_base }} · +{{ offer.xp_base }} XP
								<span v-if="offer.time_limit_minutes"> · {{ offer.time_limit_minutes }}m</span>
								· <span class="pager-timer">{{ secondsLeft }}s</span>
							</div>
							<div class="pager-actions">
								<button type="button" class="pager-hint pager-hint-accept" :disabled="busy" @click="accept">
									<span class="pager-key"><iconify-icon icon="tabler:corner-down-left" width="8"></iconify-icon>Enter</span>
									{{ t("app.accept") }}
								</button>
								<button type="button" class="pager-hint pager-hint-decline" :disabled="busy" @click="decline">
									<span class="pager-key"><iconify-icon icon="tabler:backspace" width="8"></iconify-icon>Bksp</span>
									{{ t("app.decline") }}
								</button>
							</div>
						</div>
					</div>
				</div>
			</div>
		</Transition>
	</div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useDashboardStore } from "@/stores/dashboardStore";
import { nuiCallbackAsync } from "@/nui/nuiCallbacks";
import type { AcceptPageResult, DeclinePageResult } from "@/types/dashboard";
import pagerImageUrl from "@/assets/pager.png";

const { t } = useI18n();
const dashboardStore = useDashboardStore();
const offer = computed(() => dashboardStore.pagerOffer);
const busy = ref(false);

const now = ref(Date.now());
let tick: ReturnType<typeof setInterval> | undefined;
onMounted(() => { tick = setInterval(() => { now.value = Date.now(); }, 1000); });
onUnmounted(() => { if (tick) clearInterval(tick); });

const secondsLeft = computed(() => {
	if (!offer.value) return 0;
	return Math.max(0, Math.ceil((offer.value.expiresAt * 1000 - now.value) / 1000));
});

// Server-side sweep is authoritative on real expiry (ground rule 4) — this just hides the
// pager locally so a slow client doesn't sit on a stale offer waiting for the next server tick.
watch(secondsLeft, (value) => {
	if (value <= 0 && offer.value) {
		dashboardStore.clearPagerOffer();
	}
});

async function accept() {
	if (!offer.value || busy.value) return;
	busy.value = true;

	try {
		const result = await nuiCallbackAsync<AcceptPageResult>("acceptPage");
		if (result?.ok) {
			dashboardStore.clearPagerOffer();
		}
	} catch (error) {
		console.error("acceptPage failed:", error);
	} finally {
		busy.value = false;
	}
}

async function decline() {
	if (!offer.value || busy.value) return;
	busy.value = true;

	try {
		await nuiCallbackAsync<DeclinePageResult>("declinePage");
	} catch (error) {
		console.error("declinePage failed:", error);
	} finally {
		busy.value = false;
		dashboardStore.clearPagerOffer();
	}
}
</script>

<style scoped>
.pager-view {
	position: fixed;
	inset: 0;
	z-index: 9997;
	pointer-events: none;
	font-family: 'Archivo', system-ui, sans-serif;
}

.pager-anchor {
	position: absolute;
	right: -1rem;
	top: 50%;
	transform: translateY(-50%);
	pointer-events: auto;
}

.pager-root {
	position: relative;
	width: min(460px, 80vw);
	aspect-ratio: 612 / 398;
}

.pager-image {
	position: absolute;
	z-index: 10;
	inset: 0;
	background-repeat: no-repeat;
	background-size: contain;
	background-position: center;
	pointer-events: none;
}

.pager-screen {
	position: absolute;
	z-index: 1;
	left: 22.5%;
	top: 26%;
	width: 55%;
	height: 30%;
	background: #0c0f0c;
	border-radius: 4px;
	overflow: hidden;
	display: flex;
	align-items: center;
}

.pager-text {
	width: 100%;
	padding: 6% 7%;
	text-align: left;
}

.pager-title {
	font-family: 'IBM Plex Mono', monospace;
	font-size: 9px;
	letter-spacing: 0.04em;
	font-weight: 700;
	color: #4ade80;
	line-height: 1.2;
	overflow: hidden;
	text-overflow: ellipsis;
	white-space: nowrap;
}

.pager-name {
	font-size: 11px;
	font-weight: 700;
	color: #fff;
	margin-top: 2px;
	line-height: 1.2;
	overflow: hidden;
	text-overflow: ellipsis;
	white-space: nowrap;
}

.pager-meta {
	font-family: 'IBM Plex Mono', monospace;
	font-size: 8px;
	color: #c9cdd3;
	margin-top: 3px;
	line-height: 1.3;
}

.pager-timer {
	font-family: 'IBM Plex Mono', monospace;
	color: #4ade80;
	font-weight: 700;
}

.pager-actions {
	display: flex;
	flex-direction: column;
	gap: 3px;
	margin-top: 6px;
}

.pager-hint {
	display: flex;
	align-items: center;
	gap: 5px;
	width: 100%;
	padding: 0;
	background: none;
	border: none;
	font-family: 'Archivo', system-ui, sans-serif;
	font-size: 9px;
	font-weight: 700;
	color: #fff;
	text-align: left;
	cursor: pointer;
}
.pager-hint:disabled {
	opacity: 0.5;
	cursor: not-allowed;
}
.pager-hint-decline {
	color: #c9cdd3;
}

.pager-key {
	display: inline-flex;
	align-items: center;
	gap: 2px;
	padding: 1px 4px;
	border-radius: 3px;
	background: #1c211c;
	border: 1px solid #2f362f;
	font-family: 'IBM Plex Mono', monospace;
	font-size: 8px;
	font-weight: 700;
	color: #4ade80;
	line-height: 1;
}
.pager-hint-decline .pager-key {
	color: #9aa1ab;
}

.pager-slide-enter-active,
.pager-slide-leave-active {
	transition: transform 240ms ease, opacity 240ms ease;
}
.pager-slide-enter-from,
.pager-slide-leave-to {
	transform: translateY(-50%) translateX(120%);
	opacity: 0;
}
.pager-slide-enter-to,
.pager-slide-leave-from {
	transform: translateY(-50%) translateX(0%);
	opacity: 1;
}
</style>
