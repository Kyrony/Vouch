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
		return "expected >= 4 graybox family spawns, got %d" % spawn_count
	if world.get_node_or_null("Outdoor/Terrain") == null:
		main.queue_free()
		return "Outdoor/Terrain missing"
	if world.get_node_or_null("Outdoor/Hills") == null:
		main.queue_free()
		return "Outdoor/Hills missing"
	var exits: Array = world.get_tree().get_nodes_in_group("walkable_exits")
	if exits.size() < 6:
		main.queue_free()
		return "expected walkable door exits, got %d" % exits.size()
	var fam0 = world.call("get_family_spawn_transform", 0)
	if fam0.origin.y < -0.35:
		main.queue_free()
		return "family 0 spawn is underground y=%s" % fam0.origin
	var pm_xf = world.call("get_pm_spawn_transform")
	if pm_xf.origin.y < -0.35:
		main.queue_free()
		return "PM spawn is underground y=%s" % pm_xf.origin

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
	player.set("is_horror_puppet_master", true)
	player.set("faction_id", "probe")
	player.position = world.call("get_family_spawn_transform", 0).origin + Vector3(0, 1, 0)
	player.set_multiplayer_authority(1)
	match_node.get_node("PlayersContainer").add_child(player)
	horror_script.call("attach_pm_controller", player)
	horror_script.call("attach_pm_controller", player)
	await physics_frame
	if player.get_node_or_null("PuppetMasterController") == null:
		player.free()
		main.queue_free()
		return "PuppetMasterController missing after attach"
	if player.get_node_or_null("HUD/LifeStealBar") == null or player.get_node_or_null("HUD/LifeStealCooldown") == null:
		player.free()
		main.queue_free()
		return "life-steal ProgressBars missing"
	var steal_err: String = _CHECK.call("validate_life_steal")
	if not steal_err.is_empty():
		player.free()
		main.queue_free()
		return steal_err
	var phone_err: String = _CHECK.call("validate_phone_hud", world)
	if not phone_err.is_empty():
		player.free()
		main.queue_free()
		return phone_err
	var pm_count := 0
	for child in player.get_children():
		if str(child.name).begins_with("PuppetMasterController"):
			pm_count += 1
	if pm_count != 1:
		player.free()
		main.queue_free()
		return "expected 1 PuppetMasterController, got %d" % pm_count

	var rng := root.get_node_or_null("ChildSpawnRNG")
	var pins: Array = rng.call("spawn_id_list") if rng else []
	print("  horror graybox_spawns=%d pickups=%d child_points=%d towers=%d fam0=%s pm=%s pins=%s" % [
		spawn_count, pickups.get_child_count(), child_points.size(),
		world.get_tree().get_nodes_in_group("active_towers").size(),
		fam0.origin,
		pm_xf.origin,
		pins,
	])
	main.queue_free()
	return ""
