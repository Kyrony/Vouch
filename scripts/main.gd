extends Node
## Main — root scene (Lobby + World).

const _ATTACHMENT: GDScript = preload("res://scripts/rooms/spawn_attachment_validator.gd")

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
	if OS.get_environment("VOUCH_ROOM_SPAWN_TEST") == "1":
		call_deferred("_run_room_spawn_test")
	elif OS.get_environment("VOUCH_ATTACHMENT_TEST") == "1":
		call_deferred("_run_attachment_test")
	if OS.get_environment("VOUCH_MATCH_SPAWN_TEST") == "1":
		call_deferred("_run_match_spawn_test")


func _run_match_spawn_test() -> void:
	world.visible = true
	var match_node: Match = $World/Match
	var data := {
		"room_index": 0,
		"owner_peer_id": 1,
		"rng_seed": 12345,
		"is_puppet_master": false,
		"room_scene_id": 4,
		"has_valve": true,
		"has_electrical_box": true,
		"has_fireplace": true,
		"has_drain": true,
		"has_exhaust": true,
		"total_rooms": 1,
	}
	var room := match_node._spawn_room_pod(data)
	if room == null:
		push_error("MATCH SPAWN TEST FAILED")
		get_tree().quit(1)
		return
	print("MATCH SPAWN TEST OK children=", room.get_child_count())
	get_tree().quit(0)


func _run_room_spawn_test() -> void:
	print("=== ROOM MAP SPAWN TEST START ===")
	for room_id in [1, 4, 12, 15, 20]:
		var room := _spawn_test_room(room_id)
		if room == null:
			push_error("ROOM SPAWN TEST FAILED room=%02d" % room_id)
			get_tree().quit(1)
			return
		var map := room.get_child(0) if room.get_child_count() > 0 else room
		var slots := map.get_node_or_null("ItemSpawns")
		var slot_count := slots.get_child_count() if slots else 0
		print("  room %02d OK footprint=%.0fx%.0f slots=%d" % [room_id, room.width, room.depth, slot_count])
		room.queue_free()
		await get_tree().process_frame
	print("=== ROOM MAP SPAWN TEST: ALL OK ===")
	get_tree().quit(0)


func _run_attachment_test() -> void:
	print("=== ATTACHMENT TEST START ===")
	for room_id in [1, 4, 12, 15, 20]:
		var room := _spawn_test_room(room_id, true)
		if room == null:
			push_error("ATTACHMENT TEST FAILED room=%02d (spawn)" % room_id)
			get_tree().quit(1)
			return
		var map: Node3D = room.get_child(0) if room.get_child_count() > 0 else room
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


func _spawn_test_room(room_id: int, full_items: bool = false) -> RoomPod:
	var room: RoomPod = preload("res://scenes/Match/RoomPod.tscn").instantiate()
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
