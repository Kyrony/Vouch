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


func _ready() -> void:
	world.visible = false
	GameState.match_started.connect(_on_match_started)
	if OS.get_environment("VOUCH_HALLWAY_TEST") == "1":
		call_deferred("_run_hallway_test")


func _run_hallway_test() -> void:
	print("=== CONNECTOR COLLISION TEST START ===")
	await _test_connector(RoomPod.ConnectorKind.HALLWAY, false, "HALLWAY (centered)")
	await _test_connector(RoomPod.ConnectorKind.HALLWAY, false, "HALLWAY (off-center start, x=+0.6)", 0.6)
	await _test_connector(RoomPod.ConnectorKind.HALLWAY, true, "HALLWAY (hidden/bookcase)")
	await _test_connector(RoomPod.ConnectorKind.VENT, false, "VENT (centered)")
	await _test_connector(RoomPod.ConnectorKind.CLOSET, false, "CLOSET (centered)")
	await _test_connector(RoomPod.ConnectorKind.SLIDE, false, "SLIDE (one-way, centered)")
	print("=== CONNECTOR COLLISION TEST: ALL DONE ===")
	get_tree().quit(0)


func _test_connector(kind: RoomPod.ConnectorKind, hidden: bool, label: String, x_offset: float = 0.0) -> void:
	print("--- %s ---" % label)
	var RoomPodScene: PackedScene = preload("res://scenes/Match/RoomPod.tscn")
	var room: RoomPod = RoomPodScene.instantiate()
	room.configure({
		"room_index": 0, "owner_peer_id": 1, "rng_seed": 777,
		"is_puppet_master": false,
		"module_chain": [{
			"connector": kind,
			"opening_wall": RoomPod.OpeningWall.NORTH,
			"hidden": hidden,
		}],
		"has_valve": false,
	})
	add_child(room)
	await get_tree().physics_frame

	var body := CharacterBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	body.add_child(shape)
	add_child(body)
	var start_pos: Vector3 = room.get_spawn_transform().origin + Vector3(x_offset, 0, 0)
	body.global_position = start_pos
	await get_tree().physics_frame

	if hidden and room.has_node("SecretBookcase"):
		var bookcase: MovableProp = room.get_node("SecretBookcase")
		bookcase.server_toggle_moved()
		await get_tree().create_timer(bookcase.move_duration + 0.1).timeout

	var reach := 8.0
	if kind == RoomPod.ConnectorKind.VENT or kind == RoomPod.ConnectorKind.CLOSET:
		reach = 5.5
	elif kind == RoomPod.ConnectorKind.SLIDE:
		reach = 9.0
	var target_z: float = start_pos.z - reach
	var stuck_count := 0
	var last_pos := body.global_position
	var result := "FAILED (timeout)"
	for i in range(500):
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		if not body.is_on_floor():
			body.velocity.y -= gravity * get_physics_process_delta_time()
		else:
			body.velocity.y = 0.0
		# Steer back toward x=0 (center of the doorway) while moving
		# forward - simulates a realistic (not perfectly straight) approach.
		var steer := clampf(-body.global_position.x, -1.5, 1.5)
		body.velocity.x = steer
		body.velocity.z = -2.5
		body.move_and_slide()
		await get_tree().physics_frame
		if body.global_position.distance_to(last_pos) < 0.001:
			stuck_count += 1
		else:
			stuck_count = 0
		last_pos = body.global_position
		if stuck_count > 40:
			result = "STUCK at frame %d, pos=%s" % [i, body.global_position]
			break
		if body.global_position.z <= target_z:
			result = "PASSED, reached pos=%s" % body.global_position
			break
	print("    %s" % result)
	room.queue_free()
	body.queue_free()
	await get_tree().process_frame


func _on_match_started() -> void:
	lobby.visible = false
	world.visible = true
