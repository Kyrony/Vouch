extends RefCounted
class_name PMMansionBuilder
## Puppet Master mansion: 8 rooms + basement + bunker + attic + crawlable ducts.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

const MAIN_FLOOR_Y: float = 0.0
const BASEMENT_Y: float = -4.0
const BUNKER_Y: float = -14.0
const ATTIC_Y: float = 3.2


static func build(parent: Node3D, origin: Vector3, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "PMMansion"
	root.position = origin
	parent.add_child(root)

	var child_markers: Array[Marker3D] = []
	var pm_spawn := Marker3D.new()
	pm_spawn.name = "PM_Spawn_Foyer"
	pm_spawn.position = Vector3(0, 0.1, 14)
	root.add_child(pm_spawn)

	_build_main_floor(root, mats, child_markers)
	_build_basement(root, mats, child_markers)
	_build_bunker(root, mats, child_markers)
	_build_attic(root, mats, child_markers)
	_build_ducts(root, mats)

	var emergency := OmniLight3D.new()
	emergency.position = Vector3(0, 2.5, 0)
	emergency.light_color = Color(0.85, 0.3, 0.22)
	emergency.light_energy = 0.45
	emergency.omni_range = 35
	root.add_child(emergency)

	return {
		"root": root,
		"pm_spawn": pm_spawn,
		"child_markers": child_markers,
	}


static func _build_main_floor(root: Node3D, mats, child_markers: Array) -> void:
	var floor_root := Node3D.new()
	floor_root.name = "MainFloor"
	root.add_child(floor_root)

	_GB.call("add_room_box", floor_root, Vector3(44, 3, 32), Vector3.ZERO, mats, true, true)

	for x in [-11.0, 0.0, 11.0]:
		_GB.call("add_wall_panel", floor_root, Vector3(x, 1.5, 0), Vector3(0.25, 3, 32), mats.wall, true, 1.6)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.5, 8), Vector3(44, 3, 0.25), mats.wall, true, 1.8)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.5, -8), Vector3(44, 3, 0.25), mats.wall, true, 1.8)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.5, 16), Vector3(44, 3, 0.25), mats.wall, true, 2.5)

	var prop_positions := [
		{"name": "Foyer", "pos": Vector3(0, 0, 12)},
		{"name": "Kitchen", "pos": Vector3(-16, 0, 4)},
		{"name": "Dining", "pos": Vector3(-16, 0, -4)},
		{"name": "Library", "pos": Vector3(-5, 0, -4)},
		{"name": "MasterBedroom", "pos": Vector3(5, 0, -4)},
		{"name": "GuestRoom", "pos": Vector3(16, 0, -4)},
		{"name": "Study", "pos": Vector3(16, 0, 4)},
		{"name": "Garage", "pos": Vector3(5, 0, 4)},
	]
	for p in prop_positions:
		floor_root.add_child(_GEOM.call("box", Vector3(1.5, 0.8, 0.8), Vector3(p["pos"].x, 0.4, p["pos"].z), mats.wood))

	_add_child_marker(floor_root, Vector3(6, 0.5, -6), "master_bedroom", child_markers)


static func _build_basement(root: Node3D, mats, child_markers: Array) -> void:
	var bs := Node3D.new()
	bs.name = "Basement"
	bs.position = Vector3(0, BASEMENT_Y, 0)
	root.add_child(bs)
	_GB.call("add_room_box", bs, Vector3(36, 3.5, 26), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", bs, Vector3(-9, 1.75, 0), Vector3(0.25, 3.5, 26), mats.wall, true, 1.6)
	_GB.call("add_wall_panel", bs, Vector3(9, 1.75, 0), Vector3(0.25, 3.5, 26), mats.wall, true, 1.6)
	bs.add_child(_GEOM.call("box", Vector3(2, 1, 1.2), Vector3(-12, 0.5, -8), mats.wall))
	_add_child_marker(bs, Vector3(10, 0.5, 6), "basement", child_markers)
	root.add_child(_GEOM.call("box", Vector3(2.5, 4.2, 2.5), Vector3(14, -2.1, 10), mats.wall))


static func _build_bunker(root: Node3D, mats, child_markers: Array) -> void:
	var bk := Node3D.new()
	bk.name = "Bunker"
	bk.position = Vector3(0, BUNKER_Y, 0)
	root.add_child(bk)
	_GB.call("add_room_box", bk, Vector3(40, 4, 30), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", bk, Vector3(-10, 2, 0), Vector3(0.25, 4, 30), mats.wall, true, 2.5)
	_GB.call("add_wall_panel", bk, Vector3(10, 2, 0), Vector3(0.25, 4, 30), mats.wall, true, 2.5)
	_GB.call("add_wall_panel", bk, Vector3(0, 2, -8), Vector3(40, 4, 0.25), mats.wall, true, 2.5)
	for pos in [Vector3(-16, 0.5, 8), Vector3(14, 0.5, -6), Vector3(-4, 0.5, 0)]:
		bk.add_child(_GEOM.call("box", Vector3(1.2, 1, 1.2), pos, mats.wall))
	_add_child_marker(bk, Vector3(-18, 0.5, -10), "bunker_utility", child_markers)

	var dim := OmniLight3D.new()
	dim.position = Vector3(0, 3.2, 0)
	dim.light_color = Color(0.9, 0.35, 0.25)
	dim.light_energy = 0.55
	dim.omni_range = 24
	bk.add_child(dim)


static func _build_attic(root: Node3D, mats, child_markers: Array) -> void:
	var at := Node3D.new()
	at.name = "Attic"
	at.position = Vector3(0, ATTIC_Y, 0)
	root.add_child(at)
	_GB.call("add_room_box", at, Vector3(34, 2.2, 24), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", at, Vector3(0, 1.1, 0), Vector3(0.25, 2.2, 24), mats.wall, true, 1.4)
	at.add_child(_GEOM.call("box", Vector3(3, 0.6, 1.5), Vector3(-8, 0.3, -6), mats.wood))
	_add_child_marker(at, Vector3(8, 0.5, 4), "pm_attic", child_markers)


static func _build_ducts(root: Node3D, mats) -> void:
	var ducts := Node3D.new()
	ducts.name = "DuctSystem"
	root.add_child(ducts)
	var segments := [
		{"size": Vector3(3, 1.1, 18), "pos": Vector3(-8, 1.0, 0)},
		{"size": Vector3(22, 1.1, 3), "pos": Vector3(0, 1.0, -10)},
		{"size": Vector3(3, 1.1, 12), "pos": Vector3(12, 1.0, 4)},
		{"size": Vector3(3, 1.1, 8), "pos": Vector3(-12, BASEMENT_Y + 1.0, -4)},
		{"size": Vector3(3, 1.1, 10), "pos": Vector3(0, BUNKER_Y + 1.2, 0)},
	]
	for seg in segments:
		var tunnel: StaticBody3D = _GEOM.call("box", seg["size"], seg["pos"], mats.duct)
		tunnel.add_to_group("crawl_ducts")
		ducts.add_child(tunnel)
		var floor_strip: StaticBody3D = _GEOM.call("box", Vector3(seg["size"].x - 0.4, 0.08, seg["size"].z - 0.4), seg["pos"] + Vector3(0, -seg["size"].y * 0.5 + 0.04, 0), mats.floor)
		ducts.add_child(floor_strip)


static func _add_child_marker(parent: Node3D, local_pos: Vector3, spawn_id: String, out: Array) -> void:
	var m := Marker3D.new()
	m.name = "ChildSpawn_%s" % spawn_id
	m.position = local_pos
	m.add_to_group("child_spawn_points")
	m.set_meta("spawn_id", spawn_id)
	parent.add_child(m)
	out.append(m)
