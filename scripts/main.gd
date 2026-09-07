extends Node
## Main — root scene (Lobby + World).

const _ATTACHMENT: GDScript = preload("res://scripts/rooms/spawn_attachment_validator.gd")
const _ROOM_POD: GDScript = preload("res://scripts/room_pod.gd")
const _PLAYABLE: GDScript = preload("res://scripts/rooms/playable_loop_spawns.gd")
const _PATH: GDScript = preload("res://scripts/rooms/escape_path_validator.gd")
const _SPAWN: GDScript = preload("res://scripts/rooms/graybox_spawn_validator.gd")
const _BUNKER: GDScript = preload("res://scripts/rooms/graybox_bunker_validator.gd")
const _ESCAPE_SETTINGS: GDScript = preload("res://scripts/autoload/escape_path_settings.gd")
const _HORROR: GDScript = preload("res://scripts/horror/match_horror.gd")
const EXPECTED_SLOT_COUNT: int = 16

@onready var lobby: Control = $Lobby
@onready var world: Node3D = $World
@onready var pause_menu: Node = $PauseMenu
@onready var debug_gui: Node = $DebugGui


func _ready() -> void:
	world.visible = false
	GameState.match_started.connect(_on_match_started)
	pause_menu.exit_requested.connect(_on_pause_exit)
	pause_menu.settings_requested.connect(_on_pause_settings)
	pause_menu.debug_gui_requested.connect(_on_pause_debug)
	if OS.get_environment("VOUCH_PLAYABLE_LOOP_TEST") == "1":
		call_deferred("_run_playable_loop_test")
	elif OS.get_environment("VOUCH_HORROR_MATCH_TEST") == "1":
		call_deferred("_run_horror_match_test")
	elif OS.get_environment("VOUCH_PLAYER_SCRIPT_TEST") == "1":
		call_deferred("_run_player_script_test")
	elif OS.get_environment("VOUCH_ROOM_SPAWN_TEST") == "1":
		call_deferred("_run_room_spawn_test")
	elif OS.get_environment("VOUCH_ATTACHMENT_TEST") == "1":
		call_deferred("_run_attachment_test")
	if OS.get_environment("VOUCH_MATCH_SPAWN_TEST") == "1":
		call_deferred("_run_match_spawn_test")


func _run_playable_loop_test() -> void:
	world.visible = true
	call_deferred("_run_playable_loop_test_async")


func _run_horror_match_test() -> void:
	world.visible = true
	call_deferred("_run_horror_match_test_async")


func _run_horror_match_test_async() -> void:
	var err: String = await _probe_horror_match()
	if not err.is_empty():
		push_error("HORROR MATCH TEST FAILED: %s" % err)
		get_tree().quit(1)
		return
	print("HORROR MATCH TEST OK")
	get_tree().quit(0)


func _probe_horror_match() -> String:
	if not HorrorModeSettings.is_horror_mode():
		return "Horror mode disabled — unset VOUCH_BUNKER_ONLY / VOUCH_ESCAPE_PATH"
	var match_node = $World/Match
	if not match_node.is_node_ready():
		await match_node.ready
	_HORROR.call("build_world_all_peers", match_node)
	await get_tree().process_frame
	await get_tree().physics_frame
	var world_node := match_node.get_node_or_null("HorrorWorld")
	if world_node == null:
		return "HorrorWorld missing"
	var spawn_count: int = world_node.call("get_spawn_point_count")
	if spawn_count < 4:
		return "expected >= 4 family spawns, got %d" % spawn_count
	var pickups := world_node.get_node_or_null("Pickups")
	if pickups == null or pickups.get_child_count() < 1:
		return "no pickups"
	for node_name in ["FamilyHouses", "PMMansion", "UncleHouse", "Outdoor"]:
		if world_node.get_node_or_null(node_name) == null:
			return "neighborhood node missing: %s" % node_name
	var _CHECK: GDScript = load("res://scripts/horror/world/horror_soft_go_validate.gd")
	var pin_err: String = _CHECK.call("validate_world", world_node)
	if not pin_err.is_empty():
		return pin_err
	var tower_err: String = _CHECK.call("validate_tower_roll", world_node)
	if not tower_err.is_empty():
		return tower_err
	var child_points := world_node.get_tree().get_nodes_in_group("child_spawn_points")
	var steal_err: String = _CHECK.call("validate_life_steal")
	if not steal_err.is_empty():
		return steal_err
	print("  horror spawns=%d pickups=%d child_points=%d towers=%d" % [
		spawn_count, pickups.get_child_count(), child_points.size(), TowerRules.get_active_ids().size(),
	])
	return ""


func _run_playable_loop_test_async() -> void:
	var err: String = await _probe_playable_loop_match_path()
	if not err.is_empty():
		push_error("PLAYABLE LOOP TEST FAILED: %s" % err)
		get_tree().quit(1)
		return
	print("PLAYABLE LOOP TEST OK")
	get_tree().quit(0)


func _probe_playable_loop_match_path() -> String:
	var match_node = $World/Match
	if not match_node.is_node_ready():
		await match_node.ready
	var specs: Array = _playable_loop_room_specs()
	var spawn_err: String = _PATH.call("spawn_rooms_like_live", match_node, specs)
	if not spawn_err.is_empty():
		return spawn_err
	await get_tree().process_frame
	await get_tree().physics_frame
	if _ESCAPE_SETTINGS.bunker_only():
		return _probe_playable_loop_bunker_only(match_node)
	if EscapePathSettings.is_enabled():
		return _probe_playable_loop_escape_path(match_node)
	return _probe_playable_loop_bunker_only(match_node)


func _probe_playable_loop_escape_path(match_node: Node) -> String:
	var hub := match_node.get_node_or_null("EscapeHub")
	if hub == null:
		return "EscapeHub missing"
	var ramp_count := 0
	for c in hub.get_children():
		if c.is_in_group("escape_hub_ramp"):
			ramp_count += 1
	if ramp_count < 1:
		return "EscapeHub has no ramp collision (found %d)" % ramp_count
	if hub.get_node_or_null("OutsideEscapeZone") == null:
		return "OutsideEscapeZone missing"
	var mouths: Array = _PATH.call("_collect_tunnel_mouths", match_node)
	if mouths.size() < 2:
		return "expected 2 tunnel mouths, got %d" % mouths.size()
	_PATH.call("log_path_nodes", match_node)
	var path_errors: Array = _PATH.call("validate", match_node)
	if not path_errors.is_empty():
		return "; ".join(path_errors)
	return _probe_playable_loop_comms(match_node, mouths.size(), ramp_count)


func _probe_playable_loop_bunker_only(match_node: Node) -> String:
	if match_node.get_node_or_null("EscapeHub") != null:
		return "EscapeHub must not exist when escape path is disabled"
	var mouths: Array = _PATH.call("_collect_tunnel_mouths", match_node)
	if not mouths.is_empty():
		return "tunnel mouths should not exist when escape path disabled (got %d)" % mouths.size()
	var room_pods := _count_room_pods(match_node)
	if room_pods != 1:
		return "bunker-only expects 1 room pod, got %d" % room_pods
	var room0: Node = _first_room_pod(match_node)
	if room0 == null:
		return "no RoomPod spawned"
	var map: Node = room0.get_child(0)
	var spawn_errors: Array = _SPAWN.call("validate", map)
	if not spawn_errors.is_empty():
		return "; ".join(spawn_errors)
	var bunker_errors: Array = _BUNKER.call("validate", map)
	if not bunker_errors.is_empty():
		return "; ".join(bunker_errors)
	var spawn_local: Vector3 = map.get_node("PlayerSpawn").position
	print("  playable loop (bunker-only): spawn=%s phone_dist=%.2fm walkie_dist=%.2fm" % [
		spawn_local,
		spawn_local.distance_to(map.get_node("Phone").position),
		Vector2(spawn_local.x - map.get_node("WalkieTalkie").position.x, spawn_local.z - map.get_node("WalkieTalkie").position.z).length(),
	])
	return ""


func _probe_playable_loop_comms(match_node: Node, mouth_count: int, ramp_count: int) -> String:
	var room0: Node = _first_room_pod(match_node)
	if room0 == null:
		return "no RoomPod spawned"
	var map: Node = room0.get_child(0)
	var spawn_local: Vector3 = map.get_node("PlayerSpawn").position if map.has_node("PlayerSpawn") else Vector3.ZERO
	var comms_errors: Array = _PLAYABLE.call("validate", map, spawn_local)
	if not comms_errors.is_empty():
		return "; ".join(comms_errors)
	if EscapePathSettings.is_enabled():
		print("  playable loop: mouths=%d hub_ramps=%d phone_dist=%.2f" % [
			mouth_count,
			ramp_count,
			spawn_local.distance_to(map.get_node("Phone").position),
		])
	else:
		print("  playable loop (bunker-only): phone_dist=%.2f spawn=%s" % [
			spawn_local.distance_to(map.get_node("Phone").position),
			spawn_local,
		])
	return ""


func _first_room_pod(match_node: Node) -> Node:
	for c in match_node.get_node("RoomsContainer").get_children():
		if str(c.name).begins_with("RoomPod"):
			return c
	return null


func _count_room_pods(match_node: Node) -> int:
	var n := 0
	for c in match_node.get_node("RoomsContainer").get_children():
		if str(c.name).begins_with("RoomPod"):
			n += 1
	return n


func _playable_loop_room_specs() -> Array:
	var room_count := 1 if _ESCAPE_SETTINGS.bunker_only() else 2
	var specs: Array = []
	for room_index in range(room_count):
		var recipe: Dictionary = _ROOM_POD.call("plan_recipe", false)
		recipe["room_scene_id"] = 1 if room_index == 0 else 3
		var data := {
			"room_index": room_index,
			"owner_peer_id": room_index + 1,
			"rng_seed": 7000 + room_index * 999,
			"is_puppet_master": false,
			"total_rooms": room_count,
			"has_valve": true,
			"has_fireplace": true,
			"has_drain": true,
			"has_exhaust": true,
		}
		data.merge(recipe)
		specs.append(data)
	return specs


func _run_player_script_test() -> void:
	var err := _probe_player_spawn()
	if not err.is_empty():
		push_error("PLAYER SCRIPT TEST FAILED: %s" % err)
		get_tree().quit(1)
		return
	print("PLAYER SCRIPT TEST OK")
	get_tree().quit(0)


func _probe_player_spawn() -> String:
	var player_script: Script = load("res://scripts/player.gd") as Script
	if player_script == null:
		return "player.gd did not compile — run: godot4 --headless --path . --import"

	var scene: PackedScene = load("res://scenes/Player/Player.tscn") as PackedScene
	if scene == null:
		return "Player.tscn failed to load"
	var preview: Node = scene.instantiate()
	if preview.get_script() == null:
		preview.free()
		return "Player.tscn root has no script attached"
	if not preview.has_method("enter_ladder"):
		preview.free()
		return "Player node missing enter_ladder()"
	preview.free()

	var match_node := $World/Match
	var data := {
		"peer_id": 1,
		"faction_id": "probe_faction",
		"spawn_position": Vector3.ZERO,
		"spawn_rotation_y": 0.0,
	}
	var player: Node = match_node._spawn_player(data)
	if player == null:
		return "Match._spawn_player returned null"
	if player.get_script() == null:
		player.free()
		return "spawned player has no script (bare CharacterBody3D)"
	if str(player.get("faction_id")) != "probe_faction":
		player.free()
		return "spawned player missing faction_id"
	player.free()
	return ""


func _run_match_spawn_test() -> void:
	world.visible = true
	call_deferred("_run_match_spawn_test_async")


func _run_match_spawn_test_async() -> void:
	var match_node = $World/Match
	if not match_node.is_node_ready():
		await match_node.ready
	var recipe: Dictionary = _ROOM_POD.call("plan_recipe", false)
	recipe["room_scene_id"] = 2
	var data := {
		"room_index": 0,
		"owner_peer_id": 1,
		"rng_seed": 12345,
		"is_puppet_master": false,
		"total_rooms": 1,
		"has_valve": true,
		"has_electrical_box": true,
		"has_fireplace": true,
		"has_drain": true,
		"has_exhaust": true,
	}
	data.merge(recipe)
	var room = match_node._spawn_room_pod(data)
	if room == null:
		push_error("MATCH SPAWN TEST FAILED: _spawn_room_pod returned null")
		get_tree().quit(1)
		return
	match_node.get_node("RoomsContainer").add_child(room)
	await get_tree().process_frame
	var err := _assert_room_map_built(room, "MATCH SPAWN")
	if not err.is_empty():
		push_error(err)
		get_tree().quit(1)
		return
	var map = room.get_child(0)
	var slots = map.get_node("ItemSpawns")
	var spawn_xform: Transform3D = room.get_spawn_transform()
	var player: Node = match_node._spawn_player({
		"peer_id": 1,
		"faction_id": "spawn_test",
		"spawn_position": spawn_xform.origin,
		"spawn_rotation_y": spawn_xform.basis.get_euler().y,
	})
	if player == null:
		push_error("MATCH SPAWN TEST FAILED: player spawn returned null")
		get_tree().quit(1)
		return
	match_node.get_node("PlayersContainer").add_child(player)
	await get_tree().physics_frame
	var global_errors: Array = _SPAWN.call("validate_global", map, player as Node3D)
	if not global_errors.is_empty():
		push_error("MATCH SPAWN TEST FAILED: %s" % "; ".join(global_errors))
		get_tree().quit(1)
		return
	print("MATCH SPAWN TEST OK children=%d slots=%d spawn_global=%s" % [
		room.get_child_count(),
		slots.get_child_count(),
		spawn_xform.origin,
	])
	get_tree().quit(0)


func _run_room_spawn_test() -> void:
	print("=== GRAYBOX ROOM SPAWN TEST START ===")
	for room_id in [1, 2, 3, 4, 5, 6]:
		var room = _spawn_test_room(room_id)
		if room == null:
			push_error("ROOM SPAWN TEST FAILED room=%02d" % room_id)
			get_tree().quit(1)
			return
		var map = room.get_child(0) if room.get_child_count() > 0 else null
		var err := _assert_room_map_built(room, "room %02d" % room_id)
		if not err.is_empty():
			push_error("ROOM SPAWN TEST FAILED %s" % err)
			get_tree().quit(1)
			return
		var spawn_errors: Array = _SPAWN.call("validate", map)
		if not spawn_errors.is_empty():
			push_error("ROOM SPAWN TEST FAILED room=%02d spawn: %s" % [room_id, "; ".join(spawn_errors)])
			get_tree().quit(1)
			return
		var slots = map.get_node("ItemSpawns")
		var slot_count = slots.get_child_count()
		print("  room %02d OK footprint=%.0fx%.0f slots=%d" % [room_id, room.width, room.depth, slot_count])
		room.queue_free()
		await get_tree().process_frame
	print("=== GRAYBOX ROOM SPAWN TEST: ALL OK ===")
	get_tree().quit(0)


func _run_attachment_test() -> void:
	if _ESCAPE_SETTINGS.bunker_only():
		print("=== ATTACHMENT TEST SKIPPED (bunker-only friends-MVP) ===")
		get_tree().quit(0)
		return
	print("=== ATTACHMENT TEST START ===")
	for room_id in [1, 3, 5, 6]:
		var room = _spawn_test_room(room_id, true)
		if room == null:
			push_error("ATTACHMENT TEST FAILED room=%02d (spawn)" % room_id)
			get_tree().quit(1)
			return
		var map: Node = room.get_child(0)
		var attach_err := _assert_room_map_built(room, "room %02d" % room_id)
		if not attach_err.is_empty():
			push_error("ATTACHMENT TEST FAILED %s" % attach_err)
			get_tree().quit(1)
			return
		var errors: Array = _ATTACHMENT.call("validate", map)
		if not errors.is_empty():
			for err in errors:
				push_error("ATTACHMENT room=%02d: %s" % [room_id, err])
			get_tree().quit(1)
			return
		print("  room %02d attachment OK" % room_id)
		room.queue_free()
		await get_tree().process_frame
	print("=== ATTACHMENT TEST: ALL OK ===")
	get_tree().quit(0)


func _validate_stairs(map: Node) -> String:
	var geometry := map.get_node_or_null("Geometry")
	if geometry == null:
		return ""
	var landing_count := 0
	for child in geometry.get_children():
		if child is StaticBody3D and child.position.y > 0.4:
			landing_count += 1
	var layout_script: GDScript = preload("res://scripts/rooms/room_layouts.gd")
	var layout: Dictionary = layout_script.call("get_layout", int(map.get("room_id")))
	if layout.has("stairs") and landing_count == 0:
		return "stairs present but no landing geometry"
	return ""


func _assert_room_map_built(room_pod: Node, label: String) -> String:
	if room_pod.get_child_count() < 1:
		return "%s: RoomPod has no child map (configure likely failed)" % label
	var map: Node = room_pod.get_child(0)
	if not map.has_method("configure"):
		return "%s: child missing configure() — room_map.gd did not attach" % label
	if map.get_node_or_null("Geometry") == null:
		return "%s: map has no Geometry node" % label
	if map.get_node_or_null("PlayerSpawn") == null:
		return "%s: PlayerSpawn marker missing" % label
	var spawn_errors: Array = _SPAWN.call("validate", map)
	if not spawn_errors.is_empty():
		return "%s: %s" % [label, "; ".join(spawn_errors)]
	if _ESCAPE_SETTINGS.bunker_only():
		var bunker_errors: Array = _BUNKER.call("validate", map)
		if not bunker_errors.is_empty():
			return "%s: %s" % [label, "; ".join(bunker_errors)]
		return ""
	var slots = map.get_node_or_null("ItemSpawns")
	if slots == null:
		return "%s: map has no ItemSpawns" % label
	if slots.get_child_count() != EXPECTED_SLOT_COUNT:
		return "%s: expected %d item slots, got %d" % [label, EXPECTED_SLOT_COUNT, slots.get_child_count()]
	if map.get_node_or_null("LightSwitch") == null:
		return "%s: LightSwitch missing (ItemSpawnSystem.populate did not run)" % label
	if map.get_node_or_null("EscapeDoor") == null:
		return "%s: EscapeDoor marker missing" % label
	if map.get_node_or_null("EscapeAttach") == null:
		return "%s: EscapeAttach marker missing" % label
	var spawn_local: Vector3 = map.get_node("PlayerSpawn").position if map.has_node("PlayerSpawn") else Vector3.ZERO
	var comms_errors: Array = _PLAYABLE.call("validate", map, spawn_local)
	if not comms_errors.is_empty():
		return "%s: %s" % [label, "; ".join(comms_errors)]
	return ""


func _spawn_test_room(room_id: int, full_items: bool = false):
	var room = preload("res://scenes/Match/RoomPod.tscn").instantiate()
	var data := {
		"room_index": 0,
		"owner_peer_id": 1,
		"rng_seed": room_id * 1000,
		"is_puppet_master": false,
		"room_scene_id": room_id,
		"total_rooms": 1,
	}
	if full_items:
		data.merge({
			"has_valve": true,
			"has_electrical_box": true,
			"has_fireplace": true,
			"has_drain": true,
			"has_exhaust": true,
			"has_binary_puzzle": true,
			"binary_target": 42,
			"binary_peek_room": 1,
		})
	else:
		data["has_valve"] = false
	room.configure(data)
	add_child(room)
	return room


func _on_match_started() -> void:
	lobby.visible = false
	world.visible = true


func _on_pause_exit() -> void:
	get_tree().paused = false
	var match_node: Node = world.get_node_or_null("Match")
	if match_node and match_node.has_method("teardown_match_geometry"):
		match_node.teardown_match_geometry()
	GameState.phase = GameState.Phase.LOBBY
	world.visible = false
	lobby.visible = true


func _on_pause_settings() -> void:
	if is_instance_valid(GameState.local_player_node) and GameState.local_player_node.has_method("_show_toast"):
		GameState.local_player_node._show_toast("Open Home → Settings before your next match.")


func _on_pause_debug() -> void:
	pause_menu.hide_menu()
	if debug_gui.has_method("_toggle"):
		debug_gui._toggle()
