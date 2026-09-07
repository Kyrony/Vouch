extends SceneTree
## Headless probe: Player.gd must compile and Match._spawn_player must attach the script.
## Run cold (no .godot cache): rm -rf .godot && godot4 --headless --path . -s res://scripts/vouch_player_spawn_probe.gd


func _initialize() -> void:
	var err := _probe()
	if err.is_empty():
		print("PLAYER SPAWN PROBE OK")
		quit(0)
	else:
		push_error("PLAYER SPAWN PROBE FAILED: %s" % err)
		quit(1)


func _probe() -> String:
	var player_script: Script = load("res://scripts/player.gd") as Script
	if player_script == null:
		return "player.gd did not compile (parse-time class_name deps?) — run: godot4 --headless --path . --import"

	var scene: PackedScene = load("res://scenes/Player/Player.tscn") as PackedScene
	if scene == null:
		return "Player.tscn failed to load"
	var preview: Node = scene.instantiate()
	if preview.get_script() == null:
		preview.free()
		return "Player.tscn root has no script attached"
	if not preview.has_method("enter_ladder"):
		preview.free()
		return "Player node missing enter_ladder() — script did not attach correctly"
	preview.free()

	var match_node := Node3D.new()
	match_node.set_script(load("res://scripts/match.gd"))
	var data := {
		"peer_id": 1,
		"faction_id": "probe_faction",
		"spawn_position": Vector3.ZERO,
		"spawn_rotation_y": 0.0,
	}
	var player: Node = match_node.call("_spawn_player", data)
	if player == null:
		match_node.free()
		return "Match._spawn_player returned null"
	if player.get_script() == null:
		player.free()
		match_node.free()
		return "spawned player has no script (bare CharacterBody3D — player.gd parse failure?)"
	if str(player.get("faction_id")) != "probe_faction":
		player.free()
		match_node.free()
		return "spawned player missing faction_id (expected probe_faction, got %s)" % str(player.get("faction_id"))
	player.free()
	match_node.free()
	return ""
