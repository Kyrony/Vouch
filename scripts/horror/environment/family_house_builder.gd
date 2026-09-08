extends RefCounted
class_name FamilyHouseBuilder
## One-story family house A–D on L1b farm parcels. Front is local +Z.
##
## Leonardo kit: 13.5 x 11 m, raised porch, under-porch crawl on A.
## Graybox CSG/boxes only — walls have real door cuts so bedrooms exit to yard.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _KIT: GDScript = preload("res://scripts/horror/environment/modular_kit.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const DECK_Y: float = 0.72
const FRONT_DOOR_W: float = 1.1
const FRONT_DOOR_H: float = 2.1


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
	var porch_z: float = size.z * 0.5 + 1.1
	var porch_x: float = 0.0

	_build_foundation(root, size, porch_x, porch_z, mats)
	var body_spawns: Dictionary = _build_house_body(root, size, family_index, tag, mats)
	_build_porch(root, size, porch_x, porch_z, mats)
	var stairs := Node3D.new()
	stairs.name = "Stairs"
	stairs.position = Vector3(2.2, 0.0, porch_z + 1.75)
	stairs.rotation.y = PI
	root.add_child(stairs)
	_KIT.call("add_stairs", stairs, Vector3.ZERO, 5, 1.15, DECK_Y / 5.0, 0.30, mats.wood)
	_KIT.call("add_roof_slopes", root, size, DECK_Y + size.y + 0.15, mats)

	var porch_hide: Marker3D = null
	if letter == "A" or family_index == 0:
		porch_hide = _build_under_porch_crawl(root, porch_x, porch_z, mats)
	else:
		_build_crawl_void(root, porch_x, porch_z, mats, false)

	_KIT.call("add_shed", root, Vector3(-size.x * 0.5 - 1.6, 0, -0.6), mats, "")

	var porch_lamp := OmniLight3D.new()
	porch_lamp.name = "PorchMood"
	porch_lamp.position = Vector3(porch_x, DECK_Y + 2.05, porch_z)
	porch_lamp.light_color = Color(0.85, 0.28, 0.72)
	porch_lamp.light_energy = 0.42
	porch_lamp.omni_range = 5.5
	root.add_child(porch_lamp)

	var porch_spawn: Marker3D = _GB.call(
		"add_spawn_marker",
		root,
		Vector3(porch_x, DECK_Y + 0.12, porch_z + 0.35),
		"Family%s_Porch" % tag,
	)
	porch_spawn.add_to_group("outdoor_player_spawns")
	var yard_spawn: Marker3D = _GB.call(
		"add_spawn_marker",
		root,
		Vector3(2.15, 0.12, porch_z + 1.85),
		"Family%s_Yard" % tag,
	)
	yard_spawn.add_to_group("outdoor_player_spawns")

	return {
		"root": root,
		"bedroom_spawn": body_spawns["bedroom_spawn"],
		"porch_spawn": porch_spawn,
		"yard_spawn": yard_spawn,
		"family_index": family_index,
		"letter": tag,
		"porch_hide": porch_hide,
	}


static func _build_foundation(root: Node3D, size: Vector3, porch_x: float, porch_z: float, mats) -> void:
	var found := Node3D.new()
	found.name = "Foundation"
	root.add_child(found)
	var hx: float = size.x * 0.5 - 0.45
	var hz: float = size.z * 0.5 - 0.45
	for p in [
		Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz),
		Vector3(-hx, 0, hz), Vector3(hx, 0, hz),
		Vector3(0, 0, -hz), Vector3(0, 0, hz),
		Vector3(porch_x - 2.6, 0, porch_z - 0.7),
		Vector3(porch_x + 2.6, 0, porch_z - 0.7),
		Vector3(porch_x - 2.6, 0, porch_z + 0.7),
		Vector3(porch_x + 2.6, 0, porch_z + 0.7),
	]:
		_KIT.call("add_foundation_pillar", found, p, DECK_Y, mats)
	_KIT.call("add_box", found, Vector3(size.x - 0.5, 0.12, 0.16), Vector3(0, DECK_Y - 0.08, size.z * 0.5), mats.wood)


static func _build_house_body(root: Node3D, size: Vector3, family_index: int, tag: String, mats) -> Dictionary:
	var body := Node3D.new()
	body.name = "HouseBody"
	body.position = Vector3(0, DECK_Y, 0)
	root.add_child(body)

	var doors := {
		"plus_z": FRONT_DOOR_W,
		"plus_z_off": 0.0,
		"height": FRONT_DOOR_H,
	}
	_GB.call("add_room_box_open", body, size, Vector3(0, size.y * 0.5, 0), mats, true, true, doors)

	# Kit plan at live scale: kitchen/dining/living along -Z, bath + bedroom along +Z.
	_GB.call("add_wall_panel", body, Vector3(-3.2, 1.35, -3.4), Vector3(0.2, 2.7, 4.2), mats.siding, true, 1.05)
	_GB.call("add_wall_panel", body, Vector3(2.4, 1.35, -3.2), Vector3(0.2, 2.7, 4.6), mats.siding, true, 1.1)
	_GB.call("add_wall_panel", body, Vector3(0.0, 1.35, -1.15), Vector3(size.x - 0.4, 2.7, 0.2), mats.siding, true, 1.45)
	_GB.call("add_wall_panel", body, Vector3(-4.6, 1.35, 3.5), Vector3(0.2, 2.7, 4.0), mats.siding, true, 0.95)
	_GB.call("add_wall_panel", body, Vector3(-5.5, 1.35, 1.5), Vector3(2.4, 2.7, 0.2), mats.siding, false, 0.0)
	_GB.call("add_wall_panel", body, Vector3(3.25, 1.35, 3.6), Vector3(0.2, 2.7, 3.8), mats.siding, true, 1.05)

	_name_room(body, "Kitchen", Vector3(-5.0, 0, -3.6))
	_name_room(body, "Dining", Vector3(-0.4, 0, -3.6))
	_name_room(body, "Living", Vector3(4.6, 0, -3.2))
	_name_room(body, "Bath", Vector3(-5.6, 0, 3.8))
	_name_room(body, "Bedroom", Vector3(5.0, 0, 3.6))

	_add_window_facing(body, Vector3(-size.x * 0.5, 1.45, -2.2), PI * 0.5, mats)
	_add_window_facing(body, Vector3(size.x * 0.5, 1.45, 2.4), -PI * 0.5, mats)
	_add_window_facing(body, Vector3(-3.4, 1.45, -size.z * 0.5), PI, mats)

	var front_door: Node3D = _KIT.call("add_open_door", body, Vector3(0.0, 0.0, size.z * 0.5), mats)
	front_door.name = "DoorModule"
	_GB.call("add_walkable_exit", body, Vector3(0.0, 0.12, size.z * 0.5 + 0.35), "FrontExit")

	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 2.35, 0)
	interior.light_color = Color(0.78, 0.68, 0.58)
	interior.light_energy = 0.32
	interior.omni_range = 11
	body.add_child(interior)

	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	body.add_child(spawns)
	var bedroom_spawn: Marker3D = _GB.call("add_spawn_marker", spawns, Vector3(5.0, 0.12, 3.5), "Family%s_Bedroom" % tag)
	_GB.call("add_dead_body_stub", body, Vector3(4.4, 0, -2.4), family_index)
	return {"bedroom_spawn": bedroom_spawn}


static func _add_window_facing(parent: Node3D, pos: Vector3, yaw: float, mats) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	_KIT.call("add_window", holder, Vector3.ZERO, mats)


static func _build_porch(root: Node3D, size: Vector3, porch_x: float, porch_z: float, mats) -> void:
	var porch := Node3D.new()
	porch.name = "Porch"
	root.add_child(porch)
	_KIT.call("add_box", porch, Vector3(6.0, 0.12, 2.2), Vector3(porch_x, DECK_Y, porch_z), mats.wood)
	_KIT.call("add_railing", porch, Vector3(porch_x - 1.55, DECK_Y, porch_z + 1.02), 2.6, true, mats.wood)
	_KIT.call("add_railing", porch, Vector3(porch_x - 2.85, DECK_Y, porch_z), 1.8, false, mats.wood)
	_KIT.call("add_box", porch, Vector3(0.18, 2.1, 0.18), Vector3(porch_x - 2.85, DECK_Y + 1.05, porch_z + 1.0), mats.wood)
	_KIT.call("add_box", porch, Vector3(0.18, 2.1, 0.18), Vector3(porch_x + 2.85, DECK_Y + 1.05, porch_z + 1.0), mats.wood)
	_KIT.call("add_box", porch, Vector3(5.8, 0.1, 0.16), Vector3(porch_x, DECK_Y + 2.12, porch_z + 1.0), mats.wood)


static func _build_under_porch_crawl(root: Node3D, porch_x: float, porch_z: float, mats) -> Marker3D:
	var crawl: Node3D = _build_crawl_void(root, porch_x, porch_z, mats, true)
	var hide := Marker3D.new()
	hide.position = Vector3(0, 0.28, 0)
	crawl.add_child(hide)
	_V05.call("stamp_child_pin", hide, "under_porch_crawl")
	var tag := Label3D.new()
	tag.name = "CrawlLabel"
	tag.text = "CRAWL"
	tag.font_size = 22
	tag.modulate = Color(0.72, 0.42, 0.92)
	tag.position = Vector3(0, 0.42, 0.7)
	tag.pixel_size = 0.012
	crawl.add_child(tag)
	return hide


static func _build_crawl_void(root: Node3D, porch_x: float, porch_z: float, mats, named_spawn: bool) -> Node3D:
	var crawl := Node3D.new()
	crawl.name = "UnderPorchCrawl" if named_spawn else "UnderPorchVoid"
	crawl.position = Vector3(porch_x, 0.0, porch_z)
	root.add_child(crawl)
	_KIT.call("add_box", crawl, Vector3(5.6, 0.08, 2.05), Vector3(0, 0.04, 0), mats.dirt)
	var haze: Node = _KIT.call("add_box", crawl, Vector3(5.2, 0.55, 1.8), Vector3(0, 0.34, 0), mats.glass, 0)
	haze.name = "CrawlHaze"
	var mood := OmniLight3D.new()
	mood.name = "CrawlMood"
	mood.position = Vector3(0, 0.3, 0)
	mood.light_color = Color(0.55, 0.28, 0.85)
	mood.light_energy = 0.55 if named_spawn else 0.18
	mood.omni_range = 2.8
	crawl.add_child(mood)
	return crawl


static func _name_room(parent: Node3D, room_name: String, local_pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = room_name
	n.position = local_pos
	parent.add_child(n)
	return n
