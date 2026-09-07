extends Control
class_name NeonHud
## Cyberpunk neon meters: heart = health, cyan = stamina, violet = fear,
## phone + spotty mast signal. Control-node graybox only.

const NEON_HEART := Color(1.0, 0.22, 0.48)
const CYAN := Color(0.2, 0.92, 1.0)
const VIOLET := Color(0.72, 0.32, 1.0)
const PANEL := Color(0.04, 0.03, 0.07, 0.72)
const DIM := Color(0.18, 0.16, 0.24, 0.85)


var health_ratio: float = 1.0
var stamina_ratio: float = 1.0
var fear_ratio: float = 0.0
var steal_active: bool = false
var steal_duration_ratio: float = 0.0
var steal_cooldown_ratio: float = 0.0
var tower_strength: float = 0.0
var selected_slot: int = 0
var slot_labels: Array[String] = []
var show_steal: bool = false


func _ready() -> void:
	name = "NeonHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0


func _process(_delta: float) -> void:
	queue_redraw()


func set_meters(hp: float, hp_max: float, stamina: float, fear: float) -> void:
	health_ratio = clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	stamina_ratio = clampf(stamina / 100.0, 0.0, 1.0)
	fear_ratio = clampf(fear / 100.0, 0.0, 1.0)


func set_hotbar(slots: Array, selected: int) -> void:
	slot_labels.clear()
	for s in slots:
		slot_labels.append(str(s))
	selected_slot = selected


func set_steal(active: bool, duration_ratio: float, cooldown_ratio: float) -> void:
	show_steal = true
	steal_active = active
	steal_duration_ratio = clampf(duration_ratio, 0.0, 1.0)
	steal_cooldown_ratio = clampf(cooldown_ratio, 0.0, 1.0)


func set_tower_strength(value: float) -> void:
	tower_strength = clampf(value, 0.0, 1.0)


func _draw() -> void:
	_draw_panel(Rect2(12, 36, 268, 132))
	_draw_neon_heart(Vector2(52, 88), 32.0)
	_draw_cyan_stamina(Rect2(96, 52, 168, 14))
	_draw_violet_fear(Rect2(96, 74, 168, 14))
	_draw_phone_signal(Rect2(96, 100, 168, 48))
	_draw_neon_slots(Rect2(16, 628, 520, 56))
	if show_steal:
		_draw_steal_battery(Rect2(560, 36, 168, 28))


func _draw_panel(r: Rect2) -> void:
	draw_rect(r, PANEL)
	draw_rect(r, CYAN.darkened(0.45), false, 1.5)
	draw_line(r.position, r.position + Vector2(28, 0), NEON_HEART, 2.0)
	draw_line(r.end, r.end - Vector2(28, 0), VIOLET, 2.0)


func _draw_neon_heart(center: Vector2, scale: float) -> void:
	var pts := PackedVector2Array()
	for i in 36:
		var t := float(i) * TAU / 36.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(x, -y) * (scale / 18.0))
	var glow := NEON_HEART
	glow.a = 0.18 + health_ratio * 0.35
	var halo := PackedVector2Array()
	for p in pts:
		halo.append(center + (p - center) * 1.12)
	draw_colored_polygon(halo, glow)
	var fill := NEON_HEART.lerp(Color(0.12, 0.02, 0.06), 1.0 - health_ratio)
	fill.a = 0.45 + health_ratio * 0.55
	if health_ratio < 0.28:
		fill.a *= 0.55 + 0.45 * abs(sin(Time.get_ticks_msec() * 0.018))
	draw_colored_polygon(pts, fill)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], NEON_HEART.lightened(0.2), 1.8)


func _draw_cyan_stamina(r: Rect2) -> void:
	draw_rect(r, DIM)
	var fill := Rect2(r.position.x + 2, r.position.y + 2, (r.size.x - 4) * stamina_ratio, r.size.y - 4)
	draw_rect(fill, CYAN)
	draw_rect(r, CYAN.darkened(0.2), false, 1.2)


func _draw_violet_fear(r: Rect2) -> void:
	draw_rect(r, DIM)
	var fill := Rect2(r.position.x + 2, r.position.y + 2, (r.size.x - 4) * fear_ratio, r.size.y - 4)
	draw_rect(fill, VIOLET)
	draw_rect(r, VIOLET.darkened(0.15), false, 1.2)


func _draw_phone_signal(r: Rect2) -> void:
	# Handset glyph
	var body := Rect2(r.position.x + 4, r.position.y + 14, 28, 16)
	draw_rect(body, CYAN.darkened(0.35))
	draw_rect(Rect2(body.position.x - 4, body.position.y - 6, 12, 8), CYAN)
	draw_rect(Rect2(body.end.x - 8, body.position.y - 6, 12, 8), CYAN)
	# Spotty bars — mid signal drops a bar on a tick so it never looks like a clean carrier.
	var flicker := 0.0
	if tower_strength > 0.08 and tower_strength < 0.92:
		flicker = 0.22 if (int(Time.get_ticks_msec() / 280) % 3) == 0 else 0.0
	var shown := clampf(tower_strength - flicker, 0.0, 1.0)
	var base := Vector2(r.position.x + 48, r.end.y - 8)
	for i in 4:
		var h := 8.0 + float(i) * 7.0
		var on := shown > (0.12 + float(i) * 0.22)
		var col := CYAN if on else Color(0.22, 0.28, 0.34, 0.55)
		if on and i >= 2 and flicker > 0.0:
			col = CYAN.darkened(0.45)
		draw_rect(Rect2(base.x + float(i) * 14.0, base.y - h, 10, h), col)


func _draw_neon_slots(r: Rect2) -> void:
	draw_rect(r, PANEL)
	var x := r.position.x + 8
	for i in range(8):
		var cell := Rect2(x, r.position.y + 8, 58, 40)
		var selected := i == selected_slot
		var item := slot_labels[i] if i < slot_labels.size() else ""
		var border := CYAN if selected else Color(0.28, 0.32, 0.4, 0.8)
		draw_rect(cell, DIM)
		draw_rect(cell, border, false, 1.4 if selected else 1.0)
		if not item.is_empty():
			draw_string(ThemeDB.fallback_font, cell.position + Vector2(4, 26), item, HORIZONTAL_ALIGNMENT_LEFT, 50, 11, CYAN.lightened(0.1))
		x += 64


func _draw_steal_battery(r: Rect2) -> void:
	draw_rect(r, PANEL)
	draw_rect(r, NEON_HEART.darkened(0.2), false, 1.5)
	var nub := Rect2(r.end.x, r.position.y + 8, 7, r.size.y - 16)
	draw_rect(nub, NEON_HEART.darkened(0.1))
	var fill_ratio := steal_duration_ratio if steal_active else steal_cooldown_ratio
	var inner := Rect2(r.position.x + 4, r.position.y + 5, (r.size.x - 8) * fill_ratio, r.size.y - 10)
	draw_rect(inner, NEON_HEART if steal_active else CYAN.darkened(0.1))
