extends RefCounted
class_name UiTheme
## Soft bunker UI palette — readable at 1080p, lower-saturation neon accents.


static func bg_dark() -> Color:
	return Color(0.1, 0.11, 0.13)


static func panel_bg() -> Color:
	return Color(0.14, 0.15, 0.18, 0.94)


static func text_primary() -> Color:
	return Color(0.88, 0.9, 0.93)


static func text_secondary() -> Color:
	return Color(0.62, 0.66, 0.72)


static func text_muted() -> Color:
	return Color(0.48, 0.52, 0.58)


static func accent_cyan() -> Color:
	return Color(0.45, 0.72, 0.78)


static func accent_warm() -> Color:
	return Color(0.78, 0.68, 0.52)


static func success() -> Color:
	return Color(0.52, 0.78, 0.58)


static func danger() -> Color:
	return Color(0.82, 0.48, 0.48)


static func title_font_size() -> int:
	return 28


static func heading_font_size() -> int:
	return 20


static func body_font_size() -> int:
	return 16


static func caption_font_size() -> int:
	return 13


static func style_panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = panel_bg()
	box.border_color = accent_cyan().darkened(0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func apply_label_hierarchy(label: Label, tier: String = "body") -> void:
	match tier:
		"title":
			label.add_theme_font_size_override("font_size", title_font_size())
			label.add_theme_color_override("font_color", text_primary())
		"heading":
			label.add_theme_font_size_override("font_size", heading_font_size())
			label.add_theme_color_override("font_color", text_primary())
		"caption":
			label.add_theme_font_size_override("font_size", caption_font_size())
			label.add_theme_color_override("font_color", text_muted())
		_:
			label.add_theme_font_size_override("font_size", body_font_size())
			label.add_theme_color_override("font_color", text_secondary())
