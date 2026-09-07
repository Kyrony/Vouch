extends SceneTree
## Headless smoke: horror Match starts without crash.
## Run: godot4 --headless --path . -s res://scripts/vouch_horror_match_probe.gd

const _HORROR: GDScript = preload("res://scripts/horror/match_horror.gd")
const _HORROR_SETTINGS: GDScript = preload("res://scripts/autoload/horror_mode_settings.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var err: String = await _probe()
	if err.is_empty():
		print("HORROR MATCH PROBE OK")
		quit(0)
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

	_HORROR.call("build_world_all_peers", match_node)
	await process_frame
	await physics_frame

	var world := match_node.get_node_or_null("HorrorWorld")
	if world == null:
		main.queue_free()
		return "HorrorWorld missing after build_world_all_peers"

	var spawn_count: int = world.call("get_spawn_point_count")
	if spawn_count < 4:
		main.queue_free()
		return "expected >= 4 bunker spawn points, got %d" % spawn_count

	var pickups := world.get_node_or_null("Pickups")
	if pickups == null or pickups.get_child_count() < 1:
		main.queue_free()
		return "no world pickups spawned"

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
	player.position = Vector3(0, -16, 0)
	match_node.get_node("PlayersContainer").add_child(player)
	await physics_frame

	if world.get_node_or_null("Bunker") == null:
		main.queue_free()
		return "Bunker geometry missing"
	if world.get_node_or_null("SurfaceHouse") == null:
		main.queue_free()
		return "SurfaceHouse missing"
	if world.get_node_or_null("Field") == null:
		main.queue_free()
		return "Field missing"

	print("  horror spawns=%d pickups=%d bunker=OK house=OK field=OK" % [
		spawn_count, pickups.get_child_count(),
	])
	main.queue_free()
	return ""
