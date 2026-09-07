extends RefCounted
class_name NeighborhoodV05
## Leonardo Neighborhood Layout v0.5 — production footprints.
## World: +X east (PM mansion), +Z south (uncle / stem), origin = cul-de-sac.

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
const NEIGHBORHOOD_SPAN_M: float = 40.0

const CUL_DE_SAC := Vector3(0, 0, 0)
const BULB_RADIUS: float = 5.5
const STEM_WIDTH: float = 5.0
const STEM_LENGTH: float = 12.0

const FAMILY_HOUSE_SIZE := Vector3(8.0, 3.0, 6.5)
const FAMILY_RING: float = 9.2

const FAMILY_HOUSES: Array[Dictionary] = [
	{"letter": "A", "index": 0, "origin": Vector3(0, 0, -9.2), "yaw": 0.0},
	{"letter": "B", "index": 1, "origin": Vector3(9.2, 0, 0), "yaw": -PI / 2.0},
	{"letter": "C", "index": 2, "origin": Vector3(0, 0, 9.2), "yaw": PI},
	{"letter": "D", "index": 3, "origin": Vector3(-9.2, 0, 0), "yaw": PI / 2.0},
]

const UNCLE_ORIGIN := Vector3(-7.0, 0, 18.0)
const UNCLE_YAW: float = PI

const MANSION_ORIGIN := Vector3(22.5, 0, 0)
const MANSION_YAW: float = -PI / 2.0
const MANSION_SIZE := Vector3(14.0, 3.2, 12.0)

const FAMILY_SHED_POS := Vector3(-14.0, 0, -6.0)
const STORM_DRAIN_POS := Vector3(3.6, 0, 5.4)
const GARDEN_WELL_POS := Vector3(-5.0, 0, -14.0)
const CAR_TRUNK_POS := Vector3(3.2, 0, 16.0)
const SOFT_ESCAPE_POS := Vector3(-18.0, 0.5, 0.0)

## Phase 1 Host Match spawns — outdoor street / yard, not bedrooms or bunker.
## Y is ground-ish; OutdoorBuilder samples the heightfield and writes the marker.
const OUTDOOR_FAMILY_SPAWNS: Array[Vector3] = [
	Vector3(0.0, 0.12, -4.8),
	Vector3(4.8, 0.12, 0.0),
	Vector3(0.0, 0.12, 4.8),
	Vector3(-4.8, 0.12, 0.0),
]
const OUTDOOR_PM_SPAWN := Vector3(14.8, 0.12, 0.0)
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
	{"id": "pm_gate", "pos": Vector3(15.4, 0, 0)},
	{"id": "pm_east", "pos": Vector3(30.0, 0, 0)},
	{"id": "pm_north", "pos": Vector3(22.5, 0, -8.5)},
	{"id": "pm_south", "pos": Vector3(22.5, 0, 8.5)},
	{"id": "bulb_island", "pos": Vector3(0, 0, 0)},
	{"id": "bulb_north", "pos": Vector3(0, 0, -6.8)},
	{"id": "bulb_west", "pos": Vector3(-6.8, 0, 0)},
	{"id": "street_stem", "pos": Vector3(0, 0, 14.0)},
	{"id": "uncle_yard", "pos": Vector3(-10.5, 0, 20.5)},
	{"id": "shed_lane", "pos": Vector3(-13.0, 0, -2.0)},
	{"id": "garden", "pos": Vector3(-3.5, 0, -13.0)},
	{"id": "field_west", "pos": Vector3(-16.5, 0, 6.0)},
	{"id": "field_south", "pos": Vector3(6.0, 0, 20.0)},
	{"id": "curb_east", "pos": Vector3(13.2, 0, 4.5)},
]

const PHONE_SPOTS: Array[Dictionary] = [
	{"id": "house_a_porch", "pos": Vector3(1.6, 0.2, -6.4)},
	{"id": "street_phone", "pos": Vector3(2.2, 0.2, 12.5)},
	{"id": "uncle_phone", "pos": Vector3(-4.2, 0.2, 16.8)},
	{"id": "mansion_gate_phone", "pos": Vector3(16.2, 0.2, 1.6)},
]


static func spawn_id_list() -> Array[String]:
	return SPAWN_IDS.duplicate()


static func family_letter(index: int) -> String:
	if index < 0 or index >= FAMILY_HOUSES.size():
		return "?"
	return str(FAMILY_HOUSES[index]["letter"])
