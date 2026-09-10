extends "res://scripts/interactables/interactable.gd"
class_name RopeAnchor
## A high ledge. Using a rope here pulls you up.

@export var climb_height: float = 4.2
var used: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("rope_anchors")
	prompt_text = "Ledge — rope"
	collision_layer = 2
	collision_mask = 0


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		_try_attach(by_peer_id)
	else:
		_rpc_try_attach.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_try_attach() -> void:
	if multiplayer.is_server():
		_try_attach(multiplayer.get_remote_sender_id())


func _try_attach(by_peer_id: int) -> void:
	if not PlayerInventory.server_has_item(by_peer_id, "rope"):
		return
	if server_attach_rope(by_peer_id):
		PlayerInventory.server_remove_item(by_peer_id, "rope")


func server_attach_rope(by_peer_id: int) -> bool:
	if not multiplayer.is_server() or used:
		return false
	used = true
	var dest := Vector3.ZERO
	var found := false
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name).to_int() != by_peer_id:
			continue
		if node is Node3D:
			dest = (node as Node3D).global_position
			dest.y = global_position.y + maxf(climb_height, 2.0)
			found = true
		break
	if not found:
		used = false
		return false
	_client_lift.rpc(by_peer_id, dest)
	print("[RopeAnchor] peer %d climbed with a rope" % by_peer_id)
	return true


@rpc("authority", "call_local", "reliable")
func _client_lift(peer_id: int, dest: Vector3) -> void:
	used = true
	prompt_text = "Rope hanging"
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name).to_int() != peer_id:
			continue
		if node is Node3D:
			(node as Node3D).global_position = dest
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		return
