extends RefCounted
class_name OutdoorBuilder
## Phase 1 outdoor yard: large walkable heightfield, streets + curbs, outdoor pins.
## Houses / PM interiors stay kit-stubbed; player Host Match spawns are outdoors.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _KIT: GDScript = preload("res://scripts/horror/environment/modular_kit.gd")
const _TERRAIN: GDScript = preload("res://scripts/horror/environment/outdoor_terrain.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const ROAD_Y: float = 0.02
const ROAD_THICK: float = 0.10
const CURB_H: float = 0.16


static func build(parent: Node3D, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "Outdoor"
	parent.add_child(root)

	var terrain_result: Dictionary = _TERRAIN.call("build", root)
	_build_roads(root, mats)
	_build_street_lamps(root)

	var outdoor_markers: Array[Marker3D] = []
	_build_family_shed(root, mats, outdoor_markers)
	_build_storm_drain(root, mats, outdoor_markers)
	_build_garden_well(root, mats, outdoor_markers)
	_build_car_trunk(root, mats, outdoor_markers)

	var player_spawns: Array[Marker3D] = _build_player_spawns(root)
	var pm_spawn: Marker3D = _add_spawn_marker(
		root,
		_grounded(_V05.OUTDOOR_PM_SPAWN),
		"Outdoor_PM_Street",
		-PI / 2.0,
	)

	var zone := _build_soft_escape(_grounded(_V05.SOFT_ESCAPE_POS))
	root.add_child(zone)

	var fill := OmniLight3D.new()
	fill.name = "OutdoorFill"
	fill.position = Vector3(0, 14, 4)
	fill.light_color = Color(0.72, 0.78, 0.88)
	fill.light_energy = 0.55
	fill.omni_range = 70
	root.add_child(fill)

	return {
		"root": root,
		"escape_zone": zone,
		"outdoor_markers": outdoor_markers,
		"player_spawns": player_spawns,
		"pm_spawn": pm_spawn,
		"terrain": terrain_result.get("root"),
	}


static func _grounded(pos: Vector3) -> Vector3:
	var y: float = float(_TERRAIN.call("height_at", pos.x, pos.z))
	return Vector3(pos.x, maxf(y, 0.0) + 0.12, pos.z)


static func _build_player_spawns(root: Node3D) -> Array[Marker3D]:
	var folder := Node3D.new()
	folder.name = "PlayerSpawns"
	root.add_child(folder)
	var out: Array[Marker3D] = []
	var yaws: Array[float] = [0.0, -PI / 2.0, PI, PI / 2.0]
	var letters: Array[String] = ["A", "B", "C", "D"]
	for i in _V05.OUTDOOR_FAMILY_SPAWNS.size():
		var pos: Vector3 = _grounded(_V05.OUTDOOR_FAMILY_SPAWNS[i])
		out.append(_add_spawn_marker(folder, pos, "Outdoor_Family_%s" % letters[i], yaws[i]))
	return out


static func _add_spawn_marker(parent: Node3D, pos: Vector3, marker_name: String, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	m.rotation.y = yaw
	m.add_to_group("outdoor_player_spawns")
	parent.add_child(m)
	return m


static func _build_roads(root: Node3D, mats) -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)

	# Cul-de-sac bulb + grass island + stem south + mansion approach + west lane.
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 2.4, ROAD_THICK, Vector3(0, ROAD_Y, 0), mats.asphalt))
	roads.add_child(_GEOM.call("cylinder", 2.3, 0.18, Vector3(0, ROAD_Y + 0.04, 0), mats.grass))
	roads.add_child(_GEOM.call(
		"box",
		Vector3(_V05.STEM_WIDTH, ROAD_THICK, 26.0),
		Vector3(0, ROAD_Y, 16.0),
		mats.asphalt,
	))
	roads.add_child(_GEOM.call("box", Vector3(16.5, ROAD_THICK, 4.4), Vector3(12.0, ROAD_Y, 0), mats.asphalt))
	roads.add_child(_GEOM.call("box", Vector3(16.0, ROAD_THICK, 3.6), Vector3(-12.5, ROAD_Y, 0), mats.asphalt))

	_add_curbs(roads, mats)
	_add_road_paint(roads)


static func _add_curbs(roads: Node3D, mats) -> void:
	# Light concrete edges. Collision stays off so curbs never fence the street.
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 2.72, CURB_H, Vector3(0, ROAD_Y + 0.04, 0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(0.28, CURB_H, 26.0), Vector3(-2.72, ROAD_Y + 0.08, 16.0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(0.28, CURB_H, 26.0), Vector3(2.72, ROAD_Y + 0.08, 16.0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(16.5, CURB_H, 0.28), Vector3(12.0, ROAD_Y + 0.08, 2.34), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(16.5, CURB_H, 0.28), Vector3(12.0, ROAD_Y + 0.08, -2.34), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(16.0, CURB_H, 0.28), Vector3(-12.5, ROAD_Y + 0.08, 1.94), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(16.0, CURB_H, 0.28), Vector3(-12.5, ROAD_Y + 0.08, -1.94), mats.curb, 0))
	# Dirt shoulders — second ground collider next to asphalt (readable step, not a wall).
	var dirt_y: float = ROAD_Y - 0.01
	roads.add_child(_GEOM.call("box", Vector3(0.9, 0.08, 26.0), Vector3(-3.3, dirt_y, 16.0), mats.dirt))
	roads.add_child(_GEOM.call("box", Vector3(0.9, 0.08, 26.0), Vector3(3.3, dirt_y, 16.0), mats.dirt))
	roads.add_child(_GEOM.call("box", Vector3(16.5, 0.08, 0.85), Vector3(12.0, dirt_y, 2.95), mats.dirt))
	roads.add_child(_GEOM.call("box", Vector3(16.5, 0.08, 0.85), Vector3(12.0, dirt_y, -2.95), mats.dirt))
	roads.add_child(_GEOM.call("box", Vector3(16.0, 0.08, 0.85), Vector3(-12.5, dirt_y, 2.55), mats.dirt))
	roads.add_child(_GEOM.call("box", Vector3(16.0, 0.08, 0.85), Vector3(-12.5, dirt_y, -2.55), mats.dirt))


static func _add_road_paint(roads: Node3D) -> void:
	var paint := _mat(Color(0.82, 0.72, 0.28))
	# Dashed center lines — first-person readable asphalt, no collision.
	for i in 7:
		var z: float = 7.0 + float(i) * 3.2
		roads.add_child(_GEOM.call("box", Vector3(0.16, 0.03, 1.4), Vector3(0, ROAD_Y + 0.08, z), paint, 0))
	for i in 5:
		var x: float = 6.0 + float(i) * 2.8
		roads.add_child(_GEOM.call("box", Vector3(1.3, 0.03, 0.16), Vector3(x, ROAD_Y + 0.08, 0), paint, 0))


static func _build_street_lamps(root: Node3D) -> void:
	var lamps := Node3D.new()
	lamps.name = "StreetLamps"
	root.add_child(lamps)
	var spots: Array[Vector3] = [
		Vector3(-3.1, 0, -6.4),
		Vector3(3.1, 0, 6.4),
		Vector3(-3.1, 0, 14.0),
		Vector3(12.4, 0, -2.6),
		Vector3(-12.0, 0, 2.4),
	]
	var pole := _mat(Color(0.22, 0.22, 0.24))
	for p in spots:
		var g: Vector3 = _grounded(p)
		var lamp := Node3D.new()
		lamp.position = Vector3(g.x, 0, g.z)
		lamps.add_child(lamp)
		lamp.add_child(_GEOM.call("cylinder", 0.07, 3.4, Vector3(0, 1.7, 0), pole))
		lamp.add_child(_GEOM.call("box", Vector3(0.35, 0.12, 0.35), Vector3(0, 3.45, 0), _mat(Color(0.9, 0.82, 0.55)), 0))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.3, 0)
		light.light_color = Color(1.0, 0.88, 0.62)
		light.light_energy = 0.85
		light.omni_range = 11.0
		lamp.add_child(light)


static func _build_family_shed(root: Node3D, mats, markers: Array) -> void:
	var shed := Node3D.new()
	shed.name = "FamilyShed"
	shed.position = _grounded(_V05.FAMILY_SHED_POS) - Vector3(0, 0.12, 0)
	root.add_child(shed)
	_KIT.call("add_box", shed, Vector3(3.4, 2.15, 2.8), Vector3(0, 1.08, 0), mats.siding)
	var roof: StaticBody3D = _KIT.call("add_box", shed, Vector3(3.7, 0.14, 3.1), Vector3(0, 2.28, 0), mats.shingle) as StaticBody3D
	roof.rotation.z = 0.16
	_KIT.call("add_box", shed, Vector3(0.85, 1.45, 0.1), Vector3(0, 0.72, 1.42), mats.wood)
	_add_child_marker(shed, Vector3(0, 0.3, 0), "family_shed", markers)


static func _build_storm_drain(root: Node3D, mats, markers: Array) -> void:
	var drain := Node3D.new()
	drain.name = "StormDrain"
	drain.position = _grounded(_V05.STORM_DRAIN_POS)
	root.add_child(drain)
	drain.add_child(_GEOM.call("box", Vector3(2.6, 0.32, 1.8), Vector3(0, -0.36, 0), mats.dirt))
	drain.add_child(_GEOM.call("box", Vector3(2.1, 0.08, 1.3), Vector3(0, 0.02, 0), _mat(Color(0.2, 0.2, 0.22))))
	_add_child_marker(drain, Vector3(0, -0.12, 0), "storm_drain", markers)


static func _build_garden_well(root: Node3D, mats, markers: Array) -> void:
	var well := Node3D.new()
	well.name = "GardenWell"
	well.position = _grounded(_V05.GARDEN_WELL_POS)
	root.add_child(well)
	well.add_child(_GEOM.call("cylinder", 0.85, 1.05, Vector3(0, 0.52, 0), mats.wall))
	well.add_child(_GEOM.call("box", Vector3(1.1, 0.12, 1.1), Vector3(0, 1.1, 0), mats.wood))
	_add_child_marker(well, Vector3(0, 0.2, 0), "garden_well", markers)


static func _build_car_trunk(root: Node3D, mats, markers: Array) -> void:
	var car := Node3D.new()
	car.name = "ParkedCar"
	car.position = _grounded(_V05.CAR_TRUNK_POS)
	root.add_child(car)
	car.add_child(_GEOM.call("box", Vector3(3.8, 1.0, 1.7), Vector3(0, 0.5, 0), _mat(Color(0.18, 0.2, 0.22))))
	car.add_child(_GEOM.call("box", Vector3(1.5, 0.65, 1.6), Vector3(-0.35, 1.15, 0), _mat(Color(0.16, 0.17, 0.19))))
	car.add_child(_GEOM.call("box", Vector3(0.85, 0.32, 1.5), Vector3(1.55, 0.62, 0), _mat(Color(0.14, 0.14, 0.15))))
	_add_child_marker(car, Vector3(1.55, 0.42, 0), "car_trunk", markers)


static func _add_child_marker(parent: Node3D, local_pos: Vector3, spawn_id: String, out: Array) -> void:
	var m := Marker3D.new()
	m.name = "ChildSpawn_%s" % spawn_id
	m.position = local_pos
	m.add_to_group("child_spawn_points")
	m.set_meta("spawn_id", spawn_id)
	parent.add_child(m)
	out.append(m)


static func _build_soft_escape(pos: Vector3) -> Area3D:
	# Master sheet has no escape routes — zone is unmarked, no signage.
	var zone := Area3D.new()
	zone.name = "HorrorEscapeZone"
	zone.position = pos
	zone.collision_layer = 0
	zone.collision_mask = 4
	zone.set_meta("soft_gated", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3.2, 6)
	shape.shape = box
	zone.add_child(shape)
	zone.set_script(load("res://scripts/interactables/escape_zone.gd"))
	var dirt: StaticBody3D = _GEOM.call("box", Vector3(4.2, 0.08, 4.2), Vector3(0, -0.35, 0), _mat(Color(0.3, 0.26, 0.2)))
	zone.add_child(dirt)
	return zone


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m
