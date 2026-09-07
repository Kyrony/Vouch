extends RefCounted
class_name NeonMenu
## Runtime cyberpunk home-screen styling — Control nodes only, no image assets.

const BG := Color(0.03, 0.03, 0.05, 1)
const MAGENTA := Color(1.0, 0.22, 0.48)
const CYAN := Color(0.2, 0.92, 1.0)
const VIOLET := Color(0.62, 0.38, 0.95)
const MUTED := Color(0.62, 0.68, 0.78)


static func apply(lobby: Control) -> void:
	var bg := lobby.get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = BG
	_ensure_frame(lobby)
	var home := lobby.get_node_or_null("HomePanel") as Control
	if home:
		_style_home(home)
	var play := lobby.get_node_or_null("PlayPanel") as Control
	if play:
		_style_play(play)
	_style_buttons(lobby)


static func _ensure_frame(lobby: Control) -> void:
	if lobby.get_node_or_null("NeonFrame") != null:
		return
	var frame := Control.new()
	frame.name = "NeonFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(frame)
	lobby.move_child(frame, 1)
	var top := ColorRect.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 3
	top.color = MAGENTA
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top)
	var bot := ColorRect.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -3
	bot.color = CYAN
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bot)


static func _style_home(home: Control) -> void:
	var title := home.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title:
		title.text = "VOUCH"
		title.add_theme_font_size_override("font_size", 52)
		title.add_theme_color_override("font_color", MAGENTA)
	var subtitle := home.get_node_or_null("VBoxContainer/SubtitleLabel") as Label
	if subtitle:
		subtitle.text = "Find the missing child. The old man is watching."
		subtitle.add_theme_color_override("font_color", MUTED)


static func _style_play(play: Control) -> void:
	var title := play.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title:
		title.text = "Host or Join"
		title.add_theme_color_override("font_color", CYAN)
	var status := play.get_node_or_null("VBoxContainer/StatusLabel") as Label
	if status:
		status.add_theme_color_override("font_color", MUTED)


static func _style_buttons(root: Node) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.96)
	style.border_color = CYAN.darkened(0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	var hover := style.duplicate()
	hover.bg_color = Color(0.16, 0.08, 0.18, 0.98)
	hover.border_color = MAGENTA
	_walk_buttons(root, style, hover)


static func _walk_buttons(node: Node, normal: StyleBox, hover: StyleBox) -> void:
	if node is Button:
		var b := node as Button
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96))
		b.add_theme_color_override("font_hover_color", MAGENTA.lightened(0.15))
	for child in node.get_children():
		_walk_buttons(child, normal, hover)
