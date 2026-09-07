extends Node3D
class_name GasLeak
## GasLeak
##
## Mystery EFFECT on the "gas" channel. When triggered, disables gas
## utility in this room (stub gameplay: local toast + RoomUtilities flag).

var effect_id: String = ""
var owner_peer_id: int = -1
var room_index: int = -1
var _leak_active: bool = false


func _ready() -> void:
	add_to_group("link_effects")
	if multiplayer.is_server():
		LinkGraph.server_register_effect(effect_id, self, owner_peer_id, room_index, "gas")
	_add_leak_mesh()
	_set_leak_visual(false)


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
	mat.emission = Color(0.85, 0.55, 0.12)
	mat.emission_energy_multiplier = 0.45
	mesh.set_surface_override_material(0, mat)
	mesh.visible = false
	add_child(mesh)


func server_apply_effect() -> void:
	_leak_active = true
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_GAS, false)
	_client_sync.rpc(true)
	_set_leak_visual(true)


func server_repair() -> void:
	if not multiplayer.is_server():
		return
	_leak_active = false
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_GAS, true)
	_client_sync.rpc(false)
	_set_leak_visual(false)


func client_link_pulse() -> void:
	_set_leak_visual(true)
	var tween := create_tween()
	tween.tween_callback(func(): _set_leak_visual(_leak_active)).set_delay(0.5)


func _set_leak_visual(active: bool) -> void:
	for c in get_children():
		if c is MeshInstance3D and c.name == "LeakMesh":
			c.visible = active


@rpc("authority", "call_remote", "reliable")
func _client_sync(active: bool) -> void:
	_leak_active = active
	_set_leak_visual(active)
