extends Node
class_name PuppetMasterController
## Puppet Master: possession of dead family stubs, float, radius life-steal aura.

const _PM: GDScript = preload("res://scripts/horror/characters/puppet_master_data.gd")

var _player: CharacterBody3D
var _swap_active: bool = false
var _swap_timer: float = 0.0
var _swap_target_peer: int = -1
var _possession_target: Node3D = null
var _original_peer: int = -1
var _floating: bool = false
var _steal_active: bool = false
var _steal_bar: ProgressBar
var _cooldown_bar: ProgressBar


func setup(player: CharacterBody3D) -> void:
	_player = player
	set_process(false)
	set_physics_process(false)
	if _player.is_multiplayer_authority():
		set_process(true)
		set_physics_process(true)
		_build_steal_bars()


func _build_steal_bars() -> void:
	var hud: CanvasLayer = _player.get_node("HUD")
	_steal_bar = ProgressBar.new()
	_steal_bar.name = "LifeStealBar"
	_steal_bar.visible = false
	_steal_bar.custom_minimum_size = Vector2(180, 14)
	_steal_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_steal_bar.offset_top = 80
	_steal_bar.offset_left = -90
	_steal_bar.offset_right = 90
	_steal_bar.show_percentage = false
	hud.add_child(_steal_bar)

	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.name = "LifeStealCooldown"
	_cooldown_bar.visible = false
	_cooldown_bar.custom_minimum_size = Vector2(180, 8)
	_cooldown_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cooldown_bar.offset_top = 98
	_cooldown_bar.offset_left = -90
	_cooldown_bar.offset_right = 90
	_cooldown_bar.modulate = Color(0.7, 0.35, 0.35)
	_cooldown_bar.show_percentage = false
	hud.add_child(_cooldown_bar)


func _process(delta: float) -> void:
	if not _player.is_multiplayer_authority():
		return
	if _swap_active:
		_swap_timer -= delta
		if _swap_timer <= 0.0:
			_end_body_swap()
	_update_steal_ui()


func _physics_process(delta: float) -> void:
	if not _player.is_multiplayer_authority():
		return
	_update_life_steal_aura(delta)


func process_movement(delta: float, locked: bool) -> void:
	if not _player.is_multiplayer_authority() or locked:
		return
	if Input.is_action_just_pressed("body_swap") and not _swap_active:
		if not _try_possess_dead_body():
			_try_body_swap()
	if Input.is_action_just_pressed("interact"):
		_try_activate_life_steal()
	_floating = Input.is_action_pressed("jump") and not _player.is_on_floor()
	if _floating:
		_player.velocity.y += _PM.FLOAT_LIFT * delta


func _try_activate_life_steal() -> void:
	var peer := multiplayer.get_unique_id()
	if not PlayerEffects.server_effect_cooldown_ready(peer, _PM.LIFE_STEAL_EFFECT):
		return
	if multiplayer.is_server():
		PlayerEffects.server_apply_effect(peer, _PM.LIFE_STEAL_EFFECT)
	else:
		_rpc_activate_steal.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_activate_steal() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != GameState.puppet_master_peer_id:
		return
	PlayerEffects.server_apply_effect(GameState.puppet_master_peer_id, _PM.LIFE_STEAL_EFFECT)


func _try_possess_dead_body() -> bool:
	var target := _nearest_in_group("possession_targets", _PM.POSSESSION_RANGE)
	if target == null:
		return false
	_possession_target = target
	_swap_active = true
	_swap_timer = _PM.POSSESSION_DURATION
	_player.global_position = target.global_position + Vector3(0, 0.5, 0)
	return true


func _try_body_swap() -> void:
	var nearest: Node = _nearest_survivor(_PM.BODY_SWAP_RANGE)
	if nearest == null:
		return
	var target_peer := int(str(nearest.name))
	if target_peer <= 0:
		return
	_original_peer = multiplayer.get_unique_id()
	_swap_target_peer = target_peer
	_swap_active = true
	_swap_timer = _PM.BODY_SWAP_DURATION
	if multiplayer.is_server():
		_server_begin_swap(_original_peer, _swap_target_peer)
	else:
		_rpc_begin_swap.rpc_id(1, _original_peer, _swap_target_peer)


func _end_body_swap() -> void:
	if not _swap_active:
		return
	_swap_active = false
	_possession_target = null
	if _swap_target_peer > 0:
		if multiplayer.is_server():
			_server_end_swap(_original_peer, _swap_target_peer)
		else:
			_rpc_end_swap.rpc_id(1, _original_peer, _swap_target_peer)
	_swap_target_peer = -1


@rpc("any_peer", "call_remote", "reliable")
func _rpc_begin_swap(pm_peer: int, victim_peer: int) -> void:
	if not multiplayer.is_server():
		return
	_server_begin_swap(pm_peer, victim_peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_end_swap(pm_peer: int, victim_peer: int) -> void:
	if not multiplayer.is_server():
		return
	_server_end_swap(pm_peer, victim_peer)


func _server_begin_swap(pm_peer: int, victim_peer: int) -> void:
	_client_apply_swap.rpc(pm_peer, victim_peer, true)


func _server_end_swap(pm_peer: int, victim_peer: int) -> void:
	_client_apply_swap.rpc(pm_peer, victim_peer, false)


@rpc("authority", "call_local", "reliable")
func _client_apply_swap(pm_peer: int, victim_peer: int, active: bool) -> void:
	var local := multiplayer.get_unique_id()
	if active:
		if local == pm_peer:
			_hijack_player(victim_peer)
		elif local == victim_peer:
			_freeze_local(true)
	else:
		if local == pm_peer:
			_restore_pm_camera()
		elif local == victim_peer:
			_freeze_local(false)


func _hijack_player(target_peer: int) -> void:
	var target := _find_player(target_peer)
	if target == null:
		return
	_player.get_node("Head/Camera3D").current = false
	target.get_node("Head/Camera3D").current = true
	GameState.local_player_node = target


func _restore_pm_camera() -> void:
	_player.get_node("Head/Camera3D").current = true
	GameState.local_player_node = _player


func _freeze_local(frozen: bool) -> void:
	_player.set_physics_process(not frozen)
	if frozen:
		_player.velocity = Vector3.ZERO


func _update_life_steal_aura(delta: float) -> void:
	var pm_peer := multiplayer.get_unique_id()
	if not PlayerEffects.server_has_effect(pm_peer, _PM.LIFE_STEAL_EFFECT):
		_steal_active = false
		return
	_steal_active = true
	var max_range := _PM.LIFE_STEAL_MAX_RANGE
	var origin := _player.global_position
	for node in get_tree().get_nodes_in_group("players"):
		if node == _player:
			continue
		var victim_peer := int(str(node.name))
		if victim_peer <= 0:
			continue
		if GameState.players.get(victim_peer, {}).get("is_puppet_master", false):
			continue
		if multiplayer.is_server() and GameState.server_is_eliminated(victim_peer):
			continue
		var dist: float = origin.distance_to(node.global_position)
		if dist > max_range:
			continue
		if multiplayer.is_server():
			PlayerEffects.server_apply_life_steal(victim_peer, pm_peer, dist, max_range, delta)
		else:
			_rpc_life_steal_tick.rpc_id(1, victim_peer, dist)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_life_steal_tick(victim_peer: int, dist: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != GameState.puppet_master_peer_id:
		return
	if not PlayerEffects.server_has_effect(sender, _PM.LIFE_STEAL_EFFECT):
		return
	PlayerEffects.server_apply_life_steal(victim_peer, sender, dist, _PM.LIFE_STEAL_MAX_RANGE, 1.0 / 30.0)


func _update_steal_ui() -> void:
	var peer := multiplayer.get_unique_id()
	var active := PlayerEffects.server_has_effect(peer, _PM.LIFE_STEAL_EFFECT)
	_steal_bar.visible = active
	if active:
		var nearest := _nearest_survivor(_PM.LIFE_STEAL_MAX_RANGE)
		if nearest != null:
			var hp := PlayerHealth.server_get_health(int(str(nearest.name))) if multiplayer.is_server() else 100.0
			_steal_bar.value = hp
	# Cooldown indicator stub — show when effect on cooldown
	_cooldown_bar.visible = not active and not PlayerEffects.server_effect_cooldown_ready(peer, _PM.LIFE_STEAL_EFFECT)


func _nearest_survivor(max_dist: float) -> Node:
	return _nearest_in_group("players", max_dist, true)


func _nearest_in_group(group: String, max_dist: float, skip_pm: bool = false) -> Node:
	var best: Node = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group(group):
		if skip_pm and node.is_in_group("players"):
			if GameState.players.get(int(str(node.name)), {}).get("is_puppet_master", false):
				continue
		if node == _player:
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _find_player(peer_id: int) -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node
	return null
