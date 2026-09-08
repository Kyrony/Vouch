extends RefCounted
class_name VouchMenuTheme
## Kyle React VouchMenu palette + type. Gold / blood on #050203.
## Title art lives on MenuAtmosphere (menu_title_bg.png). Does not load mansion-bg.png or modes/*.png.

const BASE := Color(0.0196078, 0.0078431, 0.0117647, 1.0) ## #050203
const GOLD := Color(0.941176, 0.768627, 0.227451, 1.0) ## #f0c43a
const GOLD_DIM := Color(0.788235, 0.635294, 0.152941, 1.0) ## #c9a227
const BLOOD := Color(0.760784, 0.0941176, 0.0941176, 1.0) ## #c21818
const BLOOD_DIM := Color(0.478431, 0.0588235, 0.0588235, 1.0) ## #7a0f0f
const STONE := Color(0.78, 0.74, 0.68, 1.0)
const STONE_DIM := Color(0.52, 0.48, 0.44, 1.0)
const PANEL := Color(0.035, 0.016, 0.02, 0.94)
const PLACEHOLDER := Color(0.0196078, 0.0078431, 0.0117647, 1.0) ## same as BASE — blank field
const WHITE := Color(0.92, 0.90, 0.86, 1.0)

const FONT_UI := "res://assets/fonts/Cinzel-Bold.ttf"
const FONT_UI_REG := "res://assets/fonts/Cinzel-Regular.ttf"
const FONT_STONE := "res://assets/fonts/SpecialElite-Regular.ttf"

const TOAST_SECONDS := 2.8

const NAV_IDS: PackedStringArray = ["play", "friends", "settings", "quit"]
const MODE_IDS: PackedStringArray = ["classic", "hardcore", "custom", "practice", "friends-lobby"]

const MODES := {
	"classic": {
		"title": "CLASSIC",
		"desc": "Neighborhood hunt. Host or join a match.",
	},
	"hardcore": {
		"title": "HARDCORE",
		"desc": "Permadeath. One life. No second chances.",
	},
	"custom": {
		"title": "CUSTOM",
		"desc": "House rules. Tune the hunt when this ships.",
	},
	"practice": {
		"title": "PRACTICE",
		"desc": "Learn the streets. No stakes.",
	},
	"friends-lobby": {
		"title": "FRIENDS LOBBY",
		"desc": "Private lobby. Invite with a code.",
	},
}


static func load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			return res as Font
	if not FileAccess.file_exists(path):
		return ThemeDB.fallback_font
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ThemeDB.fallback_font
	var ff := FontFile.new()
	ff.data = bytes
	return ff


static func ui_font() -> Font:
	return load_font(FONT_UI)


static func ui_font_reg() -> Font:
	return load_font(FONT_UI_REG)


static func stone_font() -> Font:
	return load_font(FONT_STONE)


static func box(border: Color, fill: Color, border_w: int = 1, radius: int = 2, glow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if glow:
		s.shadow_color = Color(border.r, border.g, border.b, 0.55)
		s.shadow_size = 12
	return s


static func apply_nav_button(button: Button, selected: bool) -> void:
	var idle := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	# Hover is a shake + brighter ink. Gold plate is reserved for the active nav.
	var hover := box(Color(GOLD.r, GOLD.g, GOLD.b, 0.35), Color(GOLD.r, GOLD.g, GOLD.b, 0.04), 1, 2, false)
	var active := box(GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.10), 2, 2, true)
	if selected:
		hover = active
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", active if selected else idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_override("font", ui_font())
	button.add_theme_font_size_override("font_size", 18)
	var ink := GOLD if selected else STONE
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", BLOOD)
	button.add_theme_color_override("font_focus_color", GOLD)
	var diamond := button.get_node_or_null("Row/Diamond") as Label
	if diamond:
		diamond.text = "◆"
		diamond.add_theme_color_override("font_color", BLOOD if selected else BLOOD_DIM)
		diamond.add_theme_font_size_override("font_size", 16)
	var caption := button.get_node_or_null("Row/Caption") as Label
	if caption:
		caption.add_theme_font_override("font", ui_font())
		caption.add_theme_font_size_override("font_size", 18)
		caption.add_theme_color_override("font_color", ink)
	var glyph := button.get_node_or_null("Row/Glyph") as Control
	if glyph and glyph.has_method("set_ink"):
		glyph.call("set_ink", ink)


static func apply_mode_button(button: Button, selected: bool) -> void:
	var idle := box(Color(GOLD.r, GOLD.g, GOLD.b, 0.15), Color(0.03, 0.015, 0.018, 0.55), 1)
	var active := box(GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.12), 2, 2, true)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", active if selected else idle)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("focus", active)
	var title := button.get_node_or_null("Col/Title") as Label
	var desc := button.get_node_or_null("Col/Desc") as Label
	if title:
		title.add_theme_font_override("font", ui_font())
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", GOLD if selected else STONE)
	if desc:
		desc.add_theme_font_override("font", stone_font())
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", STONE if selected else STONE_DIM)


static func apply_action_button(button: Button, kind: String = "gold") -> void:
	var border := GOLD if kind != "blood" else BLOOD
	var fill := Color(0.06, 0.03, 0.02, 0.95)
	button.add_theme_stylebox_override("normal", box(border, fill, 2, 2, true))
	button.add_theme_stylebox_override("hover", box(GOLD, Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 2, 2, true))
	button.add_theme_stylebox_override("pressed", box(BLOOD, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.18), 2, 2, true))
	button.add_theme_stylebox_override("focus", box(GOLD, fill, 2, 2, true))
	button.add_theme_font_override("font", ui_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", GOLD.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", BLOOD)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_slider(slider: Slider) -> void:
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD
	grab.set_corner_radius_all(8)
	grab.set_content_margin_all(6)
	var track := StyleBoxFlat.new()
	track.bg_color = BLOOD_DIM
	track.set_corner_radius_all(2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", track)
	slider.add_theme_stylebox_override("grabber_area_highlight", track)


static func apply_line_edit(edit: LineEdit) -> void:
	edit.add_theme_stylebox_override("normal", box(GOLD_DIM, Color(0.02, 0.01, 0.012, 0.95), 1))
	edit.add_theme_stylebox_override("focus", box(GOLD, Color(0.04, 0.02, 0.015, 0.95), 2, 2, true))
	edit.add_theme_font_override("font", stone_font())
	edit.add_theme_font_size_override("font_size", 16)
	edit.add_theme_color_override("font_color", STONE)
	edit.add_theme_color_override("font_placeholder_color", STONE_DIM)


static func apply_label(label: Label, kind: String = "body") -> void:
	match kind:
		"ui":
			label.add_theme_font_override("font", ui_font())
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", GOLD)
		"stone":
			label.add_theme_font_override("font", stone_font())
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", STONE)
		_:
			label.add_theme_font_override("font", ui_font_reg())
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", STONE)
