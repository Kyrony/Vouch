extends Node3D
class_name HorrorWorld
## Authored farm country. Terrain/roads/markers live in HorrorWorld.tscn.
## Start Match instantiates that packed scene — it does not loop-build geometry.

const PICKUP_SCENE: String = "res://scenes/Horror/WorldPickup.tscn"

var _family_spawns: Array[Marker3D] = []
var _pm_spawn: Marker3D = null
var _tick_accum: float = 0.0


func _ready() -> void:
	add_to_group("horror_world")
	_suppress_parallel_worlds()
	_bind_authored_spawns()
	print("[HorrorWorld] loaded authored farm scene family_pads=%d l2_markers=%d" % [
		_family_spawns.size(), get_tree().get_nodes_in_group("child_spawn_points").size(),
	])


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
