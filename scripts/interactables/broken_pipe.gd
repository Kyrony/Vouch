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
## Host-authoritative rise speed (water level units per second). Tunable.
const TRICKLE_RATE: float = 0.08
## Water never visually rises above this fraction of room height, so it
## never clips through the ceiling even at MAX_LEVEL.
const MAX_HEIGHT_FRACTION: float = 0.85

@onready var water_mesh: MeshInstance3D = $WaterMesh

var effect_id: String = ""
var owner_peer_id: int = -1
var room_index: int = -1
var room_height: float = 10.0
var water_level: float = 0.0

var _trickling: bool = false
var _trickle_target: float = 0.0
var _sync_timer: float = 0.0


func _ready() -> void:
	add_to_group("link_effects")
	var mat := water_mesh.get_active_material(0)
	if mat:
		water_mesh.set_surface_override_material(0, mat.duplicate())

	if multiplayer.is_server():
		LinkGraph.server_register_effect(effect_id, self, owner_peer_id, room_index, "flood")
	_apply_visual(water_level)


func _process(delta: float) -> void:
	if not multiplayer.is_server() or not _trickling:
		return
	if water_level >= _trickle_target - 0.0001:
		_trickling = false
		_client_sync_state.rpc(water_level)
		return

	water_level = minf(water_level + TRICKLE_RATE * delta, _trickle_target)
	GameState.room_water_levels[room_index] = water_level
	_apply_visual(water_level)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.1
		_client_sync_state.rpc(water_level)


## Called server-side by LinkGraph when a linked valve is activated.
func server_apply_effect() -> void:
	if not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_WATER):
		return
	_trickle_target = minf(_trickle_target + LEVEL_INCREMENT, MAX_LEVEL)
	if water_level >= _trickle_target - 0.0001:
		_trickle_target = water_level
		return
	if not _trickling:
		_trickling = true
		_sync_timer = 0.0


func server_repair() -> void:
	if not multiplayer.is_server():
		return
	_trickling = false
	_trickle_target = 0.0
	water_level = 0.0
	GameState.room_water_levels[room_index] = 0.0
	_apply_visual(0.0)
	_client_sync_state.rpc(0.0)


@rpc("authority", "call_remote", "reliable")
func _client_sync_state(level: float) -> void:
	water_level = level
	_trickle_target = maxf(_trickle_target, level)
	GameState.room_water_levels[room_index] = level
	_apply_visual(level)


func _apply_visual(level: float) -> void:
	water_mesh.visible = level > 0.01
	var height: float = maxf(room_height * MAX_HEIGHT_FRACTION * level, 0.001)
	water_mesh.scale.y = height
	water_mesh.position.y = height / 2.0
	if multiplayer.is_server() and level >= 0.35:
		_try_extinguish_room_fires()


func client_link_pulse() -> void:
	if not is_instance_valid(water_mesh):
		return
	var mat := water_mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var pulse := mat.duplicate()
		pulse.emission_enabled = true
		pulse.emission = Color(0.35, 0.55, 0.72)
		pulse.emission_energy_multiplier = 0.4
		water_mesh.set_surface_override_material(0, pulse)
		var tween := create_tween()
		tween.tween_callback(func(): _apply_visual(water_level)).set_delay(0.4)


func _try_extinguish_room_fires() -> void:
	var fire := get_node_or_null("/root/FireSystem")
	if not fire or not fire.has_method("server_extinguish_in_room"):
		return
	fire.server_extinguish_in_room(room_index)
