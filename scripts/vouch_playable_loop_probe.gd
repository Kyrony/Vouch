extends SceneTree
## Mirrors live Match._spawn_room_pod + EscapeHub.build — proves playable loop geometry.
## Run: godot4 --headless --path . -s res://scripts/vouch_playable_loop_probe.gd

const _PLAYABLE: GDScript = preload("res://scripts/rooms/playable_loop_spawns.gd")
const _ROOM_POD: GDScript = preload("res://scripts/room_pod.gd")
const _PATH: GDScript = preload("res://scripts/rooms/escape_path_validator.gd")


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	var err: String = await _probe()
	if err.is_empty():
		print("PLAYABLE LOOP PROBE OK")
		quit(0)
	push_error("PLAYABLE LOOP PROBE FAILED: %s" % err)
	quit(1)


func _probe() -> String:
	var match_root := Node3D.new()
	match_root.set_script(load("res://scripts/match.gd"))
	root.add_child(match_root)

	var recipe: Dictionary = _ROOM_POD.call("plan_recipe", false)
	recipe["room_scene_id"] = 4
	var data := {
		"room_index": 0,
		"owner_peer_id": 1,
		"rng_seed": 4242,
		"is_puppet_master": false,
		"total_rooms": 2,
		"has_valve": true,
		"has_electrical_box": true,
		"has_fireplace": true,
		"has_drain": true,
		"has_exhaust": true,
	}
	data.merge(recipe)

	var room_pod: Node = match_root.call("_spawn_room_pod", data)
	if room_pod == null:
		match_root.queue_free()
		return "Match._spawn_room_pod returned null"
	match_root.add_child(room_pod)
	if room_pod.get_child_count() < 1:
		match_root.queue_free()
		return "RoomPod has no map child"

	await process_frame

	var map: Node = room_pod.get_child(0)
	var spawn_local: Vector3 = Vector3.ZERO
	if map.has_node("PlayerSpawn"):
		spawn_local = map.get_node("PlayerSpawn").position

	var comms_errors: Array = _PLAYABLE.call("validate", map, spawn_local)
	if not comms_errors.is_empty():
		match_root.queue_free()
		return "; ".join(comms_errors)

	var hub := match_root.get_node_or_null("EscapeHub")
	if hub == null:
		match_root.queue_free()
		return "EscapeHub node missing after _spawn_room_pod"

	var ramp_steps: Array = []
	for c in hub.get_children():
		if c.is_in_group("escape_hub_ramp"):
			ramp_steps.append(c)
	if ramp_steps.is_empty():
		match_root.queue_free()
		return "EscapeHub has no escape_hub_ramp collision segments"

	_PATH.call("log_path_nodes", match_root)

	var path_errors: Array = _PATH.call("validate", match_root)
	if not path_errors.is_empty():
		match_root.queue_free()
		return "; ".join(path_errors)

	print("  Phone dist=%.2fm Walkie dist=%.2fm ramp_segments=%d" % [
		spawn_local.distance_to(map.get_node("Phone").position),
		spawn_local.distance_to(map.get_node("WalkieTalkie").position),
		ramp_steps.size(),
	])
	match_root.queue_free()
	return ""
