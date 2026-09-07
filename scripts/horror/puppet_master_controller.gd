extends Node
class_name PuppetMasterController
## Puppet Master horror abilities: body swap, float, life steal.
## Attached to Player nodes flagged as PM.

const BODY_SWAP_RANGE: float = 6.0
const BODY_SWAP_DURATION: float = 4.0
const FLOAT_LIFT: float = 5.5
const LIFE_STEAL_RANGE: float = 2.8

var _player: CharacterBody3D
var _swap_active: bool = false
var _swap_timer: float = 0.0
var _swap_target_peer: int = -1
var _original_peer: int = -1
var _floating: bool = false
var _steal_target: Node = null
var _steal_bar: ProgressBar


func setup(player: CharacterBody3D) -> void:
	_player = player
	set_process(false)
	set_physics_process(false)
	if _player.is_multiplayer_authority():
		set_process(true)
		set_physics_process(true)
		_build_steal_bar()


func _build_steal_bar() -> void:
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


func _process(delta: float) -> void:
	if not _player.is_multiplayer_authority():
		return
	if _swap_active:
		_swap_timer -= delta
		if _swap_timer <= 0.0:
			_end_body_swap()


func _physics_process(_delta: float) -> void:
	if not _player.is_multiplayer_authority():
		return
	_update_life_steal()


func process_movement(delta: float, locked: bool) -> void:
	if not _player.is_multiplayer_authority() or locked:
		return
	if Input.is_action_just_pressed("body_swap") and not _swap_active:
		_try_body_swap()
	_floating = Input.is_action_pressed("jump") and not _player.is_on_floor()
	if _floating:
		_player.velocity.y += FLOAT_LIFT * delta


func _try_body_swap() -> void:
	var nearest: Node = _nearest_survivor(BODY_SWAP_RANGE)
	if nearest == null:
		return
	var target_peer := int(str(nearest.name))
	if target_peer <= 0:
		return
	_original_peer = multiplayer.get_unique_id()
	_swap_target_peer = target_peer
	_swap_active = true
	_swap_timer = BODY_SWAP_DURATION
	if multiplayer.is_server():
		_server_begin_swap(_original_peer, _swap_target_peer)
	else:
		_rpc_begin_swap.rpc_id(1, _original_peer, _swap_target_peer)


func _end_body_swap() -> void:
	if not _swap_active:
		return
	_swap_active = false
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


func _update_life_steal() -> void:
	_steal_target = _nearest_survivor(LIFE_STEAL_RANGE)
	if _steal_target == null or not Input.is_action_pressed("interact"):
		_steal_bar.visible = false
		return
	_steal_bar.visible = true
	var victim_peer := int(str(_steal_target.name))
	var hp := PlayerHealth.server_get_health(victim_peer) if multiplayer.is_server() else 100.0
	_steal_bar.value = hp
	if multiplayer.is_server():
		PlayerHealth.server_tick_drain(victim_peer, multiplayer.get_unique_id(), get_physics_process_delta_time())
	else:
		PlayerHealth._rpc_life_steal_tick.rpc_id(1, victim_peer)


func _nearest_survivor(max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("players"):
		if node == _player:
			continue
		var peer := int(str(node.name))
		if peer <= 0:
			continue
		if GameState.players.get(peer, {}).get("is_puppet_master", false):
			continue
		if GameState.server_is_eliminated(peer) if multiplayer.is_server() else false:
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
