extends RefCounted
class_name MatchHorror
## Host-authoritative horror neighborhood match (family spawns + child hunt).

const HORROR_WORLD_SCENE: String = "res://scenes/Horror/HorrorWorld.tscn"
const PM_AI_SCENE: String = "res://scenes/Horror/PMChaseAI.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/Player/Player.tscn"


static func server_build(match_node: Node) -> void:
	if not match_node.multiplayer.is_server():
		return
	var peer_ids: Array = GameState.players.keys()
	peer_ids.shuffle()
	print("HORROR match_start players=%d peer_ids=%s" % [peer_ids.size(), peer_ids])

	PlayerHealth.reset()
	PlayerInventory.reset()
	PlayerEffects.reset()
	ChildSpawnRNG.reset()
	TowerRules.reset()
	PhoneSystem.reset()
	EscapeSystem.reset()
	PuppetMasterSystem.reset()

	var pm_peer := _ensure_puppet_master(peer_ids)
	var survivors: Array = peer_ids.duplicate()
	survivors.erase(pm_peer)

	for peer_id in peer_ids:
		GameState.server_set_room(peer_id, 0)

	var world: Node = match_node.get_node_or_null("HorrorWorld")
	if world == null:
		push_error("MatchHorror: HorrorWorld missing")
		return

	if world.has_method("server_init_match"):
		world.call("server_init_match", peer_ids.size())

	var family_count: int = world.call("get_family_count") if world.has_method("get_family_count") else survivors.size()
	var survivor_idx := 0
	for peer_id in peer_ids:
		var is_pm: bool = peer_id == pm_peer
		var xform: Transform3D
		if is_pm:
			xform = world.call("get_pm_spawn_transform") if world.has_method("get_pm_spawn_transform") else Transform3D.IDENTITY
		else:
			var fam := survivor_idx % maxi(family_count, 1)
			survivor_idx += 1
			xform = world.call("get_family_spawn_transform", fam) if world.has_method("get_family_spawn_transform") else world.call("get_random_spawn_transform")
		_server_spawn_horror_player(match_node, peer_id, xform, is_pm, survivor_idx - 1 if not is_pm else -1)

	if pm_peer == -1:
		_spawn_pm_ai(match_node, world)

	PhoneSystem.server_assign_line_ids(peer_ids)
	for peer_id in peer_ids:
		PhoneSystem.server_register_phone(peer_id, match_node)
	_grant_pm_horror(pm_peer)
	match_node.call_deferred("_log_horror_match_ready", peer_ids.size(), world.call("get_spawn_point_count"))


static func _ensure_puppet_master(peer_ids: Array) -> int:
	var existing := GameState.puppet_master_peer_id
	if existing > 0:
		return existing
	if peer_ids.is_empty():
		return -1
	if peer_ids.size() >= 2:
		var chosen: int = peer_ids[randi() % peer_ids.size()]
		GameState.server_set_puppet_master(chosen)
		return chosen
	return -1


static func build_world_all_peers(match_node: Node) -> void:
	if match_node.get_node_or_null("HorrorWorld") != null:
		return
	_spawn_world(match_node)


static func _spawn_world(match_node: Node) -> void:
	var scene: PackedScene = load(HORROR_WORLD_SCENE)
	if scene == null:
		push_error("MatchHorror: failed to load %s" % HORROR_WORLD_SCENE)
		return
	var world: Node = scene.instantiate()
	world.name = "HorrorWorld"
	match_node.add_child(world)


static func _server_spawn_horror_player(match_node: Node, peer_id: int, xform: Transform3D, is_pm: bool, family_index: int) -> void:
	PlayerHealth.server_init_peer(peer_id)
	PlayerEffects.server_init_peer(peer_id)
	if not is_pm:
		PlayerInventory.server_init_peer(peer_id)

	var faction_id: String = "" if is_pm else GameState.server_get_faction(peer_id)
	var data := {
		"peer_id": peer_id,
		"faction_id": faction_id,
		"spawn_position": xform.origin + Vector3(0, 1.0, 0),
		"spawn_rotation_y": xform.basis.get_euler().y,
		"is_puppet_master": is_pm,
		"horror_mode": true,
		"family_index": family_index,
	}
	var player: Node = match_node.players_spawner.spawn(data)
	if player == null:
		push_error("MatchHorror: failed to spawn player %d" % peer_id)
		return
	if is_pm:
		attach_pm_controller(player)
	EscapeSystem.server_register_player_node(peer_id, player)


static func attach_pm_controller(player: Node) -> void:
	var ctrl := Node.new()
	ctrl.name = "PuppetMasterController"
	ctrl.set_script(load("res://scripts/horror/puppet_master_controller.gd"))
	player.add_child(ctrl)
	ctrl.call("setup", player)
	player.set("is_horror_puppet_master", true)


static func _spawn_pm_ai(match_node: Node, world: Node) -> void:
	var scene: PackedScene = load(PM_AI_SCENE)
	if scene == null:
		return
	var ai: Node = scene.instantiate()
	ai.name = "PMChaseAI"
	match_node.add_child(ai)
	var spawn: Vector3 = world.global_position + Vector3(0, 1.2, -48)
	if world.has_method("get_pm_spawn_transform"):
		spawn = world.call("get_pm_spawn_transform").origin + Vector3(0, 1.0, 0)
	if ai.has_method("server_activate"):
		ai.call("server_activate", spawn)


static func _grant_pm_horror(pm_peer: int) -> void:
	if pm_peer <= 0:
		return
	var all_rooms: Array = [0]
	PuppetMasterSystem.server_grant_targets(pm_peer, all_rooms, all_rooms)


static func teardown(match_node: Node) -> void:
	if not match_node.is_node_ready():
		return
	var hw := match_node.get_node_or_null("HorrorWorld")
	if hw:
		hw.queue_free()
	var ai := match_node.get_node_or_null("PMChaseAI")
	if ai:
		ai.queue_free()
