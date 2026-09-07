extends Control
## Lobby
##
## Acts as the game's "home screen": Play / Settings / Character / Exit.
## Play swaps in the host/join sub-panel (IP-based direct connect only for
## MVP - lobby codes and relay/NAT traversal are explicitly future work,
## see docs/MVP_GDD.md). Settings has real key-remapping, mouse
## sensitivity, and audio volume controls, all persisted locally via
## `SettingsManager`. Character is still a stub panel. The Play panel
## shows a LIVE joined-player list (name + peer id) that updates as peers
## connect, broadcast to everyone via `NetworkManager.lobby_roster_updated`
## - this is pre-match "who's here" information only, never faction/role
## info - plus host-only "match spawn odds" sliders (`MatchSettings`).

const REMAP_ACTION_LABELS: Dictionary = {
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"interact": "Interact",
	"destroy": "Destroy (hold)",
}

@onready var home_panel: Control = $HomePanel
@onready var play_panel: Control = $PlayPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var character_panel: Control = $CharacterPanel

@onready var play_button: Button = $HomePanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $HomePanel/VBoxContainer/SettingsButton
@onready var character_button: Button = $HomePanel/VBoxContainer/CharacterButton
@onready var exit_button: Button = $HomePanel/VBoxContainer/ExitButton

@onready var host_button: Button = $PlayPanel/VBoxContainer/HostButton
@onready var ip_input: LineEdit = $PlayPanel/VBoxContainer/JoinRow/IPInput
@onready var join_button: Button = $PlayPanel/VBoxContainer/JoinRow/JoinButton
@onready var start_match_button: Button = $PlayPanel/VBoxContainer/StartMatchButton
@onready var status_label: Label = $PlayPanel/VBoxContainer/StatusLabel
@onready var play_back_button: Button = $PlayPanel/VBoxContainer/BackButton

@onready var player_count_label: Label = $PlayPanel/PlayerListPanel/VBoxContainer/PlayerCountLabel
@onready var player_list_box: VBoxContainer = $PlayPanel/PlayerListPanel/VBoxContainer/PlayerListScroll/PlayerListBox

@onready var match_settings_panel: Panel = $PlayPanel/MatchSettingsPanel
@onready var match_settings_client_label: Label = $PlayPanel/MatchSettingsClientLabel
@onready var match_settings_host_box: VBoxContainer = $PlayPanel/MatchSettingsPanel/VBoxContainer
@onready var hallway_slider: HSlider = $PlayPanel/MatchSettingsPanel/VBoxContainer/HiddenHallwayRow/Slider
@onready var hallway_value_label: Label = $PlayPanel/MatchSettingsPanel/VBoxContainer/HiddenHallwayRow/ValueLabel
@onready var code_lock_slider: HSlider = $PlayPanel/MatchSettingsPanel/VBoxContainer/CodeLockRow/Slider
@onready var code_lock_value_label: Label = $PlayPanel/MatchSettingsPanel/VBoxContainer/CodeLockRow/ValueLabel
@onready var flame_paper_slider: HSlider = $PlayPanel/MatchSettingsPanel/VBoxContainer/FlamePaperRow/Slider
@onready var flame_paper_value_label: Label = $PlayPanel/MatchSettingsPanel/VBoxContainer/FlamePaperRow/ValueLabel
@onready var flood_valve_slider: HSlider = $PlayPanel/MatchSettingsPanel/VBoxContainer/FloodValveRow/Slider
@onready var flood_valve_value_label: Label = $PlayPanel/MatchSettingsPanel/VBoxContainer/FloodValveRow/ValueLabel

@onready var remap_container: VBoxContainer = $SettingsPanel/ScrollContainer/VBoxContainer/RemapContainer
@onready var sensitivity_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/SensitivityRow/Slider
@onready var sensitivity_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/SensitivityRow/ValueLabel
@onready var master_volume_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/MasterVolumeRow/Slider
@onready var master_volume_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/MasterVolumeRow/ValueLabel
@onready var sfx_volume_slider: HSlider = $SettingsPanel/ScrollContainer/VBoxContainer/SfxVolumeRow/Slider
@onready var sfx_volume_value_label: Label = $SettingsPanel/ScrollContainer/VBoxContainer/SfxVolumeRow/ValueLabel
@onready var settings_back_button: Button = $SettingsPanel/ButtonRow/BackButton

@onready var character_back_button: Button = $CharacterPanel/VBoxContainer/BackButton

@onready var lobby_code_row: HBoxContainer = $PlayPanel/VBoxContainer/LobbyCodeRow
@onready var lobby_code_input: LineEdit = $PlayPanel/VBoxContainer/LobbyCodeRow/LobbyCodeInput

const _UI: GDScript = preload("res://scripts/ui/ui_theme.gd")

## Set while waiting for the next input event to finish a key-remap.
var _awaiting_remap_action: String = ""
var _remap_buttons: Dictionary = {}


func _ready() -> void:
	play_button.pressed.connect(func(): _show_panel(play_panel))
	settings_button.pressed.connect(func(): _show_panel(settings_panel))
	character_button.pressed.connect(func(): _show_panel(character_panel))
	exit_button.pressed.connect(_on_exit_pressed)

	play_back_button.pressed.connect(func(): _show_panel(home_panel))
	settings_back_button.pressed.connect(func(): _show_panel(home_panel))
	character_back_button.pressed.connect(func(): _show_panel(home_panel))

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
	_setup_match_settings_controls()
	_apply_ui_theme()

	_show_panel(home_panel)
	_on_roster_updated(NetworkManager.lobby_roster)


func _show_panel(panel: Control) -> void:
	home_panel.visible = false
	play_panel.visible = false
	settings_panel.visible = false
	character_panel.visible = false
	panel.visible = true
	if panel == play_panel:
		_refresh_match_settings_access()


func _refresh_match_settings_access() -> void:
	var is_host := NetworkManager.is_server()
	match_settings_panel.visible = is_host
	match_settings_client_label.visible = not is_host and NetworkManager.multiplayer.multiplayer_peer != null
	if is_host:
		_set_odds_sliders_enabled(true)
	else:
		_set_odds_sliders_enabled(false)


func _set_odds_sliders_enabled(enabled: bool) -> void:
	hallway_slider.editable = enabled
	code_lock_slider.editable = enabled
	flame_paper_slider.editable = enabled
	flood_valve_slider.editable = enabled
	for row in match_settings_host_box.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is HSlider:
					child.editable = enabled


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_host_pressed() -> void:
	var err := NetworkManager.host_game()
	if err == OK:
		status_label.text = "Hosting on port %d. Friends join via direct IP (see below)." % NetworkManager.DEFAULT_PORT
		start_match_button.visible = true
		_refresh_match_settings_access()
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
	_refresh_match_settings_access()


func _on_join_failed(reason: String) -> void:
	status_label.text = "Join failed: %s" % reason


func _on_disconnected() -> void:
	status_label.text = "Disconnected from host."
	start_match_button.visible = false
	match_settings_panel.visible = false
	match_settings_client_label.visible = false


func _on_roster_updated(roster: Array) -> void:
	for child in player_list_box.get_children():
		child.queue_free()

	for entry in roster:
		var label := Label.new()
		label.text = "\u2022 %s  (peer %d)" % [entry["name"], entry["peer_id"]]
		player_list_box.add_child(label)

	player_count_label.text = "Players connected: %d" % roster.size()


# --- Match settings (host-only spawn odds) ------------------------------

func _setup_match_settings_controls() -> void:
	hallway_slider.value = MatchSettings.hidden_hallway_chance
	code_lock_slider.value = MatchSettings.code_lock_chance
	flame_paper_slider.value = MatchSettings.flame_paper_chance
	flood_valve_slider.value = MatchSettings.flood_valve_chance
	_refresh_odds_labels()

	hallway_slider.value_changed.connect(func(v):
		MatchSettings.hidden_hallway_chance = v
		_refresh_odds_labels())
	code_lock_slider.value_changed.connect(func(v):
		MatchSettings.code_lock_chance = v
		_refresh_odds_labels())
	flame_paper_slider.value_changed.connect(func(v):
		MatchSettings.flame_paper_chance = v
		_refresh_odds_labels())
	flood_valve_slider.value_changed.connect(func(v):
		MatchSettings.flood_valve_chance = v
		_refresh_odds_labels())


func _refresh_odds_labels() -> void:
	hallway_value_label.text = "%d%%" % roundi(MatchSettings.hidden_hallway_chance * 100)
	code_lock_value_label.text = "%d%%" % roundi(MatchSettings.code_lock_chance * 100)
	flame_paper_value_label.text = "%d%%" % roundi(MatchSettings.flame_paper_chance * 100)
	flood_valve_value_label.text = "%d%%" % roundi(MatchSettings.flood_valve_chance * 100)


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
	var bg := $Background as ColorRect
	if bg and HorrorModeSettings.is_horror_mode():
		bg.color = Color(0.04, 0.035, 0.045, 1)
	var title := home_panel.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title and HorrorModeSettings.is_horror_mode():
		title.text = "VOUCH"
		title.add_theme_font_size_override("font_size", 48)
		title.add_theme_color_override("font_color", Color(0.72, 0.18, 0.16))
	var subtitle := home_panel.get_node_or_null("VBoxContainer/SubtitleLabel") as Label
	if subtitle and HorrorModeSettings.is_horror_mode():
		subtitle.text = "Find the missing child. The old man is watching."
		subtitle.add_theme_color_override("font_color", Color(0.55, 0.48, 0.52))
	for panel in [home_panel, play_panel, settings_panel, character_panel]:
		if panel.get_node_or_null("VBoxContainer"):
			pass
	_UI.call("apply_label_hierarchy", status_label, "body")
	if is_instance_valid(lobby_code_input):
		lobby_code_input.placeholder_text = "Lobby codes not wired yet — use direct IP"
		lobby_code_input.editable = false
		lobby_code_input.tooltip_text = "Session codes and relay are post-MVP. Join with the host LAN IP."
