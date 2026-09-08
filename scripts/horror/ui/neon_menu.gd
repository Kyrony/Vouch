extends RefCounted
class_name NeonMenu
## Hybrid home: Leonardo plate is the visual. Godot only supplies hitboxes.
## Classic is the live Host Match path. Other painted modes are soft stubs.

const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")
const ART := "res://assets/horror/ui/menu_leonardo_locked.png"
const LIVE_MODE := "classic"


static func apply(lobby: Control) -> void:
	_apply_plate(lobby)
	_apply_home_hitboxes(lobby.get_node_or_null("HomePanel") as Control)
	var play := lobby.get_node_or_null("PlayPanel") as Control
	if play:
		_style_play(play)
	var settings := lobby.get_node_or_null("SettingsPanel") as Control
	if settings:
		_style_settings(settings)


static func _apply_plate(lobby: Control) -> void:
	var atmo := lobby.get_node_or_null("MenuAtmosphere")
	if atmo:
		atmo.queue_free()
	var nav := lobby.get_node_or_null("HomePanel/NavColumn")
	if nav:
		nav.queue_free()
	var banner := lobby.get_node_or_null("HomePanel/Banner")
	if banner:
		banner.visible = false
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := lobby.get_node_or_null("Background")
	if bg is ColorRect or bg == null:
		var plate := TextureRect.new()
		plate.name = "Background"
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.offset_left = 0
		plate.offset_top = 0
		plate.offset_right = 0
		plate.offset_bottom = 0
		plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
		plate.grow_vertical = Control.GROW_DIRECTION_BOTH
		if bg:
			bg.replace_by(plate)
			bg.free()
		else:
			lobby.add_child(plate)
			lobby.move_child(plate, 0)
		bg = plate
	if bg is TextureRect:
		var plate := bg as TextureRect
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if plate.texture == null and ResourceLoader.exists(ART):
			plate.texture = load(ART) as Texture2D


static func _apply_home_hitboxes(home: Control) -> void:
	if home == null:
		return
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := home.get_node_or_null("Banner")
	if banner:
		banner.visible = false
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [
		"HitboxRoot/MenuButtons/PlayButton",
		"HitboxRoot/MenuButtons/JoinFriendsButton",
		"HitboxRoot/MenuButtons/SettingsButton",
		"HitboxRoot/MenuButtons/QuitButton",
		"HitboxRoot/GameModes/ClassicButton",
		"HitboxRoot/GameModes/HardcoreButton",
		"HitboxRoot/GameModes/CustomButton",
		"HitboxRoot/GameModes/PracticeButton",
		"HitboxRoot/GameModes/FriendsLobbyButton",
	]:
		var btn := home.get_node_or_null(path) as Button
		if btn:
			_KIT.apply_invisible_hitbox(btn)
	var classic := home.get_node_or_null("HitboxRoot/GameModes/ClassicButton") as Button
	if classic:
		classic.disabled = false
		classic.tooltip_text = "Classic outdoor Host Match."
	for gated_name in ["HardcoreButton", "CustomButton", "PracticeButton", "FriendsLobbyButton"]:
		var gated := home.get_node_or_null("HitboxRoot/GameModes/%s" % gated_name) as Button
		if gated:
			gated.disabled = false
			gated.tooltip_text = "Uses the Classic outdoor match."


static func _ensure_dim(panel: Control) -> void:
	if panel.get_node_or_null("Dim") != null:
		return
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.color = Color(0.03, 0.03, 0.04, 1)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dim)
	panel.move_child(dim, 0)


static func _style_play(play: Control) -> void:
	_ensure_dim(play)
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
	for child in play.get_children():
		if child is Button:
			_KIT.apply_button(child as Button, "normal")
	var back := play.get_node_or_null("BackButton") as Button
	if back == null:
		back = play.get_node_or_null("VBoxContainer/BackButton") as Button
	if back:
		_KIT.apply_button(back, "normal")
	var join := play.get_node_or_null("VBoxContainer/JoinRow/JoinButton") as Button
	if join:
		_KIT.apply_button(join, "normal")
	for panel_name in ["MatchSettingsPanel", "PlayerListPanel"]:
		var p := play.get_node_or_null(panel_name) as Panel
		if p:
			p.add_theme_stylebox_override("panel", _KIT.panel_default())


static func _style_settings(settings: Control) -> void:
	_ensure_dim(settings)
	var title := settings.get_node_or_null("TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", _KIT.YELLOW)
	_KIT.apply_buttons(settings)
	for slider_path in [
		"ScrollContainer/VBoxContainer/SensitivityRow/Slider",
		"ScrollContainer/VBoxContainer/MasterVolumeRow/Slider",
		"ScrollContainer/VBoxContainer/SfxVolumeRow/Slider",
	]:
		var sl := settings.get_node_or_null(slider_path) as Slider
		if sl:
			var fill := _KIT.RED if slider_path.contains("Volume") else _KIT.YELLOW
			_KIT.apply_slider(sl, fill)
