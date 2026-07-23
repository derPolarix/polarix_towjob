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

export interface DashboardPayload {
  player: PlayerData;
  levelTitles: string[];
  xpThresholds: number[];
  unlockedAreaIds: string[];
  missions: unknown[]; // populated in Phase 5
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
