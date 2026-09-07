extends Interactable
class_name Gun
## Gun
##
## *** TEST-ONLY TOOL - REMOVE BEFORE FULL RELEASE ***
## Exists purely so hit-registration against `DummyTarget` props can be
## exercised during development. Not part of the intended MVP feature
## set (no ammo, no damage model, no gameplay purpose). See
## `scenes/Outside/Outside.tscn` and docs/MVP_GDD.md for the matching
## "remove before release" notes.

var is_picked_up: bool = false


func interact(_by_peer_id: int) -> void:
	if is_picked_up:
		return
	if multiplayer.is_server():
		server_pickup()
	else:
		_rpc_request_pickup.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_pickup() -> void:
	if not multiplayer.is_server():
		return
	server_pickup()


func server_pickup() -> void:
	if not multiplayer.is_server() or is_picked_up:
		return
	is_picked_up = true
	_client_apply_picked_up.rpc()
	_apply_picked_up()


@rpc("authority", "call_remote", "reliable")
func _client_apply_picked_up() -> void:
	_apply_picked_up()


func _apply_picked_up() -> void:
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
