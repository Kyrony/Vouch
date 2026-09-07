extends RefCounted
class_name RoomKitRecipes
## James plan IDs → modular kit assembly recipes (module graph + snap positions).

const _KB: GDScript = preload("res://scripts/kit/kit_builder.gd")

## Each recipe: { "id", "modules": [{type, pos, rot_y, opts, role}], "plan_ids": [...] }
## Positions are module centers in apartment space (+Z south / entry).


static func recipe_for_plan(plan_id: String) -> Dictionary:
	for recipe in _recipes():
		if plan_id in recipe.get("plan_ids", []):
			return recipe.duplicate(true)
	return _recipes()[0].duplicate(true)


static func _recipes() -> Array:
	return [
		_compact_1bed(),
		_l_shape(),
		_wide_living(),
		_split_bed(),
		_utility_focus(),
		_two_story(),
	]


static func _compact_1bed() -> Dictionary:
	var hall_z := -(_KB.SIZES["living"].y * 0.5 + _KB.SIZES["hall"].y * 0.5)
	var bed_z := hall_z - (_KB.SIZES["hall"].y * 0.5 + _KB.SIZES["bedroom"].y * 0.5)
	var bath_x := _KB.SIZES["living"].x * 0.5 + _KB.SIZES["bath"].x * 0.5
	return {
		"id": "compact_1bed",
		"plan_ids": ["01", "02", "03", "06"],
		"modules": [
			{"type": "living", "pos": Vector3(0, 0, 0), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true}},
			{"type": "hall", "pos": Vector3(0, 0, hall_z), "rot_y": 0.0, "role": "hall", "opts": {"open_s": true, "open_n": true, "door_n": true}},
			{"type": "bedroom", "pos": Vector3(0, 0, bed_z), "rot_y": 0.0, "role": "bedroom", "opts": {"open_s": true, "door_s": true}},
			{"type": "bath", "pos": Vector3(bath_x, 0, -0.3), "rot_y": 0.0, "role": "bath", "opts": {"open_w": true, "door_w": true}},
			{"type": "closet", "pos": Vector3(bath_x + _KB.SIZES["bath"].x * 0.5 + _KB.SIZES["closet"].x * 0.5 - 0.05, 0, bed_z + 0.4), "rot_y": 0.0, "role": "closet", "opts": {"open_w": true}},
		],
	}


static func _l_shape() -> Dictionary:
	var living_z := 0.0
	var bed_z := -(_KB.SIZES["living_large"].y * 0.5 + _KB.SIZES["bedroom"].y * 0.5 + 0.02)
	var bath_x := -_KB.SIZES["living_large"].x * 0.5 - _KB.SIZES["bath"].x * 0.5 + 0.02
	return {
		"id": "l_shape",
		"plan_ids": ["04", "05", "07"],
		"modules": [
			{"type": "living_large", "pos": Vector3(0, 0, living_z), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true, "door_n": true}},
			{"type": "bedroom", "pos": Vector3(0, 0, bed_z), "rot_y": 0.0, "role": "bedroom", "opts": {"open_s": true, "door_s": true}},
			{"type": "bath", "pos": Vector3(bath_x, 0, 0.2), "rot_y": 0.0, "role": "bath", "opts": {"open_e": true, "door_e": true}},
			{"type": "hall", "pos": Vector3(bath_x, 0, bed_z + 0.5), "rot_y": 0.0, "role": "hall", "opts": {"open_e": true, "open_n": true}},
			{"type": "closet", "pos": Vector3(bath_x, 0, living_z + 1.2), "rot_y": 0.0, "role": "closet", "opts": {"open_e": true}},
		],
	}


static func _wide_living() -> Dictionary:
	var bed_z := -(_KB.SIZES["living_large"].y * 0.5 + _KB.SIZES["bedroom"].y * 0.5)
	var util_x := _KB.SIZES["living_large"].x * 0.5 + _KB.SIZES["utility"].x * 0.5
	return {
		"id": "wide_living",
		"plan_ids": ["08", "09", "10", "11"],
		"modules": [
			{"type": "living_large", "pos": Vector3(0, 0, 0), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true}},
			{"type": "bedroom", "pos": Vector3(0, 0, bed_z), "rot_y": 0.0, "role": "bedroom", "opts": {"open_s": true, "door_s": true}},
			{"type": "bath", "pos": Vector3(util_x, 0, bed_z * 0.5), "rot_y": 0.0, "role": "bath", "opts": {"open_w": true, "door_w": true}},
			{"type": "utility", "pos": Vector3(util_x, 0, 0.8), "rot_y": 0.0, "role": "utility", "opts": {"open_w": true, "open_s": true}},
			{"type": "fireplace_nook", "pos": Vector3(-1.0, 0, 0.5), "rot_y": 0.0, "role": "living", "opts": {}},
		],
	}


static func _split_bed() -> Dictionary:
	var hall_z := -(_KB.SIZES["living"].y * 0.5 + _KB.SIZES["hall"].y * 0.5)
	var bed1_x := -(_KB.SIZES["hall"].x * 0.5 + _KB.SIZES["bedroom"].x * 0.5)
	var bed2_x := _KB.SIZES["hall"].x * 0.5 + _KB.SIZES["bedroom"].x * 0.5
	return {
		"id": "split_bed",
		"plan_ids": ["12", "13", "14"],
		"modules": [
			{"type": "living", "pos": Vector3(0, 0, 0), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true}},
			{"type": "hall", "pos": Vector3(0, 0, hall_z), "rot_y": 0.0, "role": "hall", "opts": {"open_s": true, "open_n": true, "door_n": true, "door_s": true}},
			{"type": "bedroom", "pos": Vector3(bed1_x, 0, hall_z - _KB.SIZES["hall"].y * 0.5 - _KB.SIZES["bedroom"].y * 0.5), "rot_y": 0.0, "role": "bedroom", "opts": {"open_e": true, "door_e": true}},
			{"type": "bedroom", "pos": Vector3(bed2_x, 0, hall_z - _KB.SIZES["hall"].y * 0.5 - _KB.SIZES["bedroom"].y * 0.5), "rot_y": 0.0, "role": "bedroom", "opts": {"open_w": true, "door_w": true}},
			{"type": "bath", "pos": Vector3(bed2_x + _KB.SIZES["bedroom"].x * 0.5 + _KB.SIZES["bath"].x * 0.5, 0, hall_z - 0.2), "rot_y": 0.0, "role": "bath", "opts": {"open_w": true}},
		],
	}


static func _utility_focus() -> Dictionary:
	var util_z := -(_KB.SIZES["living"].y * 0.5 + _KB.SIZES["utility"].y * 0.5)
	return {
		"id": "utility_focus",
		"plan_ids": [],
		"modules": [
			{"type": "living", "pos": Vector3(0, 0, 0), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true}},
			{"type": "utility", "pos": Vector3(0, 0, util_z), "rot_y": 0.0, "role": "utility", "opts": {"open_s": true, "door_s": true}},
			{"type": "bath", "pos": Vector3(2.2, 0, util_z), "rot_y": 0.0, "role": "bath", "opts": {"open_w": true}},
			{"type": "closet", "pos": Vector3(-2.0, 0, util_z), "rot_y": 0.0, "role": "closet", "opts": {"open_e": true}},
		],
	}


static func _two_story() -> Dictionary:
	var stair_z := -(_KB.SIZES["living_large"].y * 0.5 + _KB.SIZES["stairwell"].y * 0.5)
	var bed_z := stair_z - (_KB.SIZES["stairwell"].y * 0.5 + _KB.SIZES["bedroom"].y * 0.5)
	return {
		"id": "two_story",
		"plan_ids": ["15", "16", "17", "18", "19", "20"],
		"modules": [
			{"type": "living_large", "pos": Vector3(0, 0, 0), "rot_y": 0.0, "role": "living", "opts": {"corridor_out": true, "open_n": true}},
			{"type": "stairwell", "pos": Vector3(0, 0, stair_z), "rot_y": 0.0, "role": "hall", "opts": {"open_s": true, "door_s": true}},
			{"type": "bedroom", "pos": Vector3(0, _KB.HEIGHT, bed_z), "rot_y": 0.0, "role": "bedroom", "opts": {"spawn_here": false, "open_s": true}},
			{"type": "bath", "pos": Vector3(2.0, _KB.HEIGHT, bed_z + 0.5), "rot_y": 0.0, "role": "bath", "opts": {"open_w": true}},
			{"type": "utility", "pos": Vector3(-2.0, 0, stair_z), "rot_y": 0.0, "role": "utility", "opts": {"open_e": true}},
		],
	}
