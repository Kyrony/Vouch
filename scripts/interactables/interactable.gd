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
var _outline_meshes: Array[MeshInstance3D] = []


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
			if glow is StandardMaterial3D:
				glow.emission_enabled = true
				glow.emission = Color(0.55, 0.78, 0.82)
				glow.emission_energy_multiplier = 0.28
				glow.albedo_color = glow.albedo_color.lerp(Color(0.92, 0.94, 0.96), 0.08)
			mesh.set_surface_override_material(0, glow)
		else:
			mesh.set_surface_override_material(0, _mesh_overrides[mesh])
	_set_outline(on)


func _set_outline(on: bool) -> void:
	for om in _outline_meshes:
		if is_instance_valid(om):
			om.queue_free()
	_outline_meshes.clear()
	if not on:
		return
	for mesh: MeshInstance3D in _mesh_overrides.keys():
		if not is_instance_valid(mesh):
			continue
		var outline := MeshInstance3D.new()
		outline.mesh = mesh.mesh
		outline.scale = mesh.scale * 1.03
		outline.position = mesh.position
		outline.rotation = mesh.rotation
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.45, 0.72, 0.78, 0.18)
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.set_surface_override_material(0, mat)
		add_child(outline)
		_outline_meshes.append(outline)


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
