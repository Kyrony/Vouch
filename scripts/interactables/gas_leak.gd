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
	_add_leak_mesh()


func _add_leak_mesh() -> void:
	if has_node("LeakMesh"):
		return
	var mesh := MeshInstance3D.new()
	mesh.name = "LeakMesh"
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	mesh.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.2, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 0.8
	mesh.set_surface_override_material(0, mat)
	mesh.visible = false
	add_child(mesh)


func server_apply_effect() -> void:
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_GAS, false)
	_client_sync.rpc()
	_set_leak_visual(true)


func server_repair() -> void:
	if not multiplayer.is_server():
		return
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_GAS, true)
	_client_sync.rpc()
	_set_leak_visual(false)


func _set_leak_visual(active: bool) -> void:
	for c in get_children():
		if c is MeshInstance3D and c.name == "LeakMesh":
			c.visible = active


@rpc("authority", "call_remote", "reliable")
func _client_sync() -> void:
	pass
