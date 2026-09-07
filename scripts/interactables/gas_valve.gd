extends "res://scripts/interactables/interactable.gd"
class_name GasValve
## GasValve
##
## Mystery CONTROL on the "gas" utility channel. Turning it affects gas
## state in another room via LinkGraph (same pattern as WaterValve).

var control_id: String = ""
var room_index: int = -1


func _ready() -> void:
	if multiplayer.is_server():
		LinkGraph.server_register_control(control_id, self, room_index, "gas")


func interact(by_peer_id: int) -> void:
	if control_id.is_empty():
		return
	if multiplayer.is_server():
		LinkGraph.server_handle_activation(control_id, by_peer_id)
	else:
		LinkGraph.request_activate.rpc_id(1, control_id)
