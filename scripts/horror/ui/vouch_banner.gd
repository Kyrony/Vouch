extends Control
class_name VouchBanner
## React wordmark: gold-gradient V + stone OUCH + hanging ticks.
## Banner form only. No puppet X, no crossbar, no stick through the V.

const BANNER_HAS_CROSSBAR := false
const BANNER_HAS_PUPPET_X := false
const BANNER_HAS_STICK_THROUGH_V := false
const BANNER_FORM_ONLY := true

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")


func has_forbidden_stick() -> bool:
	return BANNER_HAS_CROSSBAR or BANNER_HAS_PUPPET_X or BANNER_HAS_STICK_THROUGH_V


func is_banner_form() -> bool:
	return BANNER_FORM_ONLY and not has_forbidden_stick()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ui: Font = _T.ui_font()
	var stone: Font = _T.stone_font()
	var v_size := 92
	var ouch_size := 56
	var v_pos := Vector2(8, 88)
	# Dark gold under-stroke, bright gold on top — reads as a gold gradient V.
	draw_string(ui, v_pos + Vector2(2, 3), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, v_size, _T.GOLD_DIM)
	draw_string(ui, v_pos, "V", HORIZONTAL_ALIGNMENT_LEFT, -1, v_size, _T.GOLD)
	var ouch_pos := Vector2(86, 86)
	draw_string(stone, ouch_pos + Vector2(1, 1), "OUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, ouch_size, _T.STONE_DIM)
	draw_string(stone, ouch_pos, "OUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, ouch_size, _T.STONE)
	# Decorative hanging ticks under OUCH (not a puppet crossbar).
	var tick_top := ouch_pos.y + 10.0
	var widths := [42.0, 40.0, 38.0, 40.0]
	var x := ouch_pos.x + 18.0
	for i in 4:
		var len := 11.0 + float(i % 2) * 5.0
		draw_line(Vector2(x, tick_top), Vector2(x, tick_top + len), _T.GOLD_DIM, 2.0)
		draw_line(Vector2(x, tick_top), Vector2(x, tick_top + 5.0), _T.GOLD, 1.4)
		x += widths[i]
