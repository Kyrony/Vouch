extends Node
## Main
##
## Root scene. Composes the Lobby UI and the persistent "World" (Match +
## Outside) as siblings and just toggles visibility between them, instead
## of using `change_scene_to_file()`. This sidesteps a lot of Godot 4
## multiplayer scene-change replication timing headaches for a project
## this size: Match/Outside/their MultiplayerSpawners are always present
## in the tree (on every peer) and ready to receive spawned nodes the
## moment the host starts the match.
##
## TODO(post-MVP): if the project grows multiple maps/rounds, revisit this
## in favor of proper scene streaming.

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
	if OS.get_environment("VOUCH_FLOOR_PLAN_TEST") == "1":
		call_deferred("_run_floor_plan_test")
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
		"floor_plan_id": "04",
		"has_valve": false,
		"total_rooms": 1,
	}
	var room := match_node._spawn_room_pod(data)
	if room == null:
		push_error("MATCH SPAWN TEST FAILED")
		get_tree().quit(1)
		return
	print("MATCH SPAWN TEST OK children=", room.get_child_count())
	get_tree().quit(0)


func _run_floor_plan_test() -> void:
	print("=== FLOOR PLAN SPAWN TEST START ===")
	var plans := ["01", "04", "12", "15"]
	for plan_id in plans:
		var room := _spawn_test_room(plan_id)
		if room == null:
			push_error("FLOOR PLAN TEST FAILED plan=%s" % plan_id)
			get_tree().quit(1)
			return
		print("  plan %s OK children=%d footprint=%.0fx%.0f" % [plan_id, room.get_child_count(), room.width, room.depth])
		room.queue_free()
		await get_tree().process_frame
	print("=== FLOOR PLAN SPAWN TEST: ALL OK ===")
	get_tree().quit(0)


func _spawn_test_room(plan_id: String) -> RoomPod:
	var RoomPodScene: PackedScene = preload("res://scenes/Match/RoomPod.tscn")
	var room: RoomPod = RoomPodScene.instantiate()
	room.configure({
		"room_index": 0,
		"owner_peer_id": 1,
		"rng_seed": int(plan_id) * 1000,
		"is_puppet_master": false,
		"floor_plan_id": plan_id,
		"has_valve": false,
		"total_rooms": 1,
	})
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
	# REMOVE DEBUG GUI FROM PAUSE MENU BEFORE FINAL LAUNCH
	pause_menu.hide_menu()
	if debug_gui.has_method("_toggle"):
		debug_gui._toggle()
