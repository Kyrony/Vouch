extends Control
class_name MenuAtmosphere
## Soft-go night yard behind the locked home screen.

const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")

var _tex: Texture2D


func _ready() -> void:
	name = "MenuAtmosphere"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_tex = _KIT.texture("menu_title_bg")
	if _tex == null:
		_tex = _KIT.texture("menu_atmosphere")
	queue_redraw()


func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.025, 0.04, 1))
	var mansion := PackedVector2Array([
		Vector2(size.x * 0.52, size.y * 0.78),
		Vector2(size.x * 0.62, size.y * 0.32),
		Vector2(size.x * 0.78, size.y * 0.32),
		Vector2(size.x * 0.88, size.y * 0.78),
	])
	draw_colored_polygon(mansion, Color(0.04, 0.035, 0.05, 1))
	draw_rect(Rect2(size.x * 0.68, size.y * 0.62, size.x * 0.04, size.y * 0.16), Color(0.18, 0.04, 0.05, 0.8))
