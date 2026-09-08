extends Node
## PuppetMasterSystem
##
## A fifth, independent role with no escape. The PM WINS by eliminating
## every other player before any faction fully escapes; otherwise the first
## faction to escape wins. Whichever happens first flips GameState.phase to
## MATCH_OVER once. PM state (camera+sabotage set, eliminable rooms) is sent
## only to the PM.

signal you_are_puppet_master(camera_targets: Array, eliminable_targets: Array)
signal sabotage_result(room_index: int, success: bool)
signal you_were_eliminated

# ── TUNABLES — tweak these to balance gameplay ──
## The Puppet Master can only ever be in play with at least this many
## players - below that, a solo "hunt everyone" role doesn't make sense.
const MIN_PLAYERS_FOR_PUPPET_MASTER: int = 4
## Even when eligible, the Puppet Master doesn't spawn every match - only
## this fraction of otherwise-eligible matches get one.
const SPAWN_CHANCE: float = 0.5

## Server-only: pm_peer_id -> Array[int] of granted camera+sabotage room
## indices (the "few" rooms, per the design brief).
var _granted_targets: Dictionary = {}
## Server-only: pm_peer_id -> Array[int] of every other (non-PM) room
## index - the full elimination pool.
var _eliminable_targets: Dictionary = {}
## Server-only: msec deadline until which the PM's abilities are locked out
## (set by a survivor's crowbar strike).
var _stun_until_ms: int = 0


func reset() -> void:
	_granted_targets.clear()
	_eliminable_targets.clear()
	_stun_until_ms = 0


## Lock the Puppet Master's abilities for `seconds` (crowbar counter-play).
func server_stun(seconds: float) -> void:
	if not multiplayer.is_server():
		return
	_stun_until_ms = maxi(_stun_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))


func server_is_pm_stunned() -> bool:
	return Time.get_ticks_msec() < _stun_until_ms


## Picks one of `peer_ids` to be the Puppet Master, subject to the spawn
## rules above (needs >= MIN_PLAYERS_FOR_PUPPET_MASTER, and even then only
## SPAWN_CHANCE of matches get one at all). Returns the chosen peer id, or
## -1 if no Puppet Master was assigned this match (a perfectly normal,
## expected outcome - most systems already treat -1 as "no PM in play").
func server_assign_puppet_master(peer_ids: Array) -> int:
	if not multiplayer.is_server():
		return -1
	if peer_ids.size() < MIN_PLAYERS_FOR_PUPPET_MASTER:
		return -1
	if randf() >= SPAWN_CHANCE:
		return -1

	var chosen: int = peer_ids[randi() % peer_ids.size()]
	GameState.server_set_puppet_master(chosen)
	return chosen


## Called by the Match director once every room has been built, so target
## room indices are valid. Both arrays should exclude the PM's own room;
## `camera_targets` should be a subset of `all_other_rooms`.
func server_grant_targets(pm_peer_id: int, camera_targets: Array, all_other_rooms: Array) -> void:
	if not multiplayer.is_server():
		return
	_granted_targets[pm_peer_id] = camera_targets.duplicate()
	_eliminable_targets[pm_peer_id] = all_other_rooms.duplicate()

	if pm_peer_id == multiplayer.get_unique_id():
		_client_you_are_puppet_master(camera_targets, all_other_rooms)
	else:
		_client_you_are_puppet_master.rpc_id(pm_peer_id, camera_targets, all_other_rooms)


func _has_camera_access(pm_peer_id: int, room_index: int) -> bool:
	if GameState.puppet_master_peer_id != pm_peer_id:
		return false
	if GameState.phase != GameState.Phase.IN_MATCH:
		return false
	var targets: Array = _granted_targets.get(pm_peer_id, [])
	return targets.has(room_index)


func _can_eliminate(pm_peer_id: int, room_index: int) -> bool:
	if GameState.puppet_master_peer_id != pm_peer_id:
		return false
	if GameState.phase != GameState.Phase.IN_MATCH:
		return false
	var targets: Array = _eliminable_targets.get(pm_peer_id, [])
	return targets.has(room_index)


## --- Sabotage (reuses LinkGraph's per-room effect nodes) - camera-scope ---

@rpc("any_peer", "call_remote", "reliable")
func request_sabotage(room_index: int) -> void:
	if not multiplayer.is_server():
		return
	server_handle_sabotage(multiplayer.get_remote_sender_id(), room_index)


func server_handle_sabotage(pm_peer_id: int, room_index: int) -> void:
	if not multiplayer.is_server():
		return
	if not _has_camera_access(pm_peer_id, room_index):
		_notify_sabotage_result(pm_peer_id, room_index, false)
		return

	var effect_node = LinkGraph.server_get_effect_node("room_%d_room_light" % room_index)
	var success := false
	if is_instance_valid(effect_node) and effect_node.has_method("server_apply_effect"):
		effect_node.server_apply_effect()
		success = true

		var target_peer := GameState.server_get_peer_by_room(room_index)
		if target_peer != -1:
			LinkGraph.notify_room_affected(target_peer, "room_%d_room_light" % room_index)

	_notify_sabotage_result(pm_peer_id, room_index, success)


func _notify_sabotage_result(peer_id: int, room_index: int, success: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_sabotage_result(room_index, success)
	else:
		_client_sabotage_result.rpc_id(peer_id, room_index, success)


## --- Elimination (host-authoritative stub kill switch) - full scope ---

@rpc("any_peer", "call_remote", "reliable")
func request_eliminate(room_index: int) -> void:
	if not multiplayer.is_server():
		return
	server_handle_eliminate(multiplayer.get_remote_sender_id(), room_index)


func server_handle_eliminate(pm_peer_id: int, room_index: int) -> void:
	if not multiplayer.is_server():
		return
	if not _can_eliminate(pm_peer_id, room_index):
		return

	var target_peer := GameState.server_get_peer_by_room(room_index)
	if target_peer == -1 or GameState.server_is_eliminated(target_peer):
		return

	GameState.server_mark_eliminated(target_peer)
	GameState.player_eliminated.emit(target_peer)

	_notify_eliminated(target_peer)
	# Public knowledge - a body is a body, everyone visiting that room can
	# see the model vanish. No mystery to preserve here.
	_client_show_eliminated_visual.rpc(target_peer)

	_check_for_pm_win()


func _notify_eliminated(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_you_were_eliminated()
	else:
		_client_you_were_eliminated.rpc_id(peer_id)


func _check_for_pm_win() -> void:
	if GameState.phase == GameState.Phase.MATCH_OVER:
		return
	if not GameState.server_all_others_eliminated():
		return
	GameState.puppet_master_won = true
	GameState.phase = GameState.Phase.MATCH_OVER
	_client_pm_won.rpc()


## --- Client-side RPC handlers ---


@rpc("authority", "call_remote", "reliable")
func _client_you_are_puppet_master(camera_targets: Array, eliminable_targets: Array) -> void:
	GameState.local_is_puppet_master = true
	print("[PuppetMasterSystem] You are the Puppet Master. Cameras: %s, eliminable: %s" % [camera_targets, eliminable_targets])
	you_are_puppet_master.emit(camera_targets, eliminable_targets)


@rpc("authority", "call_remote", "reliable")
func _client_sabotage_result(room_index: int, success: bool) -> void:
	sabotage_result.emit(room_index, success)


@rpc("authority", "call_remote", "reliable")
func _client_you_were_eliminated() -> void:
	print("[PuppetMasterSystem] You have been eliminated.")
	you_were_eliminated.emit()


@rpc("authority", "call_local", "reliable")
func _client_show_eliminated_visual(peer_id: int) -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if node.name == str(peer_id) and node.has_method("apply_eliminated_visual"):
			node.apply_eliminated_visual()
			break


@rpc("authority", "call_local", "reliable")
func _client_pm_won() -> void:
	print("[PuppetMasterSystem] MATCH OVER - the Puppet Master eliminated everyone and WON.")
