extends Control
## Lobby
##
## Acts as the game's "home screen": Play / Join Friends / Settings / Quit.
## Play reveals the painted game-modes panel. Classic is the live Host Match
## path (IP-based direct connect only for MVP). Other listed modes are
## soft-gated. Host lobby is minimal: host / join / Start Match. Settings
## has key-remapping, mouse sensitivity, and audio volume via SettingsManager.

const REMAP_ACTION_LABELS: Dictionary = {
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"interact": "Interact",
	"destroy": "Destroy (hold)",
	"sprint": "Sprint",
	"crouch": "Crouch",
}

@onready var home_panel: Control = $HomePanel
@onready var play_panel: Control = $PlayPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var character_panel: Control = $CharacterPanel

@onready var play_button: Button = $HomePanel/HitboxRoot/MenuButtons/PlayButton
@onready var join_friends_button: Button = $HomePanel/HitboxRoot/MenuButtons/JoinFriendsButton
@onready var settings_button: Button = $HomePanel/HitboxRoot/MenuButtons/SettingsButton
@onready var quit_button: Button = $HomePanel/HitboxRoot/MenuButtons/QuitButton
@onready var mode_panel: Control = $HomePanel/HitboxRoot/GameModes
@onready var modes_cover: Control = $HomePanel/HitboxRoot/ModesCover
@onready var classic_button: Button = $HomePanel/HitboxRoot/GameModes/ClassicButton
@onready var hardcore_button: Button = $HomePanel/HitboxRoot/GameModes/HardcoreButton
@onready var custom_button: Button = $HomePanel/HitboxRoot/GameModes/CustomButton
@onready var practice_button: Button = $HomePanel/HitboxRoot/GameModes/PracticeButton
@onready var friends_lobby_button: Button = $HomePanel/HitboxRoot/GameModes/FriendsLobbyButton

@onready var host_button: Button = $PlayPanel/VBoxContainer/HostButton
@onready var ip_input: LineEdit = $PlayPanel/VBoxContainer/JoinRow/IPInput
@onready var join_button: Button = $PlayPanel/VBoxContainer/JoinRow/JoinButton
@onready var start_match_button: Button = $PlayPanel/VBoxContainer/StartMatchButton
@onready var status_label: Label = $PlayPanel/VBoxContainer/StatusLabel
@onready var play_back_button: Button = $PlayPanel/BackButton

@onready var player_count_label: Label = $PlayPanel/VBoxContainer/PlayerCountLabel
@onready var player_list_box: VBoxContainer = $PlayPanel/VBoxContainer/PlayerListBox

@onready var remap_container: VBoxContainer = $SettingsPanel/ScrollContainer/VBoxContainer/RemapContainer
@onready var sensitivity_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/SensitivityRow/Slider
@onready var sensitivity_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/SensitivityRow/ValueLabel
@onready var master_volume_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/MasterVolumeRow/Slider
@onready var master_volume_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/MasterVolumeRow/ValueLabel
@onready var sfx_volume_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/SfxVolumeRow/Slider
@onready var sfx_volume_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/SfxVolumeRow/ValueLabel
@onready var settings_back_button: Button = $SettingsPanel/ButtonRow/BackButton

@onready var character_back_button: Button = $CharacterPanel/VBoxContainer/BackButton

const _UI: GDScript = preload("res://scripts/ui/ui_theme.gd")
const _NEON: GDScript = preload("res://scripts/horror/ui/neon_menu.gd")

var _modes_open: bool = false

## Set while waiting for the next input event to finish a key-remap.
var _awaiting_remap_action: String = ""
var _remap_buttons: Dictionary = {}


func _ready() -> void:
	play_button.pressed.connect(_on_play_nav_pressed)
	join_friends_button.pressed.connect(_on_join_friends_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_exit_pressed)
	classic_button.pressed.connect(_on_classic_pressed)
	hardcore_button.pressed.connect(_on_gated_mode_pressed)
	custom_button.pressed.connect(_on_gated_mode_pressed)
	practice_button.pressed.connect(_on_gated_mode_pressed)
	friends_lobby_button.pressed.connect(_on_gated_mode_pressed)

	play_back_button.pressed.connect(_close_play_flow)
	settings_back_button.pressed.connect(_close_play_flow)
	character_back_button.pressed.connect(_close_play_flow)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	start_match_button.visible = false

	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.lobby_roster_updated.connect(_on_roster_updated)

	_build_remap_rows()
	_setup_settings_controls()
	_apply_ui_theme()
	set_process_unhandled_input(true)

	_show_panel(home_panel)
	_set_modes_open(false)
	_on_roster_updated(NetworkManager.lobby_roster)


func _show_panel(panel: Control) -> void:
	home_panel.visible = false
	play_panel.visible = false
	settings_panel.visible = false
	character_panel.visible = false
	panel.visible = true
	var plate := get_node_or_null("Background") as CanvasItem
	if plate:
		plate.visible = panel == home_panel
	if panel == home_panel:
		_set_modes_open(_modes_open)


func _set_modes_open(open: bool) -> void:
	_modes_open = open
	if mode_panel:
		mode_panel.visible = open
	if modes_cover:
		modes_cover.visible = not open
	_NEON.call("set_play_selected", home_panel, open)


func _close_play_flow() -> void:
	_set_modes_open(false)
	_show_panel(home_panel)


func _on_play_nav_pressed() -> void:
	_set_modes_open(not _modes_open)
	_show_panel(home_panel)


func _on_settings_pressed() -> void:
	_set_modes_open(false)
	_show_panel(settings_panel)


func _on_classic_pressed() -> void:
	_show_panel(play_panel)
	status_label.text = "Classic outdoor neighborhood. Host a match or join by IP."


func _on_join_friends_pressed() -> void:
	_set_modes_open(false)
	_show_panel(play_panel)
	status_label.text = "Join a friend's host via direct IP."


func _on_gated_mode_pressed() -> void:
	# Soft stub: stay on the Play-open home. Do not start another mode.
	_set_modes_open(true)
	_show_panel(home_panel)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_host_pressed() -> void:
	var err := NetworkManager.host_game()
	if err == OK:
		status_label.text = "Hosting on port %d. Friends join via direct IP." % NetworkManager.DEFAULT_PORT
		start_match_button.visible = true
	else:
		status_label.text = "Failed to host (error %s)." % err


func _on_join_pressed() -> void:
	var address := ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var err := NetworkManager.join_game(address)
	if err == OK:
		status_label.text = "Connecting to %s..." % address
	else:
		status_label.text = "Failed to connect (error %s)." % err


func _on_start_match_pressed() -> void:
	NetworkManager.start_match()


func _on_joined_server() -> void:
	status_label.text = "Connected. Waiting for the host to start the match."


func _on_join_failed(reason: String) -> void:
	status_label.text = "Join failed: %s" % reason


func _on_disconnected() -> void:
	status_label.text = "Disconnected from host."
	start_match_button.visible = false


func _on_roster_updated(roster: Array) -> void:
	for child in player_list_box.get_children():
		child.queue_free()

	for entry in roster:
		var label := Label.new()
		label.text = "\u2022 %s  (peer %d)" % [entry["name"], entry["peer_id"]]
		player_list_box.add_child(label)

	player_count_label.text = "Players connected: %d" % roster.size()


# --- Settings: key remapping ---------------------------------------------

func _build_remap_rows() -> void:
	for action_name in SettingsManager.REMAPPABLE_ACTIONS:
		var row := HBoxContainer.new()

		var label := Label.new()
		label.text = REMAP_ACTION_LABELS.get(action_name, action_name)
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)

		var bind_button := Button.new()
		bind_button.text = SettingsManager.get_binding_label(action_name)
		bind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bind_button.focus_mode = Control.FOCUS_ALL
		bind_button.pressed.connect(func(): _start_remap(action_name, bind_button))
		row.add_child(bind_button)
		_remap_buttons[action_name] = bind_button

		var reset_button := Button.new()
		reset_button.text = "Reset"
		reset_button.pressed.connect(func():
			SettingsManager.reset_action_to_default(action_name)
			bind_button.text = SettingsManager.get_binding_label(action_name))
		row.add_child(reset_button)

		remap_container.add_child(row)


func _start_remap(action_name: String, button: Button) -> void:
	if not _awaiting_remap_action.is_empty():
		return
	_awaiting_remap_action = action_name
	button.text = "Press any key/button..."
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_remap_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			if play_panel.visible or settings_panel.visible or character_panel.visible:
				_close_play_flow()
				get_viewport().set_input_as_handled()
			elif home_panel.visible and _modes_open:
				_set_modes_open(false)
				get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_remap()
			return
		SettingsManager.rebind_action(_awaiting_remap_action, event)
		_finish_remap()
	elif event is InputEventMouseButton and event.pressed:
		SettingsManager.rebind_action(_awaiting_remap_action, event)
		_finish_remap()
	elif event is InputEventJoypadButton and event.pressed:
		SettingsManager.rebind_action(_awaiting_remap_action, event)
		_finish_remap()


func _cancel_remap() -> void:
	var button: Button = _remap_buttons.get(_awaiting_remap_action)
	if button:
		button.text = SettingsManager.get_binding_label(_awaiting_remap_action)
	_awaiting_remap_action = ""


func _finish_remap() -> void:
	var action_name := _awaiting_remap_action
	var button: Button = _remap_buttons.get(action_name)
	if button:
		button.text = SettingsManager.get_binding_label(action_name)
	_awaiting_remap_action = ""


# --- Settings: sensitivity / audio ---------------------------------------

func _setup_settings_controls() -> void:
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	master_volume_slider.value = SettingsManager.master_volume
	sfx_volume_slider.value = SettingsManager.sfx_volume
	_refresh_settings_labels()

	sensitivity_slider.value_changed.connect(func(v):
		SettingsManager.set_mouse_sensitivity(v)
		_refresh_settings_labels())
	master_volume_slider.value_changed.connect(func(v):
		SettingsManager.set_master_volume(v)
		_refresh_settings_labels())
	sfx_volume_slider.value_changed.connect(func(v):
		SettingsManager.set_sfx_volume(v)
		_refresh_settings_labels())


func _refresh_settings_labels() -> void:
	sensitivity_value_label.text = "%.2fx" % sensitivity_slider.value
	master_volume_value_label.text = "%d%%" % roundi(master_volume_slider.value * 100)
	sfx_volume_value_label.text = "%d%%" % roundi(sfx_volume_slider.value * 100)


func _apply_ui_theme() -> void:
	var neon: GDScript = load("res://scripts/horror/ui/neon_menu.gd")
	neon.call("apply", self)
	if HorrorModeSettings.is_horror_mode():
		start_match_button.text = "Start Match"
	_UI.call("apply_label_hierarchy", status_label, "body")
