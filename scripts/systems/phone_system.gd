extends Node
## PhoneSystem
##
## Bunker phones are unknown/random lines: a caller cannot pick who they're
## calling. MVP only implements the text-first flow (dial -> send a short
## text -> server randomly routes it to some other living, non-escaped,
## non-eliminated player). Voice and player-chosen targeting are
## explicitly out of scope for MVP (see docs/MVP_GDD.md).
##
## Every peer is given an opaque, per-match "line_id" (e.g. "Line 07") -
## NOT their peer_id - and incoming texts are tagged with the SENDER's
## line_id instead of a generic "Unknown Line" literal. This still tells
## the recipient nothing about who's calling, but it lets them tell
## multiple different anonymous callers apart across a match, which is
## what makes ContactBook's local rename-a-line feature meaningful
## ("I think Line 07 is Sam, Line 12 is someone else").
##
## TODO(post-MVP): voice lines, line "busy"/cooldown state, PA/window/note
## comms reusing this same routing core.

signal text_received(from_label: String, message: String)
signal text_sent_confirmation()

## peer_id -> Phone node. Server-only registry.
var _phones: Dictionary = {}
## peer_id -> line_id (e.g. "Line 07"). Server-only, assigned once per
## match; deliberately NOT derived from peer_id so it can't be reversed.
var _line_ids: Dictionary = {}


func reset() -> void:
	_phones.clear()
	_line_ids.clear()


func server_register_phone(peer_id: int, phone_node: Node) -> void:
	if not multiplayer.is_server():
		return
	_phones[peer_id] = phone_node


## Called once by the Match director at match start, after every peer is
## known. Order doesn't matter - it's just a shuffled label, not tied to
## faction/room assignment in any way.
func server_assign_line_ids(peer_ids: Array) -> void:
	if not multiplayer.is_server():
		return
	var shuffled: Array = peer_ids.duplicate()
	shuffled.shuffle()
	for i in range(shuffled.size()):
		_line_ids[shuffled[i]] = "Line %02d" % (i + 1)


func server_get_line_id(peer_id: int) -> String:
	return _line_ids.get(peer_id, "Unknown Line")


## Client entry point.
@rpc("any_peer", "call_remote", "reliable")
func request_send_text(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_peer := multiplayer.get_remote_sender_id()
	server_handle_send_text(sender_peer, message)


## Shared server-side logic; also called directly for the host's own phone.
func server_handle_send_text(sender_peer: int, message: String) -> void:
	if not multiplayer.is_server():
		return

	var candidates: Array = []
	for peer_id in _phones.keys():
		if peer_id == sender_peer:
			continue
		if GameState.players.has(peer_id) and (GameState.players[peer_id]["escaped"] or GameState.players[peer_id]["eliminated"]):
			continue
		var phone_node = _phones[peer_id]
		if is_instance_valid(phone_node) and phone_node.is_destroyed:
			continue
		candidates.append(peer_id)

	# Truncate hard so a griefer can't spam huge payloads across the wire.
	var clipped_message: String = message.substr(0, 140)

	if candidates.is_empty():
		_notify_sent(sender_peer)
		return

	var recipient: int = candidates[randi() % candidates.size()]
	# The recipient never learns the sender's identity - just their
	# per-match anonymous line tag.
	var sender_line_id := server_get_line_id(sender_peer)
	_notify_text_received(recipient, sender_line_id, clipped_message)
	_notify_sent(sender_peer)


func _notify_sent(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_text_sent_confirmation()
	else:
		_client_text_sent_confirmation.rpc_id(peer_id)


func _notify_text_received(peer_id: int, from_label: String, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_text_received(from_label, message)
	else:
		_client_text_received.rpc_id(peer_id, from_label, message)


@rpc("authority", "call_remote", "reliable")
func _client_text_received(from_label: String, message: String) -> void:
	print("[PhoneSystem] incoming text from %s: %s" % [from_label, message])
	text_received.emit(from_label, message)


@rpc("authority", "call_remote", "reliable")
func _client_text_sent_confirmation() -> void:
	print("[PhoneSystem] text sent into the unknown...")
	text_sent_confirmation.emit()
