extends Area3D
## EscapeZone
##
## Trigger at the top of the central escape shaft / Outside entrance.
## Walking into it completes escape (host-authoritative via EscapeSystem).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	var peer_id := int(str(body.name))
	if peer_id <= 0:
		return
	if multiplayer.is_server():
		EscapeSystem.server_handle_escape_request(peer_id)
	elif body.is_multiplayer_authority():
		EscapeSystem.request_escape.rpc_id(1)
