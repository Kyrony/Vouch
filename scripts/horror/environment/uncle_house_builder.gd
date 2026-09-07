extends RefCounted
class_name UncleHouseBuilder
## Uncle house across the street — bedroom + attached garage (alive hides).

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, origin: Vector3, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "UncleHouse"
	root.position = origin
	parent.add_child(root)

	_GB.call("add_room_box", root, Vector3(12, 3, 10), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 0), Vector3(0.25, 3, 10), mats.wall, true, 1.6)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 5), Vector3(12, 3, 0.25), mats.wall, true, 2.0)
	root.add_child(_GEOM.call("box", Vector3(2, 0.75, 1), Vector3(-3, 0.38, -2), mats.wood))

	var bedroom := Marker3D.new()
	bedroom.name = "ChildSpawn_uncle_bedroom"
	bedroom.position = Vector3(-4, 0.5, -3)
	bedroom.add_to_group("child_spawn_points")
	bedroom.set_meta("spawn_id", "uncle_bedroom")
	root.add_child(bedroom)

	var garage := Node3D.new()
	garage.name = "UncleGarage"
	garage.position = Vector3(9.5, 0, 0)
	root.add_child(garage)
	_GB.call("add_room_box", garage, Vector3(7, 2.8, 8), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", garage, Vector3(-3.5, 1.4, 0), Vector3(0.25, 2.8, 8), mats.wall, true, 2.2)
	garage.add_child(_GEOM.call("box", Vector3(1.6, 0.9, 2.4), Vector3(1.2, 0.45, -1.2), mats.wall))

	var garage_child := Marker3D.new()
	garage_child.name = "ChildSpawn_uncle_garage"
	garage_child.position = Vector3(1.6, 0.4, 2.2)
	garage_child.add_to_group("child_spawn_points")
	garage_child.set_meta("spawn_id", "uncle_garage")
	garage.add_child(garage_child)

	return {"root": root, "child_marker": bedroom, "garage_marker": garage_child}
