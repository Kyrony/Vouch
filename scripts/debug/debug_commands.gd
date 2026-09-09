extends RefCounted
class_name DebugCommands
## Host-side debug spawn helpers. Kept out of gameplay scripts.

const PLAYER_SCENE := "res://scenes/Player/Player.tscn"
const CRATE_SCENE := "res://scenes/Match/Props/Crate.tscn"
const BARREL_SCENE := "res://scenes/Match/Props/Barrel.tscn"
const _HORROR: GDScript = preload("res://scripts/horror/match_horror.gd")


static func _world() -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("horror_world") as Node3D


static func _match_node() -> Node:
	var world := _world()
	if world:
		return world.get_parent()
	return null


static func _local_player() -> Node3D:
	var gs := Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs:
		return gs.get("local_player_node") as Node3D
	return null


static func _in_front(distance: float = 3.2) -> Vector3:
	var player := _local_player()
	if player == null:
		var world := _world()
		if world and world.has_method("get_family_spawn_transform"):
			return world.call("get_family_spawn_transform", 0).origin + Vector3(0, 0.4, 3.0)
		return Vector3.ZERO
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, 1)
	return player.global_position + forward.normalized() * distance + Vector3(0, 0.15, 0)


static func spawn_playtest_kit() -> void:
	var world := _world()
	if world == null or not world.multiplayer.is_server():
		return
	if world.get_node_or_null("TestProps") != null:
		return
	var origin: Vector3
	if world.has_method("get_family_spawn_transform"):
		origin = world.call("get_family_spawn_transform", 0).origin + Vector3(2.4, 0.0, 4.2)
	else:
		origin = _in_front(4.0)
	_spawn_box_prop(world, "res://scripts/interactables/props/fuse_box.gd", origin + Vector3(-1.6, 0.55, 0.0), Vector3(0.42, 0.55, 0.16), Color(0.35, 0.28, 0.16), "FuseBox", {"room_index": 0})
	_spawn_box_prop(world, "res://scripts/interactables/props/locked_gate.gd", origin + Vector3(1.8, 0.9, 1.2), Vector3(2.2, 1.8, 0.16), Color(0.42, 0.44, 0.48), "LockedGate", {"locked": true, "kind": "gate"})
	_spawn_box_prop(world, "res://scripts/interactables/props/wall_light_switch.gd", origin + Vector3(-2.4, 1.2, -0.4), Vector3(0.12, 0.18, 0.08), Color(0.82, 0.78, 0.55), "WallSwitch", {"room_index": 0})
	_instance_prop(world, CRATE_SCENE, origin + Vector3(0.4, 0.0, -0.8))
	_instance_prop(world, BARREL_SCENE, origin + Vector3(-0.6, 0.0, -1.1))
	var lamp := Node3D.new()
	lamp.set_script(load("res://scripts/interactables/props/street_light.gd"))
	lamp.set("starts_on", true)
	lamp.position = origin + Vector3(2.8, 0.0, -1.6)
	_folder(world).add_child(lamp)
	print("[Debug] playtest props spawned at %s" % origin)


static func spawn_test_items() -> void:
	var world := _world()
	if world == null or not world.has_method("spawn_pickup"):
		return
	if not world.multiplayer.is_server():
		return
	var catalog: GDScript = load("res://scripts/horror/items/item_catalog.gd")
	var ids: Array = catalog.survivor_item_ids()
	var base := _in_front(2.4)
	var i := 0
	for item_id in ids:
		var angle := float(i) * TAU / float(max(ids.size(), 1))
		world.call("spawn_pickup", str(item_id), base + Vector3(cos(angle) * 1.6, 0.35, sin(angle) * 1.6))
		i += 1
	world.call("spawn_pickup", "puppet", base + Vector3(0.0, 0.4, 2.2))


static func spawn_debug_pawn(as_puppet_master: bool) -> Node:
	var match_node := _match_node()
	if match_node == null:
		return null
	if not ResourceLoader.exists(PLAYER_SCENE):
		return null
	var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
	var pawn: Node = packed.instantiate()
	if pawn == null:
		return null
	var id := 9000 + match_node.get_tree().get_nodes_in_group("debug_pawns").size()
	pawn.name = "DebugPawn_%d" % id
	pawn.add_to_group("debug_pawns")
	pawn.set("horror_mode", true)
	pawn.set("is_horror_puppet_master", as_puppet_master)
	pawn.set("faction_id", "debug")
	# Dummy authority so this mannequin never steals host input / HUD / camera.
	pawn.set_multiplayer_authority(id)
	var at := _in_front(2.8)
	pawn.position = at + Vector3(0, 1.0, 0)
	var hud := pawn.get_node_or_null("HUD")
	if hud:
		hud.visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := pawn.get_node_or_null("Head/Camera3D") as Camera3D
	if cam:
		cam.current = false
	match_node.add_child(pawn)
	if as_puppet_master:
		_HORROR.call("attach_pm_controller", pawn)
	_tint_pawn(pawn, Color(0.62, 0.18, 0.72) if as_puppet_master else Color(0.55, 0.62, 0.42))
	print("[Debug] spawned %s at %s" % [pawn.name, pawn.position])
	return pawn


static func apply_local_character(as_puppet_master: bool) -> void:
	var player := _local_player()
	if player == null:
		return
	player.set("is_horror_puppet_master", as_puppet_master)
	player.set("horror_mode", true)
	var gs := Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs:
		gs.set("local_is_puppet_master", as_puppet_master)
	if as_puppet_master:
		_HORROR.call("attach_pm_controller", player)
		_tint_pawn(player, Color(0.62, 0.18, 0.72))
	else:
		var ctrl := player.get_node_or_null("PuppetMasterController")
		if ctrl:
			ctrl.queue_free()
		_tint_pawn(player, Color(0.55, 0.56, 0.58))
	print("[Debug] local character -> %s" % ("Puppet Master" if as_puppet_master else "Survivor"))


static func _folder(world: Node) -> Node:
	var folder: Node = world.get_node_or_null("TestProps")
	if folder == null:
		folder = Node3D.new()
		folder.name = "TestProps"
		world.add_child(folder)
	return folder


static func _instance_prop(world: Node, path: String, at: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	var node: Node3D = packed.instantiate() as Node3D
	if node == null:
		return
	node.position = at
	_folder(world).add_child(node)


static func _spawn_box_prop(world: Node, script_path: String, at: Vector3, size: Vector3, color: Color, node_name: String, props: Dictionary) -> void:
	var body: Node = load(script_path).new()
	body.name = node_name
	for k in props:
		body.set(k, props[k])
	if body is Node3D:
		(body as Node3D).position = at
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 2
		(body as CollisionObject3D).collision_mask = 0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.2
	mesh.set_surface_override_material(0, mat)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_folder(world).add_child(body)


static func _tint_pawn(pawn: Node, color: Color) -> void:
	var mesh := pawn.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh.set_surface_override_material(0, mat)
