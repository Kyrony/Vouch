extends RefCounted
class_name PMMansionBuilder
## L4 PM interior: named rooms + basement, bunker, utility closet, attic, ducts.
## Main floor sits at y=0 with a walkable foyer door onto the courtyard.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _KIT: GDScript = preload("res://scripts/horror/environment/modular_kit.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const MAIN_FLOOR_Y: float = 0.0
const BASEMENT_Y: float = -4.0
const BUNKER_Y: float = -12.0
const ATTIC_Y: float = 3.6
const DOOR_W: float = 1.15
const DOOR_H: float = 2.1


static func build(parent: Node3D, origin: Vector3, mats, rotation_y: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	root.name = "PMMansion"
	root.position = origin
	root.rotation.y = rotation_y
	parent.add_child(root)

	var child_markers: Array[Marker3D] = []
	var size: Vector3 = _V05.MANSION_SIZE
	var foyer_z: float = size.z * 0.5 - 1.4
	var pm_spawn := Marker3D.new()
	pm_spawn.name = "PM_Spawn_Foyer"
	pm_spawn.position = Vector3(0, 0.12, foyer_z)
	root.add_child(pm_spawn)

	var courtyard_spawn: Marker3D = _GB.call(
		"add_spawn_marker",
		root,
		Vector3(0, 0.12, size.z * 0.5 + 3.2),
		"PM_Courtyard",
	)
	courtyard_spawn.add_to_group("outdoor_player_spawns")

	_build_main_floor(root, mats, child_markers)
	_build_basement(root, mats, child_markers)
	_build_bunker(root, mats, child_markers)
	_build_attic(root, mats, child_markers)
	_build_ducts(root, mats)
	_build_stairwell(root, mats)

	var emergency := OmniLight3D.new()
	emergency.position = Vector3(0, 2.6, 0)
	emergency.light_color = Color(0.85, 0.3, 0.22)
	emergency.light_energy = 0.45
	emergency.omni_range = 26
	root.add_child(emergency)

	return {
		"root": root,
		"pm_spawn": pm_spawn,
		"courtyard_spawn": courtyard_spawn,
		"child_markers": child_markers,
	}


static func _build_main_floor(root: Node3D, mats, child_markers: Array) -> void:
	var floor_root := Node3D.new()
	floor_root.name = "MainFloor"
	root.add_child(floor_root)
	var size: Vector3 = _V05.MANSION_SIZE
	var doors := {"plus_z": DOOR_W, "height": DOOR_H}
	_GB.call("add_room_box_open", floor_root, size, Vector3(0, size.y * 0.5, 0), mats, true, true, doors)
	_KIT.call("add_open_door", floor_root, Vector3(0.0, 0.0, size.z * 0.5), mats)
	_GB.call("add_walkable_exit", floor_root, Vector3(0.0, 0.12, size.z * 0.5 + 0.4), "FoyerExit")

	# Three bays: west living stack, center circulation, east private.
	_GB.call("add_wall_panel", floor_root, Vector3(-3.4, 1.6, 0), Vector3(0.22, 3.2, size.z - 0.4), mats.wall, true, 1.5)
	_GB.call("add_wall_panel", floor_root, Vector3(3.4, 1.6, 0), Vector3(0.22, 3.2, size.z - 0.4), mats.wall, true, 1.5)
	_GB.call("add_wall_panel", floor_root, Vector3(-6.6, 1.6, 2.0), Vector3(6.2, 3.2, 0.22), mats.wall, true, 1.3)
	_GB.call("add_wall_panel", floor_root, Vector3(-6.6, 1.6, -2.2), Vector3(6.2, 3.2, 0.22), mats.wall, true, 1.2)
	_GB.call("add_wall_panel", floor_root, Vector3(0, 1.6, -2.2), Vector3(6.4, 3.2, 0.22), mats.wall, true, 1.15)
	_GB.call("add_wall_panel", floor_root, Vector3(6.6, 1.6, -0.4), Vector3(6.4, 3.2, 0.22), mats.wall, true, 1.4)

	_name_room(floor_root, "Hallway", Vector3(0, 0, 4.6))
	_name_room(floor_root, "Living", Vector3(-6.6, 0, 4.6))
	_name_room(floor_root, "Dining", Vector3(-6.6, 0, 0.0))
	_name_room(floor_root, "Kitchen", Vector3(-6.6, 0, -4.6))
	_name_room(floor_root, "Study", Vector3(0, 0, -5.0))
	_name_room(floor_root, "Bathroom", Vector3(6.4, 0, -4.8))
	var master := _name_room(floor_root, "MasterBedroom", Vector3(6.4, 0, 2.8))
	_add_child_marker(master, Vector3(0.6, 0.5, 0.4), "master_bedroom", child_markers)

	floor_root.add_child(_GEOM.call("box", Vector3(1.8, 0.7, 0.8), Vector3(-6.2, 0.35, 4.2), mats.wood))
	floor_root.add_child(_GEOM.call("box", Vector3(2.0, 0.85, 0.55), Vector3(-6.4, 0.42, -4.4), mats.wall))
	floor_root.add_child(_GEOM.call("box", Vector3(1.6, 0.45, 2.2), Vector3(6.0, 0.24, 2.6), mats.wood))


static func _build_basement(root: Node3D, mats, child_markers: Array) -> void:
	var bs := Node3D.new()
	bs.name = "Basement"
	bs.position = Vector3(0, BASEMENT_Y, 0)
	root.add_child(bs)
	var doors := {"plus_z": 1.2, "height": DOOR_H}
	_GB.call("add_room_box_open", bs, Vector3(14, 3.4, 12), Vector3(0, 1.7, 0), mats, true, true, doors)
	_GB.call("add_wall_panel", bs, Vector3(0, 1.7, 0), Vector3(0.22, 3.4, 11.6), mats.concrete, true, 1.5)
	_KIT.call("add_crate", bs, Vector3(-4.2, 0, -3.6), mats)
	_KIT.call("add_crate", bs, Vector3(-3.6, 0, -3.8), mats)
	_KIT.call("add_grate", bs, Vector3(2.6, 0.12, -2.6), mats)
	var pipes := Node3D.new()
	pipes.name = "Pipes"
	bs.add_child(pipes)
	_KIT.call("add_pipe_run", pipes, Vector3(-6.0, 2.8, -5.0), Vector3(6.0, 2.8, -5.0), 0.07, mats)
	_KIT.call("add_pipe_run", pipes, Vector3(-5.6, 2.4, 4.4), Vector3(-5.6, 0.4, 4.4), 0.08, mats)
	_KIT.call("add_fluorescent", bs, Vector3(0, 3.1, 0), mats)
	_add_child_marker(bs, Vector3(3.8, 0.5, 2.4), "basement", child_markers)
	_GB.call("add_walkable_exit", bs, Vector3(0.0, 0.12, 6.1), "BasementExit")


static func _build_bunker(root: Node3D, mats, child_markers: Array) -> void:
	var bk := Node3D.new()
	bk.name = "Bunker"
	bk.position = Vector3(0, BUNKER_Y, 0)
	root.add_child(bk)
	var doors := {"plus_z": 1.2, "height": DOOR_H}
	_GB.call("add_room_box_open", bk, Vector3(14, 3.8, 12), Vector3(0, 1.9, 0), mats, true, true, doors)
	_GB.call("add_wall_panel", bk, Vector3(-2.8, 1.9, 0), Vector3(0.22, 3.8, 11.6), mats.concrete, true, 2.0)

	var work := Node3D.new()
	work.name = "Workbench"
	bk.add_child(work)
	_KIT.call("add_workbench", work, Vector3(4.4, 0, 3.8), mats)

	var shelves := Node3D.new()
	shelves.name = "Shelves"
	bk.add_child(shelves)
	_KIT.call("add_shelf", shelves, Vector3(5.4, 0, -3.2), mats)
	_KIT.call("add_shelf", shelves, Vector3(5.4, 0, -1.4), mats)
	_KIT.call("add_crate", bk, Vector3(3.6, 0, -4.0), mats)
	_KIT.call("add_crate", bk, Vector3(4.1, 0, -3.6), mats)
	_KIT.call("add_grate", bk, Vector3(0.8, 0.12, 1.4), mats)

	var pipes := Node3D.new()
	pipes.name = "Pipes"
	bk.add_child(pipes)
	_KIT.call("add_pipe_run", pipes, Vector3(-6.2, 3.2, -5.2), Vector3(6.2, 3.2, -5.2), 0.08, mats)
	_KIT.call("add_pipe_run", pipes, Vector3(6.0, 3.2, -5.2), Vector3(6.0, 3.2, 4.8), 0.07, mats)
	_KIT.call("add_pipe_run", pipes, Vector3(-6.1, 2.9, 2.6), Vector3(-6.1, 0.5, 2.6), 0.09, mats)
	_KIT.call("add_pipe_run", pipes, Vector3(-1.8, 3.1, -4.8), Vector3(-1.8, 3.1, 4.0), 0.06, mats)
	_KIT.call("add_cyl", pipes, 0.1, 0.35, Vector3(6.0, 3.2, -5.2), mats.metal)
	_KIT.call("add_box", pipes, Vector3(0.55, 0.7, 0.22), Vector3(-6.0, 1.4, 4.0), mats.metal)

	var neon := Node3D.new()
	neon.name = "NeonStrips"
	bk.add_child(neon)
	_KIT.call("add_neon_strip", neon, Vector3(-2.6, 2.5, 0), Vector3(0.06, 0.06, 8.2), mats.neon_red)
	_KIT.call("add_neon_strip", neon, Vector3(3.0, 2.7, -5.4), Vector3(7.0, 0.06, 0.06), mats.fluorescent)
	_KIT.call("add_neon_strip", neon, Vector3(0.2, 0.18, 5.4), Vector3(5.4, 0.05, 0.05), mats.neon_red)

	var lights := Node3D.new()
	lights.name = "Fluorescent"
	bk.add_child(lights)
	_KIT.call("add_fluorescent", lights, Vector3(1.8, 3.5, 1.4), mats)
	_KIT.call("add_fluorescent", lights, Vector3(-3.8, 3.5, -1.8), mats)

	var panel := Node3D.new()
	panel.name = "ElectricalPanel"
	bk.add_child(panel)
	_KIT.call("add_box", panel, Vector3(0.55, 0.8, 0.12), Vector3(2.4, 1.4, 5.5), mats.metal)
	_KIT.call("add_neon_strip", panel, Vector3(2.4, 1.55, 5.56), Vector3(0.12, 0.08, 0.04), mats.neon_red)

	_build_utility_closet(bk, mats, child_markers)
	_GB.call("add_walkable_exit", bk, Vector3(0.0, 0.12, 6.1), "BunkerExit")

	var dim := OmniLight3D.new()
	dim.name = "BunkerMood"
	dim.position = Vector3(0, 3.1, 0)
	dim.light_color = Color(0.9, 0.32, 0.24)
	dim.light_energy = 0.38
	dim.omni_range = 18
	bk.add_child(dim)


static func _build_utility_closet(bk: Node3D, mats, child_markers: Array) -> void:
	var util := Node3D.new()
	util.name = "UtilityCloset"
	util.position = Vector3(-4.8, 0, -3.6)
	bk.add_child(util)
	var doors := {"plus_x": 1.05, "height": 2.05}
	_GB.call("add_room_box_open", util, Vector3(3.6, 2.6, 3.4), Vector3(0, 1.3, 0), mats, true, true, doors)
	var door := Node3D.new()
	door.name = "ClosetDoor"
	door.position = Vector3(1.8, 0.0, 0.0)
	door.rotation.y = -PI * 0.5
	util.add_child(door)
	_KIT.call("add_open_door", door, Vector3.ZERO, mats)
	var door_tag := Label3D.new()
	door_tag.text = "UTILITY"
	door_tag.font_size = 18
	door_tag.modulate = Color(0.95, 0.82, 0.35)
	door_tag.position = Vector3(0, 1.7, 0.12)
	door_tag.pixel_size = 0.01
	door.add_child(door_tag)
	_GB.call("add_walkable_exit", util, Vector3(1.9, 0.12, 0.0), "ClosetExit")

	var closet_shelves := Node3D.new()
	closet_shelves.name = "Shelves"
	util.add_child(closet_shelves)
	_KIT.call("add_shelf", closet_shelves, Vector3(-1.2, 0, -1.2), mats)
	_KIT.call("add_shelf", closet_shelves, Vector3(0.2, 0, -1.2), mats)
	_KIT.call("add_crate", util, Vector3(1.05, 0, -1.05), mats)

	var warm := OmniLight3D.new()
	warm.name = "ClosetLamp"
	warm.position = Vector3(0, 2.15, 0)
	warm.light_color = Color(1.0, 0.82, 0.42)
	warm.light_energy = 0.7
	warm.omni_range = 4.2
	util.add_child(warm)
	_KIT.call("add_neon_strip", util, Vector3(0, 2.3, -1.55), Vector3(1.6, 0.05, 0.05), mats.fluorescent)
	_add_child_marker(util, Vector3(0, 0.45, 0), "bunker_utility", child_markers)


static func _build_attic(root: Node3D, mats, child_markers: Array) -> void:
	var at := Node3D.new()
	at.name = "Attic"
	at.position = Vector3(0, ATTIC_Y, 0)
	root.add_child(at)
	var doors := {"plus_z": 1.1, "height": 1.9}
	_GB.call("add_room_box_open", at, Vector3(14, 2.2, 12), Vector3(0, 1.1, 0), mats, true, true, doors)
	_GB.call("add_wall_panel", at, Vector3(0, 1.1, 0), Vector3(0.22, 2.2, 11.6), mats.wall, true, 1.3)
	at.add_child(_GEOM.call("box", Vector3(2.6, 0.5, 1.3), Vector3(-3.6, 0.25, -3.0), mats.wood))
	_add_child_marker(at, Vector3(3.6, 0.45, 2.0), "pm_attic", child_markers)
	_GB.call("add_walkable_exit", at, Vector3(0.0, 0.12, 6.1), "AtticExit")


static func _build_stairwell(root: Node3D, mats) -> void:
	var sw := Node3D.new()
	sw.name = "Stairwell"
	sw.position = Vector3(0, 0, -1.2)
	root.add_child(sw)
	# Walkable switchbacks — start at the lower landing and climb.
	_add_switchback(sw, Vector3(0, BUNKER_Y, 1.4), BASEMENT_Y - BUNKER_Y, 0.0, mats)
	_add_switchback(sw, Vector3(0, BASEMENT_Y, -1.2), MAIN_FLOOR_Y - BASEMENT_Y, PI, mats)
	_add_switchback(sw, Vector3(0, MAIN_FLOOR_Y, 1.4), ATTIC_Y - MAIN_FLOOR_Y, 0.0, mats)
	sw.add_child(_GEOM.call("box", Vector3(1.6, 0.16, 1.6), Vector3(0, BASEMENT_Y, 0), mats.wood))
	sw.add_child(_GEOM.call("box", Vector3(1.6, 0.16, 1.6), Vector3(0, 0.0, 0), mats.wood))
	sw.add_child(_GEOM.call("box", Vector3(1.6, 0.16, 1.6), Vector3(0, ATTIC_Y, 0), mats.wood))


static func _add_switchback(parent: Node3D, origin: Vector3, rise: float, yaw: float, mats) -> void:
	var step_r: float = 0.18
	var step_t: float = 0.28
	var steps: int = maxi(2, int(round(rise / step_r)))
	var half: int = maxi(1, steps / 2)
	_add_flight(parent, origin, half, yaw, step_r, step_t, mats)
	var mid: Vector3 = origin + Vector3(sin(yaw), 0, cos(yaw)) * (float(half) * step_t) + Vector3(0, float(half) * step_r, 0)
	parent.add_child(_GEOM.call("box", Vector3(1.4, 0.16, 1.2), mid + Vector3(0, 0.02, 0), mats.wood))
	_add_flight(parent, mid, steps - half, yaw + PI, step_r, step_t, mats)


static func _add_flight(
	parent: Node3D,
	origin: Vector3,
	steps: int,
	yaw: float,
	rise: float,
	run: float,
	mats,
) -> void:
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	for i in steps:
		var p: Vector3 = origin + dir * (float(i) * run) + Vector3(0, rise * 0.5 + float(i) * rise, 0)
		var body: StaticBody3D = _GEOM.call("box", Vector3(1.25, rise, run), p, mats.wood)
		body.rotation.y = yaw
		parent.add_child(body)


static func _build_ducts(root: Node3D, mats) -> void:
	var ducts := Node3D.new()
	ducts.name = "DuctSystem"
	root.add_child(ducts)
	# Visual runs sit near the L4 rooms they link (collision off — not player traps).
	var placements := {
		"Attic-Study": {"size": Vector3(1.6, 0.7, 4.2), "pos": Vector3(-1.2, ATTIC_Y - 0.4, -2.4)},
		"Study-Kitchen": {"size": Vector3(4.8, 0.7, 1.6), "pos": Vector3(-2.8, 2.6, -4.6)},
		"Study-MasterBedroom": {"size": Vector3(4.2, 0.7, 1.6), "pos": Vector3(3.2, 2.6, -1.6)},
		"MasterBedroom-Living": {"size": Vector3(1.6, 0.7, 5.0), "pos": Vector3(6.2, 1.8, 3.6)},
		"Living-Basement": {"size": Vector3(1.6, 3.2, 1.6), "pos": Vector3(-6.2, BASEMENT_Y + 2.0, 4.2)},
		"Basement-Bunker": {"size": Vector3(1.6, 6.4, 1.6), "pos": Vector3(0.0, BUNKER_Y + 4.0, 2.2)},
		"Bunker-UtilityCloset": {"size": Vector3(3.2, 0.7, 1.6), "pos": Vector3(-3.2, BUNKER_Y + 2.8, -3.4)},
		"UtilityCloset-Hallway": {"size": Vector3(1.6, 10.4, 1.6), "pos": Vector3(-4.4, BUNKER_Y + 6.2, 4.4)},
		"Hallway-Stairwell": {"size": Vector3(2.4, 0.7, 1.6), "pos": Vector3(0.0, 2.4, 1.6)},
		"Stairwell-Dining": {"size": Vector3(4.6, 0.7, 1.6), "pos": Vector3(-3.2, 2.4, 0.2)},
		"Dining-Kitchen": {"size": Vector3(1.6, 0.7, 4.4), "pos": Vector3(-6.4, 2.6, -2.2)},
	}
	for link in _V05.PM_L4_DUCT_LINKS:
		var a: String = str(link["a"])
		var b: String = str(link["b"])
		var key: String = "%s-%s" % [a, b]
		var spec: Dictionary = placements.get(key, {"size": Vector3(1.6, 0.7, 2.4), "pos": Vector3.ZERO})
		var tunnel: StaticBody3D = _GEOM.call("box", spec["size"], spec["pos"], mats.duct, 0)
		tunnel.name = "Duct_%s_%s" % [a, b]
		tunnel.add_to_group("crawl_ducts")
		tunnel.set_meta("duct_a", a)
		tunnel.set_meta("duct_b", b)
		ducts.add_child(tunnel)


static func _name_room(parent: Node3D, room_name: String, local_pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = room_name
	n.position = local_pos
	parent.add_child(n)
	return n


static func _add_child_marker(parent: Node3D, local_pos: Vector3, spawn_id: String, out: Array) -> void:
	var m := Marker3D.new()
	m.position = local_pos
	parent.add_child(m)
	_V05.call("stamp_child_pin", m, spawn_id)
	out.append(m)
