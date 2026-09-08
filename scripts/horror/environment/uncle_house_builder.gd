extends RefCounted
class_name UncleHouseBuilder
## L-shaped uncle house (center-west) + detached garage (NE of PM, L1b).

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _KIT: GDScript = preload("res://scripts/horror/environment/modular_kit.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(parent: Node3D, origin: Vector3, mats, rotation_y: float = -PI / 2.0) -> Dictionary:
	var root := Node3D.new()
	root.name = "UncleHouse"
	root.position = origin
	root.rotation.y = rotation_y
	parent.add_child(root)

	var size: Vector3 = _V05.UNCLE_HOUSE_SIZE
	var doors := {"plus_z": 1.1, "plus_x": 1.1, "plus_x_off": 1.1, "height": 2.1}
	_GB.call("add_room_box_open", root, size, Vector3(0, size.y * 0.5, 0), mats, true, true, doors)
	_GB.call("add_wall_panel", root, Vector3(-1.4, 1.4, 0.2), Vector3(0.22, 2.8, 7.4), mats.wall, true, 1.1)
	_GB.call("add_wall_panel", root, Vector3(1.6, 1.4, 1.2), Vector3(6.4, 2.8, 0.22), mats.wall, true, 1.05)
	# L-wing toward local +X
	root.add_child(_GEOM.call("box", Vector3(4.4, 0.2, 4.6), Vector3(5.4, 0.1, 1.6), mats.floor))
	root.add_child(_GEOM.call("box", Vector3(4.4, 0.2, 4.6), Vector3(5.4, 2.7, 1.6), mats.ceiling))
	root.add_child(_GEOM.call("box", Vector3(0.22, 2.8, 4.6), Vector3(7.55, 1.4, 1.6), mats.wall))
	root.add_child(_GEOM.call("box", Vector3(4.4, 2.8, 0.22), Vector3(5.4, 1.4, 3.85), mats.wall))
	root.add_child(_GEOM.call("box", Vector3(4.4, 2.8, 0.22), Vector3(5.4, 1.4, -0.65), mats.wall))
	root.add_child(_GEOM.call("box", Vector3(1.8, 0.7, 0.9), Vector3(-2.6, 0.35, -1.8), mats.wood))

	_KIT.call("add_open_door", root, Vector3(0.0, 0.0, size.z * 0.5), mats)
	_GB.call("add_walkable_exit", root, Vector3(0.0, 0.12, size.z * 0.5 + 0.4), "FrontExit")
	_KIT.call("add_roof_slopes", root, size, size.y + 0.12, mats)

	var bedroom := Marker3D.new()
	bedroom.position = Vector3(-2.8, 0.5, -2.1)
	root.add_child(bedroom)
	_V05.call("stamp_child_pin", bedroom, "uncle_bedroom")

	var porch_spawn: Marker3D = _GB.call("add_spawn_marker", root, Vector3(0.0, 0.12, size.z * 0.5 + 1.2), "Uncle_Porch")
	porch_spawn.add_to_group("outdoor_player_spawns")

	return {"root": root, "child_marker": bedroom, "porch_spawn": porch_spawn}


static func build_garage(parent: Node3D, origin: Vector3, mats, rotation_y: float = PI / 2.0) -> Dictionary:
	var garage := Node3D.new()
	garage.name = "UncleGarage"
	garage.position = origin
	garage.rotation.y = rotation_y
	parent.add_child(garage)

	var size: Vector3 = _V05.UNCLE_GARAGE_SIZE
	var doors := {"plus_z": 2.6, "height": 2.2}
	_GB.call("add_room_box_open", garage, size, Vector3(0, size.y * 0.5, 0), mats, true, true, doors)
	garage.add_child(_GEOM.call("box", Vector3(1.6, 0.85, 2.3), Vector3(-1.4, 0.42, -1.2), mats.wall))
	_KIT.call("add_open_door", garage, Vector3(0.0, 0.0, size.z * 0.5), mats)
	_GB.call("add_walkable_exit", garage, Vector3(0.0, 0.12, size.z * 0.5 + 0.35), "GarageBay")

	var garage_child := Marker3D.new()
	garage_child.position = Vector3(-1.5, 0.4, 1.6)
	garage.add_child(garage_child)
	_V05.call("stamp_child_pin", garage_child, "uncle_garage")

	return {"root": garage, "garage_marker": garage_child}
