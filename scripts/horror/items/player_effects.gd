extends Node
## PlayerEffects — data-driven timed modifier stacks on horror players.
##
## Tracks fear / health / stamina meters and active timed effects that tick down.
## Life-steal aura is applied externally by PuppetMasterController using radius falloff.

signal meters_changed(peer_id: int, health: float, stamina: float, fear: float)
signal local_meters_changed(health: float, stamina: float, fear: float)

const DEFAULT_MAX: float = 100.0
const STAMINA_REGEN: float = 6.0
const FEAR_DECAY: float = 3.0

var _health: Dictionary = {}
var _stamina: Dictionary = {}
var _fear: Dictionary = {}
var _max: Dictionary = {}
var _active_effects: Dictionary = {}  # peer_id -> Array of {id, time_left, cooldown_left}


func reset() -> void:
	_health.clear()
	_stamina.clear()
	_fear.clear()
	_max.clear()
	_active_effects.clear()


func server_init_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_max[peer_id] = Vector3(DEFAULT_MAX, DEFAULT_MAX, DEFAULT_MAX)
	_health[peer_id] = DEFAULT_MAX
	_stamina[peer_id] = DEFAULT_MAX
	_fear[peer_id] = 0.0
	_active_effects[peer_id] = []
	_broadcast_meters(peer_id)


func server_get_meters(peer_id: int) -> Vector3:
	return Vector3(
		PlayerHealth.server_get_health(peer_id) if multiplayer.is_server() else float(_health.get(peer_id, DEFAULT_MAX)),
		float(_stamina.get(peer_id, DEFAULT_MAX)),
		float(_fear.get(peer_id, 0.0)),
	)


func server_apply_effect(peer_id: int, effect_id: String) -> bool:
	if not multiplayer.is_server():
		return false
	var def: Dictionary = EffectDefinitions.get_def(effect_id)
	if def.is_empty():
		return false
	if not _active_effects.has(peer_id):
		server_init_peer(peer_id)
	if def.get("instant", false):
		_apply_meter_delta(peer_id, int(def.get("meter", 0)), -float(def.get("apply_rate", 0.0)))
		_broadcast_meters(peer_id)
		return true
	var effects: Array = _active_effects[peer_id]
	for e in effects:
		if e["id"] == effect_id and float(e.get("cooldown_left", 0.0)) > 0.0:
			return false
	effects.append({
		"id": effect_id,
		"time_left": float(def.get("duration", 1.0)),
		"cooldown_left": 0.0,
	})
	_active_effects[peer_id] = effects
	return true


func server_has_effect(peer_id: int, effect_id: String) -> bool:
	if not _active_effects.has(peer_id):
		return false
	for e in _active_effects[peer_id]:
		if e["id"] == effect_id and float(e["time_left"]) > 0.0:
			return true
	return false


func server_effect_cooldown_ready(peer_id: int, effect_id: String) -> bool:
	if not _active_effects.has(peer_id):
		return true
	for e in _active_effects[peer_id]:
		if e["id"] == effect_id and float(e.get("cooldown_left", 0.0)) > 0.0:
			return false
	return true


func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for peer_id in _health.keys():
		_stamina[peer_id] = minf(float(_max[peer_id].y), float(_stamina.get(peer_id, DEFAULT_MAX)) + STAMINA_REGEN * delta)
		_fear[peer_id] = maxf(0.0, float(_fear.get(peer_id, 0.0)) - FEAR_DECAY * delta)
		_tick_effects(peer_id, delta)
		_broadcast_meters(peer_id)


func server_apply_life_steal(victim_peer: int, pm_peer: int, dist: float, max_range: float, delta: float) -> void:
	if not multiplayer.is_server():
		return
	var def: Dictionary = EffectDefinitions.get_def("life_steal_aura")
	var t := clampf(1.0 - (dist / maxf(max_range, 0.1)), 0.0, 1.0)
	var rate: float = lerpf(float(def.get("min_drain_per_sec", 4.0)), float(def.get("max_drain_per_sec", 22.0)), t)
	PlayerHealth.server_apply_drain(victim_peer, rate * delta, pm_peer)
	_apply_meter_delta(victim_peer, EffectDefinitions.Meter.FEAR, rate * 0.15 * delta)
	if pm_peer > 0:
		_apply_meter_delta(pm_peer, EffectDefinitions.Meter.STAMINA, -rate * 0.08 * delta)


func _tick_effects(peer_id: int, delta: float) -> void:
	if not _active_effects.has(peer_id):
		return
	var effects: Array = _active_effects[peer_id]
	var remaining: Array = []
	for e in effects:
		var def: Dictionary = EffectDefinitions.get_def(e["id"])
		var time_left: float = float(e["time_left"])
		var cd_left: float = float(e.get("cooldown_left", 0.0))
		if cd_left > 0.0:
			cd_left -= delta
			if cd_left > 0.0:
				remaining.append({"id": e["id"], "time_left": 0.0, "cooldown_left": cd_left})
			continue
		if time_left > 0.0:
			time_left -= delta
			var rate: float = float(def.get("apply_rate", 0.0))
			if rate != 0.0:
				_apply_meter_delta(peer_id, int(def.get("meter", 0)), rate * delta)
			if time_left > 0.0:
				remaining.append({"id": e["id"], "time_left": time_left, "cooldown_left": 0.0})
			else:
				var cd: float = float(def.get("cooldown", 0.0))
				if cd > 0.0:
					remaining.append({"id": e["id"], "time_left": 0.0, "cooldown_left": cd})
	_active_effects[peer_id] = remaining


func _apply_meter_delta(peer_id: int, meter: int, delta: float) -> void:
	var caps: Vector3 = _max.get(peer_id, Vector3(DEFAULT_MAX, DEFAULT_MAX, DEFAULT_MAX))
	var cap: float = float(caps[meter])
	match meter:
		EffectDefinitions.Meter.HEALTH:
			pass  # health owned by PlayerHealth for elimination sync
		EffectDefinitions.Meter.STAMINA:
			_stamina[peer_id] = clampf(float(_stamina.get(peer_id, DEFAULT_MAX)) - delta, 0.0, cap)
		EffectDefinitions.Meter.FEAR:
			_fear[peer_id] = clampf(float(_fear.get(peer_id, 0.0)) + delta, 0.0, cap)


func _broadcast_meters(peer_id: int) -> void:
	var m := server_get_meters(peer_id)
	meters_changed.emit(peer_id, m.x, m.y, m.z)
	if peer_id == multiplayer.get_unique_id():
		local_meters_changed.emit(m.x, m.y, m.z)
	else:
		_client_meters.rpc_id(peer_id, m.x, m.y, m.z)


@rpc("authority", "call_remote", "reliable")
func _client_meters(hp: float, stamina: float, fear: float) -> void:
	local_meters_changed.emit(hp, stamina, fear)
