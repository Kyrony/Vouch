extends RefCounted
class_name PracticeArena
## Lit indoor bay for item / string tests. Built on every peer.

const DUMMY_PEER: int = 9001
const ARENA_NAME := "PracticeArena"


static func ensure(match_node: Node) -> Node3D:
	var existing := match_node.get_node_or_null(ARENA_NAME) as Node3D
	if existing:
		_reconfigure_dummy(existing)
		return existing
	var stale := match_node.get_node_or_null("WorldEnvironment")
	if stale:
		stale.queue_free()
	var match_sun := match_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if match_sun:
		match_sun.visible = false
	var root := Node3D.new()
	root.name = ARENA_NAME
	root.set_script(load("res://scripts/horror/practice_world.gd"))
	root.add_to_group("horror_world")
	match_node.add_child(root)
	_build_room(root)
	_build_dummy(root, not GameState.practice_as_pm)
	var props: GDScript = load("res://scripts/horror/world/farm_props.gd")
	props.call("install_on_practice", root)
	_drop_extra_items(root)
	return root


static func teardown(match_node: Node) -> void:
	var node := match_node.get_node_or_null(ARENA_NAME)
	if node:
		node.queue_free()


static func player_spawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 4.2))


static func dummy_spawn() -> Vector3:
	return Vector3(0.0, 1.0, -2.4)


static func _drop_extra_items(root: Node3D) -> void:
	if not ResourceLoader.exists("res://scenes/Horror/WorldPickup.tscn"):
		return
	var packed: PackedScene = load("res://scenes/Horror/WorldPickup.tscn")
	var extras: Array = ["key", "fuse", "lockpick", "shovel", "rope", "firearm"]
	var i := 0
	for item_id in extras:
		var pickup: Node3D = packed.instantiate() as Node3D
		pickup.set("item_id", str(item_id))
		pickup.position = Vector3(-5.0 + float(i) * 1.6, 0.4, 5.6)
		pickup.name = "PracticePickup_%s" % item_id
		root.add_child(pickup)
		i += 1


static func _build_room(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	we.name = "PracticeSky"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.14, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.50, 0.44)
	env.ambient_light_energy = 0.7
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "PracticeSun"
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.05
	root.add_child(sun)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.26, 0.24)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.38, 0.34, 0.30)
	_box(root, "Floor", Vector3(18, 0.4, 16), Vector3(0, -0.2, 0), floor_mat)
	_box(root, "Back", Vector3(18, 5, 0.35), Vector3(0, 2.3, -8), wall_mat)
	_box(root, "Front", Vector3(18, 5, 0.35), Vector3(0, 2.3, 8), wall_mat)
	_box(root, "Left", Vector3(0.35, 5, 16), Vector3(-9, 2.3, 0), wall_mat)
	_box(root, "Right", Vector3(0.35, 5, 16), Vector3(9, 2.3, 0), wall_mat)
	_box(root, "Ceiling", Vector3(18, 0.3, 16), Vector3(0, 5.0, 0), wall_mat)

	var lamp := OmniLight3D.new()
	lamp.name = "BayLight"
	lamp.position = Vector3(0, 3.6, 0)
	lamp.light_energy = 2.4
	lamp.omni_range = 14.0
	lamp.light_color = Color(1.0, 0.88, 0.7)
	root.add_child(lamp)

	var hud := Label3D.new()
	hud.name = "Hint"
	hud.position = Vector3(0, 3.4, -7.4)
	hud.font_size = 48
	hud.modulate = Color(0.95, 0.82, 0.28)
	hud.text = "PRACTICE  —  items vs dummy"
	root.add_child(hud)


static func _build_dummy(root: Node3D, as_survivor: bool) -> void:
	var dummy := CharacterBody3D.new()
	dummy.set_script(load("res://scripts/horror/practice_dummy.gd"))
	dummy.position = dummy_spawn()
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	cap.shape = shape
	cap.position.y = 0.85
	dummy.add_child(cap)
	var mesh := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.38
	cap_mesh.height = 1.7
	mesh.mesh = cap_mesh
	mesh.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.22, 0.22) if as_survivor else Color(0.42, 0.16, 0.55)
	mesh.material_override = mat
	dummy.add_child(mesh)
	var reading := Label3D.new()
	reading.name = "Reading"
	reading.position = Vector3(0, 2.25, 0)
	reading.font_size = 28
	reading.modulate = Color(1.0, 0.86, 0.35)
	dummy.add_child(reading)
	root.add_child(dummy)
	if dummy.has_method("configure_as_role"):
		dummy.call("configure_as_role", as_survivor)


static func _reconfigure_dummy(root: Node3D) -> void:
	var dummy := root.get_node_or_null(str(DUMMY_PEER))
	if dummy and dummy.has_method("configure_as_role"):
		dummy.call("configure_as_role", not GameState.practice_as_pm)


static func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	parent.add_child(body)
