// GTA V world-coordinate <-> Leaflet CRS.Simple pixel-space conversion for the reused
// gta_map.jpg overlay. Same image and constants as polarix_truckerjob's OrderRouteMap.vue
// (originally from vinewood_blipmanager). Area polygons and any future map markers are
// stored in GTA world coords and converted here at render time.
import L from "leaflet";

export const IMG_WIDTH = 4096;
export const IMG_HEIGHT = 6144;

// Full-image bounds for L.imageOverlay / map.fitBounds under CRS.Simple.
export const MAP_IMAGE_BOUNDS: L.LatLngBoundsExpression = [
	[0, 0],
	[IMG_HEIGHT, IMG_WIDTH],
];

const SCALE_X = 0.454685;
const SCALE_Y = -0.45483;
const OFFSET_X = 1882.72;
const OFFSET_Y = 3826.58;

export function gtaToLatLng(x: number, y: number): L.LatLngTuple {
	const lng = x * SCALE_X + OFFSET_X;
	const lat = IMG_HEIGHT - (y * SCALE_Y + OFFSET_Y);
	return [lat, lng];
}

export function latLngToGta(lat: number, lng: number): { x: number; y: number } {
	return {
		x: (lng - OFFSET_X) / SCALE_X,
		y: (IMG_HEIGHT - lat - OFFSET_Y) / SCALE_Y,
	};
}
