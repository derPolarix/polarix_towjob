export interface AdminVehicleColors {
  primary: number;
  secondary: number;
}

export type AdminMissionDifficulty = "easy" | "medium" | "hard";

// Hand-placed parked-car spots inside the mission's area — one is picked per delivery.
export interface AdminSpawnPoint {
  x: number;
  y: number;
  z: number;
  heading: number;
}

export interface AdminMission {
  id: string;
  area_id: string;
  area_name: string | null;
  name: string;
  vehicle_model: string;
  vehicle_label: string;
  vehicle_colors: AdminVehicleColors;
  spawn_points: AdminSpawnPoint[];
  dropoff_x: number;
  dropoff_y: number;
  dropoff_z: number;
  dropoff_heading: number;
  dropoff_width: number;
  dropoff_length: number;
  reward_base: number;
  xp_base: number;
  time_limit_minutes: number | null;
  difficulty: AdminMissionDifficulty;
  level_required: number;
  is_active: boolean;
  created_by: string | null;
  updated_by: string | null;
  delivery_count: number;
}

export interface AdminAreaPoint {
  x: number;
  y: number;
}

export interface AdminArea {
  id: string;
  name: string;
  region: string;
  points: AdminAreaPoint[];
  unlock_cost: number;
  level_required: number;
  reward_multiplier: number;
  xp_multiplier: number;
  note: string | null;
  is_default: boolean;
  is_active: boolean;
}

export interface AdminSetting {
  key: string;
  label: string;
  value: number;
  default: number;
}

export interface AdminListMissionsResult {
  ok: boolean;
  reason?: string;
  missions?: AdminMission[];
  testActive?: boolean;
}

export interface AdminListAreasResult {
  ok: boolean;
  reason?: string;
  areas?: AdminArea[];
}

export interface AdminGetSettingsResult {
  ok: boolean;
  reason?: string;
  settings?: AdminSetting[];
}

export interface AdminActionResult {
  ok: boolean;
  reason?: string;
  missionId?: string;
  areaId?: string;
  settings?: AdminSetting[];
  /** Set by AdminMissions.TestRun's underlying Missions.Accept response — mirrors
   * AcceptMissionResult so the test-run flow can drive the same client spawn logic. */
  deliveryId?: number;
  needsParkOut?: boolean;
}

export interface AdminCurrentPosition {
  x: number;
  y: number;
  z: number;
  heading: number;
}

export type AdminSection = "missions" | "areas" | "settings";
