extends SceneTree
## Headless smoke: horror neighborhood Match starts without crash.
## Run: godot4 --headless --path . -s res://scripts/vouch_horror_match_probe.gd

const _HORROR_SETTINGS: GDScript = preload("res://scripts/autoload/horror_mode_settings.gd")

var _running: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _running:
		return
	_running = true
	await process_frame
	var err: String = await _probe()
	if err.is_empty():
		print("HORROR MATCH PROBE OK")
		quit(0)
		return
	push_error("HORROR MATCH PROBE FAILED: %s" % err)
	quit(1)


func _probe() -> String:
	if not _HORROR_SETTINGS.is_horror_mode():
		return "HorrorModeSettings.is_horror_mode() is false — unset VOUCH_BUNKER_ONLY / VOUCH_ESCAPE_PATH"

	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var match_node: Node = main.get_node("World/Match")
	if not match_node.is_node_ready():
		await match_node.ready

	var horror_script: GDScript = load("res://scripts/horror/match_horror.gd") as GDScript
	if horror_script == null:
		main.queue_free()
		return "match_horror.gd failed to load"
	horror_script.call("build_world_all_peers", match_node)
	await process_frame
	await physics_frame

	var world := match_node.get_node_or_null("HorrorWorld")
	if world == null:
		main.queue_free()
		return "HorrorWorld missing after build_world_all_peers"

	var spawn_count: int = world.call("get_spawn_point_count")
	if spawn_count < 4:
		main.queue_free()
		return "expected >= 4 family bedroom spawns, got %d" % spawn_count

	var pickups := world.get_node_or_null("Pickups")
	if pickups == null or pickups.get_child_count() < 1:
		main.queue_free()
		return "no world pickups spawned"

	for node_name in ["FamilyHouses", "PMMansion", "UncleHouse", "Outdoor"]:
		if world.get_node_or_null(node_name) == null:
			main.queue_free()
			return "neighborhood node missing: %s" % node_name

	var _CHECK: GDScript = load("res://scripts/horror/world/horror_soft_go_validate.gd")
	var pin_err: String = _CHECK.call("validate_world", world)
	if not pin_err.is_empty():
		main.queue_free()
		return pin_err
	var tower_err: String = _CHECK.call("validate_tower_roll", world)
	if not tower_err.is_empty():
		main.queue_free()
		return tower_err
	var child_points := world.get_tree().get_nodes_in_group("child_spawn_points")

	var player_scene: PackedScene = load("res://scenes/Player/Player.tscn")
	if player_scene == null:
		main.queue_free()
		return "Player.tscn failed to load"

	var player: Node = player_scene.instantiate()
	if player.get_script() == null:
		player.free()
		main.queue_free()
		return "Player script missing"

	player.set("horror_mode", true)
	player.set("faction_id", "probe")
	player.position = world.call("get_family_spawn_transform", 0).origin + Vector3(0, 1, 0)
	match_node.get_node("PlayersContainer").add_child(player)
	await physics_frame

	print("  horror spawns=%d pickups=%d child_points=%d towers=%d neighborhood=OK" % [
		spawn_count, pickups.get_child_count(), child_points.size(),
		world.get_tree().get_nodes_in_group("active_towers").size(),
	])
	main.queue_free()
	return ""
