extends Control
class_name NeonHud
## Leonardo v2 neon-horror HUD: heart / cyan pulse / violet glitch-eye /
## yellow phone LED / signal full-weak-dead. Control-node graybox + optional
## soft-go textures from assets/horror/hud.

const _PACK: GDScript = preload("res://scripts/horror/ui/hud_icon_pack.gd")

var health_ratio: float = 1.0
var stamina_ratio: float = 1.0
var fear_ratio: float = 0.0
var steal_active: bool = false
var steal_duration_ratio: float = 0.0
var steal_cooldown_ratio: float = 0.0
var tower_strength: float = 0.0
var signal_band: String = "dead"
var selected_slot: int = 0
var slot_labels: Array[String] = []
var show_steal: bool = false
var has_phone: bool = false
var phone_battery: float = 100.0
var phone_led_on: bool = false
var hiding: bool = false
var panic: bool = false

var _tex_health: Texture2D
var _tex_stamina: Texture2D
var _tex_fear: Texture2D
var _tex_phone: Texture2D
var _tex_ability: Texture2D
var _tex_hide: Texture2D
var _tex_panic: Texture2D


func _ready() -> void:
	name = "NeonHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_tex_health = _PACK.texture(_PACK.TEX_HEALTH)
	_tex_stamina = _PACK.texture(_PACK.TEX_STAMINA)
	_tex_fear = _PACK.texture(_PACK.TEX_FEAR)
	_tex_phone = _PACK.texture(_PACK.TEX_PHONE_LED)
	_tex_ability = _PACK.texture(_PACK.TEX_ABILITY)
	_tex_hide = _PACK.texture(_PACK.TEX_HIDE)
	_tex_panic = _PACK.texture(_PACK.TEX_PANIC)


func _process(_delta: float) -> void:
	queue_redraw()


func set_meters(hp: float, hp_max: float, stamina: float, fear: float) -> void:
	health_ratio = clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	stamina_ratio = clampf(stamina / 100.0, 0.0, 1.0)
	fear_ratio = clampf(fear / 100.0, 0.0, 1.0)
	panic = fear_ratio >= 0.7


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
	if signal_band.is_empty():
		signal_band = _PACK.band_from_strength(tower_strength)


func set_signal_band(band: String) -> void:
	if band == "service":
		band = "full"
	if band != "full" and band != "weak":
		band = "dead"
	signal_band = band


func set_phone_device(holding: bool, battery: float, led_on: bool) -> void:
	has_phone = holding
	phone_battery = clampf(battery, 0.0, 100.0)
	phone_led_on = led_on and holding and phone_battery >= 1.0


func set_utility_flags(in_cover: bool, panic_spike: bool) -> void:
	hiding = in_cover
	if panic_spike:
		panic = true


func _draw() -> void:
	_draw_panel(Rect2(12, 36, 300, 168))
	_draw_health_heart(Vector2(54, 92), 30.0)
	_draw_stamina_pulse(Vector2(118, 62), Rect2(150, 50, 148, 14))
	_draw_fear_eye(Vector2(118, 96), Rect2(150, 84, 148, 14))
	_draw_phone_led(Vector2(118, 136))
	_draw_signal_pack(Rect2(150, 118, 148, 40))
	if has_phone:
		_draw_battery_readout(Rect2(150, 156, 148, 16))
	_draw_neon_slots(Rect2(16, 628, 520, 56))
	if show_steal:
		_draw_ability_ring(Vector2(620, 58), 26.0)
	if hiding:
		_blit_or_draw_hide(Vector2(292, 48))
	if panic:
		_blit_or_draw_panic(Vector2(332, 48))


func _draw_panel(r: Rect2) -> void:
	draw_rect(r, _PACK.PANEL)
	draw_rect(r, _PACK.STAMINA.darkened(0.45), false, 1.5)
	draw_line(r.position, r.position + Vector2(28, 0), _PACK.HEALTH, 2.0)
	draw_line(r.end, r.end - Vector2(28, 0), _PACK.FEAR, 2.0)


func _draw_health_heart(center: Vector2, scale: float) -> void:
	if _blit(_tex_health, Rect2(center.x - 28, center.y - 30, 56, 56), Color(1, 1, 1, 0.45 + health_ratio * 0.55)):
		_draw_ekg(center, scale * 0.55)
		return
	var pts := PackedVector2Array()
	for i in 36:
		var t := float(i) * TAU / 36.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(x, -y) * (scale / 18.0))
	var glow := _PACK.HEALTH
	glow.a = 0.18 + health_ratio * 0.35
	var halo := PackedVector2Array()
	for p in pts:
		halo.append(center + (p - center) * 1.12)
	draw_colored_polygon(halo, glow)
	var fill := _PACK.HEALTH.lerp(Color(0.12, 0.02, 0.06), 1.0 - health_ratio)
	fill.a = 0.45 + health_ratio * 0.55
	if health_ratio < 0.28:
		fill.a *= 0.55 + 0.45 * abs(sin(Time.get_ticks_msec() * 0.018))
	draw_colored_polygon(pts, fill)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], _PACK.HEALTH.lightened(0.2), 1.8)
	_draw_ekg(center, scale * 0.62)
	draw_line(center + Vector2(-6, 22), center + Vector2(-4, 34), _PACK.HEALTH, 1.6)
	draw_line(center + Vector2(2, 24), center + Vector2(3, 38), _PACK.HEALTH, 1.6)


func _draw_ekg(center: Vector2, amp: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-amp, 0),
		center + Vector2(-amp * 0.35, 0),
		center + Vector2(-amp * 0.12, -amp * 0.45),
		center + Vector2(amp * 0.08, amp * 0.55),
		center + Vector2(amp * 0.28, -amp * 0.7),
		center + Vector2(amp * 0.48, amp * 0.2),
		center + Vector2(amp, 0),
	])
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(1.0, 0.78, 0.82, 0.9), 1.6)


func _draw_stamina_pulse(icon_c: Vector2, bar: Rect2) -> void:
	if not _blit(_tex_stamina, Rect2(icon_c.x - 16, icon_c.y - 16, 32, 32)):
		draw_arc(icon_c, 13.0, 0.2, TAU * 0.22, 10, _PACK.STAMINA, 1.8, true)
		draw_arc(icon_c, 13.0, TAU * 0.28, TAU * 0.47, 10, _PACK.STAMINA, 1.8, true)
		draw_arc(icon_c, 13.0, TAU * 0.53, TAU * 0.72, 10, _PACK.STAMINA, 1.8, true)
		draw_arc(icon_c, 13.0, TAU * 0.78, TAU * 0.97, 10, _PACK.STAMINA, 1.8, true)
		var wave := PackedVector2Array()
		for i in 10:
			wave.append(icon_c + Vector2(-9.0 + float(i) * 2.0, sin(float(i) * 0.7) * 4.0))
		for i in range(wave.size() - 1):
			draw_line(wave[i], wave[i + 1], _PACK.STAMINA, 1.5)
	draw_rect(bar, _PACK.DIM)
	var fill := Rect2(bar.position.x + 2, bar.position.y + 2, (bar.size.x - 4) * stamina_ratio, bar.size.y - 4)
	draw_rect(fill, _PACK.STAMINA)
	draw_rect(bar, _PACK.STAMINA.darkened(0.2), false, 1.2)


func _draw_fear_eye(icon_c: Vector2, bar: Rect2) -> void:
	if not _blit(_tex_fear, Rect2(icon_c.x - 16, icon_c.y - 16, 32, 32)):
		draw_arc(icon_c, 11.0, 0.35, PI - 0.35, 12, _PACK.FEAR, 1.7, true)
		draw_arc(icon_c, 11.0, PI + 0.35, TAU - 0.35, 12, _PACK.FEAR, 1.7, true)
		draw_circle(icon_c, 4.2, _PACK.FEAR.darkened(0.35))
		draw_circle(icon_c, 1.8, Color(0.95, 0.88, 1.0))
		var g := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		draw_line(icon_c + Vector2(-12, -3), icon_c + Vector2(12, -3), _PACK.FEAR.lightened(0.2), 1.2)
		draw_line(icon_c + Vector2(-12, 3), icon_c + Vector2(12, 3 * g), _PACK.FEAR, 1.2)
	draw_rect(bar, _PACK.DIM)
	var fill := Rect2(bar.position.x + 2, bar.position.y + 2, (bar.size.x - 4) * fear_ratio, bar.size.y - 4)
	draw_rect(fill, _PACK.FEAR)
	draw_rect(bar, _PACK.FEAR.darkened(0.15), false, 1.2)


func _draw_phone_led(center: Vector2) -> void:
	var lit := phone_led_on
	var col: Color = _PACK.PHONE_LED if (has_phone and phone_battery >= 1.0) else _PACK.PHONE_LED.darkened(0.55)
	if not has_phone:
		col.a = 0.45
	if _blit(_tex_phone, Rect2(center.x - 16, center.y - 16, 32, 32), col):
		if lit:
			draw_circle(center + Vector2(8, -8), 3.5, Color(1.0, 0.95, 0.7, 0.55))
		return
	var body := Rect2(center.x - 7, center.y - 12, 14, 24)
	draw_rect(body, Color(0.12, 0.1, 0.08, 0.95))
	draw_rect(body, col, false, 1.6)
	draw_rect(Rect2(body.position.x + 2, body.position.y + 3, 10, 16), Color(0.08, 0.02, 0.04, 0.9))
	var led_p := Vector2(body.end.x - 3, body.position.y + 4)
	draw_circle(led_p, 1.6, col)
	if lit:
		draw_line(led_p, led_p + Vector2(10, -4), col, 1.4)
		draw_line(led_p, led_p + Vector2(12, 0), col.lightened(0.3), 1.6)
		draw_line(led_p, led_p + Vector2(10, 4), col, 1.4)


func _draw_signal_pack(r: Rect2) -> void:
	var band := signal_band
	if band.is_empty():
		band = _PACK.band_from_strength(tower_strength)
	var tex: Texture2D = _PACK.signal_texture(band)
	var col: Color = _PACK.signal_color(band)
	if tex:
		draw_texture_rect(tex, Rect2(r.position, Vector2(40, 36)), false, col)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(44, 24), band.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 90, 12, col)
		return
	var bars := 5
	var lit_count := 5 if band == "full" else (2 if band == "weak" else 0)
	var base := Vector2(r.position.x + 2, r.end.y - 6)
	for i in bars:
		var h := 7.0 + float(i) * 5.5
		var on := i < lit_count
		var c := col if on else Color(0.22, 0.2, 0.24, 0.5)
		if band == "weak" and on:
			var flicker := (int(Time.get_ticks_msec() / 280) % 3) == 0 and i == 1
			if flicker:
				c = col.darkened(0.45)
		draw_rect(Rect2(base.x + float(i) * 9.0, base.y - h, 7, h), c)
	if band == "dead":
		var mid := r.position + Vector2(26, 16)
		draw_arc(mid, 9.0, 0.0, TAU, 18, _PACK.SIGNAL_DEAD, 1.8, true)
		draw_line(mid + Vector2(-6, -6), mid + Vector2(6, 6), _PACK.SIGNAL_DEAD, 2.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(52, 24), band.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 90, 12, col)


func _draw_battery_readout(r: Rect2) -> void:
	var col := _PACK.PHONE_LED if phone_battery > 15.0 else _PACK.SIGNAL_DEAD
	var body := Rect2(r.position.x, r.position.y + 3, 28, 10)
	draw_rect(body, _PACK.DIM)
	draw_rect(body, col, false, 1.1)
	draw_rect(Rect2(body.end.x, body.position.y + 2, 3, 6), col)
	var fill_w := (body.size.x - 3) * (phone_battery / 100.0)
	draw_rect(Rect2(body.position.x + 1.5, body.position.y + 2, fill_w, 6), col)
	var led := "LED" if phone_led_on else "LED OFF"
	draw_string(ThemeDB.fallback_font, r.position + Vector2(36, 13), "%d%%  %s" % [int(round(phone_battery)), led], HORIZONTAL_ALIGNMENT_LEFT, 140, 11, col)


func _draw_neon_slots(r: Rect2) -> void:
	draw_rect(r, _PACK.PANEL)
	var x := r.position.x + 8
	for i in range(8):
		var cell := Rect2(x, r.position.y + 8, 58, 40)
		var selected := i == selected_slot
		var item := slot_labels[i] if i < slot_labels.size() else ""
		var border := _PACK.STAMINA if selected else Color(0.28, 0.32, 0.4, 0.8)
		if item == "phone" and selected:
			border = _PACK.PHONE_LED
		draw_rect(cell, _PACK.DIM)
		draw_rect(cell, border, false, 1.4 if selected else 1.0)
		if not item.is_empty():
			var icon: Texture2D = _PACK.hotbar_texture(item)
			if icon:
				draw_texture_rect(icon, Rect2(cell.position + Vector2(18, 4), Vector2(22, 22)), false)
			var label: String = _PACK.hotbar_label(item)
			var lcol := _PACK.PHONE_LED if item == "phone" else _PACK.STAMINA.lightened(0.1)
			if item == "medkit" or item == "bandage":
				lcol = _PACK.HEALTH
			draw_string(ThemeDB.fallback_font, cell.position + Vector2(4, 34), label, HORIZONTAL_ALIGNMENT_LEFT, 50, 10, lcol)
		x += 64


func _draw_ability_ring(center: Vector2, radius: float) -> void:
	var ratio := steal_duration_ratio if steal_active else steal_cooldown_ratio
	var col := _PACK.HEALTH if steal_active else _PACK.GOLD
	if _tex_ability:
		draw_texture_rect(_tex_ability, Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0), false, col)
	else:
		draw_arc(center, radius, 0.2, TAU * 0.22, 8, col, 2.2, true)
		draw_arc(center, radius, TAU * 0.28, TAU * 0.47, 8, col, 2.2, true)
		draw_arc(center, radius, TAU * 0.53, TAU * 0.72, 8, col, 2.2, true)
		draw_arc(center, radius, TAU * 0.78, TAU * 0.97, 8, col, 2.2, true)
		draw_circle(center, 8.0, col.darkened(0.35))
		draw_arc(center + Vector2(-4, -1), 2.4, 0, TAU, 8, col, 1.2, true)
		draw_arc(center + Vector2(4, -1), 2.4, 0, TAU, 8, col, 1.2, true)
	draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, col, 3.0, true)
	var tag := "STEAL" if steal_active else "RECHARGE"
	draw_string(ThemeDB.fallback_font, center + Vector2(-28, radius + 16), tag, HORIZONTAL_ALIGNMENT_LEFT, 64, 11, col)


func _blit_or_draw_hide(pos: Vector2) -> void:
	if _blit(_tex_hide, Rect2(pos, Vector2(28, 28))):
		return
	draw_rect(Rect2(pos, Vector2(6, 2)), _PACK.STAMINA)
	draw_rect(Rect2(pos + Vector2(22, 0), Vector2(6, 2)), _PACK.STAMINA)
	draw_circle(pos + Vector2(14, 10), 3.2, _PACK.STAMINA)
	draw_line(pos + Vector2(14, 13), pos + Vector2(10, 24), _PACK.STAMINA, 1.6)


func _blit_or_draw_panic(pos: Vector2) -> void:
	if _blit(_tex_panic, Rect2(pos, Vector2(28, 28))):
		return
	draw_arc(pos + Vector2(14, 14), 11.0, 0, TAU, 16, _PACK.FEAR, 1.5, true)
	draw_line(pos + Vector2(4, 14), pos + Vector2(10, 8), _PACK.FEAR, 1.4)
	draw_line(pos + Vector2(10, 8), pos + Vector2(16, 22), _PACK.FEAR, 1.4)
	draw_line(pos + Vector2(16, 22), pos + Vector2(24, 12), _PACK.FEAR, 1.4)


func _blit(tex: Texture2D, dest: Rect2, modulate: Color = Color.WHITE) -> bool:
	if tex == null:
		return false
	draw_texture_rect(tex, dest, false, modulate)
	return true
