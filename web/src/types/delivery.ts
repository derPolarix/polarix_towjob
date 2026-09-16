import type { VehicleColors } from "@/types/dashboard";

export type DeliveryPhase = "searching" | "found";

export interface ActiveDeliveryUpdate {
  deliveryId: number;
  state: DeliveryPhase;
  isPriority: boolean;
  missionName: string;
  vehicleLabel: string;
  vehicleColors: VehicleColors | null;
  distance: number;
  damagePercent?: number;
  secondsRemaining?: number;
}
