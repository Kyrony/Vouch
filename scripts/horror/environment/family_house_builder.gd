extends RefCounted
class_name FamilyHouseBuilder
## One-story family house with bedroom spawn room per survivor team.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func build(parent: Node3D, origin: Vector3, family_index: int, mats: HorrorGrayboxMaterials) -> Dictionary:
	var root := Node3D.new()
	root.name = "FamilyHouse_%d" % family_index
	root.position = origin
	parent.add_child(root)

	# Footprint 14x10, wall height 3m — living + kitchen + bedroom
	_GB.call("add_room_box", root, Vector3(14, 3, 10), Vector3.ZERO, mats, true, true)
	# Split: bedroom west, living east
	_GB.call("add_wall_panel", root, Vector3(-3.5, 1.5, 0), Vector3(0.25, 3, 10), mats.wall, true, 1.8)
	# Bathroom partition in bedroom wing
	_GB.call("add_wall_panel", root, Vector3(-5.5, 1.5, 2.5), Vector3(5, 3, 0.25), mats.wall, true, 1.2)

	# Front door (+Z)
	_GB.call("add_wall_panel", root, Vector3(2, 1.5, 5), Vector3(8, 3, 0.25), mats.wall, true, 2.0)
	# Porch
	root.add_child(_GEOM.call("box", Vector3(3.5, 0.15, 2), Vector3(2, 0.08, 6.2), mats.floor))
	# Kitchen counter
	root.add_child(_GEOM.call("box", Vector3(2.5, 0.9, 0.5), Vector3(4, 0.45, -3.5), mats.wall))

	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	var bedroom_spawn: Marker3D = _GB.call("add_spawn_marker", spawns, Vector3(-5.5, 0.1, -2), "Family%d_Bedroom" % family_index)

	# Dead family body stub in living room (PM possession target)
	_GB.call("add_dead_body_stub", root, Vector3(3, 0, 1), family_index)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 0)
	light.light_color = Color(0.85, 0.7, 0.55)
	light.light_energy = 0.35
	light.omni_range = 12
	root.add_child(light)

	return {
		"root": root,
		"bedroom_spawn": bedroom_spawn,
		"family_index": family_index,
	}
