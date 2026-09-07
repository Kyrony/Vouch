extends RefCounted
class_name RoomLayouts
## Twenty unique fixed room maps — each layout is a complete sealed space (not modules / CSG plans).

const HEIGHT: float = WorldScale.CEILING_H
const WALL: float = WorldScale.WALL_THICK


static func get_layout(room_id: int) -> Dictionary:
	var id := clampi(room_id, 1, 20)
	return _layouts()[id - 1].duplicate(true)


static func scene_path(room_id: int) -> String:
	if room_id <= 0:
		return "res://scenes/Rooms/Room_PM.tscn"
	return "res://scenes/Rooms/Room_%02d.tscn" % clampi(room_id, 1, 20)


static func pick_id(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 20)


static func _layouts() -> Array:
	return [
		_studio(1, 9.0, 7.5),
		_split_hall(2, 10.5, 8.0),
		_l_corner(3, 11.0, 9.5),
		_wide_living(4, 12.0, 8.5),
		_narrow_galley(5, 8.0, 11.0),
		_bedroom_wing(6, 10.0, 10.0),
		_utility_adjacent(7, 9.5, 9.0),
		_chamfer_entry(8, 11.5, 8.0),
		_diagonal_hall(9, 10.0, 10.5),
		_compact_bath(10, 8.5, 8.5),
		_double_bed(11, 12.5, 9.0),
		_open_kitchen(12, 11.0, 10.0),
		_closet_maze(13, 9.0, 10.0),
		_porch_box(14, 10.0, 9.5),
		_loft_stub(15, 10.5, 9.0),
		_stair_nook(16, 11.0, 10.0),
		_upper_deck(17, 10.0, 11.5),
		_split_level(18, 11.5, 10.5),
		_long_ranch(19, 13.0, 8.0),
		_bunker_suite(20, 12.0, 11.0),
	]


static func _base(name: String, id: int, w: float, d: float, theme: String, partitions: Array, props: Array) -> Dictionary:
	var hw := w * 0.5
	var hd := d * 0.5
	return {
		"id": id,
		"name": name,
		"width": w,
		"depth": d,
		"height": HEIGHT,
		"theme": theme,
		"partitions": partitions,
		"props": props,
		"spawn": Vector3(0, 0.1, hd - 1.6),
		"escape": Vector3(0, 1.025, hd - WALL),
		"corridor_out": Vector3(0, 1.025, hd + 0.15),
		"slots": slot_layout(id, w, d),
	}


static func slot_layout(room_id: int, w: float, d: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = room_id * 104729
	var hw := w * 0.5 - 0.5
	var hd := d * 0.5 - 0.5
	var flush := 0.08
	var slots: Array = []

	# 1× wall+floor (fireplace)
	slots.append({
		"position": Vector3(rng.randf_range(-hw * 0.35, hw * 0.35), 0.0, hd - flush),
		"surface_type": "wall_floor",
		"wall_normal": Vector3(0, 0, -1),
	})

	# 1× ceiling (security camera)
	slots.append({
		"position": Vector3(rng.randf_range(-hw * 0.25, hw * 0.25), HEIGHT - 0.12, rng.randf_range(-hd * 0.25, hd * 0.25)),
		"surface_type": "ceiling",
		"wall_normal": Vector3(0, -1, 0),
	})

	# 8× wall (switch, phone, exhaust, valves, electrical, terminal, monitor, gas)
	var wall_heights := [1.25, 1.15, 1.45, 1.1, 0.95, 1.0, 1.35, 1.2]
	var wall_faces := ["s", "s", "e", "w", "n", "e", "w", "n"]
	for i in range(8):
		var face: String = wall_faces[i]
		var t := rng.randf_range(0.22, 0.78)
		slots.append(_wall_slot(hw, hd, flush, face, wall_heights[i], t))

	# 6× floor (drain, ladder, props, bookcase)
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


static func _studio(id: int, w: float, d: float) -> Dictionary:
	return _base("Studio Entry", id, w, d, "bedroom", [
		{"pos": Vector3(-1.8, HEIGHT * 0.5, -0.5), "size": Vector3(WALL, HEIGHT, 3.2)},
	], [
		{"pos": Vector3(1.2, 0.21, -1.0), "size": Vector3(2.0, 0.42, 0.9)},
		{"pos": Vector3(-2.0, 0.275, 0.8), "size": Vector3(1.6, 0.55, 2.0)},
	])


static func _split_hall(id: int, w: float, d: float) -> Dictionary:
	return _base("Split Hall", id, w, d, "bedroom", [
		{"pos": Vector3(0, HEIGHT * 0.5, 0.2), "size": Vector3(WALL, HEIGHT, d - 1.0)},
		{"pos": Vector3(-2.5, HEIGHT * 0.5, -2.0), "size": Vector3(4.5, HEIGHT, WALL)},
	], [
		{"pos": Vector3(2.5, 0.21, 1.5), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(-2.8, 0.275, -0.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(2.8, 0.225, -2.5), "size": Vector3(0.55, 0.45, 0.7)},
	])


static func _l_corner(id: int, w: float, d: float) -> Dictionary:
	return _base("L Corner", id, w, d, "bedroom", [
		{"pos": Vector3(-1.0, HEIGHT * 0.5, -1.5), "size": Vector3(5.5, HEIGHT, WALL)},
		{"pos": Vector3(2.0, HEIGHT * 0.5, 1.0), "size": Vector3(WALL, HEIGHT, 4.0)},
	], [
		{"pos": Vector3(0.5, 0.21, 2.0), "size": Vector3(2.2, 0.42, 1.0)},
		{"pos": Vector3(-3.0, 0.275, 1.0), "size": Vector3(1.6, 0.55, 2.0)},
	])


static func _wide_living(id: int, w: float, d: float) -> Dictionary:
	return _base("Wide Living", id, w, d, "bedroom", [
		{"pos": Vector3(0, HEIGHT * 0.5, -1.8), "size": Vector3(WALL, HEIGHT, 5.0)},
	], [
		{"pos": Vector3(-2.0, 0.21, 0.5), "size": Vector3(2.4, 0.42, 1.0)},
		{"pos": Vector3(2.5, 0.21, 0.0), "size": Vector3(1.2, 0.35, 0.5)},
		{"pos": Vector3(3.5, 0.275, -2.5), "size": Vector3(1.6, 0.55, 2.0)},
	])


static func _narrow_galley(id: int, w: float, d: float) -> Dictionary:
	return _base("Narrow Galley", id, w, d, "utility", [
		{"pos": Vector3(0, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 2.0)},
		{"pos": Vector3(0, HEIGHT * 0.5, -2.5), "size": Vector3(w - 2.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-2.0, 0.45, 2.0), "size": Vector3(0.5, 0.9, 0.4)},
		{"pos": Vector3(2.0, 0.7, -1.0), "size": Vector3(0.6, 1.4, 0.5)},
	])


static func _bedroom_wing(id: int, w: float, d: float) -> Dictionary:
	return _base("Bedroom Wing", id, w, d, "bedroom", [
		{"pos": Vector3(1.5, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 1.5)},
		{"pos": Vector3(-1.0, HEIGHT * 0.5, -2.0), "size": Vector3(4.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-2.5, 0.275, 0.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(3.0, 0.21, 1.5), "size": Vector3(1.8, 0.42, 0.9)},
	])


static func _utility_adjacent(id: int, w: float, d: float) -> Dictionary:
	return _base("Utility Adjacent", id, w, d, "utility", [
		{"pos": Vector3(2.0, HEIGHT * 0.5, -0.5), "size": Vector3(WALL, HEIGHT, 4.5)},
		{"pos": Vector3(0, HEIGHT * 0.5, -2.8), "size": Vector3(w - 1.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-1.5, 0.21, 1.0), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(3.0, 0.7, 0.5), "size": Vector3(0.6, 1.4, 0.5)},
	])


static func _chamfer_entry(id: int, w: float, d: float) -> Dictionary:
	return _base("Chamfer Entry", id, w, d, "bedroom", [
		{"pos": Vector3(-2.5, HEIGHT * 0.5, 1.0), "size": Vector3(3.5, HEIGHT, WALL)},
		{"pos": Vector3(0.5, HEIGHT * 0.5, -1.5), "size": Vector3(WALL, HEIGHT, 4.0)},
	], [
		{"pos": Vector3(2.5, 0.21, 0.5), "size": Vector3(2.0, 0.42, 0.9)},
		{"pos": Vector3(-1.0, 0.175, -2.5), "size": Vector3(1.2, 0.35, 0.5)},
	])


static func _diagonal_hall(id: int, w: float, d: float) -> Dictionary:
	return _base("Diagonal Hall", id, w, d, "bedroom", [
		{"pos": Vector3(-0.5, HEIGHT * 0.5, 0.5), "size": Vector3(WALL, HEIGHT, d - 2.5)},
		{"pos": Vector3(-2.5, HEIGHT * 0.5, -2.0), "size": Vector3(4.0, HEIGHT, WALL)},
		{"pos": Vector3(2.5, HEIGHT * 0.5, 1.5), "size": Vector3(3.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(1.0, 0.21, -1.0), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(-3.0, 0.275, 1.5), "size": Vector3(1.6, 0.55, 2.0)},
	])


static func _compact_bath(id: int, w: float, d: float) -> Dictionary:
	return _base("Compact Bath", id, w, d, "bedroom", [
		{"pos": Vector3(1.8, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 2.0)},
		{"pos": Vector3(3.0, HEIGHT * 0.5, -2.0), "size": Vector3(2.5, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-1.0, 0.21, 0.5), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(3.2, 0.225, -0.5), "size": Vector3(0.55, 0.45, 0.7)},
	])


static func _double_bed(id: int, w: float, d: float) -> Dictionary:
	return _base("Double Bed", id, w, d, "bedroom", [
		{"pos": Vector3(0, HEIGHT * 0.5, 0.5), "size": Vector3(WALL, HEIGHT, d - 2.0)},
		{"pos": Vector3(-2.5, HEIGHT * 0.5, -1.5), "size": Vector3(4.5, HEIGHT, WALL)},
		{"pos": Vector3(2.5, HEIGHT * 0.5, -1.5), "size": Vector3(4.5, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-2.5, 0.275, 1.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(2.5, 0.275, 1.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(0, 0.21, 2.0), "size": Vector3(2.0, 0.42, 0.9)},
	])


static func _open_kitchen(id: int, w: float, d: float) -> Dictionary:
	return _base("Open Kitchen", id, w, d, "utility", [
		{"pos": Vector3(-2.0, HEIGHT * 0.5, -1.0), "size": Vector3(4.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(1.5, 0.45, 0.5), "size": Vector3(2.4, 0.9, 0.6)},
		{"pos": Vector3(-2.5, 0.21, 1.5), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(3.0, 0.7, -2.0), "size": Vector3(0.6, 1.4, 0.5)},
	])


static func _closet_maze(id: int, w: float, d: float) -> Dictionary:
	return _base("Closet Maze", id, w, d, "bedroom", [
		{"pos": Vector3(1.5, HEIGHT * 0.5, 0.5), "size": Vector3(WALL, HEIGHT, 3.5)},
		{"pos": Vector3(0, HEIGHT * 0.5, -1.5), "size": Vector3(3.0, HEIGHT, WALL)},
		{"pos": Vector3(-2.0, HEIGHT * 0.5, 0.5), "size": Vector3(WALL, HEIGHT, 2.5)},
	], [
		{"pos": Vector3(-1.0, 0.21, 2.0), "size": Vector3(1.4, 0.42, 0.8)},
		{"pos": Vector3(2.8, 0.9, -0.5), "size": Vector3(0.9, 1.8, 0.35)},
	])


static func _porch_box(id: int, w: float, d: float) -> Dictionary:
	return _base("Porch Box", id, w, d, "bedroom", [
		{"pos": Vector3(0, HEIGHT * 0.5, 1.5), "size": Vector3(w - 1.5, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-2.0, 0.21, -1.0), "size": Vector3(2.0, 0.42, 0.9)},
		{"pos": Vector3(2.5, 0.275, -1.5), "size": Vector3(1.6, 0.55, 2.0)},
	])


static func _loft_stub(id: int, w: float, d: float) -> Dictionary:
	var layout := _base("Loft Stub", id, w, d, "bedroom", [
		{"pos": Vector3(-1.5, HEIGHT * 0.5, -0.5), "size": Vector3(4.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(1.5, 0.21, 1.0), "size": Vector3(1.8, 0.42, 0.9)},
		{"pos": Vector3(-2.5, 0.275, 1.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(0.5, 1.5, -2.0), "size": Vector3(2.5, WALL, 2.0)},
	])
	layout["loft"] = true
	return layout


static func _stair_nook(id: int, w: float, d: float) -> Dictionary:
	var layout := _base("Stair Nook", id, w, d, "bedroom", [
		{"pos": Vector3(2.0, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 2.0)},
		{"pos": Vector3(0, HEIGHT * 0.5, -2.5), "size": Vector3(4.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(-2.0, 0.21, 1.0), "size": Vector3(1.8, 0.42, 0.9)},
	])
	layout["loft"] = true
	layout["stairs"] = {"pos": Vector3(3.0, 0, -1.0), "size": Vector2(1.0, 2.2), "landing_y": HEIGHT * 0.55}
	return layout


static func _upper_deck(id: int, w: float, d: float) -> Dictionary:
	var layout := _base("Upper Deck", id, w, d, "bedroom", [
		{"pos": Vector3(0, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 2.5)},
	], [
		{"pos": Vector3(-2.0, 0.21, 2.0), "size": Vector3(2.0, 0.42, 0.9)},
		{"pos": Vector3(2.5, 1.2, -2.0), "size": Vector3(3.0, WALL, 2.5)},
	])
	layout["loft"] = true
	return layout


static func _split_level(id: int, w: float, d: float) -> Dictionary:
	var layout := _base("Split Level", id, w, d, "bedroom", [
		{"pos": Vector3(-1.0, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 1.5)},
		{"pos": Vector3(2.0, HEIGHT * 0.5, -2.0), "size": Vector3(4.0, HEIGHT, WALL)},
	], [
		{"pos": Vector3(2.5, 0.21, 1.5), "size": Vector3(1.8, 0.42, 0.9)},
	])
	layout["loft"] = true
	layout["mezzanine"] = {"pos": Vector3(-2.8, HEIGHT * 0.55, 1.8), "size": Vector3(2.4, WALL, 2.0)}
	layout["stairs"] = {"pos": Vector3(-2.5, 0, -1.5), "size": Vector2(1.1, 2.0), "landing_y": HEIGHT * 0.55}
	return layout


static func _long_ranch(id: int, w: float, d: float) -> Dictionary:
	return _base("Long Ranch", id, w, d, "bedroom", [
		{"pos": Vector3(-3.0, HEIGHT * 0.5, 0), "size": Vector3(WALL, HEIGHT, d - 2.0)},
		{"pos": Vector3(1.0, HEIGHT * 0.5, -2.0), "size": Vector3(6.0, HEIGHT, WALL)},
		{"pos": Vector3(4.0, HEIGHT * 0.5, 1.0), "size": Vector3(WALL, HEIGHT, 3.0)},
	], [
		{"pos": Vector3(-1.0, 0.21, 1.5), "size": Vector3(2.2, 0.42, 1.0)},
		{"pos": Vector3(3.5, 0.275, -0.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(-4.5, 0.225, -1.0), "size": Vector3(0.55, 0.45, 0.7)},
	])


static func _bunker_suite(id: int, w: float, d: float) -> Dictionary:
	var layout := _base("Bunker Suite", id, w, d, "basement", [
		{"pos": Vector3(0, HEIGHT * 0.5, -1.0), "size": Vector3(WALL, HEIGHT, 5.0)},
		{"pos": Vector3(-2.5, HEIGHT * 0.5, -3.0), "size": Vector3(4.5, HEIGHT, WALL)},
		{"pos": Vector3(2.5, HEIGHT * 0.5, 1.5), "size": Vector3(4.5, HEIGHT, WALL)},
	], [
		{"pos": Vector3(0, 0.21, 2.0), "size": Vector3(2.4, 0.42, 1.0)},
		{"pos": Vector3(-3.5, 0.275, 0.5), "size": Vector3(1.6, 0.55, 2.0)},
		{"pos": Vector3(3.5, 0.7, -1.0), "size": Vector3(0.6, 1.4, 0.5)},
	])
	layout["mezzanine"] = {"pos": Vector3(2.2, HEIGHT * 0.42, -2.2), "size": Vector3(2.8, WALL, 2.2)}
	layout["stairs"] = {"pos": Vector3(1.2, 0, 0.5), "size": Vector2(1.0, 1.8), "landing_y": HEIGHT * 0.42}
	return layout
