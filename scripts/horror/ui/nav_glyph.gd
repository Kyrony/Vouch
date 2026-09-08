extends Control
class_name NavGlyph
## Lucide-ish Play / Users / Settings / DoorOpen glyphs.

@export var kind: String = "play"
var ink: Color = Color(0.941, 0.769, 0.227, 1.0)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func set_ink(color: Color) -> void:
	ink = color
	queue_redraw()


func _draw() -> void:
	var c := ink
	var w := size.x
	var h := size.y
	match kind:
		"play":
			var pts := PackedVector2Array([
				Vector2(w * 0.22, h * 0.18),
				Vector2(w * 0.82, h * 0.5),
				Vector2(w * 0.22, h * 0.82),
			])
			draw_colored_polygon(pts, c)
		"users":
			draw_arc(Vector2(w * 0.36, h * 0.32), w * 0.16, 0, TAU, 16, c, 1.6)
			draw_arc(Vector2(w * 0.64, h * 0.30), w * 0.13, 0, TAU, 16, c, 1.4)
			draw_arc(Vector2(w * 0.36, h * 0.82), w * 0.28, PI, TAU, 12, c, 1.6)
			draw_arc(Vector2(w * 0.66, h * 0.80), w * 0.22, PI, TAU, 12, c, 1.4)
		"settings":
			draw_arc(Vector2(w * 0.5, h * 0.5), w * 0.16, 0, TAU, 16, c, 1.8)
			for i in 6:
				var a := float(i) * TAU / 6.0
				var inner := Vector2(w * 0.5, h * 0.5) + Vector2(cos(a), sin(a)) * w * 0.22
				var outer := Vector2(w * 0.5, h * 0.5) + Vector2(cos(a), sin(a)) * w * 0.40
				draw_line(inner, outer, c, 2.0)
		"quit":
			draw_rect(Rect2(w * 0.28, h * 0.16, w * 0.44, h * 0.68), c, false, 1.6)
			draw_line(Vector2(w * 0.50, h * 0.38), Vector2(w * 0.88, h * 0.38), c, 1.6)
			draw_line(Vector2(w * 0.74, h * 0.24), Vector2(w * 0.90, h * 0.38), c, 1.6)
			draw_line(Vector2(w * 0.74, h * 0.52), Vector2(w * 0.90, h * 0.38), c, 1.6)
		_:
			draw_rect(Rect2(2, 2, w - 4, h - 4), c, false, 1.2)
