extends RefCounted
class_name HorrorSoftGoValidate
## Shared headless checks for Lauren-cleared spawn pins + tower stub.


static func _child_rng() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("ChildSpawnRNG")


static func _towers() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TowerRules")


static func validate_world(world: Node3D) -> String:
	if world == null:
		return "HorrorWorld missing"
	var rng := _child_rng()
	if rng == null:
		return "ChildSpawnRNG autoload missing"
	var expected: Array[String] = rng.call("spawn_id_list")
	if expected.size() != int(rng.call("expected_count")):
		return "SPAWN_IDS size %d != expected %d" % [expected.size(), ChildSpawnRNG.expected_count()]
	var child_points: Array = world.get_tree().get_nodes_in_group("child_spawn_points")
	if child_points.size() != expected.size():
		return "expected %d child spawn points, got %d" % [expected.size(), child_points.size()]
	var seen: Dictionary = {}
	for node in child_points:
		var sid := str(node.get_meta("spawn_id", ""))
		if sid.is_empty():
			return "child spawn marker %s missing spawn_id" % node.name
		if not expected.has(sid):
			return "unexpected child spawn_id=%s" % sid
		if seen.has(sid):
			return "duplicate child spawn_id=%s" % sid
		seen[sid] = true
	for sid in expected:
		if not seen.has(sid):
			return "missing child spawn_id=%s" % sid

	var candidates: Array = world.get_tree().get_nodes_in_group("tower_candidates")
	if candidates.size() < 8:
		return "expected many tower candidates (>=8), got %d" % candidates.size()
	if world.get_node_or_null("RadioTowers") == null:
		return "RadioTowers root missing"
	if world.get_node_or_null("SignalPhones") == null:
		return "SignalPhones root missing"
	var phones: Array = world.get_tree().get_nodes_in_group("signal_phones")
	if phones.size() < 3:
		return "expected signal phones, got %d" % phones.size()
	return ""


static func validate_tower_roll(world: Node3D) -> String:
	var rules := _towers()
	if rules == null:
		return "TowerRules autoload missing"
	var active: Array = rules.call("server_roll", world, 42)
	var want: int = int(rules.call("active_count"))
	if active.size() != want:
		return "expected %d active towers, got %d (%s)" % [want, active.size(), active]
	var live: Array = world.get_tree().get_nodes_in_group("active_towers")
	if live.size() != want:
		return "active_towers group size %d != %d" % [live.size(), want]
	var forced: String = str(rules.call("get_forced_id"))
	if forced.is_empty():
		return "forced near-PM tower id empty"
	var pm: Vector3 = world.call("get_pm_spawn_transform").origin
	var forced_node: Node3D = null
	for node in live:
		if str(node.get_meta("tower_id", "")) == forced:
			forced_node = node
			break
	if forced_node == null:
		return "forced tower %s not in active_towers" % forced
	var max_d: float = float(rules.call("near_pm_max"))
	if forced_node.global_position.distance_to(pm) > max_d:
		return "forced tower %s too far from PM (%.1f)" % [forced, forced_node.global_position.distance_to(pm)]
	return ""
