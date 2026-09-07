extends Node
## FireSystem
##
## Host-authoritative stylized fire: ignites wood-tagged props near flames,
## spreads only to the same material group, extinguishable by room flood.

const BURN_TICK: float = 0.15
const SPREAD_INTERVAL: float = 1.4
const SPREAD_RADIUS: float = 1.25
const EXTINGUISH_WATER_LEVEL: float = 0.35

var _burning: Dictionary = {}  # instance_id -> { node, time_left, total, spread_cd }


func _ready() -> void:
	set_process(multiplayer.is_server())


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var done: Array = []
	for key in _burning.keys():
		var entry: Dictionary = _burning[key]
		var node: Node = entry.get("node")
		if not is_instance_valid(node):
			done.append(key)
			continue
		entry["time_left"] = float(entry["time_left"]) - delta
		var progress := 1.0 - float(entry["time_left"]) / float(entry["total"])
		if node.has_method("server_set_burn_progress"):
			node.server_set_burn_progress(progress)
		entry["spread_cd"] = float(entry.get("spread_cd", 0.0)) - delta
		if float(entry["spread_cd"]) <= 0.0:
			entry["spread_cd"] = SPREAD_INTERVAL
			_try_spread(node)
		if float(entry["time_left"]) <= 0.0:
			if node.has_method("server_finish_burn"):
				node.server_finish_burn()
			done.append(key)
	for key in done:
		_burning.erase(key)


func server_try_ignite(node: Node) -> void:
	if not multiplayer.is_server() or not is_instance_valid(node):
		return
	if not node.has_method("can_ignite") or not node.can_ignite():
		return
	if not _is_wood_prop(node):
		return
	var id := node.get_instance_id()
	if _burning.has(id):
		return
	var burn_time: float = node.get_burn_duration() if node.has_method("get_burn_duration") else 3.0
	_burning[id] = {"node": node, "time_left": burn_time, "total": burn_time, "spread_cd": SPREAD_INTERVAL * 0.5}
	if node.has_method("server_on_ignited"):
		node.server_on_ignited()
	_client_ignite.rpc(id, burn_time)


func server_extinguish(node: Node) -> void:
	if not multiplayer.is_server() or not is_instance_valid(node):
		return
	var id := node.get_instance_id()
	if not _burning.has(id):
		return
	_burning.erase(id)
	if node.has_method("server_extinguish"):
		node.server_extinguish()
	elif node.has_method("server_finish_burn"):
		node.server_finish_burn()


func server_extinguish_in_room(room_index: int) -> void:
	if not multiplayer.is_server():
		return
	var to_stop: Array = []
	for key in _burning.keys():
		var node: Node = _burning[key].get("node")
		if is_instance_valid(node) and _node_room_index(node) == room_index:
			to_stop.append(node)
	for node in to_stop:
		server_extinguish(node)


func server_scan_proximity(node: Node3D, ignite_radius: float = 1.1) -> void:
	if not multiplayer.is_server():
		return
	if GameState.room_water_levels.get(_node_room_index(node), 0.0) >= EXTINGUISH_WATER_LEVEL:
		return
	for flame in get_tree().get_nodes_in_group("flames"):
		if not is_instance_valid(flame):
			continue
		if node.global_position.distance_to(flame.global_position) <= ignite_radius:
			server_try_ignite(node)
			return
	for fp in get_tree().get_nodes_in_group("fire_hazards"):
		if not is_instance_valid(fp):
			continue
		if fp.has_method("is_fire_active") and fp.is_fire_active():
			if node.global_position.distance_to(fp.global_position) <= ignite_radius * 1.5:
				server_try_ignite(node)
				return


func _try_spread(source: Node) -> void:
	if not source is Node3D:
		return
	for node in get_tree().get_nodes_in_group("flammable_props"):
		if node == source or not node is Node3D:
			continue
		if not _is_wood_prop(node):
			continue
		if node.global_position.distance_to((source as Node3D).global_position) > SPREAD_RADIUS:
			continue
		if node.has_method("can_ignite") and node.can_ignite():
			server_try_ignite(node)


func _is_wood_prop(node: Node) -> bool:
	return node.is_in_group("wood_props") or node.is_in_group("flammable_props")


func _node_room_index(node: Node) -> int:
	if node.get("room_index") != null:
		return int(node.room_index)
	if node is Node3D:
		var pos: Vector3 = (node as Node3D).global_position
		var col := int(roundi(pos.x / WorldScale.GRID_SPACING))
		var row := int(roundi(pos.z / WorldScale.GRID_SPACING))
		return row * 4 + col
	return -1


@rpc("authority", "call_remote", "reliable")
func _client_ignite(instance_id: int, burn_time: float) -> void:
	for node in get_tree().get_nodes_in_group("flammable_props"):
		if node.get_instance_id() == instance_id:
			if node.has_method("client_on_ignited"):
				node.client_on_ignited(burn_time)
			return
