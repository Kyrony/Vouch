extends RefCounted
class_name FloorPlanTemplates
## FloorPlanTemplates
##
## James's 20 house-style floor plans on a 1 ft = 1 Godot unit grid.
## Coordinates: origin at SW corner (x east, z north). RoomPod centers
## the footprint on the world origin when building.

const FT: float = 1.0
const DOOR_W: float = 3.5
const DOOR_H: float = 7.0
const WALL_H: float = 10.0

## zone: {x, z, w, d, role, label}
## door: {kind, pos, gap_start, gap_w} — kind: s/n/w/e/v/h (v=vertical int, h=horizontal int)
## pos = constant coord (z for s/n, x for w/e, x for v, z for h)


static func pick_id(rng: RandomNumberGenerator, allow_two_story: bool = true) -> String:
	var ids := get_one_story_ids()
	if allow_two_story and rng.randf() < 0.25:
		ids = get_two_story_ids()
	return ids[rng.randi() % ids.size()]


static func get_one_story_ids() -> Array[String]:
	return ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14"]


static func get_two_story_ids() -> Array[String]:
	return ["15", "16", "17", "18", "19", "20"]


static func get_plan(plan_id: String) -> Dictionary:
	return plans().get(plan_id, plans()["01"])


static func footprint(plan: Dictionary) -> Vector2:
	return Vector2(plan["w"], plan["d"])


## Returns center of the living zone in plan coords (for spawn / escape placement).
static func living_center(plan: Dictionary) -> Vector3:
	for z in plan.get("zones", []):
		if z.get("role", "") == "living":
			return Vector3(z["x"] + z["w"] * 0.5, 0.0, z["z"] + z["d"] * 0.5)
	return Vector3(plan["w"] * 0.5, 0.0, plan["d"] * 0.5)


static func entry_door(plan: Dictionary) -> Dictionary:
	for d in plan.get("doors", []):
		if d.get("exterior", false):
			return d
	return plan.get("doors", [{}])[0]


static func plans() -> Dictionary:
	if not _PLANS.is_empty():
		return _PLANS
	_PLANS = {
	"01": _p("01", "Studio Square", 20, 20, 1,
		[{"x": 0, "z": 0, "w": 20, "d": 20, "role": "living", "label": "LIVING / SLEEP"}],
		[{"kind": "s", "pos": 0, "gap_start": 8, "gap_w": 4, "exterior": true}]),
	"02": _p("02", "Micro Loft", 20, 14, 1,
		[
			{"x": 0, "z": 0, "w": 16, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 16, "z": 0, "w": 4, "d": 14, "role": "closet", "label": "CLOSET"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 6, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 16, "gap_start": 5, "gap_w": 3},
		]),
	"03": _p("03", "Studio Bath", 24, 14, 1,
		[
			{"x": 0, "z": 0, "w": 18, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 18, "z": 0, "w": 6, "d": 6, "role": "closet", "label": "CLOSET"},
			{"x": 18, "z": 6, "w": 6, "d": 8, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 7, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 18, "gap_start": 0, "gap_w": 3},
			{"kind": "h", "pos": 6, "gap_start": 19, "gap_w": 3},
		]),
	"04": _p("04", "One Bed Simple", 24, 12, 1,
		[
			{"x": 0, "z": 0, "w": 14, "d": 12, "role": "living", "label": "LIVING"},
			{"x": 14, "z": 0, "w": 10, "d": 12, "role": "bedroom", "label": "BEDROOM"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 5, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 14, "gap_start": 4.5, "gap_w": 3.5},
		]),
	"05": _p("05", "One Bed + Bath", 26, 14, 1,
		[
			{"x": 0, "z": 0, "w": 16, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 16, "z": 0, "w": 10, "d": 10, "role": "bedroom", "label": "BEDROOM"},
			{"x": 16, "z": 10, "w": 10, "d": 4, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 6, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 16, "gap_start": 2, "gap_w": 3.5},
			{"kind": "h", "pos": 10, "gap_start": 18, "gap_w": 3},
		]),
	"06": _p("06", "One Bed + Closet", 24, 14, 1,
		[
			{"x": 0, "z": 0, "w": 14, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 14, "z": 0, "w": 10, "d": 4, "role": "closet", "label": "CLOSET"},
			{"x": 14, "z": 4, "w": 10, "d": 10, "role": "bedroom", "label": "BEDROOM"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 5, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 14, "gap_start": 5, "gap_w": 3.5},
			{"kind": "h", "pos": 4, "gap_start": 16, "gap_w": 3},
		]),
	"07": _p("07", "One Bed Full", 30, 14, 1,
		[
			{"x": 0, "z": 0, "w": 16, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 16, "z": 0, "w": 10, "d": 4, "role": "closet", "label": "CLOSET"},
			{"x": 16, "z": 4, "w": 5, "d": 4, "role": "closet", "label": "CLOSET"},
			{"x": 21, "z": 4, "w": 5, "d": 4, "role": "closet", "label": "CLOSET"},
			{"x": 16, "z": 8, "w": 10, "d": 6, "role": "bedroom", "label": "BEDROOM"},
			{"x": 26, "z": 0, "w": 4, "d": 14, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 6, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 16, "gap_start": 5, "gap_w": 3.5},
			{"kind": "v", "pos": 26, "gap_start": 5, "gap_w": 3.5},
			{"kind": "h", "pos": 4, "gap_start": 17, "gap_w": 3},
			{"kind": "h", "pos": 8, "gap_start": 18, "gap_w": 3},
		]),
	"08": _p("08", "L-Shape Living", 18, 18, 1,
		[
			{"x": 0, "z": 0, "w": 18, "d": 10, "role": "living", "label": "LIVING"},
			{"x": 0, "z": 10, "w": 10, "d": 8, "role": "living", "label": "LIVING"},
			{"x": 10, "z": 10, "w": 8, "d": 8, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 7, "gap_w": 4, "exterior": true},
			{"kind": "h", "pos": 10, "gap_start": 0, "gap_w": 3.5},
			{"kind": "v", "pos": 10, "gap_start": 11, "gap_w": 3.5},
		]),
	"09": _p("09", "Two Bed Simple", 24, 14, 1,
		[
			{"x": 0, "z": 0, "w": 14, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 14, "z": 0, "w": 10, "d": 7, "role": "bedroom", "label": "BEDROOM 2"},
			{"x": 14, "z": 7, "w": 10, "d": 7, "role": "bedroom", "label": "BEDROOM 1"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 5, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 14, "gap_start": 5.5, "gap_w": 3.5},
		]),
	"10": _p("10", "Two Bed + Bath", 30, 18, 1,
		[
			{"x": 0, "z": 0, "w": 14, "d": 16, "role": "living", "label": "LIVING"},
			{"x": 14, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 14, "z": 8, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 24, "z": 5, "w": 6, "d": 8, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 5, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 14, "gap_start": 6, "gap_w": 3.5},
			{"kind": "v", "pos": 24, "gap_start": 6, "gap_w": 3.5},
		]),
	"11": _p("11", "Two Bed Max", 34, 18, 1,
		[
			{"x": 0, "z": 0, "w": 16, "d": 16, "role": "living", "label": "LIVING"},
			{"x": 16, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 16, "z": 8, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 26, "z": 0, "w": 4, "d": 8, "role": "closet", "label": "CLOSET"},
			{"x": 26, "z": 8, "w": 4, "d": 8, "role": "closet", "label": "CLOSET"},
			{"x": 30, "z": 4, "w": 4, "d": 10, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 6, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 16, "gap_start": 6, "gap_w": 3.5},
			{"kind": "v", "pos": 26, "gap_start": 3, "gap_w": 3},
			{"kind": "v", "pos": 30, "gap_start": 6, "gap_w": 3.5},
		]),
	"12": _p("12", "Hall Spine", 26, 16, 1,
		[
			{"x": 0, "z": 0, "w": 12, "d": 16, "role": "living", "label": "LIVING"},
			{"x": 12, "z": 6, "w": 4, "d": 4, "role": "hall", "label": "HALL"},
			{"x": 16, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 16, "z": 8, "w": 10, "d": 8, "role": "bath", "label": "BATH"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 4, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 12, "gap_start": 7, "gap_w": 2},
			{"kind": "v", "pos": 16, "gap_start": 7, "gap_w": 2},
			{"kind": "h", "pos": 8, "gap_start": 17, "gap_w": 3},
		]),
	"13": _p("13", "Corner Bath", 28, 14, 1,
		[
			{"x": 0, "z": 0, "w": 18, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 18, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 18, "z": 8, "w": 6, "d": 6, "role": "bath", "label": "BATH"},
			{"x": 24, "z": 8, "w": 4, "d": 6, "role": "closet", "label": "CLOSET"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 7, "gap_w": 4, "exterior": true},
			{"kind": "v", "pos": 18, "gap_start": 4, "gap_w": 3.5},
			{"kind": "h", "pos": 8, "gap_start": 19, "gap_w": 3},
			{"kind": "v", "pos": 24, "gap_start": 9, "gap_w": 3},
		]),
	"14": _p("14", "Wide Living", 24, 18, 1,
		[
			{"x": 0, "z": 0, "w": 24, "d": 10, "role": "living", "label": "LIVING"},
			{"x": 0, "z": 10, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM 1"},
			{"x": 10, "z": 10, "w": 8, "d": 8, "role": "bath", "label": "BATH"},
			{"x": 18, "z": 10, "w": 6, "d": 8, "role": "bedroom", "label": "BEDROOM 2"},
		],
		[
			{"kind": "s", "pos": 0, "gap_start": 10, "gap_w": 4, "exterior": true},
			{"kind": "h", "pos": 10, "gap_start": 2, "gap_w": 3.5},
			{"kind": "v", "pos": 10, "gap_start": 11.5, "gap_w": 3},
			{"kind": "v", "pos": 18, "gap_start": 11.5, "gap_w": 3},
		]),
	"15": _two_story("15", "Two-Story A", 18, 14, 10,
		[{"x": 0, "z": 0, "w": 18, "d": 14, "role": "living", "label": "LIVING"}],
		[
			{"x": 0, "z": 0, "w": 12, "d": 10, "role": "bedroom", "label": "BEDROOM"},
			{"x": 12, "z": 0, "w": 6, "d": 10, "role": "bath", "label": "BATH"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	"16": _two_story("16", "Two-Story B", 18, 14, 12,
		[
			{"x": 0, "z": 0, "w": 12, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 12, "z": 0, "w": 6, "d": 14, "role": "bath", "label": "BATH"},
		],
		[
			{"x": 0, "z": 0, "w": 11, "d": 12, "role": "bedroom", "label": "BEDROOM"},
			{"x": 11, "z": 0, "w": 7, "d": 12, "role": "bedroom", "label": "BEDROOM"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	"17": _two_story("17", "Two-Story C", 20, 12, 12,
		[{"x": 0, "z": 0, "w": 20, "d": 12, "role": "living", "label": "LIVING"}],
		[
			{"x": 0, "z": 0, "w": 14, "d": 12, "role": "bedroom", "label": "BEDROOM"},
			{"x": 14, "z": 0, "w": 3, "d": 6, "role": "closet", "label": "CLOSET"},
			{"x": 17, "z": 0, "w": 3, "d": 6, "role": "closet", "label": "CLOSET"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	"18": _two_story("18", "Two-Story D", 18, 14, 12,
		[
			{"x": 0, "z": 0, "w": 12, "d": 14, "role": "living", "label": "LIVING"},
			{"x": 12, "z": 0, "w": 6, "d": 14, "role": "closet", "label": "CLOSET"},
		],
		[
			{"x": 0, "z": 0, "w": 12, "d": 12, "role": "bedroom", "label": "BEDROOM"},
			{"x": 12, "z": 0, "w": 6, "d": 12, "role": "bath", "label": "BATH"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	"19": _two_story("19", "Two-Story E", 20, 14, 14,
		[{"x": 0, "z": 0, "w": 18, "d": 14, "role": "living", "label": "LIVING"}],
		[
			{"x": 0, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 10, "z": 0, "w": 10, "d": 8, "role": "bedroom", "label": "BEDROOM"},
			{"x": 0, "z": 8, "w": 20, "d": 6, "role": "bath", "label": "BATH"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	"20": _two_story("20", "Two-Story F", 18, 12, 12,
		[
			{"x": 0, "z": 0, "w": 14, "d": 12, "role": "living", "label": "LIVING"},
			{"x": 14, "z": 0, "w": 4, "d": 12, "role": "bath", "label": "BATH"},
		],
		[
			{"x": 0, "z": 0, "w": 14, "d": 12, "role": "bedroom", "label": "BEDROOM"},
			{"x": 14, "z": 0, "w": 4, "d": 12, "role": "closet", "label": "CLOSET"},
		],
		{"x": 1, "z": 1, "w": 3, "d": 3}),
	}
	return _PLANS


static var _PLANS: Dictionary = {}


static func _p(id: String, name: String, w: float, d: float, stories: int, zones: Array, doors: Array) -> Dictionary:
	return {
		"id": id, "name": name, "w": w, "d": d, "stories": stories,
		"zones": zones, "doors": doors, "floor2": null, "stair": null,
	}


static func _two_story(id: String, name: String, w: float, d1: float, d2: float, zones1: Array, zones2: Array, stair: Dictionary) -> Dictionary:
	var doors1 := [
		{"kind": "s", "pos": 0, "gap_start": w * 0.5 - 2, "gap_w": 4, "exterior": true},
	]
	if zones1.size() > 1:
		doors1.append({"kind": "v", "pos": zones1[0]["w"], "gap_start": d1 * 0.35, "gap_w": 3.5})
	var doors2 := [{"kind": "v", "pos": zones2[0]["w"] if zones2.size() > 1 else w * 0.5, "gap_start": d2 * 0.35, "gap_w": 3.5}]
	return {
		"id": id, "name": name, "w": w, "d": d1, "stories": 2,
		"zones": zones1, "doors": doors1,
		"floor2": {"w": w, "d": d2, "zones": zones2, "doors": doors2},
		"stair": stair,
	}
