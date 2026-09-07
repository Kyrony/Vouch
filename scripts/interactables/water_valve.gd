extends Interactable
class_name WaterValve
## WaterValve
##
## A mystery CONTROL in LinkGraph's "flood" channel - turning it surges
## water into some OTHER room's broken pipe. Same anonymity rules as
## LightSwitch: the activator gets only ambiguous local feedback, never
## knowing which room (or whose) they just flooded a little more.

var control_id: String = ""
## Set by RoomPod at spawn time - which room this valve physically lives
## in (needed so LinkGraph can guarantee it never targets this same room).
var room_index: int = -1


func _ready() -> void:
	if multiplayer.is_server():
		LinkGraph.server_register_control(control_id, self, room_index, "flood")


func interact(by_peer_id: int) -> void:
	if control_id.is_empty():
		push_warning("WaterValve: control_id not set (spawned outside a RoomPod?)")
		return

	if multiplayer.is_server():
		LinkGraph.server_handle_activation(control_id, by_peer_id)
	else:
		LinkGraph.request_activate.rpc_id(1, control_id)
