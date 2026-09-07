extends RefCounted
class_name NeonMenu
## Locked Leonardo home shell: left nav + Classic mode panel + banner.
## Classic is the live Host Match path. Other modes are soft-gated.

const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")
const _BANNER: GDScript = preload("res://scripts/horror/ui/vouch_banner.gd")
const _ATMO: GDScript = preload("res://scripts/horror/ui/menu_atmosphere.gd")

const LIVE_MODE := "classic"
const MODE_ROWS: Array[Dictionary] = [
	{"id": "classic", "title": "CLASSIC", "blurb": "Standard survival experience.", "live": true},
	{"id": "hardcore", "title": "HARDCORE", "blurb": "Permadeath and extreme difficulty.", "live": false},
	{"id": "custom", "title": "CUSTOM", "blurb": "Modify game rules and settings.", "live": false},
	{"id": "practice", "title": "PRACTICE", "blurb": "Learn the mechanics safely.", "live": false},
	{"id": "friends_lobby", "title": "FRIENDS LOBBY", "blurb": "Set up a private multiplayer game.", "live": false},
]


static func apply(lobby: Control) -> void:
	_ensure_atmosphere(lobby)
	var bg := lobby.get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.02, 0.02, 0.03, 1)
		bg.modulate = Color(1, 1, 1, 0.55)
	var home := lobby.get_node_or_null("HomePanel") as Control
	if home:
		_style_home(home)
	var play := lobby.get_node_or_null("PlayPanel") as Control
	if play:
		_style_play(play)
	var settings := lobby.get_node_or_null("SettingsPanel") as Control
	if settings:
		_style_settings(settings)
	_KIT.apply_buttons(lobby, ["ClassicButton", "PlayButton"])
	var play_btn := lobby.get_node_or_null("HomePanel/NavColumn/PlayButton") as Button
	if play_btn:
		_KIT.apply_button(play_btn, "nav_focus")
	var classic := lobby.get_node_or_null("HomePanel/ModePanel/ModeList/ClassicButton") as Button
	if classic:
		_KIT.apply_button(classic, "confirm")


static func _ensure_atmosphere(lobby: Control) -> void:
	if lobby.get_node_or_null("MenuAtmosphere") != null:
		return
	var atmo: Control = _ATMO.new()
	lobby.add_child(atmo)
	lobby.move_child(atmo, 0)


static func _style_home(home: Control) -> void:
	_ensure_banner(home)
	var version := home.get_node_or_null("VersionLabel") as Label
	if version:
		version.text = "v1.0.0"
		version.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76, 0.55))
		version.add_theme_font_size_override("font_size", 12)
	var signal_lab := home.get_node_or_null("SignalAccent/Label") as Label
	if signal_lab:
		signal_lab.add_theme_color_override("font_color", _KIT.WHITE)
		signal_lab.add_theme_font_size_override("font_size", 11)
	var bars := home.get_node_or_null("SignalAccent/Bars") as TextureRect
	if bars and bars.texture == null:
		bars.texture = _KIT.texture("signal_bars")
	var mode := home.get_node_or_null("ModePanel") as Panel
	if mode:
		mode.add_theme_stylebox_override("panel", _KIT.panel_alert())
	var preview := home.get_node_or_null("ModePanel/Preview") as TextureRect
	if preview and preview.texture == null:
		preview.texture = _KIT.texture("preview_gate")
	_style_nav_icons(home)
	_gate_modes(home)


static func _ensure_banner(home: Control) -> void:
	var existing := home.get_node_or_null("Banner")
	if existing:
		if existing.get_script() == null:
			existing.set_script(_BANNER)
		return
	var banner: Control = _BANNER.new()
	banner.name = "Banner"
	banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	banner.offset_left = 24
	banner.offset_top = 10
	banner.offset_right = 460
	banner.offset_bottom = 130
	home.add_child(banner)
	home.move_child(banner, 0)


static func _style_nav_icons(home: Control) -> void:
	var pairs := {
		"PlayButton": "icon_play",
		"JoinFriendsButton": "icon_join",
		"SettingsButton": "icon_settings",
		"QuitButton": "icon_quit",
	}
	for btn_name in pairs.keys():
		var btn := home.get_node_or_null("NavColumn/%s" % btn_name) as Button
		if btn == null:
			continue
		var tex: Texture2D = _KIT.texture(str(pairs[btn_name]))
		if tex:
			btn.icon = tex
			btn.expand_icon = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("h_separation", 12)


static func _gate_modes(home: Control) -> void:
	for row in MODE_ROWS:
		var id := str(row["id"])
		var path := "ModePanel/ModeList/%sButton" % _mode_node(id)
		var btn := home.get_node_or_null(path) as Button
		if btn == null:
			continue
		var live := bool(row["live"])
		btn.disabled = not live
		if live:
			_KIT.apply_button(btn, "confirm")
			btn.tooltip_text = "Classic outdoor Host Match."
		else:
			_KIT.apply_button(btn, "normal")
			# Soft-gate: visible, not a second mode system. No placeholder overclaims.
			btn.tooltip_text = "Uses the Classic outdoor match."


static func _mode_node(id: String) -> String:
	match id:
		"classic":
			return "Classic"
		"hardcore":
			return "Hardcore"
		"custom":
			return "Custom"
		"practice":
			return "Practice"
		"friends_lobby":
			return "FriendsLobby"
		_:
			return id.capitalize()


static func _style_play(play: Control) -> void:
	var title := play.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title:
		title.text = "Classic — Host or Join"
		title.add_theme_color_override("font_color", _KIT.YELLOW)
	var status := play.get_node_or_null("VBoxContainer/StatusLabel") as Label
	if status:
		status.add_theme_color_override("font_color", _KIT.GREY)
	var host := play.get_node_or_null("VBoxContainer/HostButton") as Button
	if host:
		_KIT.apply_button(host, "confirm")
		host.text = "Host Match"
	var start := play.get_node_or_null("VBoxContainer/StartMatchButton") as Button
	if start:
		_KIT.apply_button(start, "confirm")
		start.text = "Start Match"
	for panel_name in ["MatchSettingsPanel", "PlayerListPanel"]:
		var p := play.get_node_or_null(panel_name) as Panel
		if p:
			p.add_theme_stylebox_override("panel", _KIT.panel_default())


static func _style_settings(settings: Control) -> void:
	var title := settings.get_node_or_null("TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", _KIT.YELLOW)
	for slider_path in [
		"ScrollContainer/VBoxContainer/SensitivityRow/Slider",
		"ScrollContainer/VBoxContainer/MasterVolumeRow/Slider",
		"ScrollContainer/VBoxContainer/SfxVolumeRow/Slider",
	]:
		var sl := settings.get_node_or_null(slider_path) as Slider
		if sl:
			var fill := _KIT.RED if slider_path.contains("Volume") else _KIT.YELLOW
			_KIT.apply_slider(sl, fill)
