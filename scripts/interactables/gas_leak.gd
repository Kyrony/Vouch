extends Node3D
class_name GasLeak
## GasLeak
##
## Mystery EFFECT on the "gas" channel. When triggered, disables gas
## utility in this room (stub gameplay: local toast + RoomUtilities flag).

var effect_id: String = ""
var owner_peer_id: int = -1
var room_index: int = -1


func _ready() -> void:
	if multiplayer.is_server():
		LinkGraph.server_register_effect(effect_id, self, owner_peer_id, room_index, "gas")


func server_apply_effect() -> void:
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_GAS, false)
	_client_sync.rpc()


@rpc("authority", "call_remote", "reliable")
func _client_sync() -> void:
	pass
