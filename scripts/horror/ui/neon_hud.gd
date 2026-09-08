extends Control
class_name NeonHud
## Kyle-locked HUD: objective banner, stacked health-over-stamina empty
## tracks (top-left), phone LED + signal, PM cooldown, E prompt.
## No fear bar, no chips. Fill % is eng-owned via TextureProgressBar.

const _PACK: GDScript = preload("res://scripts/horror/ui/hud_icon_pack.gd")
const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")

var OBJECTIVE_TITLE: String = "MISSING CHILD"
var OBJECTIVE_TAG: String = "ALIVE ONLY"
var OBJECTIVE_SUB: String = "FIND HER. BRING HER HOME."

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
var interact_visible: bool = false
var interact_action: String = "INTERACT"
var interact_sub: String = "Look / Talk"

var _built: bool = false
var _health_bar: TextureProgressBar
var _stamina_bar: TextureProgressBar
var _health_pct: Label
var _stamina_pct: Label
var _phone_icon: TextureRect
var _phone_label: Label
var _signal_icon: TextureRect
var _signal_label: Label
var _ability_panel: Panel
var _ability_timer: Label
var _ability_bar: ProgressBar
var _prompt_wrap: Control
var _prompt_action: Label
var _prompt_sub: Label
var _hotbar: HBoxContainer
var _hotbar_cells: Array[Panel] = []
var _tex_phone: Texture2D
var _tex_ability: Texture2D
var _tex_key: Texture2D
var _tex_child: Texture2D
var _tex_reticle: Texture2D


func _ready() -> void:
	name = "NeonHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_load_textures()
	_build()
	_refresh()


func _process(_delta: float) -> void:
	queue_redraw()
	if _built:
		_refresh_ability()


func set_meters(hp: float, hp_max: float, stamina: float, fear: float) -> void:
	health_ratio = clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	stamina_ratio = clampf(stamina / 100.0, 0.0, 1.0)
	fear_ratio = clampf(fear / 100.0, 0.0, 1.0)
	panic = fear_ratio >= 0.7
	if _built:
		_refresh()


func set_hotbar(slots: Array, selected: int) -> void:
	slot_labels.clear()
	for s in slots:
		slot_labels.append(str(s))
	selected_slot = selected
	if _built:
		_refresh_hotbar()


func set_steal(active: bool, duration_ratio: float, cooldown_ratio: float) -> void:
	show_steal = true
	steal_active = active
	steal_duration_ratio = clampf(duration_ratio, 0.0, 1.0)
	steal_cooldown_ratio = clampf(cooldown_ratio, 0.0, 1.0)
	if _built:
		_refresh_ability()


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
	if _built:
		_refresh_signal()


func set_phone_device(holding: bool, battery: float, led_on: bool) -> void:
	has_phone = holding
	phone_battery = clampf(battery, 0.0, 100.0)
	phone_led_on = led_on and holding and phone_battery >= 1.0
	if _built:
		_refresh_phone()


func set_utility_flags(in_cover: bool, panic_spike: bool) -> void:
	hiding = in_cover
	if panic_spike:
		panic = true


func set_interact_prompt(shown: bool, action: String = "INTERACT", sub: String = "Look / Talk") -> void:
	interact_visible = shown
	if not action.is_empty():
		interact_action = action
	interact_sub = sub
	if _built:
		_refresh_prompt()


func _load_textures() -> void:
	_tex_phone = _PACK.texture(_PACK.TEX_PHONE_LED)
	_tex_ability = _PACK.texture(_PACK.TEX_ABILITY)
	_tex_key = _PACK.texture(_PACK.TEX_KEY_E)
	_tex_child = _PACK.texture(_PACK.TEX_MISSING_CHILD)
	_tex_reticle = _KIT.texture("reticle_white")


func _build() -> void:
	if _built:
		return
	_built = true
	_build_objective()
	_build_vitals()
	_build_prompt()
	_build_devices()
	_build_ability()
	_build_hotbar()


func _build_objective() -> void:
	var banner := Panel.new()
	banner.name = "ObjectiveBanner"
	banner.set_anchors_preset(PRESET_CENTER_TOP)
	banner.offset_left = -340
	banner.offset_top = 16
	banner.offset_right = 340
	banner.offset_bottom = 64
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _KIT.panel_focus())
	add_child(banner)
	var row := HBoxContainer.new()
	row.set_anchors_preset(PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	banner.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _tex_child
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var title := Label.new()
	title.name = "Title"
	title.text = OBJECTIVE_TITLE
	title.add_theme_color_override("font_color", _KIT.YELLOW)
	title.add_theme_font_size_override("font_size", 16)
	row.add_child(title)
	var tag := Label.new()
	tag.name = "AliveTag"
	tag.text = "  %s  " % OBJECTIVE_TAG
	tag.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	tag.add_theme_font_size_override("font_size", 11)
	var tag_bg := StyleBoxFlat.new()
	tag_bg.bg_color = Color(0.55, 0.08, 0.1, 0.95)
	tag_bg.set_corner_radius_all(8)
	tag_bg.content_margin_left = 8
	tag_bg.content_margin_right = 8
	tag.add_theme_stylebox_override("normal", tag_bg)
	row.add_child(tag)
	var sub := Label.new()
	sub.text = OBJECTIVE_SUB
	sub.add_theme_color_override("font_color", _KIT.WHITE)
	sub.add_theme_font_size_override("font_size", 12)
	row.add_child(sub)


func _build_vitals() -> void:
	var box := Control.new()
	box.name = "Vitals"
	box.set_anchors_preset(PRESET_TOP_LEFT)
	box.offset_left = 16
	box.offset_top = 16
	box.offset_right = 340
	box.offset_bottom = 88
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	var col := VBoxContainer.new()
	col.name = "MeterColumn"
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	_health_bar = _make_track_meter(col, "HEALTH", _PACK.HEALTH, _PACK.TEX_HEALTH)
	_stamina_bar = _make_track_meter(col, "STAMINA", _PACK.STAMINA, _PACK.TEX_STAMINA)


func _make_track_meter(parent: VBoxContainer, caption: String, color: Color, bar_stem: String) -> TextureProgressBar:
	var row := HBoxContainer.new()
	row.name = "%sRow" % caption.capitalize()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var bar := TextureProgressBar.new()
	bar.name = "%sBar" % caption.capitalize()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.custom_minimum_size = Vector2(260, 28)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.nine_patch_stretch = false
	var under: Texture2D = _PACK.texture(bar_stem)
	bar.texture_under = under
	var tw := 640
	var th := 52
	if under:
		tw = under.get_width()
		th = under.get_height()
	var inset := maxi(int(round(float(th) * 0.22)), 6)
	bar.texture_progress = _PACK.make_fill_texture(color, tw, th, inset)
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var pct := Label.new()
	pct.name = "%sPct" % caption.capitalize()
	pct.custom_minimum_size = Vector2(36, 0)
	pct.add_theme_color_override("font_color", color)
	pct.add_theme_font_size_override("font_size", 10)
	row.add_child(pct)
	if caption == "HEALTH":
		_health_pct = pct
	else:
		_stamina_pct = pct
	return bar


func _build_prompt() -> void:
	_prompt_wrap = Control.new()
	_prompt_wrap.name = "InteractPrompt"
	_prompt_wrap.set_anchors_preset(PRESET_CENTER)
	_prompt_wrap.offset_left = -90
	_prompt_wrap.offset_top = 28
	_prompt_wrap.offset_right = 90
	_prompt_wrap.offset_bottom = 88
	_prompt_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	_prompt_wrap.visible = false
	add_child(_prompt_wrap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(PRESET_TOP_WIDE)
	row.offset_bottom = 36
	_prompt_wrap.add_child(row)
	var key := TextureRect.new()
	key.custom_minimum_size = Vector2(28, 28)
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.texture = _tex_key
	key.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(key)
	_prompt_action = Label.new()
	_prompt_action.text = "INTERACT"
	_prompt_action.add_theme_color_override("font_color", _KIT.YELLOW)
	_prompt_action.add_theme_font_size_override("font_size", 16)
	row.add_child(_prompt_action)
	_prompt_sub = Label.new()
	_prompt_sub.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_prompt_sub.offset_top = -22
	_prompt_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_sub.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	_prompt_sub.add_theme_font_size_override("font_size", 11)
	_prompt_sub.text = "Look / Talk"
	_prompt_wrap.add_child(_prompt_sub)


func _build_devices() -> void:
	var row := HBoxContainer.new()
	row.name = "DeviceRow"
	row.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	row.offset_left = -236
	row.offset_top = -210
	row.offset_right = -16
	row.offset_bottom = -130
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	var phone := _square_device("PhonePanel", _KIT.CYAN)
	_phone_icon = phone["icon"]
	_phone_label = phone["label"]
	_phone_label.text = "PHONE"
	_phone_icon.texture = _tex_phone
	row.add_child(phone["panel"])
	var sig := _square_device("SignalPanel", _KIT.CYAN)
	_signal_icon = sig["icon"]
	_signal_label = sig["label"]
	_signal_label.text = "SIGNAL"
	row.add_child(sig["panel"])


func _square_device(node_name: String, border: Color) -> Dictionary:
	var panel := Panel.new()
	panel.name = node_name
	panel.custom_minimum_size = Vector2(104, 80)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _KIT.panel(border, 2))
	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", border)
	lab.add_theme_font_size_override("font_size", 11)
	col.add_child(lab)
	return {"panel": panel, "icon": icon, "label": lab}


func _build_ability() -> void:
	_ability_panel = Panel.new()
	_ability_panel.name = "AbilityCooldown"
	_ability_panel.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	_ability_panel.offset_left = -236
	_ability_panel.offset_top = -122
	_ability_panel.offset_right = -16
	_ability_panel.offset_bottom = -20
	_ability_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_ability_panel.visible = false
	_ability_panel.add_theme_stylebox_override("panel", _KIT.panel_violet())
	add_child(_ability_panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 6
	col.offset_bottom = -6
	_ability_panel.add_child(col)
	var head := Label.new()
	head.text = "ABILITY COOLDOWN"
	head.add_theme_color_override("font_color", _KIT.VIOLET.lightened(0.25))
	head.add_theme_font_size_override("font_size", 11)
	col.add_child(head)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	col.add_child(mid)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _tex_ability
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	mid.add_child(icon)
	_ability_timer = Label.new()
	_ability_timer.text = "READY"
	_ability_timer.add_theme_color_override("font_color", _KIT.VIOLET.lightened(0.2))
	_ability_timer.add_theme_font_size_override("font_size", 18)
	mid.add_child(_ability_timer)
	_ability_bar = ProgressBar.new()
	_ability_bar.max_value = 1.0
	_ability_bar.show_percentage = false
	_ability_bar.custom_minimum_size = Vector2(0, 10)
	_ability_bar.add_theme_stylebox_override("background", _KIT.meter_bg(_KIT.VIOLET))
	_ability_bar.add_theme_stylebox_override("fill", _KIT.meter_fill(_KIT.VIOLET))
	col.add_child(_ability_bar)


func _build_hotbar() -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_hotbar.offset_left = 16
	_hotbar.offset_top = -74
	_hotbar.offset_right = 540
	_hotbar.offset_bottom = -16
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	for i in 8:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(58, 48)
		cell.add_theme_stylebox_override("panel", _KIT.panel_default())
		var lab := Label.new()
		lab.name = "Item"
		lab.set_anchors_preset(PRESET_FULL_RECT)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 10)
		cell.add_child(lab)
		_hotbar.add_child(cell)
		_hotbar_cells.append(cell)


func _refresh() -> void:
	if _health_bar:
		_health_bar.value = health_ratio
		_health_pct.text = "%d%%" % int(round(health_ratio * 100.0))
	if _stamina_bar:
		_stamina_bar.value = stamina_ratio
		_stamina_pct.text = "%d%%" % int(round(stamina_ratio * 100.0))
	_refresh_phone()
	_refresh_signal()
	_refresh_ability()
	_refresh_prompt()
	_refresh_hotbar()


func _refresh_phone() -> void:
	if _phone_label == null:
		return
	if has_phone:
		_phone_label.text = "PHONE" if phone_led_on else "PHONE LED OFF"
		_phone_icon.modulate = _PACK.PHONE_LED if phone_led_on else _PACK.PHONE_LED.darkened(0.35)
	else:
		_phone_label.text = "PHONE"
		_phone_icon.modulate = Color(1, 1, 1, 0.45)


func _refresh_signal() -> void:
	if _signal_label == null:
		return
	var band := signal_band
	if band.is_empty():
		band = _PACK.band_from_strength(tower_strength)
	var col: Color = _PACK.signal_color(band)
	var tex: Texture2D = _PACK.signal_texture(band)
	_signal_icon.texture = tex
	var full_tex: Texture2D = _PACK.texture(_PACK.TEX_SIGNAL_FULL)
	if band != "full" and tex == full_tex:
		_signal_icon.modulate = col
	else:
		_signal_icon.modulate = Color.WHITE
	var word := "STRONG" if band == "full" else ("WEAK" if band == "weak" else "DEAD")
	_signal_label.text = "SIGNAL %s" % word
	_signal_label.add_theme_color_override("font_color", col)


func _refresh_ability() -> void:
	if _ability_panel == null:
		return
	_ability_panel.visible = show_steal
	if not show_steal:
		return
	var ratio := steal_duration_ratio if steal_active else steal_cooldown_ratio
	_ability_bar.value = ratio
	if steal_active:
		_ability_timer.text = "STEAL"
	elif ratio >= 0.99:
		_ability_timer.text = "READY"
	else:
		_ability_timer.text = "RECHARGE"


func _refresh_prompt() -> void:
	if _prompt_wrap == null:
		return
	_prompt_wrap.visible = interact_visible
	if interact_visible:
		_prompt_action.text = interact_action.to_upper()
		_prompt_sub.text = interact_sub


func _refresh_hotbar() -> void:
	for i in _hotbar_cells.size():
		var cell := _hotbar_cells[i]
		var item := slot_labels[i] if i < slot_labels.size() else ""
		var selected := i == selected_slot
		cell.add_theme_stylebox_override("panel", _KIT.panel_focus() if selected else _KIT.panel_default())
		var lab := cell.get_node("Item") as Label
		if item.is_empty():
			lab.text = ""
		else:
			lab.text = _PACK.hotbar_label(item)
			lab.add_theme_color_override("font_color", _PACK.PHONE_LED if item == "phone" else _KIT.WHITE)


func _draw() -> void:
	_draw_reticle()


func _draw_reticle() -> void:
	var c := size * 0.5
	if _tex_reticle:
		draw_texture_rect(_tex_reticle, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
		return
	draw_line(c + Vector2(0, -10), c + Vector2(0, -4), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 10), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(4, 0), c + Vector2(10, 0), Color(1, 1, 1, 0.75), 1.2)
