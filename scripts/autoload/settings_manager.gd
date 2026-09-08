extends Node
## SettingsManager
##
## Client-local settings: key remapping, mouse/look sensitivity, and
## audio volume stubs. Persisted to a small local config file and
## reloaded/re-applied to the engine's InputMap on startup, before any
## player pawn exists. None of this is ever networked - every peer keeps
## their own settings, exactly like a normal single-player options menu.

signal bindings_changed
signal sensitivity_changed(value: float)
signal volume_changed(bus_name: String, value: float)

const SAVE_PATH: String = "user://vouch_settings.cfg"

## Actions the Settings screen lets the player rebind. Kept as a list
## (not just "every InputMap action") so we don't accidentally expose
## `ui_release_mouse` or other internal-only bindings to remapping.
const REMAPPABLE_ACTIONS: Array[String] = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"interact",
	"destroy",
	"crouch",
]

const DEFAULT_SENSITIVITY: float = 1.0
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0
const DEFAULT_FULLSCREEN: bool = false

## Multiplier applied on top of Player.gd's base mouse-look sensitivity.
var mouse_sensitivity: float = DEFAULT_SENSITIVITY
## 0..1 linear volume stubs. `master_volume` actually drives the engine's
## "Master" audio bus (always present); `sfx_volume` is stored/persisted
## but inert until the project has actual SFX buses/sounds - see
## docs/MVP_GDD.md.
var master_volume: float = DEFAULT_MASTER_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN


## action_name -> Array[InputEvent], captured at startup BEFORE any saved
## override is applied, so "reset to default" has something real to
## restore (the events declared in project.godot's [input] section).
var _default_events: Dictionary = {}


func _ready() -> void:
	for action_name in REMAPPABLE_ACTIONS:
		_default_events[action_name] = InputMap.action_get_events(action_name).duplicate()
	_load()
	_apply_all_bindings()
	_apply_master_volume()
	_apply_fullscreen()


## Returns the first meaningful InputEvent bound to `action_name` (skips
## `ui_release_mouse`-style "no event" cases), for display purposes.
func get_binding_event(action_name: String) -> InputEvent:
	var events := InputMap.action_get_events(action_name)
	return events[0] if not events.is_empty() else null


func get_binding_label(action_name: String) -> String:
	var event := get_binding_event(action_name)
	if event == null:
		return "(unbound)"
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return OS.get_keycode_string(key_event.physical_keycode)
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return "Mouse %d" % mouse_event.button_index
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event
		return "Joy %d" % joy_event.button_index
	if event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event
		return "Joy Axis %d" % joy_motion.axis
	return event.as_text()


## Rebinds `action_name` to a single new event, replacing any previous
## binding, and persists immediately.
func rebind_action(action_name: String, event: InputEvent) -> void:
	if not REMAPPABLE_ACTIONS.has(action_name):
		return
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	_save()
	bindings_changed.emit()


func reset_action_to_default(action_name: String) -> void:
	InputMap.action_erase_events(action_name)
	for event in _default_events.get(action_name, []):
		InputMap.action_add_event(action_name, event)
	_save()
	bindings_changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.1, 4.0)
	_save()
	sensitivity_changed.emit(mouse_sensitivity)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save()
	volume_changed.emit("master", master_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save()
	volume_changed.emit("sfx", sfx_volume)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_save()


func _apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, master_volume <= 0.0001)


func _apply_all_bindings() -> void:
	for action_name in REMAPPABLE_ACTIONS:
		var saved := _load_binding(action_name)
		if saved != null:
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, saved)


var _cfg: ConfigFile = null


func _load_binding(action_name: String) -> InputEvent:
	if _cfg == null:
		return null
	if not _cfg.has_section_key("bindings", action_name):
		return null
	var data: Dictionary = _cfg.get_value("bindings", action_name, {})
	return _event_from_dict(data)


func _event_from_dict(data: Dictionary) -> InputEvent:
	if data.is_empty():
		return null
	match data.get("type", ""):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = data.get("physical_keycode", 0)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button_index", MOUSE_BUTTON_LEFT)
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = data.get("button_index", 0)
			return event
		_:
			return null


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return {"type": "key", "physical_keycode": key_event.physical_keycode}
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return {"type": "mouse_button", "button_index": mouse_event.button_index}
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event
		return {"type": "joy_button", "button_index": joy_event.button_index}
	return {}


func _save() -> void:
	var cfg := ConfigFile.new()
	for action_name in REMAPPABLE_ACTIONS:
		var event := get_binding_event(action_name)
		if event:
			cfg.set_value("bindings", action_name, _event_to_dict(event))
	cfg.set_value("audio", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save settings (err=%s)" % err)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_cfg = cfg
	mouse_sensitivity = cfg.get_value("audio", "mouse_sensitivity", DEFAULT_SENSITIVITY)
	master_volume = cfg.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	sfx_volume = cfg.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	fullscreen = cfg.get_value("video", "fullscreen", DEFAULT_FULLSCREEN)
