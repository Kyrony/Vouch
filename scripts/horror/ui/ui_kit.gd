extends RefCounted
class_name VouchUiKit
## Leonardo controls kit — StyleBoxFlat with ~12px 9-slice feel.
## Dark panels, yellow focus, red alert. Crisp corners.

const SLICE := 12
const YELLOW := Color(1.0, 0.85, 0.18)
const RED := Color(0.92, 0.16, 0.18)
const CYAN := Color(0.22, 0.92, 1.0)
const VIOLET := Color(0.73, 0.32, 1.0)
const GREY := Color(0.55, 0.58, 0.62)
const MUTED := Color(0.38, 0.40, 0.44)
const WHITE := Color(0.92, 0.93, 0.95)
const STONE := Color(0.88, 0.86, 0.82)
const PANEL_BG := Color(0.045, 0.04, 0.055, 0.92)
const PANEL_DIM := Color(0.03, 0.028, 0.04, 0.88)
const DIR := "res://assets/horror/ui"


static func panel(border: Color, radius: int = 2, fill: Color = PANEL_BG) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = SLICE
	box.content_margin_right = SLICE
	box.content_margin_top = SLICE
	box.content_margin_bottom = SLICE
	return box


static func panel_default() -> StyleBoxFlat:
	return panel(GREY)


static func panel_focus() -> StyleBoxFlat:
	return panel(YELLOW)


static func panel_alert() -> StyleBoxFlat:
	return panel(RED)


static func panel_cyan() -> StyleBoxFlat:
	return panel(CYAN)


static func panel_violet() -> StyleBoxFlat:
	return panel(VIOLET)


static func button_style(border: Color, fill: Color = PANEL_DIM) -> StyleBoxFlat:
	var box := panel(border, 2, fill)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func invisible_hitbox() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func glow_box(border: Color, fill_alpha: float = 0.08, glow: float = 10.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(border.r, border.g, border.b, fill_alpha)
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.shadow_color = Color(border.r, border.g, border.b, 0.62)
	box.shadow_size = int(glow)
	box.shadow_offset = Vector2.ZERO
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func apply_plate_hitbox(button: Button, selected: bool = false) -> void:
	var idle := glow_box(Color(0.55, 0.58, 0.62, 0.45), 0.05, 0.0)
	idle.set_border_width_all(1)
	idle.shadow_size = 0
	var hover := glow_box(YELLOW, 0.10, 12.0)
	var pressed := glow_box(RED, 0.12, 10.0)
	var focus := glow_box(YELLOW, 0.10, 12.0)
	if selected:
		idle = glow_box(YELLOW, 0.12, 12.0)
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.icon = null
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", idle)
	var clear := Color(1, 1, 1, 0)
	button.add_theme_color_override("font_color", clear)
	button.add_theme_color_override("font_hover_color", clear)
	button.add_theme_color_override("font_pressed_color", clear)
	button.add_theme_color_override("font_focus_color", clear)
	button.add_theme_color_override("font_disabled_color", clear)
	button.add_theme_color_override("icon_normal_color", clear)
	button.add_theme_color_override("icon_hover_color", clear)


static func apply_invisible_hitbox(button: Button) -> void:
	apply_plate_hitbox(button, false)


static func apply_button(button: Button, kind: String = "normal") -> void:
	var normal := button_style(GREY)
	var hover := button_style(YELLOW, Color(0.08, 0.07, 0.04, 0.95))
	var pressed := button_style(RED, Color(0.12, 0.04, 0.05, 0.96))
	var disabled := button_style(MUTED, Color(0.04, 0.04, 0.05, 0.7))
	match kind:
		"confirm":
			normal = button_style(YELLOW)
			button.add_theme_color_override("font_color", YELLOW)
		"destruct":
			normal = button_style(RED)
			button.add_theme_color_override("font_color", RED)
		"nav_focus":
			normal = button_style(YELLOW)
			button.add_theme_color_override("font_color", YELLOW)
		_:
			button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_hover_color", YELLOW.lightened(0.1))
	button.add_theme_color_override("font_pressed_color", RED)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_focus_color", YELLOW)


static func apply_buttons(root: Node, skip_names: Array = []) -> void:
	if root is Button:
		var b := root as Button
		if not skip_names.has(b.name):
			apply_button(b, "normal")
	for child in root.get_children():
		apply_buttons(child, skip_names)


static func slider_style(fill: Color) -> Dictionary:
	var grab := StyleBoxFlat.new()
	grab.bg_color = fill
	grab.set_corner_radius_all(8)
	grab.set_content_margin_all(6)
	var slide := StyleBoxFlat.new()
	slide.bg_color = fill.darkened(0.55)
	slide.set_corner_radius_all(2)
	slide.content_margin_top = 4
	slide.content_margin_bottom = 4
	return {"grabber_area": slide, "slider": slide}


static func apply_slider(slider: Slider, fill: Color) -> void:
	var bits: Dictionary = slider_style(fill)
	slider.add_theme_stylebox_override("slider", bits["slider"])
	slider.add_theme_stylebox_override("grabber_area", bits["grabber_area"])
	slider.add_theme_stylebox_override("grabber_area_highlight", bits["grabber_area"])


static func texture(stem: String) -> Texture2D:
	var path := "%s/%s.png" % [DIR, stem]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func meter_fill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	return box


static func meter_bg(border: Color) -> StyleBoxFlat:
	var box := panel(border, 2, Color(0.06, 0.05, 0.08, 0.9))
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
