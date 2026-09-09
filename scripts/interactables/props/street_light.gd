extends Node3D
class_name StreetLight
## An outdoor street/area light. It follows its circuit's power: dark until a
## fuse box (or switch) energises `circuit_room`. Purely visual state.

@export var circuit_room: int = -1  # power circuit; -1 = always lit
@export var starts_on: bool = false

var _is_on: bool = false
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("street_lights")
	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	if _light == null:
		_light = OmniLight3D.new()
		_light.omni_range = 12.0
		_light.light_color = Color(1.0, 0.85, 0.55)
		_light.light_energy = 2.0
		_light.position = Vector3(0, 4.0, 0)
		add_child(_light)
	_is_on = starts_on or circuit_room < 0
	RoomUtilities.utility_changed.connect(_on_utility_changed)
	_apply()


func _on_utility_changed(room: int, utility: String, enabled: bool) -> void:
	if room == circuit_room and utility == RoomUtilities.UTILITY_POWER:
		_is_on = enabled
		_apply()


func server_set_powered(on: bool) -> void:
	_is_on = on
	_apply()


func _apply() -> void:
	var powered := _is_on or circuit_room < 0
	if _light:
		_light.visible = powered
