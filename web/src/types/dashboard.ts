export interface PlayerData {
  identifier: string;
  name: string;
  level: number;
  xp: number;
  skill_points: number;
  skills: string[];
  total_earnings: number;
  total_deliveries: number;
  failed_deliveries: number;
  aborted_deliveries: number;
}

export interface VehicleColors {
  primary: number;
  secondary: number;
}

export type MissionDifficulty = "easy" | "medium" | "hard";

/** Sent when the on-call pager pings with a randomly-picked job (server/modules/oncall.lua).
 * No `vehicle_colors`/exact coords — same "don't show exact point" rule the old Available
 * Jobs list followed, now enforced by construction since there's no longer a browsable list. */
export interface PagerOffer {
  id: string;
  name: string;
  vehicle_label: string;
  difficulty: MissionDifficulty;
  reward_base: number;
  xp_base: number;
  time_limit_minutes: number | null;
  level_required: number;
  area_name: string;
  expiresAt: number;
  /** Police-marked tow request (server/modules/priority.lua) rather than a mission template. */
  is_priority?: boolean;
}

export interface MapAreaPoint {
  x: number;
  y: number;
}

export interface MapArea {
  id: string;
  name: string;
  region: string;
  points: MapAreaPoint[];
  unlock_cost: number;
  level_required: number;
  reward_multiplier: number;
  xp_multiplier: number;
  note: string | null;
  is_default: boolean;
  unlocked: boolean;
}

export interface UnlockAreaResult {
  ok: boolean;
  reason?: string;
  areaId?: string;
  unlockedAreaIds?: string[];
}

export type VehicleState = "stored" | "deployed";

export interface OwnedVehicle {
  id: number;
  tier_id: string;
  label: string;
  model: string;
  plate: string;
  body_health: number;
  engine_health: number;
  state: VehicleState;
}

export interface VehicleTier {
  id: string;
  model: string;
  label: string;
  price: number;
  damage_resistance: number;
  level_required: number;
}

export interface VehicleActionResult {
  ok: boolean;
  reason?: string;
  cost?: number;
  vehicles?: OwnedVehicle[];
  /** Set by the client's `parkOutVehicle` NUI callback when this Park Out also resumed a
   * mission accepted earlier via the 2+ owned vehicles path (see AcceptMissionResult.needsParkOut). */
  missionStarted?: boolean;
}

export interface ToggleOnCallResult {
  ok: boolean;
  reason?: string;
  onCall?: boolean;
}

/** Response to the "Get rental truck" confirm — used only for a zero-owned-vehicle
 * player going on-call for the first time (see OverviewTab's rental-prompt flow). */
export interface StartStandaloneRentalResult {
  ok: boolean;
  reason?: string;
  onCall?: boolean;
}

export interface ReturnRentalResult {
  ok: boolean;
  reason?: string;
}

export interface AcceptPageResult {
  ok: boolean;
  reason?: string;
  deliveryId?: number;
  deadlineAt?: number | null;
}

export interface DeclinePageResult {
  ok: boolean;
  reason?: string;
}

export interface SkillEffects {
  damage_penalty_reduction?: number;
  payout_bonus?: number;
  purchase_discount?: number;
  repair_discount?: number;
  level_requirement_reduction?: number;
  area_unlock_discount?: number;
}

export interface SkillNode {
  id: string;
  name: string;
  desc: string;
  cost: number;
  requires: string | null;
  effects: SkillEffects;
}

export interface SkillBranch {
  name: string;
  icon: string;
  skills: SkillNode[];
}

export interface UnlockSkillResult {
  ok: boolean;
  reason?: string;
  player?: PlayerData;
}

export interface ActiveDeliverySummary {
  deliveryId: number;
  missionName: string;
}

export interface AbortDeliveryResult {
  ok: boolean;
  reason?: string;
}

export type DeliveryStatus = "active" | "completed" | "failed" | "aborted";

export interface LeaderboardEntry {
  rank: number;
  name: string;
  level: number;
  total_earnings: number;
}

export interface LeaderboardResult {
  entries: LeaderboardEntry[];
  own: LeaderboardEntry | null;
}

export interface DeliveryHistoryEntry {
  id: number;
  missionName: string;
  status: DeliveryStatus;
  rewardPaid: number;
  xpPaid: number;
  damagePenalty: number;
  startedAt: string;
  completedAt: string | null;
}

export interface RecentDeliveriesResult {
  entries: DeliveryHistoryEntry[];
}

export interface DeliveryHistoryResult {
  entries: DeliveryHistoryEntry[];
  total: number;
  offset: number;
  pageSize: number;
}

export interface DashboardPayload {
  player: PlayerData;
  levelTitles: string[];
  xpThresholds: number[];
  unlockedAreaIds: string[];
  areas: MapArea[];
  vehicles: OwnedVehicle[];
  vehicleTiers: VehicleTier[];
  repairCostPerHealthPoint: number;
  activeDelivery: ActiveDeliverySummary | null;
  skillBranches: SkillBranch[];
  onCall: boolean;
  rentalActive: boolean;
  rentalPricePerCharge: number;
  rentalIntervalMinutes: number;
  rentalTruckLabel: string;
}

export type TabKey =
  | "overview"
  | "areas"
  | "vehicles"
  | "leaderboard"
  | "skilltree"
  | "history";
