extends Node3D
class_name HorrorWorld
## Procedural graybox horror neighborhood: family houses, PM mansion, uncle house, yard.

const _LAYOUT: GDScript = preload("res://scripts/horror/world/neighborhood_layout.gd")
const _PICKUP_SCENE: PackedScene = preload("res://scenes/Horror/WorldPickup.tscn")

var _family_spawns: Array[Marker3D] = []
var _pm_spawn: Marker3D = null
var _tick_accum: float = 0.0


func _ready() -> void:
	add_to_group("horror_world")
	var built: Dictionary = _LAYOUT.call("build", self, 4)
	_family_spawns.clear()
	var spawned = built.get("family_spawns", [])
	for m in spawned:
		if m is Marker3D:
			_family_spawns.append(m)
	var pm = built.get("pm_spawn")
	_pm_spawn = pm if pm is Marker3D else null
	_scatter_pickups()
	print("[HorrorWorld] neighborhood built families=%d graybox_spawns=%d terrain=l1b_farm" % [
		built["family_count"], _family_spawns.size(),
	])


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_accum += delta
	if _tick_accum >= 0.1:
		_tick_accum = 0.0
		PlayerEffects.server_tick(0.1)
		PhoneDevice.server_tick(0.1)


func server_init_match(player_count: int) -> void:
	if not multiplayer.is_server():
		return
	var seed_base := player_count + int(Time.get_ticks_usec() % 9973)
	ChildSpawnRNG.server_roll(self, seed_base)
	TowerRules.server_roll(self, seed_base + 17)


func get_family_spawn_transform(family_index: int) -> Transform3D:
	if _family_spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(-32.0, 0.2, -14.0))
	var idx := clampi(family_index, 0, _family_spawns.size() - 1)
	return _family_spawns[idx].global_transform


func get_pm_spawn_transform() -> Transform3D:
	if _pm_spawn == null:
		return Transform3D(Basis.IDENTITY, Vector3(24.0, 0.2, -4.0))
	return _pm_spawn.global_transform


func get_random_spawn_transform() -> Transform3D:
	if _family_spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(-32.0, 0.2, -14.0))
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
		{"id": "medkit", "pos": Vector3(-40.0, 0.9, 10.0)},
		{"id": "phone", "pos": Vector3(2.0, 0.5, 2.0)},
		{"id": "bandage", "pos": Vector3(24.0, 0.5, -4.0)},
		{"id": "battery", "pos": Vector3(-52.0, 0.5, -38.0)},
		{"id": "crowbar", "pos": Vector3(6.0, 0.9, 28.0)},
		{"id": "keycard", "pos": Vector3(-12.0, 0.5, 8.0)},
	]
	for d in defs:
		_spawn_pickup_local(d["id"], d["pos"])
