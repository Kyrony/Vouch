extends Node3D
class_name HorrorWorld
## Host Match farm: walkable terrain + roads + labeled L2 spawn markers.

const _LAYOUT: GDScript = preload("res://scripts/horror/world/neighborhood_layout.gd")
const _TERRAIN: GDScript = preload("res://scripts/horror/environment/outdoor_terrain.gd")
const _PICKUP_SCENE: PackedScene = preload("res://scenes/Horror/WorldPickup.tscn")

var _family_spawns: Array[Marker3D] = []
var _pm_spawn: Marker3D = null
var _tick_accum: float = 0.0


func _ready() -> void:
	add_to_group("horror_world")
	_suppress_parallel_worlds()
	_install_farm_environment()
	var built: Dictionary = _LAYOUT.call("build", self, 4)
	_family_spawns.clear()
	var spawned = built.get("family_spawns", [])
	for m in spawned:
		if m is Marker3D:
			_family_spawns.append(m)
	var pm = built.get("pm_spawn")
	_pm_spawn = pm if pm is Marker3D else null
	_scatter_pickups()
	print("[HorrorWorld] farm terrain+roads built family_pads=%d l2_markers=%d" % [
		_family_spawns.size(), get_tree().get_nodes_in_group("child_spawn_points").size(),
	])


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_accum += delta
	if _tick_accum >= 0.1:
		_tick_accum = 0.0
		PlayerEffects.server_tick(0.1)
		PhoneDevice.server_tick(0.1)


func _suppress_parallel_worlds() -> void:
	## Main.tscn always instances World/Outside beside Match. That courtyard
	## + mountain CSG was still visible after Start Match (Kyle fail).
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
		var mountain := outside.get_node_or_null("MountainTerrain")
		if mountain:
			mountain.queue_free()


func _install_farm_environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "FarmSky"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.58)
	env.ambient_light_energy = 0.7
	env.fog_enabled = false
	env_node.environment = env
	add_child(env_node)


func server_init_match(player_count: int) -> void:
	if not multiplayer.is_server():
		return
	var seed_base := player_count + int(Time.get_ticks_usec() % 9973)
	ChildSpawnRNG.server_roll(self, seed_base)
	## Kyle: no masts / tower meshes in the live farm world.


func get_family_spawn_transform(family_index: int) -> Transform3D:
	if _family_spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.2, -8.0))
	var idx := clampi(family_index, 0, _family_spawns.size() - 1)
	return _family_spawns[idx].global_transform


func get_pm_spawn_transform() -> Transform3D:
	if _pm_spawn == null:
		return Transform3D(Basis.IDENTITY, Vector3(40.0, 0.2, 10.0))
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


func spawn_pickup(item_id: String, global_pos: Vector3) -> void:
	if get_node_or_null("Pickups") == null:
		var pickups := Node3D.new()
		pickups.name = "Pickups"
		add_child(pickups)
	_spawn_pickup_local(item_id, global_pos)


func _spawn_pickup_local(item_id: String, pos: Vector3) -> void:
	var container := get_node_or_null("Pickups")
	if container == null:
		return
	var pickup: Node = _PICKUP_SCENE.instantiate()
	pickup.name = "Pickup_%s" % item_id
	pickup.set("item_id", item_id)
	container.add_child(pickup)
	pickup.global_position = pos + Vector3(0, 0.35, 0)


func _scatter_pickups() -> void:
	var pickups := Node3D.new()
	pickups.name = "Pickups"
	add_child(pickups)
	var defs := [
		{"id": "medkit", "xz": Vector2(-34.0, -12.0)},
		{"id": "phone", "xz": Vector2(2.0, 2.0)},
		{"id": "bandage", "xz": Vector2(40.0, 10.0)},
		{"id": "battery", "xz": Vector2(-50.0, -40.0)},
		{"id": "crowbar", "xz": Vector2(6.0, 24.0)},
		{"id": "keycard", "xz": Vector2(10.0, 6.0)},
	]
	for d in defs:
		var xz: Vector2 = d["xz"]
		var y: float = float(_TERRAIN.call("height_at", xz.x, xz.y))
		_spawn_pickup_local(d["id"], Vector3(xz.x, maxf(y, 0.0), xz.y))
