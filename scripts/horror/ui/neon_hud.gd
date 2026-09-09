extends Control
class_name NeonHud
## Kyle-locked HUD plate (1280×720): health over stamina (bottom-left),
## cell signal at the very top-right with match time just below, 5-slot
## item rail on the right edge. Objectives toast in then fade. No battery
## widget and no persistent MISSING CHILD banner. No bottom hotbar.

const _PACK: GDScript = preload("res://scripts/horror/ui/hud_icon_pack.gd")
const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")

const RAIL_SLOTS := 5
const SLOT_PX := 72
const SLOT_GAP := 18

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
var _battery_bar: TextureProgressBar
var _battery_pct: Label
var _signal_icon: TextureRect
var _signal_label: Label
var _ability_panel: Panel
var _ability_timer: Label
var _ability_bar: ProgressBar
var _prompt_wrap: Control
var _prompt_action: Label
var _prompt_sub: Label
var _rail: VBoxContainer
var _rail_wells: Array[TextureRect] = []
var _rail_icons: Array[TextureRect] = []
var _obj_banner: Panel
var _objective_label: Label
var _objective_tween: Tween
var _tex_ability: Texture2D
var _tex_key: Texture2D
var _tex_child: Texture2D
var _tex_reticle: Texture2D
var _tex_slot_empty: Texture2D
var _tex_slot_selected: Texture2D
var _clock_label: Label
var _objective_toast: Panel
var _objective_label: Label
var _objective_tween: Tween


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
	var clock := get_node_or_null("/root/MatchClock")
	if clock and clock.has_signal("clock_updated") and not clock.clock_updated.is_connected(_on_match_clock):
		clock.clock_updated.connect(_on_match_clock)
		if clock.has_method("format_clock"):
			_on_match_clock(float(clock.call("progress")), str(clock.call("format_clock")))


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
	## Inventory hook — first 5 item/consumable wells. Not a bottom hotbar.
	slot_labels.clear()
	for s in slots:
		slot_labels.append(str(s))
	selected_slot = selected
	if _built:
		_refresh_rail()


func apply_example_rail() -> void:
	## Smoke fill matching rail_example_filled: key / firearm / crowbar+select / empty / empty.
	set_hotbar(_PACK.EXAMPLE_RAIL, _PACK.EXAMPLE_RAIL_SELECTED)


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
	if band != "full" and band != "weak" and band != "empty":
		band = "dead"
	signal_band = band
	if _built:
		_refresh_signal()


func set_phone_device(holding: bool, battery: float, led_on: bool) -> void:
	has_phone = holding
	phone_battery = clampf(battery, 0.0, 100.0)
	phone_led_on = led_on and holding and phone_battery >= 1.0
	if _built:
		_refresh_battery()


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
	_tex_ability = _PACK.texture(_PACK.TEX_ABILITY)
	_tex_key = _PACK.texture(_PACK.TEX_KEY_E)
	_tex_child = _PACK.texture(_PACK.TEX_MISSING_CHILD)
	_tex_reticle = _KIT.texture("reticle_white")
	_tex_slot_empty = _PACK.texture(_PACK.TEX_SLOT_EMPTY)
	_tex_slot_selected = _PACK.texture(_PACK.TEX_SLOT_SELECTED)


func _build() -> void:
	if _built:
		return
	_built = true
	_build_obj_banner()
	_build_clock()
	_build_vitals()
	_build_prompt()
	_build_top_right()
	_build_rail()
	_build_ability()


## Transient objective banner: pops in at top-center and fades after a few
## seconds. Call show_objective() again for the next objective as play moves on.
func _build_obj_banner() -> void:
	_obj_banner = Panel.new()
	_obj_banner.name = "ObjectiveToast"
	_obj_banner.set_anchors_preset(PRESET_CENTER_TOP)
	_obj_banner.offset_left = -320
	_obj_banner.offset_top = 20
	_obj_banner.offset_right = 320
	_obj_banner.offset_bottom = 66
	_obj_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_obj_banner.add_theme_stylebox_override("panel", _KIT.panel_focus())
	_obj_banner.visible = false
	add_child(_obj_banner)
	_objective_label = Label.new()
	_objective_label.name = "Text"
	_objective_label.set_anchors_preset(PRESET_FULL_RECT)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_color_override("font_color", _KIT.YELLOW)
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.mouse_filter = MOUSE_FILTER_IGNORE
	_obj_banner.add_child(_objective_label)


## Pop a new objective at the top of the screen; it fades out after `seconds`.
func show_objective(text: String, seconds: float = 5.0) -> void:
	if not _built:
		_build()
	if _obj_banner == null:
		return
	_objective_label.text = text
	_obj_banner.visible = true
	_obj_banner.modulate.a = 1.0
	if _objective_tween and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_tween = create_tween()
	_objective_tween.tween_interval(maxf(seconds - 0.6, 0.2))
	_objective_tween.tween_property(_obj_banner, "modulate:a", 0.0, 0.6)
	_objective_tween.tween_callback(_hide_obj_banner)


func _hide_obj_banner() -> void:
	if _obj_banner == null:
		return
	_obj_banner.visible = false
	_obj_banner.modulate.a = 1.0


func _on_match_clock(_progress: float, label: String) -> void:
	if _clock_label:
		_clock_label.text = label


func _build_clock() -> void:
	_clock_label = Label.new()
	_clock_label.name = "MatchClockLabel"
	_clock_label.text = "6:00 PM"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.set_anchors_preset(PRESET_TOP_RIGHT)
	_clock_label.offset_left = -140
	_clock_label.offset_top = 52
	_clock_label.offset_right = -12
	_clock_label.offset_bottom = 84
	_clock_label.mouse_filter = MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_size_override("font_size", 18)
	_clock_label.add_theme_color_override("font_color", _KIT.YELLOW)
	add_child(_clock_label)


func _build_vitals() -> void:
	# Health over stamina, tucked into the bottom-left corner.
	var box := Control.new()
	box.name = "Vitals"
	box.set_anchors_preset(PRESET_BOTTOM_LEFT)
	box.offset_left = 16
	box.offset_top = -84
	box.offset_right = 300
	box.offset_bottom = -16
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
	# No numeric percentage — the bar length is the readout.
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


func _build_top_right() -> void:
	var box := Control.new()
	box.name = "TopRight"
	box.set_anchors_preset(PRESET_TOP_RIGHT)
	box.offset_left = -168
	box.offset_top = 42
	box.offset_right = -16
	box.offset_bottom = 134
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	var col := VBoxContainer.new()
	col.name = "SignalBattery"
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(col)
	_build_signal_widget(col)
	# Battery widget removed from the HUD per design.


func _build_signal_widget() -> void:
	var panel := Panel.new()
	panel.name = "SignalWidget"
	panel.set_anchors_preset(PRESET_TOP_RIGHT)
	panel.offset_left = -140
	panel.offset_top = 8
	panel.offset_right = -12
	panel.offset_bottom = 48
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _KIT.panel(_KIT.GREY, 6, Color(0.02, 0.02, 0.03, 0.82)))
	add_child(panel)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	_signal_icon = TextureRect.new()
	_signal_icon.name = "SignalIcon"
	_signal_icon.custom_minimum_size = Vector2(36, 28)
	_signal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_signal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_signal_icon.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_signal_icon)
	_signal_label = Label.new()
	_signal_label.name = "SignalLabel"
	_signal_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_signal_label.add_theme_font_size_override("font_size", 10)
	row.add_child(_signal_label)


func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.name = "ItemRail"
	_rail.set_anchors_preset(PRESET_TOP_RIGHT)
	_rail.offset_left = -88
	_rail.offset_top = 96
	_rail.offset_right = -10
	_rail.offset_bottom = 96 + RAIL_SLOTS * SLOT_PX + (RAIL_SLOTS - 1) * SLOT_GAP
	_rail.add_theme_constant_override("separation", SLOT_GAP)
	_rail.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rail)
	for i in RAIL_SLOTS:
		var cell := Control.new()
		cell.name = "RailSlot%d" % (i + 1)
		cell.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		var well := TextureRect.new()
		well.name = "Well"
		well.set_anchors_preset(PRESET_FULL_RECT)
		well.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		well.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		well.texture = _tex_slot_empty
		well.mouse_filter = MOUSE_FILTER_IGNORE
		cell.add_child(well)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(PRESET_FULL_RECT)
		icon.offset_left = 12
		icon.offset_top = 12
		icon.offset_right = -12
		icon.offset_bottom = -12
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		_rail.add_child(cell)
		_rail_wells.append(well)
		_rail_icons.append(icon)


func _build_ability() -> void:
	_ability_panel = Panel.new()
	_ability_panel.name = "AbilityCooldown"
	_ability_panel.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_ability_panel.offset_left = 320
	_ability_panel.offset_top = -78
	_ability_panel.offset_right = 560
	_ability_panel.offset_bottom = -16
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


func _refresh() -> void:
	if _health_bar:
		_health_bar.value = health_ratio
	if _stamina_bar:
		_stamina_bar.value = stamina_ratio
	_refresh_battery()
	_refresh_signal()
	_refresh_ability()
	_refresh_prompt()
	_refresh_rail()


func _refresh_battery() -> void:
	if _battery_bar == null:
		return
	var ratio := clampf(phone_battery / 100.0, 0.0, 1.0)
	_battery_bar.value = ratio
	_battery_pct.text = "%d%%" % int(round(ratio * 100.0))
	_battery_bar.modulate = Color.WHITE if has_phone else Color(1, 1, 1, 0.55)
	if phone_led_on:
		_battery_bar.modulate = Color(1.05, 1.02, 0.9)


func _refresh_signal() -> void:
	if _signal_icon == null:
		return
	var band := signal_band
	if band.is_empty():
		band = _PACK.band_from_strength(tower_strength)
	var col: Color = _PACK.signal_color(band)
	var tex: Texture2D = _PACK.signal_texture(band)
	_signal_icon.texture = tex
	_signal_icon.modulate = Color.WHITE
	var word := "STRONG" if band == "full" else ("WEAK" if band == "weak" else ("EMPTY" if band == "empty" else "DEAD"))
	_signal_label.text = word
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


func _rail_items() -> Array[String]:
	## First five inventory slots, items/consumables only. Phone stays off the rail.
	var items: Array[String] = []
	for raw in slot_labels:
		var item := str(raw)
		if item == "phone":
			continue
		items.append(item)
		if items.size() >= RAIL_SLOTS:
			break
	while items.size() < RAIL_SLOTS:
		items.append("")
	return items


func _rail_selected_index() -> int:
	var compact := 0
	for i in slot_labels.size():
		var item := str(slot_labels[i])
		if item == "phone":
			continue
		if i == selected_slot:
			return compact
		compact += 1
		if compact >= RAIL_SLOTS:
			break
	if selected_slot >= 0 and selected_slot < RAIL_SLOTS and (selected_slot >= slot_labels.size() or str(slot_labels[selected_slot]) != "phone"):
		return selected_slot
	return -1


func _refresh_rail() -> void:
	if _rail == null:
		return
	var items := _rail_items()
	var sel := _rail_selected_index()
	for i in _rail_wells.size():
		var item := items[i] if i < items.size() else ""
		var selected := i == sel
		_rail_wells[i].texture = _tex_slot_selected if selected else _tex_slot_empty
		var icon_tex: Texture2D = _PACK.rail_texture(item) if not item.is_empty() else null
		_rail_icons[i].texture = icon_tex
		_rail_icons[i].visible = icon_tex != null


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
