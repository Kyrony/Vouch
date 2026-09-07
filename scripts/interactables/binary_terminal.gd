extends "res://scripts/interactables/interactable.gd"
## BinaryTerminal
##
## Flip bits until the binary string equals the target decimal value.
## Host-authoritative; opens a modal UI on the interacting player.

var room_index: int = -1
var target_value: int = 0
var bit_count: int = 8
var bit_string: String = "00000000"
var solved: bool = false

var bookcase: Node = null
var peek_monitor: Node = null


func configure(p_room_index: int, p_target: int, p_bits: int = 8) -> void:
	room_index = p_room_index
	target_value = p_target
	bit_count = clampi(p_bits, 4, 12)
	bit_string = "0".repeat(bit_count)
	prompt_text = "Binary terminal"


func interact(by_peer_id: int) -> void:
	if solved:
		return
	if multiplayer.is_server():
		_client_open_panel.rpc_id(by_peer_id, target_value, bit_string, bit_count)
	else:
		_request_open.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_open() -> void:
	if multiplayer.is_server():
		_client_open_panel.rpc_id(multiplayer.get_remote_sender_id(), target_value, bit_string, bit_count)


@rpc("any_peer", "call_remote", "reliable")
func request_flip_bit(bit_index: int) -> void:
	if not multiplayer.is_server():
		return
	var result := server_flip_bit(bit_index)
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == multiplayer.get_unique_id():
		_client_flip_result(result)
	else:
		_client_flip_result.rpc_id(peer_id, result)
	if result.get("solved", false):
		pass


@rpc("authority", "call_remote", "reliable")
func _client_flip_result(result: Dictionary) -> void:
	var player := GameState.local_player_node
	if player and player.has_method("apply_binary_flip_result"):
		player.apply_binary_flip_result(result)


@rpc("authority", "call_remote", "reliable")
func _client_open_panel(_target: int, _bits: String, _count: int) -> void:
	var player := GameState.local_player_node
	if player and player.has_method("open_binary_terminal"):
		player.open_binary_terminal(self)


func server_flip_bit(bit_index: int) -> Dictionary:
	if not multiplayer.is_server() or solved or bit_index < 0 or bit_index >= bit_count:
		return {"ok": false, "error": "Invalid bit"}
	var chars := bit_string.to_utf8_buffer()
	chars[bit_index] = 48 if chars[bit_index] == 49 else 49
	bit_string = chars.get_string_from_utf8()
	var value := bit_string.bin_to_int()
	if value == target_value:
		solved = true
		_on_solved()
		return {"ok": true, "solved": true, "bits": bit_string}
	return {"ok": true, "solved": false, "bits": bit_string, "value": value}


func _on_solved() -> void:
	prompt_text = "Terminal unlocked"
	if is_instance_valid(bookcase) and bookcase.has_method("server_force_move"):
		bookcase.server_force_move(true)
	if is_instance_valid(peek_monitor) and peek_monitor.has_method("server_activate"):
		peek_monitor.server_activate()
	_client_solved.rpc()


@rpc("authority", "call_remote", "reliable")
func _client_solved() -> void:
	solved = true
	prompt_text = "Terminal unlocked"
