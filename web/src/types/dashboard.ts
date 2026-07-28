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

export interface Mission {
  id: string;
  name: string;
  vehicle_label: string;
  vehicle_colors: VehicleColors | null;
  reward_base: number;
  xp_base: number;
  difficulty: MissionDifficulty;
  time_limit_minutes: number | null;
  level_required: number;
  distance: number;
}

export interface MissionAreaGroup {
  area_id: string;
  area_name: string;
  region: string;
  missions: Mission[];
}

export interface MapArea {
  id: string;
  name: string;
  region: string;
  map_x: number;
  map_y: number;
  unlock_cost: number;
  level_required: number;
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

export interface AcceptMissionResult {
  ok: boolean;
  reason?: string;
  deliveryId?: number;
  /** True when the player owns 2+ tow trucks — the Dashboard must stay open until
   * they Park Out one themselves; the client resumes the delivery once that happens. */
  needsParkOut?: boolean;
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
  missions: MissionAreaGroup[];
  areas: MapArea[];
  vehicles: OwnedVehicle[];
  vehicleTiers: VehicleTier[];
  repairCostPerHealthPoint: number;
  activeDelivery: ActiveDeliverySummary | null;
  skillBranches: SkillBranch[];
}

export type TabKey =
  | "overview"
  | "jobs"
  | "map"
  | "vehicles"
  | "leaderboard"
  | "skilltree"
  | "history";
