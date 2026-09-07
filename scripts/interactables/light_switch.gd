extends "res://scripts/interactables/interactable.gd"
class_name LightSwitch
## LightSwitch
##
## A mystery CONTROL. Flipping it does something to a light in some other
## player's room via LinkGraph - the activator never learns what or whose.
## `control_id` is assigned by RoomPod at spawn time.

var control_id: String = ""
## Set by RoomPod at spawn time - which room this switch physically lives
## in (needed so LinkGraph can guarantee it never links to an effect in
## this same room).
var room_index: int = -1


func _ready() -> void:
	if multiplayer.is_server():
		LinkGraph.server_register_control(control_id, self, room_index, "light")


func interact(by_peer_id: int) -> void:
	if control_id.is_empty():
		push_warning("LightSwitch: control_id not set (spawned outside a RoomPod?)")
		return

	if multiplayer.is_server():
		LinkGraph.server_handle_activation(control_id, by_peer_id)
	else:
		LinkGraph.request_activate.rpc_id(1, control_id)
