extends Node
## PhoneSystem
##
## Bunker phones are unknown/random lines: a caller cannot pick who they're
## calling. MVP only implements the text-first flow (dial -> send a short
## text -> server randomly routes it to some other living, non-escaped
## player). Voice and player-chosen targeting are explicitly out of scope
## for MVP (see docs/MVP_GDD.md).
##
## TODO(post-MVP): voice lines, line "busy"/cooldown state, escaped players
## going silent, PA/window/note comms reusing this same routing core.

signal text_received(from_label: String, message: String)
signal text_sent_confirmation()

## peer_id -> Phone node. Server-only registry.
var _phones: Dictionary = {}


func reset() -> void:
	_phones.clear()


func server_register_phone(peer_id: int, phone_node: Node) -> void:
	if not multiplayer.is_server():
		return
	_phones[peer_id] = phone_node


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
		if GameState.players.has(peer_id) and GameState.players[peer_id]["escaped"]:
			continue
		candidates.append(peer_id)

	# Truncate hard so a griefer can't spam huge payloads across the wire.
	var clipped_message: String = message.substr(0, 140)

	if candidates.is_empty():
		_notify_sent(sender_peer)
		return

	var recipient: int = candidates[randi() % candidates.size()]
	# The recipient never learns who called - just that "an unknown line"
	# rang through.
	_notify_text_received(recipient, "Unknown Line", clipped_message)
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
