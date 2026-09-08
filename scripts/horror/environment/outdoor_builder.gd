extends RefCounted
class_name OutdoorBuilder
## L1b farm yard: heightfield, lane network, outdoor L2 pins, courtyard.

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
	_build_farm_dressing(root, mats)
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
	fill.position = Vector3(0, 16, 6)
	fill.light_color = Color(0.72, 0.78, 0.88)
	fill.light_energy = 0.58
	fill.omni_range = 90
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
	var yaws: Array[float] = [0.45, -PI / 2.0, PI, PI]
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

	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 1.2, ROAD_THICK, Vector3(0, ROAD_Y, 0), mats.asphalt))
	roads.add_child(_GEOM.call("cylinder", 1.6, 0.16, Vector3(0, ROAD_Y + 0.04, 0), mats.grass))
	roads.add_child(_GEOM.call("box", Vector3(14.0, ROAD_THICK, 10.0), Vector3(40.0, ROAD_Y, 10.0), mats.asphalt))

	for spec in _V05.ROAD_SPANS:
		_add_road_span(roads, spec["a"], spec["b"], float(spec["r"]) * 2.0, mats)

	_add_curbs(roads, mats)
	_add_road_paint(roads)


static func _add_road_span(roads: Node3D, a: Vector2, b: Vector2, width: float, mats) -> void:
	var mid := (a + b) * 0.5
	var delta: Vector2 = b - a
	var length: float = delta.length()
	if length < 0.2:
		return
	var body: StaticBody3D = _GEOM.call(
		"box",
		Vector3(width, ROAD_THICK, length + 0.15),
		Vector3(mid.x, ROAD_Y, mid.y),
		mats.asphalt,
	)
	body.rotation.y = atan2(delta.x, delta.y)
	roads.add_child(body)
	var curb_off: float = width * 0.5 + 0.12
	var nx: float = -delta.y / length
	var nz: float = delta.x / length
	for side in [-1.0, 1.0]:
		var curb: StaticBody3D = _GEOM.call(
			"box",
			Vector3(0.22, CURB_H, length + 0.1),
			Vector3(mid.x + nx * curb_off * side, ROAD_Y + 0.08, mid.y + nz * curb_off * side),
			mats.curb,
			0,
		)
		curb.rotation.y = atan2(delta.x, delta.y)
		roads.add_child(curb)


static func _add_curbs(roads: Node3D, mats) -> void:
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 1.45, CURB_H, Vector3(0, ROAD_Y + 0.04, 0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(14.0, CURB_H, 0.26), Vector3(40.0, ROAD_Y + 0.08, 15.15), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(14.0, CURB_H, 0.26), Vector3(40.0, ROAD_Y + 0.08, 4.85), mats.curb, 0))


static func _add_road_paint(roads: Node3D) -> void:
	var paint := _mat(Color(0.82, 0.72, 0.28))
	for i in 11:
		var x: float = -22.0 + float(i) * 5.0
		roads.add_child(_GEOM.call("box", Vector3(1.4, 0.03, 0.16), Vector3(x, ROAD_Y + 0.08, 0), paint, 0))
	for i in 9:
		var z: float = -20.0 + float(i) * 5.0
		roads.add_child(_GEOM.call("box", Vector3(0.16, 0.03, 1.4), Vector3(0, ROAD_Y + 0.08, z), paint, 0))


static func _build_farm_dressing(root: Node3D, mats) -> void:
	var dress := Node3D.new()
	dress.name = "FarmDressing"
	root.add_child(dress)
	var trunk := _mat(Color(0.28, 0.2, 0.14))
	var canopy := _mat(Color(0.22, 0.34, 0.16))
	var tree_spots: Array[Vector3] = [
		Vector3(-38.0, 0, -32.0), Vector3(-26.0, 0, -34.0), Vector3(-18.0, 0, -38.0),
		Vector3(-54.0, 0, 22.0), Vector3(-48.0, 0, 28.0),
		Vector3(22.0, 0, 36.0), Vector3(28.0, 0, 30.0),
		Vector3(54.0, 0, 16.0), Vector3(-8.0, 0, 36.0),
		Vector3(18.0, 0, -36.0), Vector3(-6.0, 0, -40.0),
	]
	for p in tree_spots:
		var g: Vector3 = _grounded(p)
		var tree := Node3D.new()
		tree.position = Vector3(g.x, 0, g.z)
		dress.add_child(tree)
		tree.add_child(_GEOM.call("cylinder", 0.22, 2.4, Vector3(0, g.y + 1.2, 0), trunk, 0))
		tree.add_child(_GEOM.call("cylinder", 1.35, 1.8, Vector3(0, g.y + 2.8, 0), canopy, 0))
	# Plowed field strips (visual only).
	dress.add_child(_GEOM.call("box", Vector3(18.0, 0.04, 14.0), Vector3(-38.0, 0.03, 24.0), mats.dirt, 0))
	dress.add_child(_GEOM.call("box", Vector3(16.0, 0.04, 12.0), Vector3(20.0, 0.03, 26.0), mats.dirt, 0))


static func _build_street_lamps(root: Node3D) -> void:
	var lamps := Node3D.new()
	lamps.name = "StreetLamps"
	root.add_child(lamps)
	var spots: Array[Vector3] = [
		Vector3(-14.0, 0, -2.8),
		Vector3(14.0, 0, 2.8),
		Vector3(-2.8, 0, 14.0),
		Vector3(2.8, 0, -14.0),
		Vector3(22.0, 0, -8.0),
		Vector3(-30.0, 0, -10.0),
		Vector3(-40.0, 0, 6.0),
		Vector3(8.0, 0, 26.0),
	]
	var pole := _mat(Color(0.22, 0.22, 0.24))
	for p in spots:
		var g: Vector3 = _grounded(p)
		var lamp := Node3D.new()
		lamp.position = Vector3(g.x, 0, g.z)
		lamps.add_child(lamp)
		lamp.add_child(_GEOM.call("cylinder", 0.07, 3.4, Vector3(0, g.y + 1.7, 0), pole))
		lamp.add_child(_GEOM.call("box", Vector3(0.35, 0.12, 0.35), Vector3(0, g.y + 3.45, 0), _mat(Color(0.9, 0.82, 0.55)), 0))
		var light := OmniLight3D.new()
		light.position = Vector3(0, g.y + 3.3, 0)
		light.light_color = Color(1.0, 0.88, 0.62)
		light.light_energy = 0.85
		light.omni_range = 13.0
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
	m.position = local_pos
	parent.add_child(m)
	_V05.call("stamp_child_pin", m, spawn_id)
	out.append(m)


static func _build_soft_escape(pos: Vector3) -> Area3D:
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
