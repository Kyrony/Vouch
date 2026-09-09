extends Node
## PlayerHealth — host-authoritative health / energy for horror mode.
##
## Survivors start at 100 HP. Puppet Master life-steal drains HP server-side;
## at 0 the server marks the player eliminated via PuppetMasterSystem.

signal health_changed(peer_id: int, health: float, max_health: float)
signal local_health_changed(health: float, max_health: float)

# ── TUNABLES — tweak these to balance gameplay ──
const DEFAULT_MAX: float = 100.0  # survivor starting HP
const DRAIN_RATE: float = 18.0  # PM life-steal HP/sec
# Reserved for a future PM self-heal tuning (currently heal uses an inline fraction).
const PM_HEAL_RATE: float = 12.0

var _health: Dictionary = {}
var _max_health: Dictionary = {}


func reset() -> void:
	_health.clear()
	_max_health.clear()


func server_init_peer(peer_id: int, max_hp: float = DEFAULT_MAX) -> void:
	if not multiplayer.is_server():
		return
	_max_health[peer_id] = max_hp
	_health[peer_id] = max_hp
	_broadcast_health(peer_id)


func server_get_health(peer_id: int) -> float:
	return float(_health.get(peer_id, DEFAULT_MAX))


func server_is_alive(peer_id: int) -> bool:
	return server_get_health(peer_id) > 0.0 and not GameState.server_is_eliminated(peer_id)


func server_apply_drain(victim_peer: int, amount: float, healer_peer: int = -1) -> void:
	if not multiplayer.is_server():
		return
	if not _health.has(victim_peer):
		return
	if GameState.server_is_eliminated(victim_peer):
		return
	var cheats := get_node_or_null("/root/DebugCheats")
	if cheats and cheats.has_method("blocks_damage") and bool(cheats.call("blocks_damage", victim_peer)):
		return
	if amount < 0.0:
		server_heal(victim_peer, -amount)
		return
	_health[victim_peer] = maxf(0.0, _health[victim_peer] - amount)
	if healer_peer > 0 and _health.has(healer_peer):
		var cap: float = float(_max_health.get(healer_peer, DEFAULT_MAX))
		_health[healer_peer] = minf(cap, _health[healer_peer] + amount * 0.35)
		_broadcast_health(healer_peer)
	_broadcast_health(victim_peer)
	if _health[victim_peer] <= 0.0:
		_server_eliminate(victim_peer)


func server_heal(peer_id: int, amount: float) -> void:
	if not multiplayer.is_server():
		return
	if not _health.has(peer_id):
		server_init_peer(peer_id)
	var cap: float = float(_max_health.get(peer_id, DEFAULT_MAX))
	_health[peer_id] = minf(cap, _health[peer_id] + amount)
	_broadcast_health(peer_id)


func server_tick_drain(victim_peer: int, pm_peer: int, delta: float) -> void:
	server_apply_drain(victim_peer, DRAIN_RATE * delta, pm_peer)


func _server_eliminate(peer_id: int) -> void:
	if GameState.server_is_eliminated(peer_id):
		return
	GameState.server_mark_eliminated(peer_id)
	GameState.player_eliminated.emit(peer_id)
	PuppetMasterSystem._notify_eliminated(peer_id)
	PuppetMasterSystem._client_show_eliminated_visual.rpc(peer_id)
	PuppetMasterSystem._check_for_pm_win()


func _broadcast_health(peer_id: int) -> void:
	var hp: float = float(_health.get(peer_id, DEFAULT_MAX))
	var cap: float = float(_max_health.get(peer_id, DEFAULT_MAX))
	health_changed.emit(peer_id, hp, cap)
	if peer_id == multiplayer.get_unique_id():
		local_health_changed.emit(hp, cap)
	elif GameState.is_network_peer(peer_id):
		_client_health.rpc_id(peer_id, hp, cap)


@rpc("authority", "call_remote", "reliable")
func _client_health(hp: float, cap: float) -> void:
	local_health_changed.emit(hp, cap)


func request_life_steal_tick(victim_peer: int) -> void:
	if multiplayer.is_server():
		server_tick_drain(victim_peer, GameState.puppet_master_peer_id, get_physics_process_delta_time())
	else:
		_rpc_life_steal_tick.rpc_id(1, victim_peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_life_steal_tick(victim_peer: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != GameState.puppet_master_peer_id:
		return
	server_tick_drain(victim_peer, sender, 1.0 / 60.0)
