extends Control
class_name PauseMenu
## PauseMenu
##
## In-match pause overlay (Esc). Settings opens the same Keybinds / Audio /
## Visual / Controls sidebox as the home menu. REMOVE DEBUG GUI FROM PAUSE
## MENU BEFORE FINAL LAUNCH.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")
const _SETTINGS: GDScript = preload("res://scripts/horror/ui/settings_sidebox.gd")

signal resume_requested
signal settings_requested
signal exit_requested
signal debug_gui_requested

var _settings_dock: Panel
var _settings_root: Control
var _back_button: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_style_pause_panel()
	_ensure_settings_dock()


func show_menu() -> void:
	visible = true
	_show_pause_buttons()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false
	_show_pause_buttons()
	get_tree().paused = false
	var gs := get_node_or_null("/root/GameState")
	if gs and int(gs.get("phase")) == 1:
		var player = gs.get("local_player_node")
		var eliminated := player != null and bool(player.get("_eliminated"))
		var spectating := player != null and bool(player.get("_spectating"))
		if eliminated and not spectating:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func dismiss_for_exit() -> void:
	visible = false
	_show_pause_buttons()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_settings() -> void:
	var panel := get_node_or_null("Panel") as Control
	if panel:
		panel.visible = false
	if _settings_dock:
		_settings_dock.visible = true
	if _settings_root:
		_SETTINGS.call("wire", _settings_root)
		_SETTINGS.call("set_tab", _settings_root, "controls")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_settings() -> void:
	_show_pause_buttons()


func _show_pause_buttons() -> void:
	var panel := get_node_or_null("Panel") as Control
	if panel:
		panel.visible = true
	if _settings_dock:
		_settings_dock.visible = false


func _style_pause_panel() -> void:
	var kit: GDScript = load("res://scripts/horror/ui/ui_kit.gd")
	if kit:
		kit.call("apply_buttons", self, ["ControlsButton", "VisualButton", "AudioButton", "KeybindsButton", "SaveButton"])
	var panel := get_node_or_null("Panel") as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", _T.box(_T.GOLD, _T.PANEL, 1, 2, true))
	var title := get_node_or_null("Panel/VBox/Title") as Label
	if title:
		_T.apply_label(title, "ui")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for path in ["Panel/VBox/ResumeButton", "Panel/VBox/SettingsButton", "Panel/VBox/ExitButton", "Panel/VBox/DebugButton"]:
		var btn := get_node_or_null(path) as Button
		if btn:
			_T.apply_action_button(btn, "gold" if path.ends_with("ResumeButton") or path.ends_with("SettingsButton") else "blood" if path.ends_with("ExitButton") else "gold")


func _ensure_settings_dock() -> void:
	_settings_dock = get_node_or_null("SettingsDock") as Panel
	if _settings_dock == null:
		_settings_dock = Panel.new()
		_settings_dock.name = "SettingsDock"
		add_child(_settings_dock)
	_settings_dock.visible = false
	_settings_dock.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_settings_dock.offset_left = -520
	_settings_dock.offset_top = 36
	_settings_dock.offset_right = -28
	_settings_dock.offset_bottom = -36
	_settings_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_dock.add_theme_stylebox_override("panel", _T.box(_T.GOLD, _T.PANEL, 1, 2, true))
	_back_button = _settings_dock.get_node_or_null("BackButton") as Button
	if _back_button == null:
		_back_button = Button.new()
		_back_button.name = "BackButton"
		_settings_dock.add_child(_back_button)
	_back_button.text = "BACK"
	_back_button.position = Vector2(16, 12)
	_back_button.size = Vector2(120, 36)
	_T.apply_action_button(_back_button, "gold")
	if not _back_button.pressed.is_connected(close_settings):
		_back_button.pressed.connect(close_settings)
	_settings_root = _settings_dock.get_node_or_null("SettingsContent") as Control
	if _settings_root == null:
		_settings_root = Control.new()
		_settings_root.name = "SettingsContent"
		_settings_dock.add_child(_settings_root)
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.offset_left = 8
	_settings_root.offset_top = 48
	_settings_root.offset_right = -8
	_settings_root.offset_bottom = -8
	_SETTINGS.call("ensure", _settings_root)
	_settings_root.offset_left = 8
	_settings_root.offset_top = 52
	_settings_root.offset_right = -8
	_settings_root.offset_bottom = -8
	var heading := _settings_root.get_node_or_null("Heading") as Label
	if heading:
		heading.visible = false
		heading.text = ""
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_button.z_index = 40
	_back_button.move_to_front()


func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	show_settings()
	settings_requested.emit()


func _on_exit_pressed() -> void:
	dismiss_for_exit()
	exit_requested.emit()


func _on_debug_pressed() -> void:
	# REMOVE DEBUG GUI FROM PAUSE MENU BEFORE FINAL LAUNCH
	debug_gui_requested.emit()
