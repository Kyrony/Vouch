extends Node
## TowerRules — many candidate masts; 3 active per match; 1 forced near PM.
##
## Towers + phones are the horror trust tools (limited radii). Soft-go stub:
## a short scratch on the slate, never a voice or SMS claim.

const ACTIVE_COUNT: int = 3
const TOWER_RADIUS: float = 18.0
const PHONE_RADIUS: float = 8.0
const NEAR_PM_MAX: float = 32.0

var _active_ids: Array[String] = []
var _forced_id: String = ""


func reset() -> void:
	_active_ids.clear()
	_forced_id = ""


func server_roll(world: Node3D, rng_seed: int = -1) -> Array[String]:
	if not multiplayer.is_server():
		return []
	if rng_seed >= 0:
		seed(rng_seed)
	else:
		randomize()
	reset()
	var candidates: Array[Node3D] = _collect_candidates(world)
	if candidates.is_empty():
		push_error("[TowerRules] no tower candidates in world")
		return []
	var pm_origin := _pm_origin(world)
	var forced: Node3D = _nearest(candidates, pm_origin)
	if forced:
		_forced_id = str(forced.get_meta("tower_id", forced.name))
		_active_ids.append(_forced_id)
	var pool: Array[Node3D] = []
	for c in candidates:
		if c != forced:
			pool.append(c)
	pool.shuffle()
	for c in pool:
		if _active_ids.size() >= ACTIVE_COUNT:
			break
		_active_ids.append(str(c.get_meta("tower_id", c.name)))
	_apply_active(world, _active_ids)
	_client_set_active.rpc(_active_ids, _forced_id)
	print("[TowerRules] active=%s forced_near_pm=%s" % [_active_ids, _forced_id])
	return _active_ids.duplicate()


func get_active_ids() -> Array[String]:
	return _active_ids.duplicate()


func get_forced_id() -> String:
	return _forced_id


func is_active_id(tower_id: String) -> bool:
	return _active_ids.has(tower_id)


func in_tower_radius(world_pos: Vector3) -> bool:
	for node in _active_tower_nodes():
		if world_pos.distance_to(node.global_position) <= TOWER_RADIUS:
			return true
	return false


func in_phone_radius(world_pos: Vector3) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("signal_phones"):
		if node is Node3D and world_pos.distance_to((node as Node3D).global_position) <= PHONE_RADIUS:
			return true
	return false


func can_use_signal(world_pos: Vector3, holding_phone: bool, at_tower: bool = false) -> bool:
	if at_tower and in_tower_radius(world_pos):
		return true
	if not in_tower_radius(world_pos):
		return false
	return holding_phone or in_phone_radius(world_pos)


func nearest_tower_strength(world_pos: Vector3) -> float:
	var best := 0.0
	for node in _active_tower_nodes():
		var d: float = world_pos.distance_to(node.global_position)
		if d <= TOWER_RADIUS:
			best = maxf(best, 1.0 - (d / TOWER_RADIUS))
	return best


@rpc("authority", "call_local", "reliable")
func _client_set_active(ids: Array, forced_id: String) -> void:
	_active_ids.clear()
	for id in ids:
		_active_ids.append(str(id))
	_forced_id = forced_id
	var world := get_tree().get_first_node_in_group("horror_world")
	if world is Node3D:
		_apply_active(world as Node3D, _active_ids)


func _apply_active(world: Node3D, ids: Array[String]) -> void:
	for node in world.get_tree().get_nodes_in_group("tower_candidates"):
		if node.has_method("set_tower_active"):
			var tid := str(node.get_meta("tower_id", ""))
			node.call("set_tower_active", ids.has(tid))


func _collect_candidates(world: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in world.get_tree().get_nodes_in_group("tower_candidates"):
		if node is Node3D:
			out.append(node)
	return out


func _active_tower_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var tree := get_tree()
	if tree == null:
		return out
	for node in tree.get_nodes_in_group("active_towers"):
		if node is Node3D:
			out.append(node)
	if not out.is_empty():
		return out
	for node in tree.get_nodes_in_group("tower_candidates"):
		if node is Node3D and _active_ids.has(str(node.get_meta("tower_id", ""))):
			out.append(node)
	return out


func _pm_origin(world: Node3D) -> Vector3:
	if world.has_method("get_pm_spawn_transform"):
		return world.call("get_pm_spawn_transform").origin
	return Vector3(0, 0, -48)


func _nearest(nodes: Array[Node3D], origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in nodes:
		var d: float = n.global_position.distance_to(origin)
		if d < best_d:
			best_d = d
			best = n
	return best


static func active_count() -> int:
	return ACTIVE_COUNT
