extends RefCounted
class_name OutdoorBuilder
## v0.5 yard: cul-de-sac + stem + curbs, outdoor pins, soft-gated escape.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(parent: Node3D, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "Outdoor"
	parent.add_child(root)

	root.add_child(_GEOM.call("box", Vector3(56, 0.35, 50), Vector3(6, -0.22, 2), mats.field))
	_build_roads(root, mats)
	_build_shoulders(root)

	var outdoor_markers: Array[Marker3D] = []
	_build_family_shed(root, mats, outdoor_markers)
	_build_storm_drain(root, mats, outdoor_markers)
	_build_garden_well(root, mats, outdoor_markers)
	_build_car_trunk(root, mats, outdoor_markers)

	var zone := _build_soft_escape(_V05.SOFT_ESCAPE_POS)
	root.add_child(zone)

	return {
		"root": root,
		"escape_zone": zone,
		"outdoor_markers": outdoor_markers,
	}


static func _build_roads(root: Node3D, mats) -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)
	# Cul-de-sac bulb + inner island + stem south + mansion approach.
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 2.4, 0.12, Vector3(0, 0.02, 0), mats.asphalt))
	roads.add_child(_GEOM.call("cylinder", 2.3, 0.16, Vector3(0, 0.06, 0), mats.grass))
	roads.add_child(_GEOM.call(
		"box",
		Vector3(_V05.STEM_WIDTH, 0.12, _V05.STEM_LENGTH),
		Vector3(0, 0.02, _V05.BULB_RADIUS + _V05.STEM_LENGTH * 0.5 - 0.4),
		mats.asphalt,
	))
	roads.add_child(_GEOM.call("box", Vector3(8.5, 0.12, 4.2), Vector3(12.6, 0.02, 0), mats.asphalt))
	# Curbs
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 2.7, 0.22, Vector3(0, 0.08, 0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(0.28, 0.22, _V05.STEM_LENGTH), Vector3(-2.7, 0.12, 11.4), mats.curb))
	roads.add_child(_GEOM.call("box", Vector3(0.28, 0.22, _V05.STEM_LENGTH), Vector3(2.7, 0.12, 11.4), mats.curb))
	roads.add_child(_GEOM.call("box", Vector3(8.5, 0.2, 0.28), Vector3(12.6, 0.1, 2.2), mats.curb))
	roads.add_child(_GEOM.call("box", Vector3(8.5, 0.2, 0.28), Vector3(12.6, 0.1, -2.2), mats.curb))


static func _build_shoulders(root: Node3D) -> void:
	var slope_mat := _mat(Color(0.34, 0.32, 0.28))
	for d in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var pos: Vector3 = d * 28.0 + Vector3(6, 4.2, 2)
		var body: StaticBody3D = _GEOM.call("box", Vector3(22, 8, 10), pos, slope_mat)
		body.rotation.y = atan2(d.x, d.z)
		body.rotation.x = -0.28
		root.add_child(body)
	var peak_mat := _mat(Color(0.45, 0.43, 0.4))
	for p in [Vector3(-24, 12, -22), Vector3(38, 14, -18), Vector3(-22, 11, 24), Vector3(36, 15, 22)]:
		root.add_child(_GEOM.call("box", Vector3(14, 14, 12), p, peak_mat))


static func _build_family_shed(root: Node3D, mats, markers: Array) -> void:
	var shed := Node3D.new()
	shed.name = "FamilyShed"
	shed.position = _V05.FAMILY_SHED_POS
	root.add_child(shed)
	shed.add_child(_GEOM.call("box", Vector3(3.4, 2.3, 2.8), Vector3(0, 1.15, 0), mats.wall))
	_add_child_marker(shed, Vector3(0, 0.3, 0), "family_shed", markers)


static func _build_storm_drain(root: Node3D, mats, markers: Array) -> void:
	var drain := Node3D.new()
	drain.name = "StormDrain"
	drain.position = _V05.STORM_DRAIN_POS
	root.add_child(drain)
	drain.add_child(_GEOM.call("box", Vector3(2.6, 0.32, 1.8), Vector3(0, -0.36, 0), mats.dirt))
	drain.add_child(_GEOM.call("box", Vector3(2.1, 0.08, 1.3), Vector3(0, 0.02, 0), _mat(Color(0.2, 0.2, 0.22))))
	_add_child_marker(drain, Vector3(0, -0.12, 0), "storm_drain", markers)


static func _build_garden_well(root: Node3D, mats, markers: Array) -> void:
	var well := Node3D.new()
	well.name = "GardenWell"
	well.position = _V05.GARDEN_WELL_POS
	root.add_child(well)
	well.add_child(_GEOM.call("cylinder", 0.85, 1.05, Vector3(0, 0.52, 0), mats.wall))
	well.add_child(_GEOM.call("box", Vector3(1.1, 0.12, 1.1), Vector3(0, 1.1, 0), mats.wood))
	_add_child_marker(well, Vector3(0, 0.2, 0), "garden_well_crawlspace", markers)


static func _build_car_trunk(root: Node3D, mats, markers: Array) -> void:
	var car := Node3D.new()
	car.name = "ParkedCar"
	car.position = _V05.CAR_TRUNK_POS
	root.add_child(car)
	car.add_child(_GEOM.call("box", Vector3(3.8, 1.0, 1.7), Vector3(0, 0.5, 0), _mat(Color(0.18, 0.2, 0.22))))
	car.add_child(_GEOM.call("box", Vector3(1.5, 0.65, 1.6), Vector3(-0.35, 1.15, 0), _mat(Color(0.16, 0.17, 0.19))))
	car.add_child(_GEOM.call("box", Vector3(0.85, 0.32, 1.5), Vector3(1.55, 0.62, 0), _mat(Color(0.14, 0.14, 0.15))))
	_add_child_marker(car, Vector3(1.55, 0.42, 0), "car_trunk_curb", markers)


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
