extends Control
class_name VouchBanner
## Locked main-menu wordmark: neon V + OUCH hanging on puppet strings.
## Banner form only. No puppet X, no crossbar, no thick stick through the V.

const BANNER_HAS_CROSSBAR := false
const BANNER_HAS_PUPPET_X := false
const BANNER_HAS_STICK_THROUGH_V := false
const BANNER_FORM_ONLY := true

const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")

var _tex: Texture2D


func has_forbidden_stick() -> bool:
	return BANNER_HAS_CROSSBAR or BANNER_HAS_PUPPET_X or BANNER_HAS_STICK_THROUGH_V


func is_banner_form() -> bool:
	return BANNER_FORM_ONLY and not has_forbidden_stick()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_tex = _KIT.texture("banner_vouch")
	queue_redraw()


func _draw() -> void:
	if _tex:
		var dest := Rect2(Vector2.ZERO, size)
		draw_texture_rect(_tex, dest, false)
		return
	_draw_procedural()


func _draw_procedural() -> void:
	var h := size.y
	var v_c := Vector2(h * 0.42, h * 0.62)
	var v_h := h * 0.72
	_draw_neon_v(v_c, v_h)
	var letters := ["O", "U", "C", "H"]
	var start_x := h * 0.95
	var step := h * 0.55
	for i in letters.size():
		var x := start_x + float(i) * step
		var top := Vector2(x + 18.0, 6.0)
		var hang := Vector2(x + 18.0, h * 0.36)
		# Strings only. Never a horizontal rail through the V.
		draw_line(top, hang, Color(0.94, 0.94, 0.96, 0.9), 1.4)
		draw_circle(top, 2.2, Color(0.95, 0.95, 0.97))
		draw_string(ThemeDB.fallback_font, Vector2(x, h * 0.78), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.42), _KIT.STONE)


func _draw_neon_v(center: Vector2, tall: float) -> void:
	var half := tall * 0.42
	var top_l := center + Vector2(-half, -tall * 0.5)
	var top_r := center + Vector2(half, -tall * 0.5)
	var bot := center + Vector2(0.0, tall * 0.5)
	draw_line(top_l, bot, _KIT.YELLOW, 10.0)
	draw_line(top_r, bot, _KIT.YELLOW, 10.0)
	draw_line(top_l, bot, _KIT.RED, 5.0)
	draw_line(top_r, bot, _KIT.RED, 5.0)
	# Intentionally no third stroke, no X, no crossbar above or through the V.
