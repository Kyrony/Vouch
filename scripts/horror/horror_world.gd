extends Node3D
class_name HorrorWorld
## Authored farm country. Terrain/roads/markers live in HorrorWorld.tscn.
## Start Match instantiates that packed scene — it does not loop-build geometry.

const PICKUP_SCENE: String = "res://scenes/Horror/WorldPickup.tscn"
const GRASS_TEX := "res://assets/horror/farm/grass_dirt_tile.png"

var _family_spawns: Array[Marker3D] = []
var _pm_spawn: Marker3D = null
var _tick_accum: float = 0.0


func _ready() -> void:
	add_to_group("horror_world")
	_suppress_parallel_worlds()
	_bind_authored_spawns()
	_ensure_placeholder_gun()
	_ensure_terrain_texture()
	## Mask placement must not block Start Match / player spawn.
	call_deferred("_run_semantic_maps")
	## Drop a sample of every survival item near the first family pad.
	call_deferred("server_scatter_starter_items")
	var clock := get_node_or_null("/root/MatchClock")
	if clock and clock.has_method("apply_to_world"):
		clock.call("apply_to_world", self)
	print("[HorrorWorld] loaded authored farm scene family_pads=%d l2_markers=%d" % [
		_family_spawns.size(), get_tree().get_nodes_in_group("child_spawn_points").size(),
	])


func _ensure_placeholder_gun() -> void:
	if get_node_or_null("PlaceholderGun") != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.49, 0.52, 1)
	mat.roughness = 0.55
	mat.metallic = 0.35
	var gun := Node3D.new()
	gun.name = "PlaceholderGun"
	var spawn := get_family_spawn_transform(0).origin
	gun.position = spawn + Vector3(1.75, 0.06, 0.55)
	gun.rotation_degrees = Vector3(8.0, 32.0, 86.0)
	_add_named_mesh(gun, "Receiver", BoxMesh.new(), Vector3(0.28, 0.085, 0.055), Vector3.ZERO, Vector3.ZERO, mat)
	_add_named_mesh(gun, "Barrel", CylinderMesh.new(), Vector3(0.016, 0.30, 0.016), Vector3(0.26, 0.01, 0.0), Vector3(0, 0, 90), mat)
	_add_named_mesh(gun, "Grip", BoxMesh.new(), Vector3(0.07, 0.15, 0.045), Vector3(-0.04, -0.09, 0.0), Vector3(18, 0, 0), mat)
	_add_named_mesh(gun, "Mag", BoxMesh.new(), Vector3(0.06, 0.09, 0.03), Vector3(0.02, -0.07, 0.0), Vector3(8, 0, 0), mat)
	add_child(gun)


func _add_named_mesh(parent: Node3D, node_name: String, mesh: Mesh, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var cyl := mesh as CylinderMesh
		cyl.top_radius = size.x
		cyl.bottom_radius = size.x
		cyl.height = size.y
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)


func _ensure_terrain_texture() -> void:
	## Mesh has no UVs — triplanar grass/dirt so dusk/night still reads as ground.
	var mesh := get_node_or_null("Outdoor/Terrain/MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var mat := mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mesh.material_override = mat
	var tex: Texture2D = mat.albedo_texture
	if tex == null or tex.get_width() < 8:
		tex = _load_png(GRASS_TEX)
		if tex:
			mat.albedo_texture = tex
	mat.albedo_color = Color(0.42, 0.50, 0.24, 1)
	mat.roughness = 0.86
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.14, 0.14, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.20, 0.09, 1)
	mat.emission_energy_multiplier = 0.22


func _run_semantic_maps() -> void:
	## Heightmap stays authored. Masks dress the farm after the match is live.
	## Failures stay warnings — authored lanes/pads/terrain must remain playable.
	if not is_inside_tree():
		return
	var script: GDScript = load("res://scripts/horror/world/neighborhood_from_masks.gd")
	if script == null:
		push_warning("[HorrorWorld] neighborhood_from_masks.gd failed to load")
		return
	var gen: Object = script.new()
	if gen == null or not gen.has_method("run"):
		return
	var err: Variant = gen.call("run", self)
	if typeof(err) == TYPE_STRING and not str(err).is_empty():
		push_warning("[HorrorWorld] semantic maps skipped: %s" % err)


func _load_png(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null and imported.get_width() > 8:
			return imported
	if not FileAccess.file_exists(path):
		return null
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return null
	var buf := fa.get_buffer(int(fa.get_length()))
	fa.close()
	var img := Image.new()
	if img.load_png_from_buffer(buf) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _bind_authored_spawns() -> void:
	_family_spawns.clear()
	var folder := get_node_or_null("Outdoor/PlayerSpawns")
	if folder:
		for child in folder.get_children():
			if child is Marker3D:
				_family_spawns.append(child)
	var pm := get_node_or_null("Outdoor/Outdoor_PM_Street")
	_pm_spawn = pm if pm is Marker3D else null


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_accum += delta
	if _tick_accum >= 0.1:
		_tick_accum = 0.0
		PlayerEffects.server_tick(0.1)
		PhoneDevice.server_tick(0.1)


func _suppress_parallel_worlds() -> void:
	var match_node := get_parent()
	if match_node == null:
		return
	var we := match_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = null
	var world_root := match_node.get_parent()
	if world_root == null:
		return
	var outside := world_root.get_node_or_null("Outside")
	if outside is Node3D:
		outside.visible = false
		outside.process_mode = Node.PROCESS_MODE_DISABLED
		for child in outside.get_children():
			child.queue_free()


func server_init_match(player_count: int) -> void:
	if not multiplayer.is_server():
		return
	var seed_base := player_count + int(Time.get_ticks_usec() % 9973)
	ChildSpawnRNG.server_roll(self, seed_base)


func get_family_spawn_transform(family_index: int) -> Transform3D:
	if _family_spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.2, -8.0))
	var idx := clampi(family_index, 0, _family_spawns.size() - 1)
	return _family_spawns[idx].global_transform


func get_pm_spawn_transform() -> Transform3D:
	if _pm_spawn == null:
		return Transform3D(Basis.IDENTITY, Vector3(22.0, 3.6, 1.0))
	return _pm_spawn.global_transform


func get_random_spawn_transform() -> Transform3D:
	if _family_spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.2, -8.0))
	var m: Marker3D = _family_spawns[randi() % _family_spawns.size()]
	return m.global_transform


func get_spawn_point_count() -> int:
	return maxi(_family_spawns.size(), 4)


func get_family_count() -> int:
	return _family_spawns.size()


func spawn_pickup(item_id: String, at: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_spawn_pickup_local.rpc(item_id, at)


@rpc("authority", "call_local", "reliable")
func _spawn_pickup_local(item_id: String, at: Vector3) -> void:
	if not ResourceLoader.exists(PICKUP_SCENE):
		return
	var packed: PackedScene = load(PICKUP_SCENE) as PackedScene
	if packed == null:
		return
	var pickup: Node3D = packed.instantiate() as Node3D
	if pickup == null:
		return
	pickup.set("item_id", item_id)
	pickup.position = at
	var folder: Node = get_node_or_null("Pickups")
	if folder == null:
		folder = Node3D.new()
		folder.name = "Pickups"
		add_child(folder)
	folder.add_child(pickup)
	print("[HorrorWorld] pickup spawned item=%s at %s" % [item_id, at])


## Scatter one of each survival item near the first family pad so players can
## try them out. Server-only; call once the match is live.
func server_scatter_starter_items() -> void:
	if not multiplayer.is_server():
		return
	var catalog: GDScript = load("res://scripts/horror/items/item_catalog.gd")
	var ids: Array = catalog.survival_item_ids()
	var base := get_family_spawn_transform(0).origin + Vector3(0, 0.4, 0)
	var i := 0
	for item_id in ids:
		var angle := float(i) * TAU / float(max(ids.size(), 1))
		var offset := Vector3(cos(angle) * 2.4, 0.0, sin(angle) * 2.4)
		spawn_pickup(str(item_id), base + offset)
		i += 1


## Flare: a temporary point light dropped on the ground (survival light).
func spawn_flare(at: Vector3, light_range: float, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_flare_local.rpc(at, light_range, seconds)


@rpc("authority", "call_local", "reliable")
func _spawn_flare_local(at: Vector3, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Flare"
	light.position = at + Vector3(0.0, 0.35, 0.0)
	light.light_color = Color(1.0, 0.45, 0.2)
	light.light_energy = 3.2
	light.omni_range = light_range
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	glow.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.15)
	mat.albedo_color = Color(1.0, 0.5, 0.2)
	glow.set_surface_override_material(0, mat)
	light.add_child(glow)
	add_child(light)
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(light):
			light.queue_free())
