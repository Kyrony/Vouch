extends RefCounted
class_name HorrorSoftGoValidate
## Shared headless checks: L2 snake_case pins on open farm terrain + roads.

const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const FORBIDDEN_SHELLS: Array[String] = [
	"FamilyHouses",
	"FamilyHouse_A",
	"FamilyHouse_B",
	"FamilyHouse_C",
	"FamilyHouse_D",
	"PMMansion",
	"UncleHouse",
	"UncleGarage",
	"RadioTowers",
	"SignalPhones",
	"FamilyShed",
	"ParkedCar",
	"GardenWell",
	"StormDrain",
	"StreetLamps",
	"FarmDressing",
	"CrawlLabel",
	"UnderPorchCrawl",
	"MountainTerrain",
	"Mast",
]


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
		var sid_s := str(sid)
		if bool(_V05.call("is_forbidden_spawn_id", sid_s)):
			return "SPAWN_IDS used non-eng id %s — snake_case short ids only" % sid_s
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
	var pin_err := validate_l2_pin_homes(world)
	if not pin_err.is_empty():
		return pin_err
	var shell_err := validate_no_building_shells(world)
	if not shell_err.is_empty():
		return shell_err
	var tower_err := validate_no_towers(world)
	if not tower_err.is_empty():
		return tower_err
	var layout_err := validate_v05_layout(world)
	if not layout_err.is_empty():
		return layout_err
	var outdoor_err := validate_outdoor_terrain(world)
	if not outdoor_err.is_empty():
		return outdoor_err
	return ""


## Place by eng id, not Leonardo art pin numbers. Art duplicates pin 4 on
## basement + under-porch; eng keeps basement=4 and under_porch_crawl=9.
static func validate_l2_pin_homes(world: Node3D) -> String:
	var basement: Node3D = null
	var crawl: Node3D = null
	for node in world.get_tree().get_nodes_in_group("child_spawn_points"):
		if not (node is Node3D):
			continue
		var n3: Node3D = node
		var sid := str(n3.get_meta("spawn_id", ""))
		if bool(_V05.call("is_forbidden_spawn_id", sid)):
			return "child marker %s wired forbidden id %s" % [n3.name, sid]
		if not bool(_V05.call("is_canonical_spawn_id", sid)):
			return "child marker %s has unknown spawn_id=%s" % [n3.name, sid]
		var want_pin: int = int(_V05.call("l2_pin_number", sid))
		if int(n3.get_meta("l2_pin", -1)) != want_pin:
			return "child marker %s l2_pin=%s != eng pin %d for %s" % [
				n3.name, n3.get_meta("l2_pin", -1), want_pin, sid,
			]
		var label_err := _require_spawn_point_label(n3)
		if not label_err.is_empty():
			return label_err
		var want: Vector3 = _V05.call("l2_world_pos", sid)
		var xz := Vector2(n3.global_position.x, n3.global_position.z)
		var want_xz := Vector2(want.x, want.z)
		if xz.distance_to(want_xz) > 4.0:
			return "child marker %s xz=%s not on L2 footprint %s" % [sid, xz, want_xz]
		if n3.global_position.y < _V05.OUTDOOR_SPAWN_Y_MIN:
			return "child marker %s is underground y=%.2f" % [sid, n3.global_position.y]
		if sid == "basement":
			basement = n3
		elif sid == "under_porch_crawl":
			crawl = n3
	if basement == null:
		return "basement marker missing"
	if crawl == null:
		return "under_porch_crawl marker missing"
	if int(basement.get_meta("l2_pin", -1)) != 4:
		return "basement must be pin 4"
	if int(crawl.get_meta("l2_pin", -1)) != 9:
		return "under_porch_crawl must be pin 9 — do not collapse onto basement"
	if basement.global_position.distance_to(crawl.global_position) < 12.0:
		return "basement and under_porch_crawl markers collapsed — place by eng id, not art pin 4"
	## QA v2: pin 9 sits on the SE road bend, not the old House A porch.
	if crawl.global_position.x < 20.0 or crawl.global_position.z < 8.0:
		return "under_porch_crawl is not on the QA v2 SE road bend (xz=%.1f,%.1f)" % [
			crawl.global_position.x, crawl.global_position.z,
		]
	return ""


static func _require_spawn_point_label(marker: Node) -> String:
	var site: Node = marker.get_parent()
	if site == null:
		return "spawn marker %s has no parent site" % marker.name
	var label: Label3D = site.get_node_or_null("Label") as Label3D
	if label == null:
		label = marker.get_node_or_null("Label") as Label3D
	if label == null:
		return "spawn marker %s missing Label3D saying Spawn Point" % marker.name
	if str(label.text) != "Spawn Point":
		return "spawn marker %s label is '%s' — must say Spawn Point" % [marker.name, label.text]
	if str(marker.get_meta("visible_label", "")) != "Spawn Point":
		return "spawn marker %s missing visible_label meta" % marker.name
	if site.get_node_or_null("Box") == null:
		return "spawn marker %s missing visible Box" % marker.name
	return ""


## Full Main/World after Play → Classic → Host → Start Match.
static func validate_live_start_match_world(world_root: Node) -> String:
	if world_root == null:
		return "Main/World missing"
	var outside := world_root.get_node_or_null("Outside")
	if outside and outside.visible:
		return "World/Outside is still visible — Start Match leaked the courtyard/mountain graybox"
	if outside:
		if outside.get_node_or_null("MountainTerrain") != null:
			return "World/Outside/MountainTerrain still in the live tree"
		if outside.find_child("*", false, false) != null:
			## Children may still be queued; wait one frame in the probe.
			pass
		for mesh in outside.find_children("*", "MeshInstance3D", true, false):
			return "World/Outside still has mesh %s — courtyard must be emptied" % mesh.get_path()
	var horror := world_root.get_node_or_null("Match/HorrorWorld") as Node3D
	if horror == null:
		return "Match/HorrorWorld missing after Start Match — live path did not load the farm"
	for node_name in FORBIDDEN_SHELLS:
		if world_root.find_child(node_name, true, false) != null:
			return "forbidden node in live World: %s" % node_name
	for node in world_root.get_tree().get_nodes_in_group("tower_candidates"):
		return "tower/mast candidate still in live tree: %s" % node.name
	for node in world_root.get_tree().get_nodes_in_group("walkable_exits"):
		return "house door exit still in live tree: %s" % node.name
	for node in world_root.find_children("*", "Label3D", true, false):
		var text := str(node.text).strip_edges()
		if text == "CRAWL" or text.contains("CRAWL"):
			return "floating CRAWL label still in live tree"
		if text != "Spawn Point" and text != "" and not _V05.SPAWN_IDS.has(text):
			if str(node.name) == "Label" or str(node.name) == "CrawlLabel":
				return "unexpected Label3D '%s' on %s" % [text, node.get_path()]
	var shell_err := validate_no_building_shells(horror)
	if not shell_err.is_empty():
		return shell_err
	return validate_world(horror)


static func dump_live_world(world_root: Node) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var type_counts: Dictionary = {}
	_dump_walk(world_root, 0, lines, type_counts)
	var types: Array = type_counts.keys()
	types.sort()
	var summary: PackedStringArray = PackedStringArray()
	summary.append("LIVE START MATCH WORLD DUMP")
	summary.append("node_count=%d" % lines.size())
	for t in types:
		summary.append("  type %s = %d" % [t, type_counts[t]])
	summary.append("TREE:")
	for line in lines:
		summary.append(line)
	return "\n".join(summary)


static func _dump_walk(node: Node, depth: int, lines: PackedStringArray, type_counts: Dictionary) -> void:
	var cls := node.get_class()
	type_counts[cls] = int(type_counts.get(cls, 0)) + 1
	var extra := ""
	if node is Label3D:
		extra = " text='%s'" % str((node as Label3D).text)
	lines.append("%s%s [%s]%s" % ["  ".repeat(depth), node.name, cls, extra])
	for child in node.get_children():
		_dump_walk(child, depth + 1, lines, type_counts)


static func validate_no_building_shells(world: Node3D) -> String:
	for node_name in FORBIDDEN_SHELLS:
		if world.find_child(node_name, true, false) != null:
			return "forbidden shell still in world: %s" % node_name
	for piece in ["HouseBody", "Bunker", "UtilityCloset", "UnderPorchCrawl", "DuctSystem"]:
		if world.find_child(piece, true, false) != null:
			return "forbidden kit piece still in world: %s" % piece
	var exits: Array = world.get_tree().get_nodes_in_group("walkable_exits")
	if not exits.is_empty():
		return "walkable_exits still present (%d) — building shells should be gone" % exits.size()
	return ""


static func validate_kit_graybox(world: Node3D) -> String:
	return validate_no_building_shells(world)


static func validate_v05_layout(world: Node3D) -> String:
	if world.get_node_or_null("Outdoor/Roads") == null:
		return "Outdoor/Roads (farm lanes / curbs) missing"
	if world.get_node_or_null("Outdoor/Fields") == null:
		return "Outdoor/Fields (L1b footprint) missing"
	var escape := world.get_node_or_null("Outdoor/HorrorEscapeZone")
	if escape == null:
		return "soft-gated HorrorEscapeZone missing"
	if not bool(escape.get_meta("soft_gated", false)):
		return "escape zone is not soft-gated"
	if escape.get_node_or_null("Sign") != null:
		return "escape signage present — master sheet has no escape routes"
	if world.get_node_or_null("L2SpawnMarkers") == null:
		return "L2SpawnMarkers root missing"
	if not bool(_V05.OUTDOOR_ONLY):
		return "OUTDOOR_ONLY must stay on — Host Match is terrain+roads only"
	if bool(_V05.GRAYBOX_NEIGHBORHOOD):
		return "GRAYBOX_NEIGHBORHOOD must stay off — no house/bunker shells"
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for node in world.get_tree().get_nodes_in_group("child_spawn_points"):
		if not (node is Node3D):
			continue
		var p: Vector3 = (node as Node3D).global_position
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	var span_x: float = max_x - min_x
	var span_z: float = max_z - min_z
	if span_x < 56.0 or span_x > 150.0 or span_z < 40.0 or span_z > 130.0:
		return "L2 footprint span %.1fx%.1f not L1b farm (~80m+)" % [span_x, span_z]
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
	return ""


static func _spawn_must_be_outdoor(origin: Vector3, label: String) -> String:
	if origin.y < _V05.OUTDOOR_SPAWN_Y_MIN:
		return "%s spawn is underground y=%.2f" % [label, origin.y]
	if origin.y > 6.5:
		return "%s spawn is not on walkable farm terrain (y=%.2f)" % [label, origin.y]
	return ""


static func validate_no_towers(world: Node3D) -> String:
	var candidates: Array = world.get_tree().get_nodes_in_group("tower_candidates")
	if not candidates.is_empty():
		return "tower candidates still in world (%d) — no masts" % candidates.size()
	var live: Array = world.get_tree().get_nodes_in_group("active_towers")
	if not live.is_empty():
		return "active_towers still in world (%d)" % live.size()
	if world.find_child("RadioTowers", true, false) != null:
		return "RadioTowers root still present"
	return ""


static func validate_tower_roll(world: Node3D) -> String:
	## Kept name for probe callers. Kyle: no masts in the live farm.
	return validate_no_towers(world)


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
	var ui: GDScript = load("res://scripts/horror/ui/leonardo_ui_validate.gd")
	var hud_err: String = ui.call("validate_hud")
	if not hud_err.is_empty():
		return hud_err
	var rules := _towers()
	if rules and not rules.has_method("signal_band"):
		return "TowerRules.signal_band missing"
	return ""


static func validate_leonardo_menu(lobby: Control) -> String:
	var ui: GDScript = load("res://scripts/horror/ui/leonardo_ui_validate.gd")
	return ui.call("validate_menu", lobby)


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
