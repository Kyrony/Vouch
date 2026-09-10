extends Node
## PuppetControlSystem
##
## The Puppet Master's other signature tool: a physical Puppet. Once the PM
## finds/holds the puppet they become the puppet (small, fast, double-jump).
## In range of a survivor they press fire to capture them — the puppet takes
## over that body fully. The victim is trapped and can only spectate until
## a teammate frees them or they win the escape-the-mind struggle.

signal local_possessed_changed(possessed: bool, struggle: float, needed: float)
signal local_puppet_state_changed(active: bool)
signal local_body_control_changed(victim_peer: int, active: bool)

# ── TUNABLES — puppet control ──
const GRAB_RANGE: float = 2.0  # puppet reach to snatch a survivor (m)
const ESCAPE_STRUGGLE_NEEDED: float = 12.0  # struggle points to self-escape
const STRUGGLE_PER_INPUT: float = 1.0  # struggle gained per mash input

## pm_peer -> bool (is the PM currently wearing the puppet)
var _pm_has_puppet: Dictionary = {}
## victim_peer -> { "pm": int, "struggle": float }
var _possessed: Dictionary = {}
## pm_peer -> victim_peer currently being driven
var _controlling: Dictionary = {}


func reset() -> void:
	_pm_has_puppet.clear()
	_possessed.clear()
	_controlling.clear()


## PM dons the puppet (found it / used the item). Returns true once active.
func server_take_puppet(pm_peer: int) -> bool:
	if not multiplayer.is_server():
		return false
	_pm_has_puppet[pm_peer] = true
	PlayerEffects.server_set_stamina_max(pm_peer, 20.0)
	if pm_peer == multiplayer.get_unique_id():
		local_puppet_state_changed.emit(true)
	elif GameState.is_network_peer(pm_peer):
		_client_puppet_state.rpc_id(pm_peer, true)
	return true


func server_drop_puppet(pm_peer: int) -> void:
	if not multiplayer.is_server():
		return
	var victim := int(_controlling.get(pm_peer, 0))
	if victim > 0:
		server_free(victim)
	_pm_has_puppet[pm_peer] = false
	PlayerEffects.server_set_stamina_max(pm_peer, PlayerEffects.DEFAULT_MAX)
	if pm_peer == multiplayer.get_unique_id():
		local_puppet_state_changed.emit(false)
	elif GameState.is_network_peer(pm_peer):
		_client_puppet_state.rpc_id(pm_peer, false)


func server_has_puppet(pm_peer: int) -> bool:
	return bool(_pm_has_puppet.get(pm_peer, false))


## Puppet tries to grab a survivor at `dist`. Possesses them if in range and
## the PM is wearing the puppet. Returns true on a successful grab.
func server_puppet_grab(pm_peer: int, victim_peer: int, dist: float) -> bool:
	if not multiplayer.is_server():
		return false
	if not server_has_puppet(pm_peer):
		return false
	if server_is_possessed(victim_peer) or dist > GRAB_RANGE:
		return false
	if int(_controlling.get(pm_peer, 0)) > 0:
		return false
	_possessed[victim_peer] = {"pm": pm_peer, "struggle": 0.0}
	_controlling[pm_peer] = victim_peer
	_sync_body_authority(victim_peer, pm_peer)
	_broadcast_possess(victim_peer)
	_broadcast_control(pm_peer, victim_peer, true)
	return true


func server_is_possessed(victim_peer: int) -> bool:
	return _possessed.has(victim_peer)


func server_possessor(victim_peer: int) -> int:
	return int(_possessed.get(victim_peer, {}).get("pm", -1))


## Another survivor frees the possessed player outright.
func server_free(victim_peer: int) -> bool:
	if not multiplayer.is_server() or not _possessed.has(victim_peer):
		return false
	var pm := server_possessor(victim_peer)
	_possessed.erase(victim_peer)
	if pm > 0:
		_controlling.erase(pm)
		_sync_body_authority(victim_peer, victim_peer)
		_broadcast_control(pm, victim_peer, false)
	_broadcast_possess(victim_peer)
	return true


## Escape-the-mind minigame: the victim mashes; each input adds struggle.
## Returns true once they break free.
func server_struggle(victim_peer: int, amount: float = STRUGGLE_PER_INPUT) -> bool:
	if not multiplayer.is_server() or not _possessed.has(victim_peer):
		return false
	var e: Dictionary = _possessed[victim_peer]
	e["struggle"] = float(e["struggle"]) + amount
	if float(e["struggle"]) >= ESCAPE_STRUGGLE_NEEDED:
		return server_free(victim_peer)
	_broadcast_possess(victim_peer)
	return false


func server_struggle_value(victim_peer: int) -> float:
	return float(_possessed.get(victim_peer, {}).get("struggle", 0.0))


func _broadcast_possess(victim_peer: int) -> void:
	var possessed := server_is_possessed(victim_peer)
	var struggle := server_struggle_value(victim_peer)
	if victim_peer == multiplayer.get_unique_id():
		local_possessed_changed.emit(possessed, struggle, ESCAPE_STRUGGLE_NEEDED)
	elif GameState.is_network_peer(victim_peer):
		_client_possessed.rpc_id(victim_peer, possessed, struggle, ESCAPE_STRUGGLE_NEEDED)


func _broadcast_control(pm_peer: int, victim_peer: int, active: bool) -> void:
	if pm_peer <= 0:
		return
	if pm_peer == multiplayer.get_unique_id():
		local_body_control_changed.emit(victim_peer, active)
	elif GameState.is_network_peer(pm_peer):
		_client_body_control.rpc_id(pm_peer, victim_peer, active)


func _sync_body_authority(victim_peer: int, auth: int) -> void:
	_apply_body_authority(victim_peer, auth)
	if not multiplayer.get_peers().is_empty():
		_rpc_body_authority.rpc(victim_peer, auth)


func _apply_body_authority(victim_peer: int, auth: int) -> void:
	var node := _player_node(victim_peer)
	if node:
		node.set_multiplayer_authority(auth)


func _player_node(peer_id: int) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("players"):
		if str(node.name).to_int() == peer_id:
			return node
	return null


@rpc("authority", "call_remote", "reliable")
func _client_possessed(possessed: bool, struggle: float, needed: float) -> void:
	local_possessed_changed.emit(possessed, struggle, needed)


@rpc("authority", "call_remote", "reliable")
func _client_puppet_state(active: bool) -> void:
	local_puppet_state_changed.emit(active)


@rpc("authority", "call_remote", "reliable")
func _client_body_control(victim_peer: int, active: bool) -> void:
	local_body_control_changed.emit(victim_peer, active)


@rpc("authority", "call_remote", "reliable")
func _rpc_body_authority(victim_peer: int, auth: int) -> void:
	_apply_body_authority(victim_peer, auth)


@rpc("any_peer", "call_remote", "reliable")
func request_struggle() -> void:
	if not multiplayer.is_server():
		return
	server_struggle(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func request_grab(victim_peer: int, dist: float) -> void:
	if not multiplayer.is_server():
		return
	server_puppet_grab(multiplayer.get_remote_sender_id(), victim_peer, dist)
