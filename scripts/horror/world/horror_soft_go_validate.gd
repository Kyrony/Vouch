extends RefCounted
class_name HorrorSoftGoValidate
## Shared headless checks for L2 CSV spawn_ids + v0.5 footprints + towers.

const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


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
	var sot: Array = _V05.SPAWN_IDS
	if expected.size() != int(rng.call("expected_count")):
		return "SPAWN_IDS size %d != expected %d" % [expected.size(), ChildSpawnRNG.expected_count()]
	if expected.size() != sot.size():
		return "ChildSpawnRNG list size %d != L2 SoT %d" % [expected.size(), sot.size()]
	for i in expected.size():
		if str(expected[i]) != str(sot[i]):
			return "ChildSpawnRNG[%d]=%s != L2 SoT %s" % [i, expected[i], sot[i]]
	for sid in expected:
		if (str(sid).begins_with("pm_") and sid != "pm_attic") or str(sid).ends_with("_closet") or str(sid).ends_with("_crawlspace") or str(sid).ends_with("_curb"):
			return "SPAWN_IDS used long-form id %s — eng short ids only" % sid
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
	var layout_err := validate_v05_layout(world)
	if not layout_err.is_empty():
		return layout_err
	return ""


static func validate_v05_layout(world: Node3D) -> String:
	var mansion := world.get_node_or_null("PMMansion") as Node3D
	if mansion == null:
		return "PMMansion missing"
	if mansion.global_position.x < 12.0:
		return "PM mansion is not east of the cul-de-sac (x=%.1f)" % mansion.global_position.x
	var families := world.get_node_or_null("FamilyHouses")
	if families == null:
		return "FamilyHouses missing"
	for letter in ["A", "B", "C", "D"]:
		if families.get_node_or_null("FamilyHouse_%s" % letter) == null:
			return "FamilyHouse_%s missing from cul-de-sac" % letter
	if world.get_node_or_null("UncleHouse") == null:
		return "UncleHouse missing"
	if world.get_node_or_null("UncleHouse/UncleGarage") == null:
		return "Uncle garage missing"
	for room_name in _V05.PM_L4_ROOMS:
		if mansion.find_child(room_name, true, false) == null:
			return "L4 PM room missing: %s" % room_name
	var roads := world.get_node_or_null("Outdoor/Roads")
	if roads == null:
		return "Outdoor/Roads (cul-de-sac / curbs) missing"
	var escape := world.get_node_or_null("Outdoor/HorrorEscapeZone")
	if escape == null:
		return "soft-gated HorrorEscapeZone missing"
	if not bool(escape.get_meta("soft_gated", false)):
		return "escape zone is not soft-gated"
	if escape.get_node_or_null("Sign") != null:
		return "escape signage present — master sheet has no escape routes"
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for letter in ["A", "B", "C", "D"]:
		var h: Node3D = families.get_node("FamilyHouse_%s" % letter)
		min_x = minf(min_x, h.global_position.x)
		max_x = maxf(max_x, h.global_position.x)
		min_z = minf(min_z, h.global_position.z)
		max_z = maxf(max_z, h.global_position.z)
	min_x = minf(min_x, mansion.global_position.x)
	max_x = maxf(max_x, mansion.global_position.x)
	min_z = minf(min_z, mansion.global_position.z)
	max_z = maxf(max_z, mansion.global_position.z)
	var uncle: Node3D = world.get_node("UncleHouse")
	min_x = minf(min_x, uncle.global_position.x)
	max_x = maxf(max_x, uncle.global_position.x)
	min_z = minf(min_z, uncle.global_position.z)
	max_z = maxf(max_z, uncle.global_position.z)
	var span_x: float = max_x - min_x
	var span_z: float = max_z - min_z
	if span_x < 28.0 or span_x > 56.0 or span_z < 22.0 or span_z > 48.0:
		return "neighborhood span %.1fx%.1f not ~40m v0.5" % [span_x, span_z]
	return ""


static func validate_tower_roll(world: Node3D) -> String:
	var rules := _towers()
	if rules == null:
		return "TowerRules autoload missing"
	var service: float = float(rules.call("service_radius"))
	var weak: float = float(rules.call("weak_radius"))
	if service <= 0.0 or weak <= service:
		return "service/weak radii invalid (service=%.1f weak=%.1f)" % [service, weak]
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


static func validate_life_steal() -> String:
	var fx: GDScript = load("res://scripts/horror/items/player_effects.gd")
	if fx == null:
		return "player_effects.gd failed to load"
	var close: float = float(fx.call("life_steal_drain_per_sec", 0.5, 8.0))
	var edge: float = float(fx.call("life_steal_drain_per_sec", 7.8, 8.0))
	if close < 8.0 or close > 16.0:
		return "close-range drain %.2f HP/s not in several-second TTK band" % close
	if edge > close * 0.35:
		return "edge drain %.2f HP/s too close to point-blank %.2f" % [edge, close]
	if 100.0 / maxf(close, 0.01) < 6.0:
		return "close TTK %.1fs is faster than several seconds" % (100.0 / close)
	return ""
