extends Node
## FireSystem
##
## Host-authoritative ignition + burn timers for FlammableProp nodes.

const BURN_TICK: float = 0.15

var _burning: Dictionary = {}  # instance_id -> { node, time_left, total }


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
	var id := node.get_instance_id()
	if _burning.has(id):
		return
	var burn_time: float = node.get_burn_duration() if node.has_method("get_burn_duration") else 3.0
	_burning[id] = {"node": node, "time_left": burn_time, "total": burn_time}
	if node.has_method("server_on_ignited"):
		node.server_on_ignited()
	_client_ignite.rpc(id, burn_time)


@rpc("authority", "call_remote", "reliable")
func _client_ignite(instance_id: int, burn_time: float) -> void:
	for node in get_tree().get_nodes_in_group("flammable_props"):
		if node.get_instance_id() == instance_id:
			if node.has_method("client_on_ignited"):
				node.client_on_ignited(burn_time)
			return


func server_scan_proximity(node: Node3D, ignite_radius: float = 1.1) -> void:
	if not multiplayer.is_server():
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
