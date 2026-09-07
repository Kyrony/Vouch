extends RefCounted
class_name UncleHouseBuilder
## Simple uncle house across the street from family homes.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, origin: Vector3, mats: HorrorGrayboxMaterials) -> Dictionary:
	var root := Node3D.new()
	root.name = "UncleHouse"
	root.position = origin
	parent.add_child(root)

	_GB.call("add_room_box", root, Vector3(12, 3, 10), Vector3.ZERO, mats, true, true)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 0), Vector3(0.25, 3, 10), mats.wall, true, 1.6)
	_GB.call("add_wall_panel", root, Vector3(0, 1.5, 5), Vector3(12, 3, 0.25), mats.wall, true, 2.0)
	root.add_child(_GEOM.call("box", Vector3(2, 0.75, 1), Vector3(-3, 0.38, -2), mats.wood))

	var child_marker := Marker3D.new()
	child_marker.name = "ChildSpawn_UncleBedroom"
	child_marker.position = Vector3(-4, 0.5, -3)
	child_marker.add_to_group("child_spawn_points")
	child_marker.set_meta("spawn_id", "uncle_bedroom")
	root.add_child(child_marker)

	return {"root": root, "child_marker": child_marker}
