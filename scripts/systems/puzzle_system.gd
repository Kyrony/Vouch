extends Node
## PuzzleSystem
##
## Code-lock puzzles. A room's escape point can be code-locked; the code
## itself is never sent to that room's keypad - it's discoverable as a
## readable clue (book or flame-lit paper) placed in a DIFFERENT player's
## room, mirroring LinkGraph's "the answer lives somewhere else" theming.
## Only the server ever holds the map of room -> correct code; clients
## only see the clue's text (which is meant to be found) and get a
## success/fail response when they submit a guess.
##
## MVP wires this up to gate ESCAPE only ("enter a code to unlock the
## escape"). The same `server_register_lock`/`request_attempt_unlock` core
## could gate a camera or other "feature" too - see the TODO below.
##
## TODO(post-MVP): reuse this to gate Puppet Master camera access or other
## non-escape features; multiple codes per room; code hints that expire.

signal unlock_result(room_index: int, success: bool)

## room_index -> { "code": String, "unlocked": bool }. Server-only.
var _locks: Dictionary = {}


func reset() -> void:
	_locks.clear()


func server_register_lock(room_index: int, code: String) -> void:
	if not multiplayer.is_server():
		return
	_locks[room_index] = {"code": code, "unlocked": false}


func server_requires_code(room_index: int) -> bool:
	return _locks.has(room_index)


func server_is_unlocked(room_index: int) -> bool:
	if not _locks.has(room_index):
		return true
	return _locks[room_index]["unlocked"]


## Client entry point - submits a guessed code for a specific room's lock.
@rpc("any_peer", "call_remote", "reliable")
func request_attempt_unlock(room_index: int, code_guess: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_peer := multiplayer.get_remote_sender_id()
	server_handle_attempt(sender_peer, room_index, code_guess)


## Shared server-side logic; also called directly by the host's own keypad.
func server_handle_attempt(peer_id: int, room_index: int, code_guess: String) -> void:
	if not multiplayer.is_server():
		return
	if not _locks.has(room_index):
		return

	var success: bool = (_locks[room_index]["code"] == code_guess.strip_edges())
	if success:
		_locks[room_index]["unlocked"] = true

	if peer_id == multiplayer.get_unique_id():
		_client_unlock_result(room_index, success)
	else:
		_client_unlock_result.rpc_id(peer_id, room_index, success)


@rpc("authority", "call_remote", "reliable")
func _client_unlock_result(room_index: int, success: bool) -> void:
	print("[PuzzleSystem] code attempt for room %d: %s" % [room_index, "UNLOCKED" if success else "wrong code"])
	unlock_result.emit(room_index, success)
