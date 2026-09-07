extends "res://scripts/interactables/interactable.gd"
class_name Drain
## Drain
##
## Floor drain in bath/kitchen zones. When water utility is on, slowly
## lowers flood level in this room (host-authoritative).

const DRAIN_RATE: float = 0.04

@export var room_index: int = -1

var _active: bool = true


func _ready() -> void:
	set_process(multiplayer.is_server())
	RoomUtilities.utility_changed.connect(_on_utility_changed)
	_active = RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_WATER)


func configure(p_room_index: int) -> void:
	room_index = p_room_index
	prompt_text = "Floor drain"


func _process(delta: float) -> void:
	if not _active:
		return
	var level: float = GameState.room_water_levels.get(room_index, 0.0)
	if level <= 0.001:
		return
	level = maxf(level - DRAIN_RATE * delta, 0.0)
	GameState.room_water_levels[room_index] = level
	var pipe := _find_broken_pipe()
	if pipe and pipe.has_method("_apply_visual"):
		pipe.water_level = level
		pipe._apply_visual(level)


func _find_broken_pipe() -> Node:
	var room := get_parent()
	if room and room.has_node("BrokenPipe"):
		return room.get_node("BrokenPipe")
	return null


func _on_utility_changed(changed_room: int, utility: String, enabled: bool) -> void:
	if changed_room != room_index or utility != RoomUtilities.UTILITY_WATER:
		return
	_active = enabled
