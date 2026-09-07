extends RefCounted
class_name OutdoorBuilder
## Mountainous yard, street, garden shed, and escape zone between houses.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "Outdoor"
	parent.add_child(root)

	# Main yard plane
	root.add_child(_GEOM.call("box", Vector3(160, 0.4, 140), Vector3(0, -0.2, -10), mats.field))

	# Street between family row (+Z) and uncle house
	root.add_child(_GEOM.call("box", Vector3(80, 0.12, 8), Vector3(0, 0.02, 28), _mat(Color(0.22, 0.22, 0.24))))

	# Mountain slopes at edges
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

	# Outdoor shed stub
	var shed := Node3D.new()
	shed.name = "OutdoorShed"
	shed.position = Vector3(42, 0, -20)
	root.add_child(shed)
	shed.add_child(_GEOM.call("box", Vector3(4, 2.5, 3), Vector3(0, 1.25, 0), mats.wall))
	var shed_child := Marker3D.new()
	shed_child.name = "ChildSpawn_outdoor_shed"
	shed_child.position = Vector3(0, 0.3, 0)
	shed_child.add_to_group("child_spawn_points")
	shed_child.set_meta("spawn_id", "outdoor_shed")
	shed.add_child(shed_child)

	# Escape zone — field edge toward mountains
	var zone := _build_escape_zone(Vector3(0, 0.5, 58))
	root.add_child(zone)

	return {
		"root": root,
		"escape_zone": zone,
		"outdoor_markers": [shed_child],
	}


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
