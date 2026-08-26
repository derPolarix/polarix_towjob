// Dev-only fixture data — `npm run dev` has no NUI runtime, so nuiCallbackAsync no-ops and
// every store stays empty by default. Seeding realistic data here means the design can
// actually be looked at (cards, tables, skill tree, pager, etc.) without a live FiveM server.
// Never imported by the production build path in App.vue except behind `if (isDev)`.
import type { DashboardPayload } from "@/types/dashboard";
import type { AdminArea, AdminMission, AdminSetting } from "@/types/admin";

export const sampleDashboardPayload: DashboardPayload = {
	player: {
		identifier: "dev:sample",
		name: "DevDriver",
		level: 4,
		xp: 620,
		skill_points: 3,
		skills: ["p1"],
		total_earnings: 18450,
		total_deliveries: 23,
		failed_deliveries: 2,
		aborted_deliveries: 1,
	},
	levelTitles: ["Trainee", "Junior Operator", "Operator", "Senior Operator", "Recovery Specialist"],
	xpThresholds: [0, 150, 400, 800, 1400, 2200],
	unlockedAreaIds: ["area_default"],
	areas: [
		{ id: "area_default", name: "Los Santos Central", region: "Los Santos", points: [{ x: 1700, y: 2700 }, { x: 2300, y: 2700 }, { x: 2300, y: 3300 }, { x: 1700, y: 3300 }], unlock_cost: 0, level_required: 1, reward_multiplier: 1.0, xp_multiplier: 1.0, note: null, is_default: true, unlocked: true },
		{ id: "area_paleto", name: "Paleto Bay", region: "Blaine County", points: [{ x: 1650, y: 650 }, { x: 2150, y: 650 }, { x: 2150, y: 1150 }, { x: 1650, y: 1150 }], unlock_cost: 750, level_required: 2, reward_multiplier: 1.5, xp_multiplier: 1.2, note: "High traffic", is_default: false, unlocked: false },
	],
	vehicles: [
		{ id: 1, tier_id: "standard", label: "Standard Flatbed", model: "towtruck2", plate: "TOW001", body_health: 820, engine_health: 940, state: "stored" },
		{ id: 2, tier_id: "heavy", label: "Heavy Duty Tow", model: "towtruck", plate: "TOW002", body_health: 1000, engine_health: 1000, state: "deployed" },
	],
	vehicleTiers: [
		{ id: "standard", model: "towtruck2", label: "Standard Flatbed", price: 45000, damage_resistance: 0.0, level_required: 1 },
		{ id: "heavy", model: "towtruck", label: "Heavy Duty Tow", price: 95000, damage_resistance: 0.20, level_required: 5 },
	],
	repairCostPerHealthPoint: 0.6,
	activeDelivery: null,
	skillBranches: [
		{
			name: "Precision", icon: "tabler:target", skills: [
				{ id: "p1", name: "Steady Rigging", desc: "Reduces damage penalty on towed vehicles.", cost: 1, requires: null, effects: { damage_penalty_reduction: 0.15 } },
				{ id: "p2", name: "Firm Grip", desc: "Further reduces towed-vehicle damage accrual.", cost: 2, requires: "p1", effects: { damage_penalty_reduction: 0.30 } },
			],
		},
		{
			name: "Economy", icon: "tabler:coin", skills: [
				{ id: "e1", name: "Fair Rates", desc: "Increases delivery payout.", cost: 1, requires: null, effects: { payout_bonus: 0.10 } },
				{ id: "e2", name: "Bulk Discount", desc: "Reduces vehicle purchase and repair costs.", cost: 2, requires: "e1", effects: { purchase_discount: 0.15, repair_discount: 0.15 } },
			],
		},
		{
			name: "Access", icon: "tabler:map-pin", skills: [
				{ id: "a1", name: "Field Certified", desc: "Unlocks timed/harder missions at a lower level.", cost: 1, requires: null, effects: { level_requirement_reduction: 2 } },
				{ id: "a2", name: "Local Rates", desc: "Reduces area unlock costs.", cost: 2, requires: "a1", effects: { area_unlock_discount: 0.20 } },
			],
		},
	],
	onCall: false,
	rentalActive: false,
	rentalPricePerCharge: 150,
	rentalIntervalMinutes: 15,
	rentalTruckLabel: "Rental Flatbed",
};

export const sampleAdminMissions: AdminMission[] = [
	{
		id: "mission_stalled_sedan", area_id: "area_default", area_name: "Los Santos Central", name: "Stalled Sedan on Innocence Blvd",
		vehicle_model: "asea", vehicle_label: "Declasse Asea", vehicle_colors: { primary: 0, secondary: 0 },
		search_center_x: 120.0, search_center_y: 80.0, search_center_z: 30.0, search_radius: 60.0,
		dropoff_x: 200.0, dropoff_y: 80.0, dropoff_z: 30.0, dropoff_heading: 90.0, dropoff_width: 6.0, dropoff_length: 10.0,
		reward_base: 350, xp_base: 40, time_limit_minutes: null, difficulty: "easy", level_required: 1,
		is_active: true, created_by: "dev", updated_by: "dev", delivery_count: 12,
	},
	{
		id: "mission_rush_hour_recovery", area_id: "area_default", area_name: "Los Santos Central", name: "Rush Hour Recovery",
		vehicle_model: "issi2", vehicle_label: "Weeny Issi", vehicle_colors: { primary: 3, secondary: 3 },
		search_center_x: 60.0, search_center_y: -200.0, search_center_z: 35.0, search_radius: 80.0,
		dropoff_x: 10.0, dropoff_y: -200.0, dropoff_z: 35.0, dropoff_heading: 0.0, dropoff_width: 6.0, dropoff_length: 10.0,
		reward_base: 800, xp_base: 110, time_limit_minutes: 8, difficulty: "medium", level_required: 3,
		is_active: true, created_by: "dev", updated_by: "dev", delivery_count: 4,
	},
];

export const sampleAdminAreas: AdminArea[] = [
	{ id: "area_default", name: "Los Santos Central", region: "Los Santos", points: [{ x: 1700, y: 2700 }, { x: 2300, y: 2700 }, { x: 2300, y: 3300 }, { x: 1700, y: 3300 }], unlock_cost: 0, level_required: 1, reward_multiplier: 1.0, xp_multiplier: 1.0, note: null, is_default: true, is_active: true },
	{ id: "area_paleto", name: "Paleto Bay", region: "Blaine County", points: [{ x: 1650, y: 650 }, { x: 2150, y: 650 }, { x: 2150, y: 1150 }, { x: 1650, y: 1150 }], unlock_cost: 750, level_required: 2, reward_multiplier: 1.5, xp_multiplier: 1.2, note: "High traffic", is_default: false, is_active: true },
];

export const sampleAdminSettings: AdminSetting[] = [
	{ key: "damage_penalty_cap_percent", label: "Damage penalty cap (%)", value: 0.30, default: 0.30 },
	{ key: "reward_multiplier", label: "Reward multiplier", value: 1.0, default: 1.0 },
	{ key: "xp_multiplier", label: "XP multiplier", value: 1.0, default: 1.0 },
	{ key: "rental_price_per_charge", label: "Rental price per charge", value: 150, default: 150 },
	{ key: "rental_interval_minutes", label: "Rental interval (minutes)", value: 15, default: 15 },
	{ key: "repair_cost_per_health_point", label: "Repair cost per health point", value: 0.6, default: 0.6 },
	{ key: "delivery_heading_tolerance", label: "Delivery heading tolerance (deg)", value: 25, default: 25 },
];
