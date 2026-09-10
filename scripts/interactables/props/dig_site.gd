extends "res://scripts/interactables/interactable.gd"
class_name DigSite
## Loose dirt a shovel can turn. First dig uncovers a buried item.

@export var buried_item: String = "key"
var dug: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("dig_sites")
	prompt_text = "Loose dirt — shovel"
	collision_layer = 2
	collision_mask = 0


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		_try_dig(by_peer_id)
	else:
		_rpc_try_dig.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_try_dig() -> void:
	if multiplayer.is_server():
		_try_dig(multiplayer.get_remote_sender_id())


func _try_dig(by_peer_id: int) -> void:
	if not PlayerInventory.server_has_item(by_peer_id, "shovel"):
		return
	server_dig(by_peer_id)


func server_dig(by_peer_id: int) -> bool:
	if not multiplayer.is_server() or dug:
		return false
	dug = true
	_client_dug.rpc()
	var world := get_tree().get_first_node_in_group("horror_world")
	if world and world.has_method("spawn_pickup") and not buried_item.is_empty():
		var at: Vector3 = global_position + Vector3(0, 0.45, 0.4)
		world.call("spawn_pickup", buried_item, at)
	elif get_parent() and get_parent().has_method("spawn_pickup") and not buried_item.is_empty():
		get_parent().call("spawn_pickup", buried_item, global_position + Vector3(0, 0.45, 0.4))
	print("[DigSite] peer %d dug up %s" % [by_peer_id, buried_item])
	return true


@rpc("authority", "call_local", "reliable")
func _client_dug() -> void:
	dug = true
	prompt_text = "Dug hole"
	modulate_dug()


func modulate_dug() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.22, 0.16, 0.10)
			(child as MeshInstance3D).set_surface_override_material(0, mat)
