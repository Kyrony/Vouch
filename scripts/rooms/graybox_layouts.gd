extends RefCounted
class_name GrayboxLayouts
## Friends-MVP hand-sealed graybox rooms — simple enclosed boxes, no procedural partitions/stairs.

const HEIGHT: float = WorldScale.CEILING_H
const WALL: float = WorldScale.WALL_THICK
const DOOR_W: float = WorldScale.DOOR_W
const DOOR_H: float = WorldScale.DOOR_H

## Match spawn picks only from this set (Room_01 … Room_06).
const FRIENDS_MVP_IDS: Array[int] = [1, 2, 3, 4, 5, 6]
const FRIENDS_MVP_COUNT: int = 6


static func get_layout(room_id: int) -> Dictionary:
	var id := clampi(room_id, 1, FRIENDS_MVP_COUNT)
	return _definitions()[id - 1].duplicate(true)


static func pick_id(rng: RandomNumberGenerator) -> int:
	return FRIENDS_MVP_IDS[rng.randi() % FRIENDS_MVP_COUNT]


static func scene_path(room_id: int) -> String:
	if room_id <= 0:
		return "res://scenes/Rooms/Room_PM.tscn"
	return "res://scenes/Rooms/Room_%02d.tscn" % clampi(room_id, 1, FRIENDS_MVP_COUNT)


static func pm_layout() -> Dictionary:
	return {
		"id": 0,
		"name": "Puppet Master",
		"width": 6.0,
		"depth": 6.0,
		"height": HEIGHT,
		"theme": "basement",
		"spawn": Vector3(0, 0.0, 0),
		"escape": Vector3.ZERO,
		"corridor_out": Vector3.ZERO,
		"slots": _slot_layout(0, 6.0, 6.0),
	}


static func _definitions() -> Array:
	return [
		_box("Studio Box", 1, 6.0, 6.0, "bedroom"),
		_box("Wide Box", 2, 7.0, 6.0, "bedroom"),
		_box("Long Box", 3, 8.0, 6.0, "utility"),
		_box("Tall Box", 4, 6.0, 7.0, "bedroom"),
		_box("Medium Box", 5, 7.0, 7.0, "utility"),
		_box("Large Box", 6, 8.0, 7.0, "basement"),
	]


static func _box(name: String, id: int, w: float, d: float, theme: String) -> Dictionary:
	var hd := d * 0.5
	return {
		"id": id,
		"name": name,
		"width": w,
		"depth": d,
		"height": HEIGHT,
		"theme": theme,
		"spawn": Vector3(0, 0.0, 0),
		"escape": Vector3(0, DOOR_H * 0.5, hd - WALL * 0.5),
		"corridor_out": Vector3(0, DOOR_H * 0.5, hd + WALL * 0.5),
		"slots": _slot_layout(id, w, d),
	}


static func _slot_layout(room_id: int, w: float, d: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = room_id * 104729 + 17
	var hw := w * 0.5 - 0.5
	var hd := d * 0.5 - 0.5
	var flush := 0.08
	var slots: Array = []

	slots.append({
		"position": Vector3(rng.randf_range(-hw * 0.35, hw * 0.35), 0.0, hd - flush),
		"surface_type": "wall_floor",
		"wall_normal": Vector3(0, 0, -1),
	})

	slots.append({
		"position": Vector3(rng.randf_range(-hw * 0.25, hw * 0.25), HEIGHT - 0.12, rng.randf_range(-hd * 0.25, hd * 0.25)),
		"surface_type": "ceiling",
		"wall_normal": Vector3(0, -1, 0),
	})

	var wall_heights := [1.25, 1.15, 1.45, 1.1, 0.95, 1.0, 1.35, 1.2]
	var wall_faces := ["s", "s", "e", "w", "n", "e", "w", "n"]
	for i in range(8):
		var face: String = wall_faces[i]
		var t := rng.randf_range(0.22, 0.78)
		slots.append(_wall_slot(hw, hd, flush, face, wall_heights[i], t))

	for i in range(6):
		slots.append({
			"position": Vector3(
				rng.randf_range(-hw * 0.55, hw * 0.55),
				0.0,
				rng.randf_range(-hd * 0.55, hd * 0.55)
			),
			"surface_type": "floor",
			"wall_normal": Vector3(0, 1, 0),
		})

	return slots


static func _wall_slot(hw: float, hd: float, flush: float, face: String, height: float, t: float) -> Dictionary:
	match face:
		"s":
			return {
				"position": Vector3(lerpf(-hw, hw, t), height, hd - flush),
				"surface_type": "wall",
				"wall_normal": Vector3(0, 0, -1),
			}
		"n":
			return {
				"position": Vector3(lerpf(-hw, hw, t), height, -hd + flush),
				"surface_type": "wall",
				"wall_normal": Vector3(0, 0, 1),
			}
		"e":
			return {
				"position": Vector3(hw - flush, height, lerpf(-hd, hd, t)),
				"surface_type": "wall",
				"wall_normal": Vector3(-1, 0, 0),
			}
		_:
			return {
				"position": Vector3(-hw + flush, height, lerpf(-hd, hd, t)),
				"surface_type": "wall",
				"wall_normal": Vector3(1, 0, 0),
			}
