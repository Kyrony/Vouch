extends RefCounted
class_name PMMansionBuilder
## L4 PM interior: named rooms + basement, bunker, utility closet, attic, ducts.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const MAIN_FLOOR_Y: float = 0.0
const BASEMENT_Y: float = -4.0
const BUNKER_Y: float = -12.0
const ATTIC_Y: float = 3.4


static func build(parent: Node3D, origin: Vector3, mats, rotation_y: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	root.name = "PMMansion"
	root.position = origin
	root.rotation.y = rotation_y
	parent.add_child(root)

	var child_markers: Array[Marker3D] = []
	var pm_spawn := Marker3D.new()
	pm_spawn.name = "PM_Spawn_Foyer"
	pm_spawn.position = Vector3(0, 0.1, 5.2)
	root.add_child(pm_spawn)

	_build_main_floor(root, mats, child_markers)
	_build_basement(root, mats, child_markers)
	_build_bunker(root, mats, child_markers)
	_build_attic(root, mats, child_markers)
	_build_ducts(root, mats)
	_build_stairwell(root, mats)

	var emergency := OmniLight3D.new()
	emergency.position = Vector3(0, 2.4, 0)
	emergency.light_color = Color(0.85, 0.3, 0.22)
	emergency.light_energy = 0.4
	emergency.omni_range = 22
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
	var size: Vector3 = _V05.MANSION_SIZE
	_GB.call("add_room_box", floor_root, size, Vector3.ZERO, mats, true, true)

	# Three bays: west living stack, center circulation, east private.
	_GB.call("add_wall_panel", floor_root, Vector3(-2.3, 1.6, 0), Vector3(0.22, 3.2, size.z), mats.wall, true, 1.5)
	_GB.call("add_wall_panel", floor_root, Vector3(2.3, 1.6, 0), Vector3(0.22, 3.2, size.z), mats.wall, true, 1.5)
	_GB.call("add_wall_panel", floor_root, Vector3(-4.6, 1.6, 1.6), Vector3(4.4, 3.2, 0.22), mats.wall, true, 1.3)
	_GB.call("add_wall_panel", floor_root, Vector3(-4.6, 1.6, -1.8), Vector3(4.4, 3.2, 0.22), mats.wall, true, 1.2)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.6, -1.8), Vector3(4.4, 3.2, 0.22), mats.wall, true, 1.1)
	_GB.call("add_wall_panel", floor_root, Vector3(4.6, 1.6, -0.6), Vector3(4.4, 3.2, 0.22), mats.wall, true, 1.4)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.6, size.z * 0.5), Vector3(size.x, 3.2, 0.22), mats.wall, true, 2.2)

	_name_room(floor_root, "Hallway", Vector3(0, 0, 3.6))
	_name_room(floor_root, "Living", Vector3(-4.6, 0, 3.6))
	_name_room(floor_root, "Dining", Vector3(-4.6, 0, 0.0))
	_name_room(floor_root, "Kitchen", Vector3(-4.6, 0, -3.6))
	_name_room(floor_root, "Study", Vector3(0, 0, -3.8))
	_name_room(floor_root, "Bathroom", Vector3(4.4, 0, -3.8))
	var master := _name_room(floor_root, "MasterBedroom", Vector3(4.4, 0, 2.2))
	_add_child_marker(master, Vector3(0.6, 0.5, 0.4), "master_bedroom", child_markers)

	floor_root.add_child(_GEOM.call("box", Vector3(1.6, 0.7, 0.7), Vector3(-4.4, 0.35, 3.2), mats.wood))
	floor_root.add_child(_GEOM.call("box", Vector3(1.8, 0.85, 0.5), Vector3(-4.6, 0.42, -3.4), mats.wall))
	floor_root.add_child(_GEOM.call("box", Vector3(1.4, 0.45, 2.0), Vector3(4.2, 0.24, 2.0), mats.wood))


static func _build_basement(root: Node3D, mats, child_markers: Array) -> void:
	var bs := Node3D.new()
	bs.name = "Basement"
	bs.position = Vector3(0, BASEMENT_Y, 0)
	root.add_child(bs)
	_GB.call("add_room_box", bs, Vector3(12, 3.4, 10), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", bs, Vector3(0, 1.7, 0), Vector3(0.22, 3.4, 10), mats.wall, true, 1.5)
	bs.add_child(_GEOM.call("box", Vector3(1.8, 0.9, 1.1), Vector3(-3.6, 0.45, -3.2), mats.wall))
	_add_child_marker(bs, Vector3(3.4, 0.5, 2.2), "basement", child_markers)
	root.add_child(_GEOM.call("box", Vector3(2.2, 4.1, 2.2), Vector3(3.6, -2.05, 3.2), mats.wall))


static func _build_bunker(root: Node3D, mats, child_markers: Array) -> void:
	var bk := Node3D.new()
	bk.name = "Bunker"
	bk.position = Vector3(0, BUNKER_Y, 0)
	root.add_child(bk)
	_GB.call("add_room_box", bk, Vector3(12, 3.8, 10), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", bk, Vector3(-2.4, 1.9, 0), Vector3(0.22, 3.8, 10), mats.wall, true, 2.0)
	for pos in [Vector3(-4.4, 0.45, 2.8), Vector3(3.6, 0.45, -2.4)]:
		bk.add_child(_GEOM.call("box", Vector3(1.1, 0.9, 1.1), pos, mats.wall))

	var util := Node3D.new()
	util.name = "UtilityCloset"
	util.position = Vector3(-4.2, 0, -3.2)
	bk.add_child(util)
	_GB.call("add_room_box", util, Vector3(3.4, 2.6, 3.2), Vector3.ZERO, mats, true, true)
	_add_child_marker(util, Vector3(0, 0.45, 0), "bunker_utility", child_markers)

	var dim := OmniLight3D.new()
	dim.position = Vector3(0, 3.0, 0)
	dim.light_color = Color(0.9, 0.35, 0.25)
	dim.light_energy = 0.5
	dim.omni_range = 16
	bk.add_child(dim)


static func _build_attic(root: Node3D, mats, child_markers: Array) -> void:
	var at := Node3D.new()
	at.name = "Attic"
	at.position = Vector3(0, ATTIC_Y, 0)
	root.add_child(at)
	_GB.call("add_room_box", at, Vector3(12, 2.1, 10), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", at, Vector3(0, 1.05, 0), Vector3(0.22, 2.1, 10), mats.wall, true, 1.3)
	at.add_child(_GEOM.call("box", Vector3(2.4, 0.5, 1.2), Vector3(-3.2, 0.25, -2.6), mats.wood))
	_add_child_marker(at, Vector3(3.2, 0.45, 1.8), "pm_attic", child_markers)


static func _build_stairwell(root: Node3D, mats) -> void:
	var sw := Node3D.new()
	sw.name = "Stairwell"
	sw.position = Vector3(0, 0, 0.2)
	root.add_child(sw)
	for i in 7:
		var y: float = -11.2 + float(i) * 2.15
		sw.add_child(_GEOM.call("box", Vector3(1.6, 0.18, 1.1), Vector3(0, y, 0.15 * float(i % 2)), mats.wood))


static func _build_ducts(root: Node3D, mats) -> void:
	var ducts := Node3D.new()
	ducts.name = "DuctSystem"
	root.add_child(ducts)
	var segments := [
		{"size": Vector3(2.4, 1.0, 10), "pos": Vector3(-3.2, 1.0, 0)},
		{"size": Vector3(10, 1.0, 2.4), "pos": Vector3(0, 1.0, -3.6)},
		{"size": Vector3(2.4, 1.0, 7), "pos": Vector3(3.4, 1.0, 1.6)},
		{"size": Vector3(2.4, 1.0, 6), "pos": Vector3(-3.0, BASEMENT_Y + 1.0, -2.2)},
		{"size": Vector3(2.4, 1.0, 7), "pos": Vector3(0, BUNKER_Y + 1.1, 0)},
		{"size": Vector3(4.2, 1.0, 2.2), "pos": Vector3(-3.4, BUNKER_Y + 1.1, -3.0)},
	]
	for seg in segments:
		var tunnel: StaticBody3D = _GEOM.call("box", seg["size"], seg["pos"], mats.duct)
		tunnel.add_to_group("crawl_ducts")
		ducts.add_child(tunnel)
		var floor_strip: StaticBody3D = _GEOM.call(
			"box",
			Vector3(seg["size"].x - 0.35, 0.08, seg["size"].z - 0.35),
			seg["pos"] + Vector3(0, -seg["size"].y * 0.5 + 0.04, 0),
			mats.floor,
		)
		ducts.add_child(floor_strip)


static func _name_room(parent: Node3D, room_name: String, local_pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = room_name
	n.position = local_pos
	parent.add_child(n)
	return n


static func _add_child_marker(parent: Node3D, local_pos: Vector3, spawn_id: String, out: Array) -> void:
	var m := Marker3D.new()
	m.name = "ChildSpawn_%s" % spawn_id
	m.position = local_pos
	m.add_to_group("child_spawn_points")
	m.set_meta("spawn_id", spawn_id)
	parent.add_child(m)
	out.append(m)
