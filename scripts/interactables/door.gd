extends Interactable
class_name Door
## Door
##
## The escape point for a room. Unlike LightSwitch/Phone, this is NOT a
## mystery prop - walking up and using the door is a direct, unambiguous
## action: it requests an escape via EscapeSystem.


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		EscapeSystem.server_handle_escape_request(by_peer_id)
	else:
		EscapeSystem.request_escape.rpc_id(1)
