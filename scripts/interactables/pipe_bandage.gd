extends "res://scripts/interactables/interactable.gd"
class_name PipeBandage
## Bandage roll — repairs broken pipe / seals gas leak in this room.

@export var room_index: int = -1


func interact(by_peer_id: int) -> void:
	if is_destroyed:
		return
	if multiplayer.is_server():
		_apply_repair()
	else:
		_rpc_repair.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_repair() -> void:
	if not multiplayer.is_server():
		return
	_apply_repair()


func _apply_repair() -> void:
	var room := get_parent()
	if room == null:
		return
	var pipe := room.get_node_or_null("BrokenPipe")
	if pipe and pipe.has_method("server_repair"):
		pipe.server_repair()
	var gas := room.get_node_or_null("GasLeak")
	if gas and gas.has_method("server_repair"):
		gas.server_repair()
	if GameState.local_player_node and GameState.local_player_node.has_method("_show_toast"):
		GameState.local_player_node._show_toast("Pipe bandaged — leak sealed.")
