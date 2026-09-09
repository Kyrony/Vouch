extends Node
## PuppetControlSystem
##
## The Puppet Master's other signature tool: a physical Puppet. Once the PM
## finds/holds the puppet they can "wear" it and walk the map as the puppet.
## If the puppet reaches a survivor it grabs them and takes control — the
## victim is locked out of their body (spectating the PM) until either another
## survivor frees them or they win an escape-the-mind struggle minigame.
##
## Host-authoritative. player.gd reads possession state to lock movement and
## swap to a spectator view; the puppet body + grab animation are visual layers.

signal local_possessed_changed(possessed: bool, struggle: float, needed: float)
signal local_puppet_state_changed(active: bool)

# ── TUNABLES — puppet control ──
const GRAB_RANGE: float = 2.0  # puppet reach to snatch a survivor (m)
const ESCAPE_STRUGGLE_NEEDED: float = 12.0  # struggle points to self-escape
const STRUGGLE_PER_INPUT: float = 1.0  # struggle gained per mash input

## pm_peer -> bool (is the PM currently wearing the puppet)
var _pm_has_puppet: Dictionary = {}
## victim_peer -> { "pm": int, "struggle": float }
var _possessed: Dictionary = {}


func reset() -> void:
	_pm_has_puppet.clear()
	_possessed.clear()


## PM dons the puppet (found it / used the item). Returns true once active.
func server_take_puppet(pm_peer: int) -> bool:
	if not multiplayer.is_server():
		return false
	_pm_has_puppet[pm_peer] = true
	if pm_peer == multiplayer.get_unique_id():
		local_puppet_state_changed.emit(true)
	else:
		_client_puppet_state.rpc_id(pm_peer, true)
	return true


func server_drop_puppet(pm_peer: int) -> void:
	if not multiplayer.is_server():
		return
	_pm_has_puppet[pm_peer] = false
	if pm_peer == multiplayer.get_unique_id():
		local_puppet_state_changed.emit(false)
	else:
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
	_possessed[victim_peer] = {"pm": pm_peer, "struggle": 0.0}
	_broadcast_possess(victim_peer)
	return true


func server_is_possessed(victim_peer: int) -> bool:
	return _possessed.has(victim_peer)


func server_possessor(victim_peer: int) -> int:
	return int(_possessed.get(victim_peer, {}).get("pm", -1))


## Another survivor frees the possessed player outright.
func server_free(victim_peer: int) -> bool:
	if not multiplayer.is_server() or not _possessed.has(victim_peer):
		return false
	_possessed.erase(victim_peer)
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
		_possessed.erase(victim_peer)
		_broadcast_possess(victim_peer)
		return true
	_broadcast_possess(victim_peer)
	return false


func server_struggle_value(victim_peer: int) -> float:
	return float(_possessed.get(victim_peer, {}).get("struggle", 0.0))


func _broadcast_possess(victim_peer: int) -> void:
	var possessed := server_is_possessed(victim_peer)
	var struggle := server_struggle_value(victim_peer)
	if victim_peer == multiplayer.get_unique_id():
		local_possessed_changed.emit(possessed, struggle, ESCAPE_STRUGGLE_NEEDED)
	else:
		_client_possessed.rpc_id(victim_peer, possessed, struggle, ESCAPE_STRUGGLE_NEEDED)


@rpc("authority", "call_remote", "reliable")
func _client_possessed(possessed: bool, struggle: float, needed: float) -> void:
	local_possessed_changed.emit(possessed, struggle, needed)


@rpc("authority", "call_remote", "reliable")
func _client_puppet_state(active: bool) -> void:
	local_puppet_state_changed.emit(active)


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
