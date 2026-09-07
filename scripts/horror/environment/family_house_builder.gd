extends RefCounted
class_name FamilyHouseBuilder
## One-story family house A–D around the cul-de-sac. Front is local +Z.
##
## Leonardo family-house kit target is ~13.5 x 11 m with a raised porch and
## under-porch crawl. The v0.5 neighborhood ring keeps FAMILY_HOUSE_SIZE so
## the ~40 m cul-de-sac still fits — this is kit-language graybox at that
## footprint, not a Steam-final GLB kitbash.

const _GB: GDScript = preload("res://scripts/horror/environment/graybox_builder.gd")
const _KIT: GDScript = preload("res://scripts/horror/environment/modular_kit.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const DECK_Y: float = 0.72


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
	var porch_z: float = size.z * 0.5 + 1.15
	var porch_x: float = 0.35

	_build_foundation(root, size, porch_x, porch_z, mats)
	var bedroom_spawn: Marker3D = _build_house_body(root, size, family_index, tag, mats)
	_build_porch(root, size, porch_x, porch_z, mats)
	var stairs := Node3D.new()
	stairs.name = "Stairs"
	root.add_child(stairs)
	_KIT.call("add_stairs", stairs, Vector3(porch_x + 2.15, 0.0, porch_z + 0.15), 5, 1.05, DECK_Y / 5.0, 0.28, mats.wood)
	_KIT.call("add_roof_slopes", root, size, DECK_Y + size.y + 0.15, mats)

	var porch_hide: Marker3D = null
	if letter == "A" or family_index == 0:
		porch_hide = _build_under_porch_crawl(root, porch_x, porch_z, mats)
	else:
		_build_crawl_void(root, porch_x, porch_z, mats, false)

	# Nearby shed module is dressing only — family_shed pin stays on Outdoor/FamilyShed.
	_KIT.call("add_shed", root, Vector3(-size.x * 0.5 - 1.35, 0, -0.4), mats, "")

	var porch_lamp := OmniLight3D.new()
	porch_lamp.name = "PorchMood"
	porch_lamp.position = Vector3(porch_x, DECK_Y + 2.05, porch_z)
	porch_lamp.light_color = Color(0.85, 0.28, 0.72)
	porch_lamp.light_energy = 0.42
	porch_lamp.omni_range = 5.5
	root.add_child(porch_lamp)

	return {
		"root": root,
		"bedroom_spawn": bedroom_spawn,
		"family_index": family_index,
		"letter": tag,
		"porch_hide": porch_hide,
	}


static func _build_foundation(root: Node3D, size: Vector3, porch_x: float, porch_z: float, mats) -> void:
	var found := Node3D.new()
	found.name = "Foundation"
	root.add_child(found)
	var hx: float = size.x * 0.5 - 0.35
	var hz: float = size.z * 0.5 - 0.35
	for p in [
		Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz),
		Vector3(-hx, 0, hz), Vector3(hx, 0, hz),
		Vector3(porch_x - 2.2, 0, porch_z - 0.7),
		Vector3(porch_x + 2.2, 0, porch_z - 0.7),
		Vector3(porch_x - 2.2, 0, porch_z + 0.7),
		Vector3(porch_x + 2.2, 0, porch_z + 0.7),
	]:
		_KIT.call("add_foundation_pillar", found, p, DECK_Y, mats)
	# Beam trim under the front wall.
	_KIT.call("add_box", found, Vector3(size.x - 0.4, 0.12, 0.16), Vector3(0, DECK_Y - 0.08, size.z * 0.5), mats.wood)


static func _build_house_body(root: Node3D, size: Vector3, family_index: int, tag: String, mats) -> Marker3D:
	var body := Node3D.new()
	body.name = "HouseBody"
	body.position = Vector3(0, DECK_Y, 0)
	root.add_child(body)

	# Floor sits at HouseBody y≈0 (raised DECK_Y in world) so bedroom spawn is walkable.
	_GB.call("add_room_box", body, size, Vector3(0, size.y * 0.5, 0), mats, true, true)
	# Kit plan (scaled): kitchen/dining/living along -Z, bath + bedroom along +Z.
	_GB.call("add_wall_panel", body, Vector3(-1.15, 1.5, -1.55), Vector3(0.2, 3, 3.1), mats.siding, true, 1.05)
	_GB.call("add_wall_panel", body, Vector3(1.35, 1.5, -1.35), Vector3(0.2, 3, 2.7), mats.siding, true, 1.05)
	_GB.call("add_wall_panel", body, Vector3(0.1, 1.5, 0.15), Vector3(size.x - 0.4, 3, 0.2), mats.siding, true, 1.35)
	_GB.call("add_wall_panel", body, Vector3(-2.45, 1.5, 1.55), Vector3(2.6, 3, 0.2), mats.siding, true, 0.95)
	_GB.call("add_wall_panel", body, Vector3(2.15, 1.5, 1.45), Vector3(3.2, 3, 0.2), mats.siding, true, 1.05)
	_GB.call("add_wall_panel", body, Vector3(0.55, 1.5, 1.7), Vector3(0.2, 3, 3.0), mats.siding, true, 1.1)

	_name_room(body, "Kitchen", Vector3(-2.4, 0, -1.9))
	_name_room(body, "Dining", Vector3(0.1, 0, -1.9))
	_name_room(body, "Living", Vector3(2.3, 0, -1.4))
	_name_room(body, "Bath", Vector3(-2.5, 0, 1.7))
	_name_room(body, "Bedroom", Vector3(2.2, 0, 1.7))

	_add_window_facing(body, Vector3(-size.x * 0.5, 1.45, -1.4), PI * 0.5, mats)
	_add_window_facing(body, Vector3(size.x * 0.5, 1.45, 1.5), -PI * 0.5, mats)
	_add_window_facing(body, Vector3(-2.2, 1.45, -size.z * 0.5), PI, mats)
	var front_door: Node3D = Node3D.new()
	front_door.name = "DoorModule"
	front_door.position = Vector3(0.35, 1.08, size.z * 0.5)
	body.add_child(front_door)
	_KIT.call("add_door", front_door, Vector3.ZERO, mats)

	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 2.45, 0)
	interior.light_color = Color(0.78, 0.68, 0.58)
	interior.light_energy = 0.28
	interior.omni_range = 9
	body.add_child(interior)

	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	body.add_child(spawns)
	var bedroom_spawn: Marker3D = _GB.call("add_spawn_marker", spawns, Vector3(2.25, 0.12, 1.55), "Family%s_Bedroom" % tag)
	_GB.call("add_dead_body_stub", body, Vector3(2.1, 0, -1.1), family_index)
	return bedroom_spawn


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
	_KIT.call("add_box", porch, Vector3(5.4, 0.12, 2.2), Vector3(porch_x, DECK_Y, porch_z), mats.wood)
	_KIT.call("add_railing", porch, Vector3(porch_x - 0.2, DECK_Y, porch_z + 1.02), 4.6, true, mats.wood)
	_KIT.call("add_railing", porch, Vector3(porch_x - 2.55, DECK_Y, porch_z), 1.8, false, mats.wood)
	_KIT.call("add_box", porch, Vector3(0.18, 2.1, 0.18), Vector3(porch_x - 2.5, DECK_Y + 1.05, porch_z + 1.0), mats.wood)
	_KIT.call("add_box", porch, Vector3(0.18, 2.1, 0.18), Vector3(porch_x + 2.5, DECK_Y + 1.05, porch_z + 1.0), mats.wood)
	_KIT.call("add_box", porch, Vector3(5.2, 0.1, 0.16), Vector3(porch_x, DECK_Y + 2.12, porch_z + 1.0), mats.wood)


static func _build_under_porch_crawl(root: Node3D, porch_x: float, porch_z: float, mats) -> Marker3D:
	var crawl: Node3D = _build_crawl_void(root, porch_x, porch_z, mats, true)
	var hide := Marker3D.new()
	hide.name = "ChildSpawn_under_porch_crawl"
	hide.position = Vector3(0, 0.28, 0)
	hide.add_to_group("child_spawn_points")
	hide.set_meta("spawn_id", "under_porch_crawl")
	crawl.add_child(hide)
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
	_KIT.call("add_box", crawl, Vector3(4.9, 0.08, 1.95), Vector3(0, 0.04, 0), mats.dirt)
	# Low dark volume — readable crawl, not a sealed box the player can't see into.
	var haze: Node = _KIT.call("add_box", crawl, Vector3(4.6, 0.55, 1.7), Vector3(0, 0.34, 0), mats.glass, 0)
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
