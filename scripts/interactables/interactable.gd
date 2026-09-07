extends StaticBody3D
class_name Interactable
## Interactable
##
## Base class for every prop a player can "use" (E key). Subclasses
## override `interact()`. Kept as a StaticBody3D so Player.gd can find it
## with a simple forward raycast on the "interactables" physics layer.

@export var prompt_text: String = "Interact"
@export var destroyable: bool = false

var is_destroyed: bool = false
var _highlighted: bool = false
var _mesh_overrides: Dictionary = {}


func _ready() -> void:
	_cache_mesh_materials()


func interact(_by_peer_id: int) -> void:
	pass


func set_highlighted(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	for mesh: MeshInstance3D in _mesh_overrides.keys():
		if not is_instance_valid(mesh):
			continue
		if on:
			var glow: StandardMaterial3D = _mesh_overrides[mesh].duplicate()
			glow.emission_enabled = true
			glow.emission = Color(0.35, 0.9, 1.0)
			glow.emission_energy_multiplier = 0.55
			mesh.set_surface_override_material(0, glow)
		else:
			mesh.set_surface_override_material(0, _mesh_overrides[mesh])


func _cache_mesh_materials() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			var base: Material = c.get_active_material(0)
			if base:
				_mesh_overrides[c] = base


func request_destroy(_by_peer_id: int) -> void:
	if not destroyable or is_destroyed:
		return
	if multiplayer.is_server():
		server_destroy()
	else:
		_rpc_request_destroy.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_destroy() -> void:
	if not multiplayer.is_server():
		return
	server_destroy()


func server_destroy() -> void:
	if not multiplayer.is_server() or is_destroyed:
		return
	is_destroyed = true
	_client_apply_destroyed.rpc()
	_apply_destroyed()


@rpc("authority", "call_remote", "reliable")
func _client_apply_destroyed() -> void:
	_apply_destroyed()


func _apply_destroyed() -> void:
	set_highlighted(false)
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
