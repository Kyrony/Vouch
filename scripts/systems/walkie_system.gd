extends Node
## WalkieSystem — host-authoritative paired faction comms (text channel MVP).

signal message_received(from_label: String, message: String)
signal message_sent_confirmation()

var _pairs: Dictionary = {}
var _walkies: Dictionary = {}


func reset() -> void:
	_pairs.clear()
	_walkies.clear()


func server_register_walkie(peer_id: int, walkie_node: Node) -> void:
	if not multiplayer.is_server():
		return
	_walkies[peer_id] = walkie_node


func server_pair_players(peer_ids: Array) -> void:
	if not multiplayer.is_server():
		return
	_pairs.clear()
	var by_faction: Dictionary = {}
	for pid in peer_ids:
		if not GameState.players.has(pid):
			continue
		if GameState.players[pid].get("is_puppet_master", false):
			continue
		var fid: String = GameState.server_get_faction(pid)
		if not by_faction.has(fid):
			by_faction[fid] = []
		by_faction[fid].append(pid)

	for fid in by_faction.keys():
		var members: Array = by_faction[fid]
		members.shuffle()
		var i := 0
		while i + 1 < members.size():
			var a: int = members[i]
			var b: int = members[i + 1]
			_pairs[a] = b
			_pairs[b] = a
			i += 2


func server_get_partner(peer_id: int) -> int:
	return int(_pairs.get(peer_id, -1))


func server_get_partner_label(peer_id: int) -> String:
	var partner := server_get_partner(peer_id)
	if partner < 0:
		return "No partner"
	return PhoneSystem.server_get_line_id(partner)


@rpc("any_peer", "call_remote", "reliable")
func request_send_text(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	server_handle_send_text(sender, message)


func server_handle_send_text(sender_peer: int, message: String) -> void:
	if not multiplayer.is_server():
		return
	var partner := server_get_partner(sender_peer)
	if partner < 0:
		_notify_sent(sender_peer)
		return

	var sender_room: int = GameState.players.get(sender_peer, {}).get("room_id", -1)
	if sender_room >= 0 and not RoomUtilities.is_enabled(sender_room, RoomUtilities.UTILITY_COMMS):
		_notify_sent(sender_peer)
		return

	var clipped: String = message.substr(0, 140)
	var label := PhoneSystem.server_get_line_id(sender_peer)
	_notify_received(partner, label, clipped)
	_notify_sent(sender_peer)


func _notify_sent(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_sent_confirmation()
	else:
		_client_sent_confirmation.rpc_id(peer_id)


func _notify_received(peer_id: int, from_label: String, message: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_received(from_label, message)
	else:
		_client_received.rpc_id(peer_id, from_label, message)


@rpc("authority", "call_remote", "reliable")
func _client_received(from_label: String, message: String) -> void:
	message_received.emit(from_label, message)


@rpc("authority", "call_remote", "reliable")
func _client_sent_confirmation() -> void:
	message_sent_confirmation.emit()
