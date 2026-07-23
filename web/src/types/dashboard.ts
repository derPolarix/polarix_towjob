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

export interface DashboardPayload {
  player: PlayerData;
  levelTitles: string[];
  xpThresholds: number[];
  unlockedAreaIds: string[];
  missions: MissionAreaGroup[];
  areas: MapArea[];
  vehicles: unknown[]; // populated in Phase 7
}

export type TabKey =
  | "overview"
  | "jobs"
  | "map"
  | "vehicles"
  | "leaderboard"
  | "skilltree"
  | "history";
