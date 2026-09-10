extends RefCounted
class_name FarmProps
## Places the farm/practice props that survivor tools actually touch:
## fuse box, locked gate, shovel dig sites, rope ledge.

const FUSE := "res://scripts/interactables/props/fuse_box.gd"
const GATE := "res://scripts/interactables/props/locked_gate.gd"
const DIG := "res://scripts/interactables/props/dig_site.gd"
const ROPE := "res://scripts/interactables/props/rope_anchor.gd"


static func install_on_world(world: Node3D) -> void:
	if world == null:
		return
	var spawn := Vector3(2.4, 0.04, 4.0)
	if world.has_method("get_family_spawn_transform"):
		spawn = world.call("get_family_spawn_transform", 0).origin
	var origin := spawn + Vector3(3.2, 0.0, 3.6)
	if world.has_method("ground_at"):
		origin = world.call("ground_at", origin)
	install_at(world, origin, false)


static func install_on_practice(root: Node3D) -> void:
	install_at(root, Vector3(0.0, 0.04, 0.0), false, true)


static func install_at(world: Node, origin: Vector3, replace: bool = false, practice_layout: bool = false) -> void:
	if world == null:
		return
	if replace:
		var old: Node = world.get_node_or_null("PlayableProps")
		if old:
			old.name = "PlayablePropsOld"
			old.queue_free()
	elif world.get_node_or_null("PlayableProps") != null:
		return
	if practice_layout:
		_box(world, FUSE, _plant(world, origin + Vector3(-6.5, 0.0, -6.4), 1.1), Vector3(0.42, 0.55, 0.16), Color(0.38, 0.28, 0.14), "FuseBox", {"room_index": 0}, "FUSE")
		_box(world, GATE, _plant(world, origin + Vector3(6.4, 0.0, -6.2), 1.1), Vector3(2.2, 2.0, 0.18), Color(0.42, 0.44, 0.48), "LockedGate", {"locked": true, "kind": "gate"}, "GATE")
		_box(world, DIG, _plant(world, origin + Vector3(-5.5, 0.0, 4.5), 0.14), Vector3(1.1, 0.22, 1.1), Color(0.42, 0.32, 0.18), "DigSiteKey", {"buried_item": "key"}, "DIG")
		_box(world, ROPE, _plant(world, origin + Vector3(6.5, 0.0, 4.2), 0.4), Vector3(0.55, 0.55, 0.55), Color(0.55, 0.38, 0.22), "RopeAnchor", {"climb_height": 3.6}, "ROPE")
	else:
		_box(world, FUSE, _plant(world, origin + Vector3(-1.8, 0.0, 0.0), 0.7), Vector3(0.42, 0.55, 0.16), Color(0.85, 0.52, 0.16), "FuseBox", {"room_index": 0}, "FUSE")
		_box(world, GATE, _plant(world, origin + Vector3(2.2, 0.0, 1.4), 1.0), Vector3(2.4, 2.0, 0.18), Color(0.78, 0.22, 0.16), "LockedGate", {"locked": true, "kind": "gate"}, "GATE")
		_box(world, DIG, _plant(world, origin + Vector3(0.2, 0.0, -1.8), 0.16), Vector3(1.2, 0.24, 1.2), Color(0.82, 0.55, 0.18), "DigSiteKey", {"buried_item": "key"}, "DIG")
		_box(world, DIG, _plant(world, origin + Vector3(-3.0, 0.0, 1.2), 0.16), Vector3(1.1, 0.24, 1.1), Color(0.78, 0.48, 0.16), "DigSiteFuse", {"buried_item": "fuse"}, "DIG")
		_box(world, ROPE, _plant(world, origin + Vector3(4.4, 0.0, -0.6), 0.45), Vector3(0.6, 0.6, 0.6), Color(0.92, 0.52, 0.18), "RopeAnchor", {"climb_height": 4.5}, "ROPE")
	print("[FarmProps] playable props at %s" % origin)


static func _plant(world: Node, xz: Vector3, lift: float) -> Vector3:
	var at := xz
	if world != null and world.has_method("ground_at"):
		at = world.call("ground_at", Vector3(xz.x, 0.0, xz.z))
	at.y += lift
	return at


static func _folder(world: Node) -> Node:
	var folder: Node = world.get_node_or_null("PlayableProps")
	if folder == null:
		folder = Node3D.new()
		folder.name = "PlayableProps"
		world.add_child(folder)
	return folder


static func _box(world: Node, script_path: String, at: Vector3, size: Vector3, color: Color, node_name: String, props: Dictionary, tag: String = "") -> void:
	var body: Node = load(script_path).new()
	body.name = node_name
	for k in props:
		body.set(k, props[k])
	if body is Node3D:
		(body as Node3D).position = at
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_mask = 0
		if script_path == GATE:
			(body as CollisionObject3D).collision_layer = 1 | 2
		else:
			(body as CollisionObject3D).collision_layer = 2
	var mesh_parent: Node = body
	if script_path == GATE:
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		body.add_child(pivot)
		mesh_parent = pivot
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	mesh.set_surface_override_material(0, mat)
	mesh_parent.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	if not tag.is_empty():
		var lab := Label3D.new()
		lab.name = "Tag"
		lab.text = tag
		lab.font_size = 42
		lab.modulate = Color(1.0, 0.82, 0.28)
		lab.outline_modulate = Color(0.05, 0.02, 0.02)
		lab.outline_size = 6
		lab.position = Vector3(0.0, size.y * 0.5 + 0.45, 0.0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(lab)
	_folder(world).add_child(body)
