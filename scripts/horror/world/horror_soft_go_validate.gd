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


const BANNED_WORLD_BUILDERS: Array[String] = [
	"res://scripts/horror/environment/outdoor_builder.gd",
	"res://scripts/horror/environment/outdoor_terrain.gd",
	"res://scripts/horror/environment/spawn_point_markers.gd",
	"res://scripts/horror/world/neighborhood_layout.gd",
	"res://scripts/horror/environment/graybox_materials.gd",
	"res://scripts/horror/environment/family_house_builder.gd",
	"res://scripts/horror/environment/uncle_house_builder.gd",
	"res://scripts/horror/environment/pm_mansion_builder.gd",
	"res://scripts/horror/environment/trust_field_builder.gd",
	"res://scripts/horror/environment/modular_kit.gd",
	"res://scripts/horror/environment/graybox_builder.gd",
]


static func validate_no_runtime_world_gen() -> String:
	for path in BANNED_WORLD_BUILDERS:
		if ResourceLoader.exists(path):
			return "runtime world builder still on disk: %s" % path
	var hw: String = FileAccess.get_file_as_string("res://scripts/horror/horror_world.gd")
	for needle in ["OutdoorBuilder", "OutdoorTerrain", "NeighborhoodLayout", "SpawnPointMarkers", "_install_farm_environment", "_scatter_pickups", "preload(\"res://scripts/horror/environment/outdoor"]:
		if hw.contains(needle):
			return "HorrorWorld still calls runtime world gen: %s" % needle
	return ""


static func validate_world(world: Node3D) -> String:
	if world == null:
		return "HorrorWorld missing"
	var gen_err := validate_no_runtime_world_gen()
	if not gen_err.is_empty():
		return gen_err
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
	var cycle_err := validate_day_cycle(world)
	if not cycle_err.is_empty():
		return cycle_err
	return ""


static func validate_day_cycle(world: Node3D) -> String:
	if not FileAccess.file_exists("res://scripts/autoload/match_clock.gd"):
		return "MatchClock script missing"
	var clock_src := FileAccess.get_file_as_string("res://scripts/autoload/match_clock.gd")
	if not clock_src.contains("MATCH_REAL_SECONDS := 1440.0"):
		return "dusk→morning must be 24 real minutes (1440s)"
	if not clock_src.contains("REAL_SECONDS_PER_GAME_HOUR := 120.0"):
		return "1 in-game hour must equal 2 real minutes"
	var clock_script: GDScript = load("res://scripts/autoload/match_clock.gd")
	if clock_script == null:
		return "MatchClock failed to load"
	if str(clock_script.call("clock_label_for_progress", 0.0)) != "6:00 PM":
		return "match must start at 6:00 PM dusk"
	if str(clock_script.call("clock_label_for_progress", 1.0)) != "6:00 AM":
		return "match must end at 6:00 AM morning"
	var dusk: Dictionary = clock_script.call("sample_lighting", 0.0)
	var night: Dictionary = clock_script.call("sample_lighting", 0.5)
	var dawn: Dictionary = clock_script.call("sample_lighting", 1.0)
	if (dusk["sky"] as Color).v <= (night["sky"] as Color).v:
		return "night sky should read darker than dusk"
	if float(dawn["lit_e"]) <= float(night["lit_e"]):
		return "morning sun should be brighter than midnight"
	if world.get_node_or_null("FarmSky") == null:
		return "FarmSky WorldEnvironment missing for the day cycle"
	if world.get_node_or_null("SunMoon") == null:
		return "SunMoon DirectionalLight3D missing for the day cycle"
	var project := FileAccess.get_file_as_string("res://project.godot")
	if not project.contains("MatchClock="):
		return "MatchClock autoload missing from project.godot"
	if not FileAccess.file_exists("res://scripts/horror/ui/morning_end_overlay.gd"):
		return "morning end overlay missing"
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
	## Kyle greybox: pin 9 sits on the SE road toward the east cliff, not House A porch.
	if crawl.global_position.x < 20.0 or crawl.global_position.z < 8.0:
		return "under_porch_crawl is not on the Kyle SE road (xz=%.1f,%.1f)" % [
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
	if horror.get_node_or_null("Outdoor") == null or horror.get_node_or_null("L2SpawnMarkers") == null:
		return "authored farm nodes missing from HorrorWorld.tscn"
	var authored_err := validate_authored_scene_geometry(horror)
	if not authored_err.is_empty():
		return authored_err
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
	if horror.get_node_or_null("PlaceholderGun") == null:
		return "PlaceholderGun missing near outdoor spawn"
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
	summary.append("RUNTIME WORLD GEN PROOF:")
	var builders_present: PackedStringArray = PackedStringArray()
	for path in BANNED_WORLD_BUILDERS:
		if ResourceLoader.exists(path):
			builders_present.append(path)
	if builders_present.is_empty():
		summary.append("  builder_scripts_on_disk=none")
	else:
		summary.append("  builder_scripts_on_disk=%s" % ",".join(builders_present))
	var horror := world_root.get_node_or_null("Match/HorrorWorld") as Node3D
	if horror:
		var auto_names := _generated_auto_names(horror)
		summary.append("  horror_world_source=res://scenes/Horror/HorrorWorld.tscn")
		var terrain := horror.get_node_or_null("Outdoor/Terrain")
		var house := horror.get_node_or_null("Outdoor/MainHouse") as Node3D
		summary.append("  outdoor_exists=%s roads=%s terrain=%s markers=%s main_house=%s" % [
			horror.get_node_or_null("Outdoor") != null,
			horror.get_node_or_null("Outdoor/Roads") != null,
			terrain != null,
			horror.get_node_or_null("L2SpawnMarkers") != null,
			house != null,
		])
		if terrain:
			summary.append("  authored_heightfield=%s peak_y=%s valley_y=%s" % [
				terrain.get_meta("authored_heightfield", false),
				terrain.get_meta("peak_y", 0.0),
				terrain.get_meta("valley_y", 0.0),
			])
		if house:
			summary.append("  main_house_pos=%s on_hilltop=%s" % [
				house.global_position, house.get_meta("on_hilltop", false),
			])
		summary.append("  generated_at_names_under_farm=%d" % auto_names.size())
		for n in auto_names:
			summary.append("    AUTO %s" % n)
	summary.append("TREE:")
	for line in lines:
		summary.append(line)
	return "\n".join(summary)


static func validate_authored_scene_geometry(world: Node3D) -> String:
	for folder_path in ["Outdoor", "L2SpawnMarkers"]:
		var folder := world.get_node_or_null(folder_path)
		if folder == null:
			return "authored folder missing: %s" % folder_path
		for node in folder.find_children("*", "", true, false):
			if str(node.name).begins_with("@"):
				return "runtime-generated node under %s: %s" % [folder_path, node.get_path()]
	var roads := world.get_node_or_null("Outdoor/Roads")
	if roads and roads.get_node_or_null("Lane_00") == null:
		return "authored Roads/Lane_00 missing — farm lanes must be scene nodes, not loop-stamped bodies"
	return ""


static func _generated_auto_names(world: Node3D) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for folder_path in ["Outdoor", "L2SpawnMarkers"]:
		var folder := world.get_node_or_null(folder_path)
		if folder == null:
			continue
		for node in folder.find_children("*", "", true, false):
			if str(node.name).begins_with("@"):
				found.append(str(node.get_path()))
	return found


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
		return "Outdoor/Fields (Kyle greybox footprint) missing"
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
		return "OUTDOOR_ONLY must stay on — no extra neighborhood houses"
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
		return "L2 footprint span %.1fx%.1f not Kyle farm (~80m+)" % [span_x, span_z]
	return ""


static func validate_outdoor_terrain(world: Node3D) -> String:
	var outdoor := world.get_node_or_null("Outdoor")
	if outdoor == null:
		return "Outdoor missing"
	var terrain := outdoor.get_node_or_null("Terrain")
	if terrain == null:
		return "Outdoor/Terrain missing (Kyle T0 heightfield)"
	if not FileAccess.file_exists("res://assets/horror/farm/kyle_T0_height_97x81.exr"):
		return "Kyle T0 height EXR missing (kyle_T0_height_97x81.exr)"
	if FileAccess.file_exists("res://assets/horror/farm/kyle_height_preview_NOISY_do_not_import.png"):
		return "noisy height preview must not be imported"
	var pads := outdoor.get_node_or_null("Pads")
	if pads == null:
		return "Outdoor/Pads missing — Kyle greybox pads"
	for pad_name in ["Pad_FamilyA", "Pad_FamilyB", "Pad_FamilyC", "Pad_FamilyD", "Pad_Uncle", "Pad_UncleGarage"]:
		if pads.get_node_or_null(pad_name) == null:
			return "Kyle greybox pad missing: Outdoor/Pads/%s" % pad_name
	var cs := terrain.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null or cs.shape == null:
		return "Outdoor/Terrain missing collision"
	var hm := cs.shape as HeightMapShape3D
	if hm == null:
		return "Outdoor/Terrain collision is not HeightMapShape3D"
	if hm.map_width != 97 or hm.map_depth != 81:
		return "Kyle T0 HeightMapShape3D must be 97x81, got %dx%d" % [hm.map_width, hm.map_depth]
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
	if pm_xf.origin.y < 3.0:
		return "PM spawn is not on the hilltop (y=%.2f)" % pm_xf.origin.y
	var house_err := validate_hilltop_main_house(world)
	if not house_err.is_empty():
		return house_err
	var peak_y: float = float(terrain.get_meta("peak_y", 0.0))
	var valley_y: float = float(terrain.get_meta("valley_y", 0.0))
	if not bool(terrain.get_meta("authored_heightfield", false)):
		return "Outdoor/Terrain is not an authored heightfield"
	if peak_y - valley_y < 3.5:
		return "farm height contrast %.2f is too flat — need rolling hills" % (peak_y - valley_y)
	return ""


static func validate_hilltop_main_house(world: Node3D) -> String:
	var house := world.get_node_or_null("Outdoor/MainHouse") as Node3D
	if house == null:
		return "Outdoor/MainHouse missing — one hilltop main house is required"
	if house.find_child("PMMansion", true, false) != null:
		return "legacy PMMansion kit leaked under MainHouse"
	if not bool(house.get_meta("on_hilltop", false)):
		return "MainHouse missing on_hilltop meta"
	if house.global_position.y < 3.5:
		return "MainHouse is not on a hill (y=%.2f)" % house.global_position.y
	if house.global_position.x < 14.0 or house.global_position.x > 40.0:
		return "MainHouse xz is not on the Kyle hilltop"
	if house.get_node_or_null("Core") == null:
		return "MainHouse missing graybox Core"
	return ""


static func _spawn_must_be_outdoor(origin: Vector3, label: String) -> String:
	if origin.y < _V05.OUTDOOR_SPAWN_Y_MIN:
		return "%s spawn is underground y=%.2f" % [label, origin.y]
	if origin.y > 8.5:
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
