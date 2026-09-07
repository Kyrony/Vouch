extends Control
class_name PauseMenu
## PauseMenu
##
## In-match pause overlay (Esc). REMOVE DEBUG GUI FROM PAUSE MENU BEFORE FINAL LAUNCH.

signal resume_requested
signal settings_requested
signal exit_requested
signal debug_gui_requested


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func show_menu() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false
	get_tree().paused = false
	var gs := get_node_or_null("/root/GameState")
	if gs and int(gs.get("phase")) == 1:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_exit_pressed() -> void:
	hide_menu()
	exit_requested.emit()


func _on_debug_pressed() -> void:
	# REMOVE DEBUG GUI FROM PAUSE MENU BEFORE FINAL LAUNCH
	debug_gui_requested.emit()
