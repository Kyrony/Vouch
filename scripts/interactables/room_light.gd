extends Node3D
class_name RoomLight
## RoomLight
##
## A mystery EFFECT target. Some other room's LightSwitch is secretly wired
## to this light via LinkGraph. When triggered, it flips on/off and
## replicates that visual change to every client (harmless - it's just a
## light in a room, it doesn't reveal who pulled the switch).

@onready var bulb_light: OmniLight3D = $OmniLight3D
@onready var bulb_mesh: MeshInstance3D = $BulbMesh

var effect_id: String = ""
var owner_peer_id: int = -1
var _is_on: bool = true


func _ready() -> void:
	# Duplicate the material so toggling emission on this bulb doesn't
	# mutate the shared graybox material resource used by every room.
	var mat := bulb_mesh.get_active_material(0)
	if mat:
		bulb_mesh.set_surface_override_material(0, mat.duplicate())

	if multiplayer.is_server():
		LinkGraph.server_register_effect(effect_id, self, owner_peer_id)
	_apply_visual(_is_on)


## Called server-side by LinkGraph when the linked control is activated.
func server_apply_effect() -> void:
	_is_on = not _is_on
	_apply_visual(_is_on)
	_client_sync_state.rpc(_is_on)


@rpc("authority", "call_remote", "reliable")
func _client_sync_state(is_on: bool) -> void:
	_apply_visual(is_on)


func _apply_visual(is_on: bool) -> void:
	bulb_light.visible = is_on
	var mat := bulb_mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.emission_enabled = is_on
