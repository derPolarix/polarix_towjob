import type { VehicleColors } from "@/types/dashboard";

export type DeliveryPhase = "searching" | "attached";

export interface ActiveDeliveryUpdate {
  deliveryId: number;
  state: DeliveryPhase;
  missionName: string;
  vehicleLabel: string;
  vehicleColors: VehicleColors | null;
  distance: number;
  damagePercent?: number;
  secondsRemaining?: number;
}
