extends Node
## TowerRules — many candidate masts; 3 active per match; 1 forced near PM.
##
## Towers + phones are the horror trust tools (limited radii). Soft-go stub:
## a short scratch on the slate, never a voice or SMS claim.

const ACTIVE_COUNT: int = 3
## L3 phone/mast bands. Service = full scratch, weak = degraded, dead = none.
const SERVICE_RADIUS: float = 7.0
const WEAK_RADIUS: float = 14.0
const TOWER_RADIUS: float = WEAK_RADIUS
const PHONE_SERVICE_RADIUS: float = 4.0
const PHONE_WEAK_RADIUS: float = 8.0
const PHONE_RADIUS: float = PHONE_WEAK_RADIUS
const NEAR_PM_MAX: float = 20.0

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
	var replicated: Array[String] = _active_ids.duplicate()
	_client_set_active.rpc(replicated, _forced_id)
	print("[TowerRules] active=%s forced_near_pm=%s" % [_active_ids, _forced_id])
	return _active_ids.duplicate()


func get_active_ids() -> Array[String]:
	return _active_ids.duplicate()


func get_forced_id() -> String:
	return _forced_id


func is_active_id(tower_id: String) -> bool:
	return _active_ids.has(tower_id)


func in_tower_radius(world_pos: Vector3) -> bool:
	return tower_band(world_pos) != "dead"


func in_phone_radius(world_pos: Vector3) -> bool:
	return phone_band(world_pos) != "dead"


func tower_band(world_pos: Vector3) -> String:
	var d := _nearest_active_distance(world_pos)
	if d <= SERVICE_RADIUS:
		return "service"
	if d <= WEAK_RADIUS:
		return "weak"
	return "dead"


func phone_band(world_pos: Vector3) -> String:
	var d := _nearest_phone_distance(world_pos)
	if d <= PHONE_SERVICE_RADIUS:
		return "service"
	if d <= PHONE_WEAK_RADIUS:
		return "weak"
	return "dead"


func can_use_signal(world_pos: Vector3, holding_phone: bool, at_tower: bool = false) -> bool:
	if at_tower and in_tower_radius(world_pos):
		return true
	if not in_tower_radius(world_pos):
		return false
	return holding_phone or in_phone_radius(world_pos)


func nearest_tower_strength(world_pos: Vector3) -> float:
	var band := tower_band(world_pos)
	if band == "service":
		return 1.0
	if band == "weak":
		var d := _nearest_active_distance(world_pos)
		var t: float = (d - SERVICE_RADIUS) / maxf(WEAK_RADIUS - SERVICE_RADIUS, 0.01)
		return lerpf(0.82, 0.22, clampf(t, 0.0, 1.0))
	return 0.0


func signal_band(world_pos: Vector3) -> String:
	## HUD / phone-screen band: full / weak / dead (service maps to full).
	var tower := tower_band(world_pos)
	if tower == "service":
		return "full"
	if tower == "weak":
		return "weak"
	var phone := phone_band(world_pos)
	if phone == "service":
		return "full"
	if phone == "weak":
		return "weak"
	return "dead"


@rpc("authority", "call_local", "reliable")
func _client_set_active(ids: Array, forced_id: String) -> void:
	var incoming: Array = ids.duplicate()
	var next_ids: Array[String] = []
	for id in incoming:
		next_ids.append(str(id))
	_active_ids = next_ids
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


func _nearest_active_distance(world_pos: Vector3) -> float:
	var best := INF
	for node in _active_tower_nodes():
		best = minf(best, world_pos.distance_to(node.global_position))
	return best


func _nearest_phone_distance(world_pos: Vector3) -> float:
	var tree := get_tree()
	if tree == null:
		return INF
	var best := INF
	for node in tree.get_nodes_in_group("signal_phones"):
		if node is Node3D:
			best = minf(best, world_pos.distance_to((node as Node3D).global_position))
	return best


func _pm_origin(world: Node3D) -> Vector3:
	if world.has_method("get_pm_spawn_transform"):
		return world.call("get_pm_spawn_transform").origin
	return Vector3(17.3, 0.1, 0)


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


static func near_pm_max() -> float:
	return NEAR_PM_MAX


static func service_radius() -> float:
	return SERVICE_RADIUS


static func weak_radius() -> float:
	return WEAK_RADIUS
