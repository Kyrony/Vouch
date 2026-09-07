extends RefCounted
class_name UncleHouseBuilder
## Uncle house + attached garage along the stem (alive hides).

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, origin: Vector3, mats, rotation_y: float = PI) -> Dictionary:
	var root := Node3D.new()
	root.name = "UncleHouse"
	root.position = origin
	root.rotation.y = rotation_y
	parent.add_child(root)

	_GB.call("add_room_box", root, Vector3(8.5, 3, 7.0), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 0), Vector3(0.25, 3, 7.0), mats.wall, true, 1.5)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 3.5), Vector3(8.5, 3, 0.25), mats.wall, true, 1.8)
	root.add_child(_GEOM.call("box", Vector3(1.8, 0.7, 0.9), Vector3(-2.2, 0.35, -1.6), mats.wood))

	var bedroom := Marker3D.new()
	bedroom.name = "ChildSpawn_uncle_bedroom"
	bedroom.position = Vector3(-2.6, 0.5, -2.0)
	bedroom.add_to_group("child_spawn_points")
	bedroom.set_meta("spawn_id", "uncle_bedroom")
	root.add_child(bedroom)

	# Local -X becomes world +X after 180° yaw — garage sits toward the stem.
	var garage := Node3D.new()
	garage.name = "UncleGarage"
	garage.position = Vector3(-6.8, 0, 0.4)
	root.add_child(garage)
	_GB.call("add_room_box", garage, Vector3(5.2, 2.7, 6.2), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", garage, Vector3(2.6, 1.35, 0), Vector3(0.25, 2.7, 6.2), mats.wall, true, 2.1)
	garage.add_child(_GEOM.call("box", Vector3(1.5, 0.85, 2.2), Vector3(-0.6, 0.42, -1.0), mats.wall))

	var garage_child := Marker3D.new()
	garage_child.name = "ChildSpawn_uncle_garage"
	garage_child.position = Vector3(-1.4, 0.4, 1.8)
	garage_child.add_to_group("child_spawn_points")
	garage_child.set_meta("spawn_id", "uncle_garage")
	garage.add_child(garage_child)

	return {"root": root, "child_marker": bedroom, "garage_marker": garage_child}
