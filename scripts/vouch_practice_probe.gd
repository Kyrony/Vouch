extends SceneTree
## Headless smoke: Practice mode builds the bay, dummy, and a player pawn.
## Run: godot4 --headless --path . -s res://scripts/vouch_practice_probe.gd

var _running: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _running:
		return
	_running = true
	await process_frame
	var err: String = await _probe()
	var net: Node = root.get_node_or_null("NetworkManager")
	if net and net.has_method("leave_game"):
		net.call("leave_game")
	if err.is_empty():
		print("PRACTICE PROBE OK")
		quit(0)
		return
	push_error("PRACTICE PROBE FAILED: %s" % err)
	quit(1)


func _probe() -> String:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var net: Node = root.get_node_or_null("NetworkManager")
	if net == null:
		main.queue_free()
		return "NetworkManager missing"
	var host_err: Error = net.call("host_game", 19841)
	if host_err != OK:
		main.queue_free()
		return "host_game failed err=%s" % host_err
	var gs: Node = root.get_node_or_null("GameState")
	if gs:
		gs.set("practice_mode", true)
		gs.set("practice_as_pm", false)
	net.call("start_match")
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	var match_node: Node = main.get_node_or_null("World/Match")
	if match_node == null:
		main.queue_free()
		return "Match missing"
	var arena := match_node.get_node_or_null("PracticeArena")
	if arena == null:
		net.call("leave_game")
		main.queue_free()
		return "PracticeArena missing after start"
	var dummy := arena.get_node_or_null("9001")
	if dummy == null:
		net.call("leave_game")
		main.queue_free()
		return "practice dummy missing"
	if not dummy.is_in_group("practice_dummy"):
		return "dummy not in practice_dummy group"
	if arena.get_node_or_null("PlayableProps") == null:
		net.call("leave_game")
		main.queue_free()
		return "practice PlayableProps missing"
	if arena.get_tree().get_nodes_in_group("fuse_boxes").is_empty():
		net.call("leave_game")
		main.queue_free()
		return "practice fuse box missing"
	if arena.get_tree().get_nodes_in_group("lockables").is_empty():
		net.call("leave_game")
		main.queue_free()
		return "practice locked gate missing"
	if arena.get_tree().get_nodes_in_group("dig_sites").is_empty():
		net.call("leave_game")
		main.queue_free()
		return "practice dig site missing"
	if arena.get_tree().get_nodes_in_group("rope_anchors").is_empty():
		net.call("leave_game")
		main.queue_free()
		return "practice rope anchor missing"
	var extras := 0
	for child in arena.get_children():
		if str(child.name).begins_with("PracticePickup_"):
			extras += 1
	if extras < 6:
		net.call("leave_game")
		main.queue_free()
		return "practice extra tool pickups missing (%d)" % extras
	var clock: Node = root.get_node_or_null("MatchClock")
	if clock and bool(clock.get("running")):
		net.call("leave_game")
		main.queue_free()
		return "practice should not run the morning clock"
	if not arena.has_method("spawn_pickup"):
		net.call("leave_game")
		main.queue_free()
		return "practice arena cannot spawn dug pickups"
	var players := match_node.get_node("PlayersContainer").get_children()
	var found_player := false
	for child in players:
		if str(child.name) == "1":
			found_player = true
	if not found_player:
		net.call("leave_game")
		main.queue_free()
		return "practice player pawn missing"
	var health: Node = root.get_node_or_null("PlayerHealth")
	if health and health.has_method("server_apply_drain"):
		health.call("server_apply_drain", 9001, 15.0)
		var hp: float = float(health.call("server_get_health", 9001))
		if hp > 86.0:
			net.call("leave_game")
			main.queue_free()
			return "dummy did not take damage (hp=%s)" % hp
	net.call("leave_game")
	main.queue_free()
	return ""
