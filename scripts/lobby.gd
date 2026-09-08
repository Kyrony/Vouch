extends Control
## F5 / main-scene home — Godot port of Kyle's React VouchMenu.
## Play / Friends / Settings / Quit. Classic Host Match is the live path.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")
const _BUILD: GDScript = preload("res://scripts/horror/ui/vouch_menu_builder.gd")
const _NEON: GDScript = preload("res://scripts/horror/ui/neon_menu.gd")

var home_panel: Control
var play_panel: Control
var side_panel: Control
var play_content: Control
var friends_content: Control
var settings_content: Control
var toast_label: Label

var play_button: Button
var join_friends_button: Button
var settings_button: Button
var quit_button: Button

var classic_button: Button
var hardcore_button: Button
var custom_button: Button
var practice_button: Button
var friends_lobby_button: Button
var start_button: Button

var lobby_code_input: LineEdit
var friends_join_button: Button

var master_volume_slider: HSlider
var sfx_volume_slider: HSlider
var fullscreen_toggle: CheckButton
var save_button: Button

var host_button: Button
var ip_input: LineEdit
var join_button: Button
var start_match_button: Button
var status_label: Label
var player_count_label: Label
var play_back_button: Button

var _nav_id: String = "play"
var _mode_id: String = "classic"
var _toast_tween: Tween


func _ready() -> void:
	_BUILD.call("ensure", self)
	_cache_nodes()
	_connect_signals()
	_load_settings_widgets()
	_NEON.call("apply", self)
	set_process_unhandled_input(true)
	_show_home()
	_set_nav("play")
	_set_mode("classic")
	_on_roster_updated(NetworkManager.lobby_roster)


func _cache_nodes() -> void:
	home_panel = $HomePanel
	play_panel = $PlayPanel
	side_panel = $HomePanel/SidePanel
	play_content = $HomePanel/SidePanel/PlayContent
	friends_content = $HomePanel/SidePanel/FriendsContent
	settings_content = $HomePanel/SidePanel/SettingsContent
	toast_label = $HomePanel/ToastLabel
	play_button = $HomePanel/NavColumn/PlayButton
	join_friends_button = $HomePanel/NavColumn/JoinFriendsButton
	settings_button = $HomePanel/NavColumn/SettingsButton
	quit_button = $HomePanel/NavColumn/QuitButton
	classic_button = $HomePanel/SidePanel/PlayContent/ModeList/ClassicButton
	hardcore_button = $HomePanel/SidePanel/PlayContent/ModeList/HardcoreButton
	custom_button = $HomePanel/SidePanel/PlayContent/ModeList/CustomButton
	practice_button = $HomePanel/SidePanel/PlayContent/ModeList/PracticeButton
	friends_lobby_button = $HomePanel/SidePanel/PlayContent/ModeList/FriendsLobbyButton
	start_button = $HomePanel/SidePanel/PlayContent/StartButton
	lobby_code_input = $HomePanel/SidePanel/FriendsContent/LobbyCodeInput
	friends_join_button = $HomePanel/SidePanel/FriendsContent/FriendsJoinButton
	master_volume_slider = $HomePanel/SidePanel/SettingsContent/MasterVolumeRow/Slider
	sfx_volume_slider = $HomePanel/SidePanel/SettingsContent/SfxVolumeRow/Slider
	fullscreen_toggle = $HomePanel/SidePanel/SettingsContent/FullscreenRow/FullscreenToggle
	save_button = $HomePanel/SidePanel/SettingsContent/SaveButton
	host_button = $PlayPanel/VBoxContainer/HostButton
	ip_input = $PlayPanel/VBoxContainer/JoinRow/IPInput
	join_button = $PlayPanel/VBoxContainer/JoinRow/JoinButton
	start_match_button = $PlayPanel/VBoxContainer/StartMatchButton
	status_label = $PlayPanel/VBoxContainer/StatusLabel
	player_count_label = $PlayPanel/VBoxContainer/PlayerCountLabel
	play_back_button = $PlayPanel/BackButton


func _connect_signals() -> void:
	var bg := $Background as ColorRect
	if bg and not bg.gui_input.is_connected(_on_backdrop_gui_input):
		bg.gui_input.connect(_on_backdrop_gui_input)
	play_button.pressed.connect(func(): _set_nav("play"))
	join_friends_button.pressed.connect(func(): _set_nav("friends"))
	settings_button.pressed.connect(func(): _set_nav("settings"))
	quit_button.pressed.connect(_on_exit_pressed)
	for btn in [play_button, join_friends_button, settings_button, quit_button]:
		if not btn.mouse_entered.is_connected(_on_nav_hover):
			btn.mouse_entered.connect(_on_nav_hover.bind(btn))
	classic_button.pressed.connect(func(): _set_mode("classic"))
	hardcore_button.pressed.connect(func(): _set_mode("hardcore"))
	custom_button.pressed.connect(func(): _set_mode("custom"))
	practice_button.pressed.connect(func(): _set_mode("practice"))
	friends_lobby_button.pressed.connect(func(): _set_mode("friends-lobby"))
	start_button.pressed.connect(_on_start_mode)
	friends_join_button.pressed.connect(_on_friends_join)
	lobby_code_input.text_changed.connect(_on_lobby_code_changed)
	save_button.pressed.connect(_on_save_settings)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	play_back_button.pressed.connect(_close_host)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	start_match_button.visible = false
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.lobby_roster_updated.connect(_on_roster_updated)


func _load_settings_widgets() -> void:
	master_volume_slider.value = SettingsManager.master_volume
	sfx_volume_slider.value = SettingsManager.sfx_volume
	fullscreen_toggle.button_pressed = SettingsManager.fullscreen


func _show_home() -> void:
	home_panel.visible = true
	play_panel.visible = false
	var plate := get_node_or_null("Background") as CanvasItem
	if plate:
		plate.visible = true


func _show_host() -> void:
	home_panel.visible = false
	play_panel.visible = true


func _close_host() -> void:
	_show_home()
	_set_nav("play")


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_set_nav("")


func _set_nav(nav_id: String) -> void:
	_nav_id = nav_id
	var open := not nav_id.is_empty() and nav_id != "quit"
	if side_panel:
		side_panel.visible = open
	if play_content:
		play_content.visible = nav_id == "play"
	if friends_content:
		friends_content.visible = nav_id == "friends"
	if settings_content:
		settings_content.visible = nav_id == "settings"
	_T.apply_nav_button(play_button, nav_id == "play")
	_T.apply_nav_button(join_friends_button, nav_id == "friends")
	_T.apply_nav_button(settings_button, nav_id == "settings")
	_T.apply_nav_button(quit_button, nav_id == "quit")
	_NEON.call("set_play_selected", home_panel, nav_id == "play")


func _set_mode(mode_id: String) -> void:
	_mode_id = mode_id
	var buttons := {
		"classic": classic_button,
		"hardcore": hardcore_button,
		"custom": custom_button,
		"practice": practice_button,
		"friends-lobby": friends_lobby_button,
	}
	for id in buttons:
		_T.apply_mode_button(buttons[id], id == mode_id)


func _on_nav_hover(button: Button) -> void:
	var row := button.get_node_or_null("Row") as Control
	if row == null:
		return
	var tw := row.create_tween()
	tw.tween_property(row, "position:x", 6.0, 0.04)
	tw.tween_property(row, "position:x", -3.0, 0.05)
	tw.tween_property(row, "position:x", 0.0, 0.05)


func _on_start_mode() -> void:
	if _mode_id == "classic":
		_show_host()
		status_label.text = "Classic outdoor neighborhood. Host a match or join by IP."
		return
	var spec: Dictionary = _T.MODES.get(_mode_id, {})
	var title: String = spec.get("title", _mode_id.to_upper())
	_toast("%s is a stub in this build." % title)


func _on_friends_join() -> void:
	var code := lobby_code_input.text.strip_edges()
	if code.is_empty():
		_toast("Enter a lobby code.")
		return
	_toast("Lobby codes are a stub. Use Classic → Host Match to join by IP.")


func _on_lobby_code_changed(text: String) -> void:
	var caret := lobby_code_input.caret_column
	var next := text.to_upper()
	if next != text:
		lobby_code_input.text = next
		lobby_code_input.caret_column = caret


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)


func _on_save_settings() -> void:
	SettingsManager.set_master_volume(master_volume_slider.value)
	SettingsManager.set_sfx_volume(sfx_volume_slider.value)
	SettingsManager.set_fullscreen(fullscreen_toggle.button_pressed)
	_toast("Settings saved.")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(_T.TOAST_SECONDS - 0.8)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)
	_toast_tween.tween_callback(func():
		toast_label.visible = false
		toast_label.modulate.a = 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if play_panel.visible:
		if key.physical_keycode == KEY_ESCAPE:
			_close_host()
			get_viewport().set_input_as_handled()
		return
	if not home_panel.visible:
		return
	if key.physical_keycode == KEY_ESCAPE:
		if not _nav_id.is_empty():
			_set_nav("")
			get_viewport().set_input_as_handled()
		return
	if _nav_id != "play":
		return
	if key.physical_keycode == KEY_UP:
		_nudge_mode(-1)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_DOWN:
		_nudge_mode(1)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER:
		_on_start_mode()
		get_viewport().set_input_as_handled()


func _nudge_mode(delta: int) -> void:
	var ids: PackedStringArray = _T.MODE_IDS
	var idx := ids.find(_mode_id)
	if idx < 0:
		idx = 0
	idx = (idx + delta + ids.size()) % ids.size()
	_set_mode(ids[idx])


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
	if player_count_label:
		player_count_label.text = "Players: %d" % roster.size()
