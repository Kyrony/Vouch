extends Node
## PuppetStringSystem
##
## The Puppet Master's signature weapon. The PM shoots strings into survivors;
## each string tethers the victim toward the PM and slows them. Enough strings
## immobilize the victim entirely. A string can be turned into a "ghost string"
## that stays attached to the victim even after the PM lets go. Strings can also
## be pinned to surfaces as traps: a survivor who walks into the trap radius gets
## a fresh string attached.
##
## Host-authoritative. Movement slow is read by player.gd; cutting is done by
## scissors / adrenaline (PlayerInventory) and by another survivor freeing them.
## Visual rope + wrapping physics are layered on top by string_tether_visual.gd;
## this node owns the gameplay state only.

signal local_tether_changed(strings: int, ghost: bool, immobilized: bool)

# ── TUNABLES — string tether feel ──
const SLOW_PER_STRING: float = 0.22  # speed lost per attached string (0..1)
const MAX_SLOW: float = 0.9  # never fully 0 — a crawl at most, unless immobilized
const IMMOBILIZE_STRINGS: int = 4  # this many strings = can't run, barely crawl
const IMMOBILIZE_SLOW: float = 0.92  # slow applied once immobilized
const TRAP_RADIUS_DEFAULT: float = 2.2  # surface-trap catch radius (m)

## victim_peer -> { "count": int, "ghost": bool, "pm": int }
var _tethers: Dictionary = {}
## Surface traps: [{ "pos": Vector3, "radius": float, "pm": int, "armed": bool }]
var _traps: Array = []


func reset() -> void:
	_tethers.clear()
	_traps.clear()


func _entry(peer: int) -> Dictionary:
	if not _tethers.has(peer):
		_tethers[peer] = {"count": 0, "ghost": false, "pm": -1}
	return _tethers[peer]


## PM shoots one string into a survivor (non-ghost). Stacks — call again to add
## more. Returns the new string count.
func server_shoot_string(pm_peer: int, victim_peer: int) -> int:
	if not multiplayer.is_server():
		return 0
	var e := _entry(victim_peer)
	e["count"] = int(e["count"]) + 1
	e["pm"] = pm_peer
	_broadcast(victim_peer)
	return int(e["count"])


## Convert the victim's strings into ghost strings — they persist on the victim
## even if the PM releases the tether.
func server_make_ghost(pm_peer: int, victim_peer: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not _tethers.has(victim_peer) or int(_tethers[victim_peer]["count"]) <= 0:
		return false
	_tethers[victim_peer]["ghost"] = true
	_tethers[victim_peer]["pm"] = pm_peer
	_broadcast(victim_peer)
	return true


## Release non-ghost strings (PM lets go / dies). Ghost strings stay.
func server_release(pm_peer: int, victim_peer: int) -> void:
	if not multiplayer.is_server() or not _tethers.has(victim_peer):
		return
	if bool(_tethers[victim_peer]["ghost"]):
		return
	_tethers[victim_peer] = {"count": 0, "ghost": false, "pm": -1}
	_broadcast(victim_peer)


## Pin a string to a surface as a trap.
func server_place_trap(pm_peer: int, pos: Vector3, radius: float = TRAP_RADIUS_DEFAULT) -> void:
	if not multiplayer.is_server():
		return
	_traps.append({"pos": pos, "radius": radius, "pm": pm_peer, "armed": true})


## Call as a survivor moves; if they enter an armed trap, a string snaps onto
## them. Returns true if a trap fired.
func server_check_traps(victim_peer: int, pos: Vector3) -> bool:
	if not multiplayer.is_server():
		return false
	for trap in _traps:
		if not bool(trap.get("armed", false)):
			continue
		if pos.distance_to(trap["pos"]) <= float(trap["radius"]):
			trap["armed"] = false  # one catch per trap
			server_shoot_string(int(trap["pm"]), victim_peer)
			return true
	return false


## Scissors / another survivor cuts strings. amount < 0 cuts them all.
func server_cut(victim_peer: int, amount: int = -1) -> bool:
	if not multiplayer.is_server() or not _tethers.has(victim_peer):
		return false
	var e: Dictionary = _tethers[victim_peer]
	if int(e["count"]) <= 0:
		return false
	if amount < 0:
		e["count"] = 0
		e["ghost"] = false
		e["pm"] = -1
	else:
		e["count"] = maxi(0, int(e["count"]) - amount)
		if int(e["count"]) == 0:
			e["ghost"] = false
			e["pm"] = -1
	_broadcast(victim_peer)
	return true


func server_string_count(peer: int) -> int:
	return int(_tethers.get(peer, {}).get("count", 0))


func server_is_ghosted(peer: int) -> bool:
	return bool(_tethers.get(peer, {}).get("ghost", false))


func server_tether_pm(peer: int) -> int:
	return int(_tethers.get(peer, {}).get("pm", -1))


func server_is_immobilized(peer: int) -> bool:
	return server_string_count(peer) >= IMMOBILIZE_STRINGS


## Movement slow fraction (0 = free, up to IMMOBILIZE_SLOW when pinned).
func server_tether_slow(peer: int) -> float:
	var n := server_string_count(peer)
	if n <= 0:
		return 0.0
	if n >= IMMOBILIZE_STRINGS:
		return IMMOBILIZE_SLOW
	return minf(float(n) * SLOW_PER_STRING, MAX_SLOW)


func _broadcast(victim_peer: int) -> void:
	var count := server_string_count(victim_peer)
	var ghost := server_is_ghosted(victim_peer)
	var immobile := server_is_immobilized(victim_peer)
	if victim_peer == multiplayer.get_unique_id():
		local_tether_changed.emit(count, ghost, immobile)
	else:
		_client_tether.rpc_id(victim_peer, count, ghost, immobile)


@rpc("authority", "call_remote", "reliable")
func _client_tether(count: int, ghost: bool, immobile: bool) -> void:
	local_tether_changed.emit(count, ghost, immobile)


@rpc("any_peer", "call_remote", "unreliable")
func request_check_traps(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	server_check_traps(multiplayer.get_remote_sender_id(), pos)


@rpc("any_peer", "call_remote", "reliable")
func request_shoot(victim_peer: int) -> void:
	if not multiplayer.is_server():
		return
	var pm := multiplayer.get_remote_sender_id()
	if pm == GameState.puppet_master_peer_id:
		server_shoot_string(pm, victim_peer)


@rpc("any_peer", "call_remote", "reliable")
func request_ghost(victim_peer: int) -> void:
	if not multiplayer.is_server():
		return
	server_make_ghost(multiplayer.get_remote_sender_id(), victim_peer)


@rpc("any_peer", "call_remote", "reliable")
func request_trap(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	server_place_trap(multiplayer.get_remote_sender_id(), pos)
