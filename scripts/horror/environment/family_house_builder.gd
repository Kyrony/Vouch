extends RefCounted
class_name FamilyHouseBuilder
## One-story family house A–D around the cul-de-sac. Front is local +Z.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(
	parent: Node3D,
	origin: Vector3,
	family_index: int,
	mats,
	rotation_y: float = 0.0,
	letter: String = "",
) -> Dictionary:
	var tag: String = letter if not letter.is_empty() else str(family_index)
	var root := Node3D.new()
	root.name = "FamilyHouse_%s" % tag
	root.position = origin
	root.rotation.y = rotation_y
	parent.add_child(root)

	var size: Vector3 = _V05.FAMILY_HOUSE_SIZE
	_GB.call("add_room_box", root, size, Vector3.ZERO, mats, true, true)
	# Bedroom west, living east
	_GB.call("add_wall_panel", root, Vector3(-1.6, 1.5, 0), Vector3(0.25, 3, size.z), mats.wall, true, 1.6)
	_GB.call("add_wall_panel", root, Vector3(-2.8, 1.5, 1.4), Vector3(3.2, 3, 0.25), mats.wall, true, 1.1)
	_GB.call("add_wall_panel", root, Vector3(1.2, 1.5, size.z * 0.5), Vector3(5.2, 3, 0.25), mats.wall, true, 1.8)

	var porch_z: float = size.z * 0.5 + 1.05
	root.add_child(_GEOM.call("box", Vector3(3.2, 0.14, 1.9), Vector3(1.1, 0.07, porch_z), mats.floor))
	root.add_child(_GEOM.call("box", Vector3(2.9, 0.32, 1.7), Vector3(1.1, -0.26, porch_z), mats.dirt))
	root.add_child(_GEOM.call("box", Vector3(2.1, 0.85, 0.45), Vector3(2.4, 0.42, -2.2), mats.wall))

	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	var bedroom_spawn: Marker3D = _GB.call(
		"add_spawn_marker",
		spawns,
		Vector3(-2.8, 0.1, -1.6),
		"Family%s_Bedroom" % tag,
	)
	_GB.call("add_dead_body_stub", root, Vector3(1.8, 0, 0.4), family_index)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.5, 0)
	light.light_color = Color(0.85, 0.7, 0.55)
	light.light_energy = 0.32
	light.omni_range = 10
	root.add_child(light)

	var porch_hide: Marker3D = null
	if letter == "A" or family_index == 0:
		porch_hide = Marker3D.new()
		porch_hide.name = "ChildSpawn_under_porch_crawl"
		porch_hide.position = Vector3(1.1, -0.1, porch_z)
		porch_hide.add_to_group("child_spawn_points")
		porch_hide.set_meta("spawn_id", "under_porch_crawl")
		root.add_child(porch_hide)

	return {
		"root": root,
		"bedroom_spawn": bedroom_spawn,
		"family_index": family_index,
		"letter": tag,
		"porch_hide": porch_hide,
	}
