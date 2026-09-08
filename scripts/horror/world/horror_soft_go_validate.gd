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
	var kit_err := validate_kit_graybox(world)
	if not kit_err.is_empty():
		return kit_err
	var outdoor_err := validate_outdoor_terrain(world)
	if not outdoor_err.is_empty():
		return outdoor_err
	return ""


static func validate_v05_layout(world: Node3D) -> String:
	var mansion := world.get_node_or_null("PMMansion") as Node3D
	if mansion == null:
		return "PMMansion missing"
	if mansion.global_position.x < 20.0:
		return "PM mansion is not east/center-right on L1b (x=%.1f)" % mansion.global_position.x
	var families := world.get_node_or_null("FamilyHouses")
	if families == null:
		return "FamilyHouses missing"
	for letter in ["A", "B", "C", "D"]:
		if families.get_node_or_null("FamilyHouse_%s" % letter) == null:
			return "FamilyHouse_%s missing from L1b farm parcels" % letter
	if world.get_node_or_null("UncleHouse") == null:
		return "UncleHouse missing"
	if world.get_node_or_null("UncleGarage") == null and world.get_node_or_null("UncleHouse/UncleGarage") == null:
		return "Uncle garage missing"
	for room_name in _V05.PM_L4_ROOMS:
		if mansion.find_child(room_name, true, false) == null:
			return "L4 PM room missing: %s" % room_name
	var roads := world.get_node_or_null("Outdoor/Roads")
	if roads == null:
		return "Outdoor/Roads (farm lanes / curbs) missing"
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
	if span_x < 56.0 or span_x > 150.0 or span_z < 40.0 or span_z > 130.0:
		return "neighborhood span %.1fx%.1f not L1b farm (~80m+)" % [span_x, span_z]
	var min_house_d := INF
	for i in 4:
		var ha: Node3D = families.get_node("FamilyHouse_%s" % ["A", "B", "C", "D"][i])
		for j in range(i + 1, 4):
			var hb: Node3D = families.get_node("FamilyHouse_%s" % ["A", "B", "C", "D"][j])
			min_house_d = minf(min_house_d, ha.global_position.distance_to(hb.global_position))
	if min_house_d < 18.0:
		return "family houses too tight (min %.1fm) — L1b wants spaced parcels" % min_house_d
	var exits: Array = world.get_tree().get_nodes_in_group("walkable_exits")
	if exits.size() < 6:
		return "expected walkable door exits on graybox buildings, got %d" % exits.size()
	if bool(_V05.OUTDOOR_ONLY):
		return "OUTDOOR_ONLY is still on — Host Match should use the graybox farm"
	if world.has_method("get_family_spawn_transform"):
		var fam0_xf: Transform3D = world.call("get_family_spawn_transform", 0)
		var house_a: Node3D = families.get_node("FamilyHouse_A")
		if fam0_xf.origin.distance_to(house_a.global_position) > 16.0:
			return "family 0 spawn is not on house A parcel"
	if world.has_method("get_pm_spawn_transform"):
		var pm_xf: Transform3D = world.call("get_pm_spawn_transform")
		if pm_xf.origin.distance_to(mansion.global_position) > 22.0:
			return "PM spawn is not at mansion approach / foyer"
	return ""


static func validate_outdoor_terrain(world: Node3D) -> String:
	var outdoor := world.get_node_or_null("Outdoor")
	if outdoor == null:
		return "Outdoor missing"
	var terrain := outdoor.get_node_or_null("Terrain")
	if terrain == null:
		return "Outdoor/Terrain missing (L1b farm heightfield)"
	if terrain.get_node_or_null("CollisionShape3D") == null:
		return "Outdoor/Terrain missing collision"
	var span_x: float = float(terrain.get_meta("span_x", 0.0))
	var span_z: float = float(terrain.get_meta("span_z", 0.0))
	if span_x < 80.0 or span_z < 64.0:
		return "outdoor terrain too small (%.1fx%.1f) — need a large walkable area" % [span_x, span_z]
	var hills := outdoor.get_node_or_null("Hills")
	if hills == null:
		return "Outdoor/Hills missing"
	if hills.get_child_count() < 5:
		return "expected farm-country hills (>=5), got %d" % hills.get_child_count()
	var roads := outdoor.get_node_or_null("Roads")
	if roads == null or roads.get_child_count() < 4:
		return "Outdoor/Roads missing street pieces"
	var spawns: Array = world.get_tree().get_nodes_in_group("outdoor_player_spawns")
	if spawns.size() < 5:
		return "expected outdoor player spawns (4 families + PM), got %d" % spawns.size()
	if not world.has_method("get_family_spawn_transform"):
		return "HorrorWorld missing get_family_spawn_transform"
	for i in 4:
		var fam_xf = world.call("get_family_spawn_transform", i)
		var ferr: String = _spawn_must_be_outdoor(fam_xf.origin, "family %d" % i)
		if not ferr.is_empty():
			return ferr
	var pm_xf = world.call("get_pm_spawn_transform")
	var perr: String = _spawn_must_be_outdoor(pm_xf.origin, "PM")
	if not perr.is_empty():
		return perr
	var bunker: Node3D = world.find_child("Bunker", true, false) as Node3D
	if bunker != null and pm_xf.origin.distance_to(bunker.global_position) < 5.0:
		if absf(pm_xf.origin.y - bunker.global_position.y) < 2.5:
			return "PM spawn is inside the bunker"
	return ""


static func _spawn_must_be_outdoor(origin: Vector3, label: String) -> String:
	if origin.y < _V05.OUTDOOR_SPAWN_Y_MIN:
		return "%s spawn is underground y=%.2f" % [label, origin.y]
	if origin.y > 6.5:
		return "%s spawn is not on walkable graybox / yard (y=%.2f)" % [label, origin.y]
	return ""


static func validate_kit_graybox(world: Node3D) -> String:
	var house_a: Node = world.get_node_or_null("FamilyHouses/FamilyHouse_A")
	if house_a == null:
		return "FamilyHouse_A missing"
	for piece in ["Foundation", "Porch", "Stairs", "HouseBody", "UnderPorchCrawl"]:
		if house_a.get_node_or_null(piece) == null:
			return "FamilyHouse_A missing modular piece %s" % piece
	var crawl: Node = house_a.get_node("UnderPorchCrawl")
	if crawl.get_node_or_null("ChildSpawn_under_porch_crawl") == null:
		return "under_porch_crawl marker is not inside UnderPorchCrawl"
	if crawl.find_child("CrawlMood", true, false) == null:
		return "under-porch crawl missing mood light"
	var bedroom: Node = house_a.find_child("Bedroom", true, false)
	if bedroom == null:
		return "FamilyHouse_A missing Bedroom (kit floor plan)"
	var mansion: Node = world.get_node_or_null("PMMansion")
	if mansion == null:
		return "PMMansion missing"
	var bunker: Node = mansion.find_child("Bunker", true, false)
	if bunker == null:
		return "Bunker missing"
	for piece in ["Pipes", "NeonStrips", "Fluorescent", "Workbench", "UtilityCloset"]:
		if bunker.get_node_or_null(piece) == null:
			return "Bunker missing kit piece %s" % piece
	var util: Node = bunker.get_node("UtilityCloset")
	if util.get_node_or_null("Shelves") == null:
		return "UtilityCloset missing shelves"
	if util.find_child("ChildSpawn_bunker_utility", true, false) == null:
		return "bunker_utility marker missing from UtilityCloset"
	if mansion.find_child("Basement", true, false) == null:
		return "Basement missing"
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


static func validate_phone_hud(world: Node3D) -> String:
	var pd: Node = Engine.get_main_loop().root.get_node_or_null("PhoneDevice")
	if pd == null:
		return "PhoneDevice autoload missing"
	if str(pd.ITEM_ID) != "phone":
		return "inventory id must stay phone (got %s)" % pd.ITEM_ID
	if str(pd.ITEM_PRODUCTION_ID) != "ITEM_DEVICE_SMARTPHONE_01":
		return "smartphone production id mismatch"
	var led_min: float = float(pd.LED_DRAIN_PER_SEC) * 60.0
	var passive_min: float = float(pd.PASSIVE_DRAIN_PER_SEC) * 60.0
	# Sheet listed ~15%/min LED and ~2%/min passive as concept — eng owns the live numbers.
	if is_equal_approx(led_min, 15.0) or is_equal_approx(passive_min, 2.0):
		return "phone drain locked to Leonardo sheet marketing numbers — use eng tunables"
	if led_min <= 0.0 or passive_min < 0.0:
		return "phone drain rates invalid (LED=%.2f%%/min passive=%.2f%%/min)" % [led_min, passive_min]
	if float(pd.LED_MIN_BATTERY) <= 0.0:
		return "dead battery must disable the phone LED"
	var saw_phone := false
	for node in world.get_tree().get_nodes_in_group("world_pickups"):
		var item_id := str(node.get("item_id"))
		if item_id == "flashlight" or item_id.contains("flashlight") or item_id.contains("torch"):
			return "classic flashlight item is forbidden — phone LED only"
		if item_id == "phone":
			saw_phone = true
			if node.get_node_or_null("Smartphone") == null:
				return "phone pickup missing graphite/gold Smartphone visual"
			if node.find_child("CameraLED", true, false) == null:
				return "phone pickup missing CameraLED"
	if not saw_phone:
		return "smartphone world pickup missing"
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	if hud_script == null:
		return "neon_hud.gd failed to load"
	var hud: Object = hud_script.new()
	if not hud.has_method("set_signal_band") or not hud.has_method("set_phone_device"):
		hud.free()
		return "NeonHud missing signal/phone LED API"
	hud.call("set_signal_band", "service")
	if str(hud.get("signal_band")) != "full":
		hud.free()
		return "NeonHud did not map service -> full"
	hud.free()
	var rules := _towers()
	if rules and not rules.has_method("signal_band"):
		return "TowerRules.signal_band missing"
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
