extends RefCounted
class_name NeighborhoodV05
## Leonardo L1b — BASE ARCHITECTURE (FARM COUNTRY).
## World: +X east, +Z south. Origin = central farm-road crossing.
##
## L2 eng short ids, L3 tower rules, and L4 PM room names stay SoT.
## Layout / spacing follows L1b (open parcels, ~80 m scale), not the old
## tight cul-de-sac ring.

## Leonardo L2 SoT — eng short ids (docs/blueprints/v0.5/L2_child_rng_spawns.csv).
const SPAWN_IDS: Array[String] = [
	"pm_attic",
	"master_bedroom",
	"bunker_utility",
	"basement",
	"uncle_bedroom",
	"uncle_garage",
	"family_shed",
	"storm_drain",
	"under_porch_crawl",
	"garden_well",
	"car_trunk",
]

const EXPECTED_PIN_COUNT: int = 11
## L1b playable span target (building origins, not the outer terrain).
const NEIGHBORHOOD_SPAN_M: float = 80.0

## PR #27 sealed interiors underground. Host Match is a playable graybox farm.
const OUTDOOR_ONLY: bool = false
const GRAYBOX_NEIGHBORHOOD: bool = true

const HUB := Vector3(0, 0, 0)
## Kept so older callers compile; L1b has a road hub, not a 9 m ring.
const CUL_DE_SAC := Vector3(0, 0, 0)
const BULB_RADIUS: float = 4.2
const STEM_WIDTH: float = 5.0
const STEM_LENGTH: float = 18.0
const FAMILY_RING: float = 0.0

## Leonardo family-house kit (1 grid = 0.5 m).
const FAMILY_HOUSE_SIZE := Vector3(13.5, 2.7, 11.0)
const UNCLE_HOUSE_SIZE := Vector3(10.0, 2.8, 8.0)
const UNCLE_GARAGE_SIZE := Vector3(6.4, 2.7, 7.2)
const MANSION_SIZE := Vector3(20.0, 3.2, 16.0)

## L1b parcels — spaced rural footprints, not a 9.2 m cul-de-sac.
const FAMILY_HOUSES: Array[Dictionary] = [
	{"letter": "A", "index": 0, "origin": Vector3(-32.0, 0, -20.0), "yaw": 0.55},
	{"letter": "B", "index": 1, "origin": Vector3(-44.0, 0, 10.0), "yaw": -PI / 2.0},
	{"letter": "C", "index": 2, "origin": Vector3(8.0, 0, -28.0), "yaw": 0.0},
	{"letter": "D", "index": 3, "origin": Vector3(6.0, 0, 32.0), "yaw": PI},
]

const UNCLE_ORIGIN := Vector3(-12.0, 0, 8.0)
const UNCLE_YAW: float = -PI / 2.0

## L1b: garage sits northeast of the PM mansion, not glued to the uncle house.
const UNCLE_GARAGE_ORIGIN := Vector3(48.0, 0, -18.0)
const UNCLE_GARAGE_YAW: float = PI / 2.0

const MANSION_ORIGIN := Vector3(36.0, 0, -4.0)
const MANSION_YAW: float = -PI / 2.0

const FAMILY_SHED_POS := Vector3(-52.0, 0, -38.0)
const STORM_DRAIN_POS := Vector3(2.4, 0, 3.0)
const GARDEN_WELL_POS := Vector3(-24.0, 0, -26.0)
const CAR_TRUNK_POS := Vector3(10.0, 0, 3.6)
const SOFT_ESCAPE_POS := Vector3(-60.0, 0.5, 10.0)
const MANSION_COURTYARD := Vector3(24.0, 0.12, -4.0)

## Fallback Host Match pads (builders write the live porch / courtyard markers).
const OUTDOOR_FAMILY_SPAWNS: Array[Vector3] = [
	Vector3(-32.0, 0.12, -13.5),
	Vector3(-36.5, 0.12, 10.0),
	Vector3(8.0, 0.12, -20.5),
	Vector3(6.0, 0.12, 24.5),
]
const OUTDOOR_PM_SPAWN := Vector3(24.0, 0.12, -4.0)
const OUTDOOR_SPAWN_Y_MIN: float = -0.35

const PM_L4_ROOMS: Array[String] = [
	"Attic",
	"MasterBedroom",
	"Study",
	"Kitchen",
	"Dining",
	"Living",
	"Bathroom",
	"Hallway",
	"Stairwell",
	"Basement",
	"Bunker",
	"UtilityCloset",
	"DuctSystem",
]

const TOWER_CANDIDATES: Array[Dictionary] = [
	{"id": "pm_gate", "pos": Vector3(26.0, 0, -2.5)},
	{"id": "pm_east", "pos": Vector3(50.0, 0, -4.0)},
	{"id": "pm_north", "pos": Vector3(36.0, 0, -20.0)},
	{"id": "pm_south", "pos": Vector3(36.0, 0, 12.0)},
	{"id": "hub", "pos": Vector3(0, 0, 0)},
	{"id": "house_a", "pos": Vector3(-28.0, 0, -16.0)},
	{"id": "house_b", "pos": Vector3(-40.0, 0, 6.0)},
	{"id": "house_d", "pos": Vector3(8.0, 0, 26.0)},
	{"id": "uncle_yard", "pos": Vector3(-16.0, 0, 8.0)},
	{"id": "shed_hill", "pos": Vector3(-48.0, 0, -34.0)},
	{"id": "garden", "pos": Vector3(-22.0, 0, -24.0)},
	{"id": "field_west", "pos": Vector3(-36.0, 0, 22.0)},
	{"id": "field_south", "pos": Vector3(18.0, 0, 38.0)},
	{"id": "lane_north", "pos": Vector3(0.0, 0, -22.0)},
]

const PHONE_SPOTS: Array[Dictionary] = [
	{"id": "house_a_porch", "pos": Vector3(-30.4, 0.2, -14.8)},
	{"id": "house_b_porch", "pos": Vector3(-38.2, 0.2, 10.0)},
	{"id": "uncle_phone", "pos": Vector3(-8.2, 0.2, 8.0)},
	{"id": "mansion_gate_phone", "pos": Vector3(22.5, 0.2, -2.4)},
]

## Shared by OutdoorBuilder (meshes) and OutdoorTerrain (flatten).
const ROAD_SPANS: Array[Dictionary] = [
	{"a": Vector2(-58.0, 0.0), "b": Vector2(54.0, 0.0), "r": 3.4},
	{"a": Vector2(0.0, -42.0), "b": Vector2(0.0, 44.0), "r": 3.0},
	{"a": Vector2(-16.0, -14.0), "b": Vector2(16.0, -14.0), "r": 2.6},
	{"a": Vector2(-16.0, 14.0), "b": Vector2(16.0, 14.0), "r": 2.6},
	{"a": Vector2(-16.0, -14.0), "b": Vector2(-16.0, 14.0), "r": 2.6},
	{"a": Vector2(16.0, -14.0), "b": Vector2(16.0, 14.0), "r": 2.6},
	{"a": Vector2(16.0, 0.0), "b": Vector2(30.0, -4.0), "r": 3.2},
	{"a": Vector2(-32.0, -8.0), "b": Vector2(-16.0, 0.0), "r": 2.4},
	{"a": Vector2(-44.0, 10.0), "b": Vector2(-16.0, 0.0), "r": 2.4},
	{"a": Vector2(0.0, 14.0), "b": Vector2(6.0, 26.0), "r": 2.4},
	{"a": Vector2(0.0, -14.0), "b": Vector2(8.0, -24.0), "r": 2.4},
	{"a": Vector2(-32.0, -20.0), "b": Vector2(-48.0, -36.0), "r": 2.2},
]

const BUILDING_PADS: Array[Dictionary] = [
	{"pos": Vector2(-32.0, -20.0), "r": 11.0},
	{"pos": Vector2(-44.0, 10.0), "r": 11.0},
	{"pos": Vector2(8.0, -28.0), "r": 11.0},
	{"pos": Vector2(6.0, 32.0), "r": 11.0},
	{"pos": Vector2(-12.0, 8.0), "r": 9.0},
	{"pos": Vector2(36.0, -4.0), "r": 14.0},
	{"pos": Vector2(48.0, -18.0), "r": 6.0},
	{"pos": Vector2(-52.0, -38.0), "r": 4.5},
	{"pos": Vector2(24.0, -4.0), "r": 8.0},
]


static func spawn_id_list() -> Array[String]:
	return SPAWN_IDS.duplicate()


static func family_letter(index: int) -> String:
	if index < 0 or index >= FAMILY_HOUSES.size():
		return "?"
	return str(FAMILY_HOUSES[index]["letter"])
