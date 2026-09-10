extends RefCounted
class_name FarmProps
## Places the farm/practice props that survivor tools actually touch:
## fuse box, locked gate, shovel dig sites, rope ledge.

const FUSE := "res://scripts/interactables/props/fuse_box.gd"
const GATE := "res://scripts/interactables/props/locked_gate.gd"
const DIG := "res://scripts/interactables/props/dig_site.gd"
const ROPE := "res://scripts/interactables/props/rope_anchor.gd"


static func install_on_world(world: Node3D) -> void:
	if world == null or world.get_node_or_null("PlayableProps") != null:
		return
	var spawn := Vector3(2.4, 1.15, 4.0)
	if world.has_method("get_family_spawn_transform"):
		spawn = world.call("get_family_spawn_transform", 0).origin
	var gy := spawn.y - 1.15
	var origin := Vector3(spawn.x + 3.2, gy, spawn.z + 3.6)
	_box(world, FUSE, origin + Vector3(-1.8, 0.7, 0.0), Vector3(0.42, 0.55, 0.16), Color(0.38, 0.28, 0.14), "FuseBox", {"room_index": 0})
	_box(world, GATE, origin + Vector3(2.2, 1.0, 1.4), Vector3(2.4, 2.0, 0.18), Color(0.42, 0.44, 0.48), "LockedGate", {"locked": true, "kind": "gate"})
	_box(world, DIG, origin + Vector3(0.2, 0.12, -1.6), Vector3(1.1, 0.22, 1.1), Color(0.42, 0.32, 0.18), "DigSiteKey", {"buried_item": "key"})
	_box(world, DIG, origin + Vector3(-3.0, 0.12, 1.2), Vector3(1.0, 0.22, 1.0), Color(0.40, 0.30, 0.16), "DigSiteFuse", {"buried_item": "fuse"})
	_box(world, ROPE, origin + Vector3(4.4, 0.4, -0.6), Vector3(0.55, 0.55, 0.55), Color(0.55, 0.38, 0.22), "RopeAnchor", {"climb_height": 4.5})
	print("[FarmProps] playable props at %s" % origin)


static func install_on_practice(root: Node3D) -> void:
	if root == null or root.get_node_or_null("PlayableProps") != null:
		return
	_box(root, FUSE, Vector3(-6.5, 1.1, -6.4), Vector3(0.42, 0.55, 0.16), Color(0.38, 0.28, 0.14), "FuseBox", {"room_index": 0})
	_box(root, GATE, Vector3(6.4, 1.1, -6.2), Vector3(2.2, 2.0, 0.18), Color(0.42, 0.44, 0.48), "LockedGate", {"locked": true, "kind": "gate"})
	_box(root, DIG, Vector3(-5.5, 0.14, 4.5), Vector3(1.1, 0.22, 1.1), Color(0.42, 0.32, 0.18), "DigSiteKey", {"buried_item": "key"})
	_box(root, ROPE, Vector3(6.5, 0.4, 4.2), Vector3(0.55, 0.55, 0.55), Color(0.55, 0.38, 0.22), "RopeAnchor", {"climb_height": 3.6})


static func _folder(world: Node) -> Node:
	var folder: Node = world.get_node_or_null("PlayableProps")
	if folder == null:
		folder = Node3D.new()
		folder.name = "PlayableProps"
		world.add_child(folder)
	return folder


static func _box(world: Node, script_path: String, at: Vector3, size: Vector3, color: Color, node_name: String, props: Dictionary) -> void:
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
	mat.emission_energy_multiplier = 0.18
	mesh.set_surface_override_material(0, mat)
	mesh_parent.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_folder(world).add_child(body)
