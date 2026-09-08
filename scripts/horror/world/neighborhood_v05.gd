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

## Host Match is authored farm terrain + roads + one hilltop main house.
## No neighborhood of extra houses / bunkers / masts.
const OUTDOOR_ONLY: bool = true
const GRAYBOX_NEIGHBORHOOD: bool = false

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

## L1 farm parcels — hub between A/B/D, long drive east to PM, courtyard south.
const FAMILY_HOUSES: Array[Dictionary] = [
	{"letter": "A", "index": 0, "origin": Vector3(-12.0, 0, -14.0), "yaw": 0.45},
	{"letter": "B", "index": 1, "origin": Vector3(-38.0, 0, -12.0), "yaw": -PI / 2.0},
	{"letter": "C", "index": 2, "origin": Vector3(32.0, 0, 20.0), "yaw": PI},
	{"letter": "D", "index": 3, "origin": Vector3(6.0, 0, 30.0), "yaw": PI},
]

const UNCLE_ORIGIN := Vector3(10.0, 0, 6.0)
const UNCLE_YAW: float = -PI / 2.0

## L1: garage sits east of the PM mansion, not glued to the uncle house.
const UNCLE_GARAGE_ORIGIN := Vector3(56.0, 0, -6.0)
const UNCLE_GARAGE_YAW: float = PI / 2.0

const MANSION_ORIGIN := Vector3(40.0, 0, -6.0)
const MANSION_YAW: float = 0.0

const FAMILY_SHED_POS := Vector3(-50.0, 0, -40.0)
const STORM_DRAIN_POS := Vector3(2.2, 0, 4.0)
const GARDEN_WELL_POS := Vector3(-22.0, 0, -28.0)
const CAR_TRUNK_POS := Vector3(18.0, 0, 3.4)
const SOFT_ESCAPE_POS := Vector3(-62.0, 0.5, 12.0)
const MANSION_COURTYARD := Vector3(40.0, 0.12, 10.0)

## Fallback Host Match pads (builders write the live porch / courtyard markers).
const OUTDOOR_FAMILY_SPAWNS: Array[Vector3] = [
	Vector3(-12.0, 0.12, -7.0),
	Vector3(-30.0, 0.12, -12.0),
	Vector3(32.0, 0.12, 13.0),
	Vector3(6.0, 0.12, 22.0),
]
const OUTDOOR_PM_SPAWN := Vector3(40.0, 0.12, 10.0)
const OUTDOOR_SPAWN_Y_MIN: float = -0.35

## L2 footprint pins — QA v2 plate (terrain/roads/markers) is visual SoT.
## World +X east, +Z south. East oval loop + west shed loop.
## CSV snake_case wins over plate typos (master_become, unclebecome, …).
## Art may stamp a second "1" in the north clearing — only one pm_attic.
const L2_WORLD_MARKERS := {
	"pm_attic": Vector3(30.0, 0, -14.0),
	"master_bedroom": Vector3(30.0, 0, -7.0),
	"bunker_utility": Vector3(30.0, 0, 0.0),
	"basement": Vector3(28.0, 0, 7.0),
	"uncle_bedroom": Vector3(50.0, 0, -12.0),
	"uncle_garage": Vector3(52.0, 0, -2.0),
	"family_shed": Vector3(-50.0, 0, -40.0),
	"storm_drain": Vector3(-40.0, 0, -18.0),
	"under_porch_crawl": Vector3(50.0, 0, 16.0),
	"garden_well": Vector3(16.0, 0, -6.0),
	"car_trunk": Vector3(0.0, 0, 16.0),
}

const SHED_LOOP := Vector2(-50.0, -40.0)
const SHED_LOOP_RADIUS: float = 4.8

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
	{"id": "pm_gate", "pos": Vector3(38.0, 0, 8.0)},
	{"id": "pm_east", "pos": Vector3(54.0, 0, -6.0)},
	{"id": "pm_north", "pos": Vector3(40.0, 0, -20.0)},
	{"id": "pm_south", "pos": Vector3(40.0, 0, 14.0)},
	{"id": "hub", "pos": Vector3(0, 0, 0)},
	{"id": "house_a", "pos": Vector3(-10.0, 0, -10.0)},
	{"id": "house_b", "pos": Vector3(-34.0, 0, -12.0)},
	{"id": "house_c", "pos": Vector3(30.0, 0, 16.0)},
	{"id": "house_d", "pos": Vector3(8.0, 0, 26.0)},
	{"id": "uncle_yard", "pos": Vector3(8.0, 0, 6.0)},
	{"id": "shed_hill", "pos": Vector3(-46.0, 0, -36.0)},
	{"id": "garden", "pos": Vector3(-20.0, 0, -26.0)},
	{"id": "field_west", "pos": Vector3(-36.0, 0, 18.0)},
	{"id": "field_nw", "pos": Vector3(-28.0, 0, -36.0)},
	{"id": "lane_north", "pos": Vector3(0.0, 0, -22.0)},
]

const PHONE_SPOTS: Array[Dictionary] = [
	{"id": "house_a_porch", "pos": Vector3(-10.4, 0.2, -8.2)},
	{"id": "house_b_porch", "pos": Vector3(-32.0, 0.2, -12.0)},
	{"id": "uncle_phone", "pos": Vector3(14.0, 0.2, 6.0)},
	{"id": "mansion_gate_phone", "pos": Vector3(38.0, 0.2, 8.5)},
]

## L4 duct graph (art connections). Names match PM_L4_ROOMS.
const PM_L4_DUCT_LINKS: Array[Dictionary] = [
	{"a": "Attic", "b": "Study"},
	{"a": "Study", "b": "Kitchen"},
	{"a": "Study", "b": "MasterBedroom"},
	{"a": "MasterBedroom", "b": "Living"},
	{"a": "Living", "b": "Basement"},
	{"a": "Basement", "b": "Bunker"},
	{"a": "Bunker", "b": "UtilityCloset"},
	{"a": "UtilityCloset", "b": "Hallway"},
	{"a": "Hallway", "b": "Stairwell"},
	{"a": "Stairwell", "b": "Dining"},
	{"a": "Dining", "b": "Kitchen"},
]

## James verify: Leonardo L2 legend camelCase is NOT SoT. Never wire these.
const L2_ART_DRIFT_IDS: Array[String] = [
	"masterBedroom",
	"master_become",
	"bunkerUtility",
	"uncleBedroom",
	"unclebecome",
	"uncle_become",
	"uncleGarage",
	"familyShed",
	"stormDrain",
	"underPorchCrawl",
	"gardenWell",
	"carTrunk",
]

## Long-form / prefixed ids — also not SoT. Eng short snake_case only.
const L2_LONG_FORM_IDS: Array[String] = [
	"pm_master_bedroom",
	"pm_bunker_utility",
	"pm_basement",
	"pm_bunker",
	"bunker_utility_closet",
	"utility_closet",
	"under_porch_crawlspace",
	"garden_well_crawlspace",
	"car_trunk_curb",
	"hsr_trunk",
]

## Eng pin numbers (CSV). Art may stamp pin 4 on both basement and under-porch —
## that duplicate is ignored. under_porch_crawl is pin 9; basement is pin 4.
const L2_PIN_BY_ID := {
	"pm_attic": 1,
	"master_bedroom": 2,
	"bunker_utility": 3,
	"basement": 4,
	"uncle_bedroom": 5,
	"uncle_garage": 6,
	"family_shed": 7,
	"storm_drain": 8,
	"under_porch_crawl": 9,
	"garden_well": 10,
	"car_trunk": 11,
}

## Authored road spans baked into HorrorWorld.tscn (data SoT only).
## West hub + family lanes, plus the east oval loop from the QA plate.
const ROAD_SPANS: Array[Dictionary] = [
	{"a": Vector2(-60.0, 0.0), "b": Vector2(22.0, 0.0), "r": 3.4},
	{"a": Vector2(0.0, -42.0), "b": Vector2(0.0, 44.0), "r": 3.0},
	{"a": Vector2(-16.0, -14.0), "b": Vector2(16.0, -14.0), "r": 2.6},
	{"a": Vector2(-16.0, 14.0), "b": Vector2(16.0, 14.0), "r": 2.6},
	{"a": Vector2(-16.0, -14.0), "b": Vector2(-16.0, 14.0), "r": 2.6},
	{"a": Vector2(16.0, -14.0), "b": Vector2(16.0, 14.0), "r": 2.6},
	{"a": Vector2(8.0, 0.0), "b": Vector2(22.0, 0.0), "r": 3.2},
	{"a": Vector2(-12.0, -14.0), "b": Vector2(0.0, 0.0), "r": 2.4},
	{"a": Vector2(-38.0, -12.0), "b": Vector2(-12.0, -14.0), "r": 2.4},
	{"a": Vector2(0.0, 14.0), "b": Vector2(6.0, 26.0), "r": 2.4},
	{"a": Vector2(-12.0, -14.0), "b": Vector2(-48.0, -38.0), "r": 2.2},
	{"a": Vector2(28.0, -20.0), "b": Vector2(52.0, -20.0), "r": 3.0},
	{"a": Vector2(52.0, -20.0), "b": Vector2(58.0, -14.0), "r": 3.0},
	{"a": Vector2(58.0, -14.0), "b": Vector2(58.0, 10.0), "r": 3.0},
	{"a": Vector2(58.0, 10.0), "b": Vector2(52.0, 16.0), "r": 3.0},
	{"a": Vector2(52.0, 16.0), "b": Vector2(28.0, 16.0), "r": 3.0},
	{"a": Vector2(28.0, 16.0), "b": Vector2(22.0, 10.0), "r": 3.0},
	{"a": Vector2(22.0, 10.0), "b": Vector2(22.0, -14.0), "r": 3.0},
	{"a": Vector2(22.0, -14.0), "b": Vector2(28.0, -20.0), "r": 3.0},
]

const BUILDING_PADS: Array[Dictionary] = [
	{"pos": Vector2(-12.0, -14.0), "r": 11.0},
	{"pos": Vector2(-38.0, -12.0), "r": 11.0},
	{"pos": Vector2(32.0, 20.0), "r": 11.0},
	{"pos": Vector2(6.0, 30.0), "r": 11.0},
	{"pos": Vector2(10.0, 6.0), "r": 9.0},
	{"pos": Vector2(40.0, -6.0), "r": 14.0},
	{"pos": Vector2(56.0, -6.0), "r": 6.0},
	{"pos": Vector2(-50.0, -40.0), "r": 4.5},
	{"pos": Vector2(40.0, 10.0), "r": 8.0},
]


static func spawn_id_list() -> Array[String]:
	return SPAWN_IDS.duplicate()


static func is_canonical_spawn_id(spawn_id: String) -> bool:
	return SPAWN_IDS.has(spawn_id)


static func is_forbidden_spawn_id(spawn_id: String) -> bool:
	if L2_ART_DRIFT_IDS.has(spawn_id) or L2_LONG_FORM_IDS.has(spawn_id):
		return true
	if spawn_id != spawn_id.to_snake_case():
		return true
	if (spawn_id.begins_with("pm_") and spawn_id != "pm_attic"):
		return true
	if spawn_id.ends_with("_closet") or spawn_id.ends_with("_crawlspace") or spawn_id.ends_with("_curb"):
		return true
	return false


static func l2_pin_number(spawn_id: String) -> int:
	return int(L2_PIN_BY_ID.get(spawn_id, -1))


static func l2_world_pos(spawn_id: String) -> Vector3:
	if L2_WORLD_MARKERS.has(spawn_id):
		return L2_WORLD_MARKERS[spawn_id]
	return Vector3.ZERO


static func stamp_child_pin(marker: Marker3D, spawn_id: String) -> void:
	marker.name = "ChildSpawn_%s" % spawn_id
	marker.add_to_group("child_spawn_points")
	marker.set_meta("spawn_id", spawn_id)
	marker.set_meta("l2_pin", l2_pin_number(spawn_id))


static func family_letter(index: int) -> String:
	if index < 0 or index >= FAMILY_HOUSES.size():
		return "?"
	return str(FAMILY_HOUSES[index]["letter"])
