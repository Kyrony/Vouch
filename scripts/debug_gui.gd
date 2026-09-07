extends CanvasLayer
class_name DebugGui
## DebugGui
##
## *** DEV/HOST ONLY - REMOVE OR GATE BEFORE FULL RELEASE ***
## Toggle with Home key. Host gets full controls; clients see a
## read-only label. Spawns test props, triggers utility toggles, and
## exposes quick match settings for iteration.

@onready var panel: PanelContainer = $Panel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var buttons_box: VBoxContainer = $Panel/VBox/ButtonsBox

var _visible: bool = false


func _ready() -> void:
	panel.visible = false
	layer = 20
	_build_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_HOME:
		_toggle()


func _toggle() -> void:
	_visible = not _visible
	panel.visible = _visible
	if _visible:
		_refresh_status()


func _refresh_status() -> void:
	if NetworkManager.is_server():
		status_label.text = "DEBUG (host) — Home to close"
	else:
		status_label.text = "DEBUG (read-only) — host controls only"
		for child in buttons_box.get_children():
			if child is Button:
				child.disabled = true


func _build_buttons() -> void:
	_add_button("Spawn test gun near player", _spawn_gun)
	_add_button("Regenerate local room preview", _regen_room_hint)
	_add_button("Toggle power in my room", _toggle_power)
	_add_button("Toggle water in my room", _toggle_water)
	_add_button("Reset match spawn odds", _reset_odds)


func _add_button(label: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(callback)
	buttons_box.add_child(btn)


func _spawn_gun() -> void:
	if not NetworkManager.is_server():
		return
	var player := GameState.local_player_node
	if not player:
		return
	var gun_script: Script = preload("res://scripts/interactables/gun.gd")
	var gun := StaticBody3D.new()
	gun.set_script(gun_script)
	gun.collision_layer = 2
	gun.position = player.global_position + player.global_transform.basis.z * -1.2 + Vector3(0, 0.5, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.12, 0.55)
	mesh.mesh = box
	gun.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.12, 0.55)
	col.shape = shape
	gun.add_child(col)
	get_tree().current_scene.add_child(gun)


func _regen_room_hint() -> void:
	status_label.text = "Re-host match to regenerate rooms (host)" if NetworkManager.is_server() else "Read-only on clients"


func _toggle_power() -> void:
	if not NetworkManager.is_server() or not GameState.local_player_node:
		return
	var room := Match.world_position_to_room_index(GameState.local_player_node.global_position)
	var enabled := not RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_POWER)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_POWER, enabled)
	status_label.text = "Power room %d: %s" % [room, "ON" if enabled else "OFF"]


func _toggle_water() -> void:
	if not NetworkManager.is_server() or not GameState.local_player_node:
		return
	var room := Match.world_position_to_room_index(GameState.local_player_node.global_position)
	var enabled := not RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_WATER)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_WATER, enabled)
	status_label.text = "Water room %d: %s" % [room, "ON" if enabled else "OFF"]


func _reset_odds() -> void:
	if not NetworkManager.is_server():
		return
	MatchSettings.reset_to_defaults()
	status_label.text = "Spawn odds reset to defaults"
