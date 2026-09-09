extends Node
## Isolated cheat flags. Gameplay may query these via /root/DebugCheats;
## it must never import debug UI. All flags no-op when DebugBuild is off.
##
## *** DEV ONLY — REMOVE OR KEEP GATED BEFORE FULL RELEASE ***

signal flags_changed

var invincible: bool = false
var infinite_jump: bool = false
## Server-only map of peer_id -> invincible. Clients RPC their toggle here
## because health is host-authoritative.
var _invincible_peers: Dictionary = {}


func _ready() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_signal("match_started"):
		gs.match_started.connect(_on_match_started)


func is_enabled() -> bool:
	var dbg: Node = get_node_or_null("/root/DebugBuild")
	return dbg != null and bool(dbg.get("enabled"))


func blocks_damage(peer_id: int) -> bool:
	if not is_enabled():
		return false
	if multiplayer and multiplayer.is_server():
		return bool(_invincible_peers.get(peer_id, false))
	return invincible


func infinite_jump_enabled() -> bool:
	return is_enabled() and infinite_jump


func set_invincible(on: bool) -> void:
	if not is_enabled():
		return
	invincible = on
	if multiplayer and multiplayer.is_server():
		_invincible_peers[multiplayer.get_unique_id()] = on
	elif multiplayer:
		_rpc_set_invincible.rpc_id(1, on)
	flags_changed.emit()


func set_infinite_jump(on: bool) -> void:
	if not is_enabled():
		return
	infinite_jump = on
	flags_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_invincible(on: bool) -> void:
	if not multiplayer.is_server() or not is_enabled():
		return
	_invincible_peers[multiplayer.get_remote_sender_id()] = on


func _on_match_started() -> void:
	if not is_enabled():
		return
	# Wait until Match has instantiated HorrorWorld on this same signal.
	call_deferred("_spawn_playtest_kit")


func _spawn_playtest_kit() -> void:
	if get_tree().get_first_node_in_group("horror_world") == null:
		await get_tree().process_frame
	DebugCommands.spawn_playtest_kit()
