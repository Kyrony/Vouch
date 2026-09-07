extends Node3D
class_name BrokenPipe
## BrokenPipe
##
## A mystery EFFECT target in LinkGraph's "flood" channel. Every room gets
## one of these (like every room gets a RoomLight), but it only ever does
## anything if some OTHER room's WaterValve happens to be linked to it.
## Each activation raises this room's water level a notch (capped), which:
##   - visually rises a water plane inside the room, and
##   - is cached into `GameState.room_water_levels[room_index]` on every
##     peer (via the same call/broadcast the visual update uses), so
##     Player.gd can cheaply slow movement for anyone standing in a
##     flooded room, and EscapeSystem can block escape once a room is
##     flooded enough - both purely from local position, no extra RPCs.

const MAX_LEVEL: float = 1.0
const LEVEL_INCREMENT: float = 0.25
## Water never visually rises above this fraction of room height, so it
## never clips through the ceiling even at MAX_LEVEL.
const MAX_HEIGHT_FRACTION: float = 0.85

@onready var water_mesh: MeshInstance3D = $WaterMesh

var effect_id: String = ""
var owner_peer_id: int = -1
var room_index: int = -1
var room_height: float = 3.0
var water_level: float = 0.0


func _ready() -> void:
	var mat := water_mesh.get_active_material(0)
	if mat:
		water_mesh.set_surface_override_material(0, mat.duplicate())

	if multiplayer.is_server():
		LinkGraph.server_register_effect(effect_id, self, owner_peer_id, room_index, "flood")
	_apply_visual(water_level)


## Called server-side by LinkGraph when a linked valve is activated.
func server_apply_effect() -> void:
	if not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_WATER):
		return
	water_level = minf(water_level + LEVEL_INCREMENT, MAX_LEVEL)
	GameState.room_water_levels[room_index] = water_level
	_apply_visual(water_level)
	_client_sync_state.rpc(water_level)


@rpc("authority", "call_remote", "reliable")
func _client_sync_state(level: float) -> void:
	water_level = level
	GameState.room_water_levels[room_index] = level
	_apply_visual(level)


func _apply_visual(level: float) -> void:
	water_mesh.visible = level > 0.01
	var height: float = maxf(room_height * MAX_HEIGHT_FRACTION * level, 0.001)
	water_mesh.scale.y = height
	water_mesh.position.y = height / 2.0
