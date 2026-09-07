extends SceneTree
## Uses the same Match.tscn + RoomsSpawner.spawn path as live Start Match.
## Run: godot4 --headless --path . -s res://scripts/vouch_playable_loop_probe.gd
## Full escape + items: VOUCH_ESCAPE_PATH=1 godot4 --headless --path . -s res://scripts/vouch_playable_loop_probe.gd

const _ROOM_POD: GDScript = preload("res://scripts/room_pod.gd")
const _PATH: GDScript = preload("res://scripts/rooms/escape_path_validator.gd")
const _SPAWN: GDScript = preload("res://scripts/rooms/graybox_spawn_validator.gd")
const _BUNKER: GDScript = preload("res://scripts/rooms/graybox_bunker_validator.gd")
const _PLAYABLE: GDScript = preload("res://scripts/rooms/playable_loop_spawns.gd")
const _ESCAPE_SETTINGS: GDScript = preload("res://scripts/autoload/escape_path_settings.gd")


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	await process_frame
	var err: String = await _probe()
	if err.is_empty():
		var mode := "escape path" if _ESCAPE_SETTINGS.escape_path_enabled() else "bunker-only"
		print("PLAYABLE LOOP PROBE OK (live Match API, 2 rooms, %s)" % mode)
		quit(0)
	push_error("PLAYABLE LOOP PROBE FAILED: %s" % err)
	quit(1)


func _probe() -> String:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var match_node: Node = main.get_node("World/Match")
	if not match_node.is_node_ready():
		await match_node.ready

	var specs: Array = _two_player_room_specs()
	var spawn_err: String = _PATH.call("spawn_rooms_like_live", match_node, specs)
	if not spawn_err.is_empty():
		main.queue_free()
		return spawn_err

	await process_frame
	await physics_frame
	await physics_frame

	if _ESCAPE_SETTINGS.bunker_only():
		return _probe_bunker_only(match_node, main)
	if _ESCAPE_SETTINGS.escape_path_enabled():
		return _probe_escape_path(match_node, main)
	return _probe_bunker_only(match_node, main)


func _probe_bunker_only(match_node: Node, main: Node) -> String:
	if match_node.get_node_or_null("EscapeHub") != null:
		main.queue_free()
		return "EscapeHub must not exist in bunker-only mode"
	var mouths: Array = _PATH.call("_collect_tunnel_mouths", match_node)
	if not mouths.is_empty():
		main.queue_free()
		return "tunnel mouths forbidden in bunker-only mode"
	var room0: Node = _first_room_pod(match_node)
	if room0 == null:
		main.queue_free()
		return "no RoomPod under RoomsContainer"
	var map0: Node = room0.get_child(0)
	var spawn_errors: Array = _SPAWN.call("validate", map0)
	if not spawn_errors.is_empty():
		main.queue_free()
		return "; ".join(spawn_errors)
	var bunker_errors: Array = _BUNKER.call("validate", map0)
	if not bunker_errors.is_empty():
		main.queue_free()
		return "; ".join(bunker_errors)
	var spawn_local: Vector3 = map0.get_node("PlayerSpawn").position
	print("  bunker-only: spawn=%s geometry-only" % spawn_local)
	main.queue_free()
	return ""


func _probe_escape_path(match_node: Node, main: Node) -> String:
	var hub := match_node.get_node_or_null("EscapeHub")
	if hub == null:
		main.queue_free()
		return "EscapeHub missing after RoomsSpawner.spawn"

	var ramp_count := 0
	for c in hub.get_children():
		if c.is_in_group("escape_hub_ramp"):
			ramp_count += 1
	if ramp_count < 1:
		main.queue_free()
		return "EscapeHub has no escape_hub_ramp segments"

	var mouths: Array = _PATH.call("_collect_tunnel_mouths", match_node)
	if mouths.size() < 2:
		main.queue_free()
		return "expected 2 tunnel mouths, got %d" % mouths.size()

	_PATH.call("log_path_nodes", match_node)
	var path_errors: Array = _PATH.call("validate", match_node)
	if not path_errors.is_empty():
		main.queue_free()
		return "; ".join(path_errors)

	var room0: Node = _first_room_pod(match_node)
	if room0 == null:
		main.queue_free()
		return "no RoomPod under RoomsContainer"
	var map0: Node = room0.get_child(0)
	var spawn_local: Vector3 = map0.get_node("PlayerSpawn").position
	var comms_errors: Array = _PLAYABLE.call("validate", map0, spawn_local)
	if not comms_errors.is_empty():
		main.queue_free()
		return "room0 comms: %s" % "; ".join(comms_errors)

	print("  ramp_segments=%d tunnel_mouths=%d room0_phone=%.2fm" % [
		ramp_count,
		mouths.size(),
		spawn_local.distance_to(map0.get_node("Phone").position),
	])
	main.queue_free()
	return ""


func _two_player_room_specs() -> Array:
	var specs: Array = []
	for room_index in range(2):
		var recipe: Dictionary = _ROOM_POD.call("plan_recipe", false)
		recipe["room_scene_id"] = 1 if room_index == 0 else 3
		var data := {
			"room_index": room_index,
			"owner_peer_id": room_index + 1,
			"rng_seed": 9000 + room_index * 1111,
			"is_puppet_master": false,
			"total_rooms": 2,
			"has_valve": true,
			"has_electrical_box": true,
			"has_fireplace": true,
			"has_drain": true,
			"has_exhaust": true,
		}
		data.merge(recipe)
		specs.append(data)
	return specs


func _first_room_pod(match_node: Node) -> Node:
	for c in match_node.get_node("RoomsContainer").get_children():
		if str(c.name).begins_with("RoomPod"):
			return c
	return null
