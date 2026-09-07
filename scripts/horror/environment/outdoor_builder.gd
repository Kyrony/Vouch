extends RefCounted
class_name OutdoorBuilder
## Mountainous yard, street, shed, storm drain, well, car, and escape zone.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "Outdoor"
	parent.add_child(root)

	root.add_child(_GEOM.call("box", Vector3(160, 0.4, 140), Vector3(0, -0.2, -10), mats.field))
	root.add_child(_GEOM.call("box", Vector3(80, 0.12, 8), Vector3(0, 0.02, 28), _mat(Color(0.22, 0.22, 0.24))))

	var slope_mat := _mat(Color(0.34, 0.32, 0.28))
	for d in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var pos: Vector3 = d * 68.0 + Vector3(0, 5, -10)
		var body: StaticBody3D = _GEOM.call("box", Vector3(50, 10, 20), pos, slope_mat)
		body.rotation.y = atan2(d.x, d.z)
		body.rotation.x = -0.25
		root.add_child(body)

	var peak_mat := _mat(Color(0.45, 0.43, 0.4))
	for p in [Vector3(-62, 16, -58), Vector3(64, 18, -52), Vector3(-58, 14, 38), Vector3(60, 20, 42)]:
		root.add_child(_GEOM.call("box", Vector3(26, 20, 22), p, peak_mat))

	var outdoor_markers: Array[Marker3D] = []
	_build_family_shed(root, mats, outdoor_markers)
	_build_storm_drain(root, mats, outdoor_markers)
	_build_garden_well(root, mats, outdoor_markers)
	_build_car_trunk(root, mats, outdoor_markers)

	var zone := _build_escape_zone(Vector3(0, 0.5, 58))
	root.add_child(zone)

	return {
		"root": root,
		"escape_zone": zone,
		"outdoor_markers": outdoor_markers,
	}


static func _build_family_shed(root: Node3D, mats, markers: Array) -> void:
	var shed := Node3D.new()
	shed.name = "FamilyShed"
	shed.position = Vector3(42, 0, -20)
	root.add_child(shed)
	shed.add_child(_GEOM.call("box", Vector3(4, 2.5, 3), Vector3(0, 1.25, 0), mats.wall))
	_add_child_marker(shed, Vector3(0, 0.3, 0), "family_shed", markers)


static func _build_storm_drain(root: Node3D, mats, markers: Array) -> void:
	var drain := Node3D.new()
	drain.name = "StormDrain"
	drain.position = Vector3(-22, 0, 22)
	root.add_child(drain)
	drain.add_child(_GEOM.call("box", Vector3(3.2, 0.35, 2.2), Vector3(0, -0.4, 0), mats.dirt))
	drain.add_child(_GEOM.call("box", Vector3(2.6, 0.08, 1.6), Vector3(0, 0.02, 0), _mat(Color(0.2, 0.2, 0.22))))
	_add_child_marker(drain, Vector3(0, -0.15, 0), "storm_drain", markers)


static func _build_garden_well(root: Node3D, mats, markers: Array) -> void:
	var well := Node3D.new()
	well.name = "GardenWell"
	well.position = Vector3(-18, 0, -24)
	root.add_child(well)
	well.add_child(_GEOM.call("box", Vector3(2.2, 1.1, 2.2), Vector3(0, 0.55, 0), mats.wall))
	well.add_child(_GEOM.call("box", Vector3(1.2, 0.15, 1.2), Vector3(0, 1.15, 0), mats.wood))
	_add_child_marker(well, Vector3(0, 0.2, 0), "garden_well", markers)


static func _build_car_trunk(root: Node3D, mats, markers: Array) -> void:
	var car := Node3D.new()
	car.name = "ParkedCar"
	car.position = Vector3(18, 0, 22)
	root.add_child(car)
	car.add_child(_GEOM.call("box", Vector3(4.2, 1.1, 1.8), Vector3(0, 0.55, 0), _mat(Color(0.18, 0.2, 0.22))))
	car.add_child(_GEOM.call("box", Vector3(1.6, 0.7, 1.7), Vector3(-0.4, 1.25, 0), _mat(Color(0.16, 0.17, 0.19))))
	car.add_child(_GEOM.call("box", Vector3(0.9, 0.35, 1.6), Vector3(1.7, 0.7, 0), _mat(Color(0.14, 0.14, 0.15))))
	_add_child_marker(car, Vector3(1.7, 0.45, 0), "car_trunk", markers)


static func _add_child_marker(parent: Node3D, local_pos: Vector3, spawn_id: String, out: Array) -> void:
	var m := Marker3D.new()
	m.name = "ChildSpawn_%s" % spawn_id
	m.position = local_pos
	m.add_to_group("child_spawn_points")
	m.set_meta("spawn_id", spawn_id)
	parent.add_child(m)
	out.append(m)


static func _build_escape_zone(pos: Vector3) -> Area3D:
	var zone := Area3D.new()
	zone.name = "HorrorEscapeZone"
	zone.position = pos
	zone.collision_layer = 0
	zone.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 4, 10)
	shape.shape = box
	zone.add_child(shape)
	zone.set_script(load("res://scripts/interactables/escape_zone.gd"))
	var pole: StaticBody3D = _GEOM.call("box", Vector3(0.3, 3, 0.3), Vector3(-7, 1.5, 0), _mat(Color(0.2, 0.7, 0.35)))
	zone.add_child(pole)
	var sign: StaticBody3D = _GEOM.call("box", Vector3(5, 1, 0.2), Vector3(0, 2, 0), _mat(Color(0.15, 0.55, 0.25)))
	zone.add_child(sign)
	return zone


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m
