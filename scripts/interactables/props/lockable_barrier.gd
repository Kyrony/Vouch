extends "res://scripts/interactables/interactable.gd"
class_name LockableBarrier
## Shared behaviour for locked gates, garages, hatches (and doors). A barrier
## can be locked and/or power-gated. It opens on interact when unlocked, and
## can be forced by a crowbar or opened with a key/lockpick.
##
## Host-authoritative. Subclasses only tweak labels/appearance via `kind`.

# ── TUNABLES — barrier behaviour ──
@export var kind: String = "gate"  # gate / garage / hatch / door (labels only)
@export var locked: bool = true  # starts locked
@export var needs_power: bool = false  # motorised (garage) won't open unpowered
@export var room_index: int = -1  # which room's power gates it (-1 = always powered)

var is_open: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("barriers")
	add_to_group("lockables")
	prompt_text = _default_prompt()


func _default_prompt() -> String:
	if locked:
		return "Locked %s" % kind
	return "Open %s" % kind


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		server_try_open(by_peer_id)
	else:
		_rpc_try_open.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_try_open() -> void:
	if multiplayer.is_server():
		server_try_open(multiplayer.get_remote_sender_id())


func _powered() -> bool:
	if not needs_power or room_index < 0:
		return true
	return RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_POWER)


## Normal interact: opens/closes only if unlocked (and powered when motorised).
func server_try_open(_by_peer_id: int) -> bool:
	if not multiplayer.is_server() or locked:
		return false
	if not _powered():
		return false
	is_open = not is_open
	_client_set_open.rpc(is_open)
	return true


## Force the lock (crowbar). Unlocks and swings it open.
func server_force_open(_by_peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	locked = false
	if not _powered():
		# Forced but the motor's dead — it's unlocked, just won't swing yet.
		_client_set_locked.rpc(false)
		return true
	is_open = true
	_client_set_locked.rpc(false)
	_client_set_open.rpc(true)
	return true


## Key / lockpick: quietly unlock without forcing it open.
func server_unlock(_by_peer_id: int) -> bool:
	if not multiplayer.is_server() or not locked:
		return false
	locked = false
	_client_set_locked.rpc(false)
	return true


func server_is_open() -> bool:
	return is_open


func server_is_locked() -> bool:
	return locked


@rpc("authority", "call_local", "reliable")
func _client_set_open(open: bool) -> void:
	is_open = open
	_apply_open_visual(open)


@rpc("authority", "call_local", "reliable")
func _client_set_locked(is_locked: bool) -> void:
	locked = is_locked
	prompt_text = _default_prompt()


func _apply_open_visual(open: bool) -> void:
	# Slide/rotate the first child pivot if present; otherwise just toggle
	# collisions so the passage clears. Real animations come later.
	var pivot := get_node_or_null("Pivot") as Node3D
	if pivot:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		match kind:
			"garage", "hatch":
				tween.tween_property(pivot, "position:y", (1.9 if open else 0.0), 0.5)
			_:
				tween.tween_property(pivot, "rotation:y", (-1.4 if open else 0.0), 0.5)
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = open
