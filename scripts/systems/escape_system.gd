extends Node
## EscapeSystem
##
## Handles a player reaching the bunker door and stepping "Outside", plus
## the faction win-check: the first faction with ALL of its members
## escaped wins immediately. No post-escape sabotage in MVP - once you're
## Outside you're just roaming a shared courtyard with other escapees.
##
## TODO(post-MVP): escape animations/transitions, partial-escape stats for
## losers, and any Outside-only interactions.

signal escaped_locally
signal match_won(faction_id: String)
signal escape_locked(feedback: String)

## Rooms flooded at or above this level (see BrokenPipe.gd) have their
## escape physically blocked - the water's too high to reach the door.
const FLOOD_BLOCK_LEVEL: float = 0.75

## Server-only: peer_id -> Player node, used to validate a player is still
## actually present before we bother teleporting them.
var _player_nodes: Dictionary = {}
## Server-only: the Outside scene director, used to fetch roam spawn points.
var _outside_director: Outside = null


func reset() -> void:
	_player_nodes.clear()
	_outside_director = null


func server_register_player_node(peer_id: int, node: Node) -> void:
	if not multiplayer.is_server():
		return
	_player_nodes[peer_id] = node


func server_register_outside(director: Outside) -> void:
	if not multiplayer.is_server():
		return
	_outside_director = director


## Client entry point - called when a player interacts with their room's
## door.
@rpc("any_peer", "call_remote", "reliable")
func request_escape() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	server_handle_escape_request(peer_id)


## Shared server-side logic; also called directly by the host's own door.
func server_handle_escape_request(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if GameState.phase != GameState.Phase.IN_MATCH:
		return
	if not GameState.players.has(peer_id):
		return
	if GameState.players[peer_id]["escaped"] or GameState.players[peer_id]["eliminated"]:
		return
	if not is_instance_valid(_player_nodes.get(peer_id)):
		push_warning("EscapeSystem: no live player node for peer %d" % peer_id)
		return

	var room_index: int = GameState.players[peer_id]["room_id"]
	if PuzzleSystem.server_requires_code(room_index) and not PuzzleSystem.server_is_unlocked(room_index):
		_notify_escape_locked(peer_id)
		return
	if GameState.room_water_levels.get(room_index, 0.0) >= FLOOD_BLOCK_LEVEL:
		_notify_escape_locked_message(peer_id, "The water's too high - you can't reach it.")
		return

	GameState.server_mark_escaped(peer_id)

	var spawn_transform := Transform3D.IDENTITY
	if is_instance_valid(_outside_director):
		spawn_transform = _outside_director.get_roam_spawn_transform()

	_teleport_player(peer_id, spawn_transform.origin, spawn_transform.basis.get_euler().y)

	var faction_id: String = GameState.server_get_faction(peer_id)
	GameState.player_escaped.emit(peer_id, faction_id)

	_check_for_win()


func _notify_escape_locked(peer_id: int) -> void:
	_notify_escape_locked_message(peer_id, "It's locked. Find the code.")


func _notify_escape_locked_message(peer_id: int, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_escape_locked(message)
	else:
		_client_escape_locked.rpc_id(peer_id, message)


@rpc("authority", "call_remote", "reliable")
func _client_escape_locked(message: String) -> void:
	print("[EscapeSystem] %s" % message)
	escape_locked.emit(message)


func _teleport_player(peer_id: int, spawn_position: Vector3, spawn_rotation_y: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_apply_escape(spawn_position, spawn_rotation_y)
	else:
		_client_apply_escape.rpc_id(peer_id, spawn_position, spawn_rotation_y)


func _check_for_win() -> void:
	var winning_faction_id := GameState.server_check_for_win()
	if winning_faction_id.is_empty():
		return
	GameState.winning_faction_id = winning_faction_id
	GameState.phase = GameState.Phase.MATCH_OVER
	# Unlike faction assignment, the WINNER is public information for
	# everyone once the match ends.
	_client_faction_won.rpc(winning_faction_id)


@rpc("authority", "call_remote", "reliable")
func _client_apply_escape(spawn_position: Vector3, spawn_rotation_y: float) -> void:
	var player: Node3D = GameState.local_player_node
	if is_instance_valid(player):
		player.global_position = spawn_position
		player.rotation.y = spawn_rotation_y
	print("[EscapeSystem] you escaped! Welcome Outside.")
	escaped_locally.emit()


@rpc("authority", "call_local", "reliable")
func _client_faction_won(faction_id: String) -> void:
	var faction_name: String = FactionData.get_faction_name(faction_id)
	print("[EscapeSystem] MATCH OVER - %s escaped completely and WON." % faction_name)
	match_won.emit(faction_id)
