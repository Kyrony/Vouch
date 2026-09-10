extends Control
class_name NeonHud
## K7 diegetic phone HUD. Overlays sit on functional Controls.
## PhoneRoot chrome + meters (center view stays clear). Right ItemRail
## wells are 88×80. InteractPrompt is a phone-toast. No camera switch.

const _PACK: GDScript = preload("res://scripts/horror/ui/hud_icon_pack.gd")
const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")
const _K7: GDScript = preload("res://scripts/horror/ui/k7_overlays.gd")

const RAIL_SLOTS := 5
const SLOT_PX := 88
const SLOT_H := 80
const SLOT_GAP := 12
const PHONE_W := 296
const PHONE_H := 620
const SEGMENTS := 10

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
var interact_hold: bool = false
var interact_hold_ratio: float = 0.0
var interact_action: String = "INTERACT"
var interact_sub: String = "Look / Talk"

var _built: bool = false
var _phone_root: Control
var _health_bar: TextureProgressBar
var _stamina_bar: TextureProgressBar
var _stamina_segs: Array[TextureRect] = []
var _signal_segs: Array[TextureRect] = []
var _signal_widget: Control
var _flashlight: TextureRect
var _tex_flash_on: Texture2D
var _tex_flash_off: Texture2D
var _bpm_label: Label
var _ecg_wave: Line2D
var _ability_panel: Panel
var _ability_timer: Label
var _ability_bar: ProgressBar
var _prompt_wrap: Control
var _prompt_overlay: TextureRect
var _prompt_action: Label
var _prompt_sub: Label
var _prompt_hold_bar: ProgressBar
var _tex_prompt: Texture2D
var _tex_prompt_hold: Texture2D
var _rail: VBoxContainer
var _rail_wells: Array[TextureRect] = []
var _rail_icons: Array[TextureRect] = []
var _obj_banner: Panel
var _objective_label: Label
var _objective_tween: Tween
var _tex_ability: Texture2D
var _tex_reticle: Texture2D
var _tex_slot_empty: Texture2D
var _tex_slot_selected: Texture2D
var _tex_slot_empty_selected: Texture2D
var _clock_label: Label
var _wave_t: float = 0.0


func _ready() -> void:
	name = "NeonHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR
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


func _process(delta: float) -> void:
	_wave_t += delta
	_refresh_ecg_wave()
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
		_refresh_flashlight()


func set_utility_flags(in_cover: bool, panic_spike: bool) -> void:
	hiding = in_cover
	if panic_spike:
		panic = true


func set_interact_prompt(shown: bool, action: String = "INTERACT", sub: String = "Look / Talk", hold: bool = false, hold_ratio: float = 0.0) -> void:
	interact_visible = shown
	interact_hold = hold and shown
	interact_hold_ratio = clampf(hold_ratio, 0.0, 1.0)
	if not action.is_empty():
		interact_action = action
	interact_sub = sub
	if _built:
		_refresh_prompt()


func set_interact_hold(shown: bool, action: String = "HOLD [E] · SEARCH", hold_ratio: float = 0.0) -> void:
	set_interact_prompt(shown, action, "Hold", true, hold_ratio)


func _load_textures() -> void:
	_tex_ability = _PACK.texture(_PACK.TEX_ABILITY)
	_tex_reticle = _KIT.texture("reticle_white")
	_tex_slot_empty = _K7.texture(_K7.SLOT_EMPTY)
	if _tex_slot_empty == null:
		_tex_slot_empty = _PACK.texture(_PACK.TEX_SLOT_EMPTY)
	_tex_slot_selected = _K7.texture(_K7.SLOT_SELECTED)
	if _tex_slot_selected == null:
		_tex_slot_selected = _PACK.texture(_PACK.TEX_SLOT_SELECTED)
	_tex_slot_empty_selected = _K7.texture(_K7.SLOT_EMPTY_SELECTED)
	_tex_flash_on = _K7.texture(_K7.FLASHLIGHT_ON)
	_tex_flash_off = _K7.texture(_K7.FLASHLIGHT_OFF)
	_tex_prompt = _K7.texture(_K7.PROMPT)
	_tex_prompt_hold = _K7.texture(_K7.PROMPT_HOLD)


func _overlay(name: String, tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = name
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_K7.apply_overlay_rect(rect)
	return rect


func _build() -> void:
	if _built:
		return
	_built = true
	_build_obj_banner()
	_build_phone_root()
	_build_prompt()
	_build_rail()
	_build_ability()


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


func _build_phone_root() -> void:
	_phone_root = Control.new()
	_phone_root.name = "PhoneRoot"
	_phone_root.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_phone_root.offset_left = 16
	_phone_root.offset_top = -PHONE_H - 16
	_phone_root.offset_right = 16 + PHONE_W
	_phone_root.offset_bottom = -16
	_phone_root.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.texture_filter = TEXTURE_FILTER_LINEAR
	add_child(_phone_root)

	var frame := _overlay("PhoneFrame", _K7.texture(_K7.PHONE_FRAME))
	frame.set_anchors_preset(PRESET_FULL_RECT)
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_phone_root.add_child(frame)

	# Functional fills on the phone screen; remaining chrome IGNORE-overlays on top.
	_build_phone_vitals()
	_build_phone_signal()
	_build_clock()

	var island := _overlay("IslandNotch", _K7.texture(_K7.ISLAND_NOTCH))
	island.set_anchors_preset(PRESET_CENTER_TOP)
	island.offset_left = -70
	island.offset_top = 10
	island.offset_right = 70
	island.offset_bottom = 42
	_phone_root.add_child(island)

	var notch := _overlay("PhoneNotch", _K7.texture(_K7.PHONE_NOTCH))
	notch.set_anchors_preset(PRESET_CENTER_TOP)
	notch.offset_left = -48
	notch.offset_top = 14
	notch.offset_right = 48
	notch.offset_bottom = 36
	_phone_root.add_child(notch)

	var status := _overlay("StatusBar", _K7.texture(_K7.STATUS_BAR))
	status.set_anchors_preset(PRESET_TOP_WIDE)
	status.offset_left = 18
	status.offset_top = 40
	status.offset_right = -18
	status.offset_bottom = 72
	_phone_root.add_child(status)

	var ecg := _overlay("EcgChrome", _K7.texture(_K7.ECG_CHROME))
	ecg.set_anchors_preset(PRESET_TOP_WIDE)
	ecg.offset_left = 20
	ecg.offset_top = 86
	ecg.offset_right = -20
	ecg.offset_bottom = 210
	_phone_root.add_child(ecg)
	_build_phone_ecg()

	var stam_track := _overlay("StaminaTrack", _K7.texture(_K7.STAMINA_TRACK))
	stam_track.set_anchors_preset(PRESET_TOP_WIDE)
	stam_track.offset_left = 20
	stam_track.offset_top = 218
	stam_track.offset_right = -20
	stam_track.offset_bottom = 286
	_phone_root.add_child(stam_track)
	_place_segments(_stamina_segs, stam_track, _K7.texture(_K7.STAMINA_SEGMENT), "StaminaSeg")

	var sig_track := _overlay("SignalTrack", _K7.texture(_K7.SIGNAL_TRACK))
	sig_track.set_anchors_preset(PRESET_TOP_WIDE)
	sig_track.offset_left = 20
	sig_track.offset_top = 294
	sig_track.offset_right = -20
	sig_track.offset_bottom = 362
	_signal_widget.add_child(sig_track)
	_place_segments(_signal_segs, sig_track, _K7.texture(_K7.SIGNAL_SEGMENT), "SignalSeg")

	_flashlight = _overlay("Flashlight", _tex_flash_off)
	_flashlight.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_flashlight.offset_left = -56
	_flashlight.offset_top = -118
	_flashlight.offset_right = 56
	_flashlight.offset_bottom = -82
	_phone_root.add_child(_flashlight)

	var nav := _overlay("BottomNav", _K7.texture(_K7.BOTTOM_NAV))
	nav.set_anchors_preset(PRESET_BOTTOM_WIDE)
	nav.offset_left = 18
	nav.offset_top = -78
	nav.offset_right = -18
	nav.offset_bottom = -12
	_phone_root.add_child(nav)


func _build_phone_vitals() -> void:
	var box := Control.new()
	box.name = "Vitals"
	box.set_anchors_preset(PRESET_TOP_WIDE)
	box.offset_left = 28
	box.offset_top = 118
	box.offset_right = -28
	box.offset_bottom = 280
	box.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.add_child(box)
	var col := VBoxContainer.new()
	col.name = "MeterColumn"
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	_health_bar = _make_track_meter(col, "HEALTH", _PACK.HEALTH, _PACK.TEX_HEALTH)
	_stamina_bar = _make_track_meter(col, "STAMINA", _PACK.STAMINA, _PACK.TEX_STAMINA)
	_health_bar.modulate.a = 0.0
	_stamina_bar.modulate.a = 0.0


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
	bar.custom_minimum_size = Vector2(220, 28)
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
	return bar


func _build_phone_ecg() -> void:
	_ecg_wave = Line2D.new()
	_ecg_wave.name = "EcgWave"
	_ecg_wave.width = 2.0
	_ecg_wave.default_color = Color(1.0, 0.28, 0.62, 0.95)
	_ecg_wave.antialiased = true
	_phone_root.add_child(_ecg_wave)
	_bpm_label = Label.new()
	_bpm_label.name = "BpmLabel"
	_bpm_label.set_anchors_preset(PRESET_TOP_LEFT)
	_bpm_label.offset_left = 64
	_bpm_label.offset_top = 178
	_bpm_label.offset_right = 140
	_bpm_label.offset_bottom = 204
	_bpm_label.add_theme_font_size_override("font_size", 14)
	_bpm_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	_bpm_label.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.add_child(_bpm_label)


func _build_phone_signal() -> void:
	_signal_widget = Control.new()
	_signal_widget.name = "SignalWidget"
	_signal_widget.set_anchors_preset(PRESET_TOP_WIDE)
	_signal_widget.offset_left = 20
	_signal_widget.offset_top = 294
	_signal_widget.offset_right = -20
	_signal_widget.offset_bottom = 362
	_signal_widget.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.add_child(_signal_widget)


func _place_segments(store: Array[TextureRect], track: TextureRect, tex: Texture2D, stem: String) -> void:
	var row := HBoxContainer.new()
	row.name = "%sRow" % stem
	row.set_anchors_preset(PRESET_BOTTOM_WIDE)
	row.offset_left = 14
	row.offset_top = -28
	row.offset_right = -14
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	track.add_child(row)
	store.clear()
	for i in SEGMENTS:
		var seg := TextureRect.new()
		seg.name = "%s%d" % [stem, i + 1]
		seg.texture = tex
		seg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seg.custom_minimum_size = Vector2(18, 16)
		seg.size_flags_horizontal = SIZE_EXPAND_FILL
		_K7.apply_overlay_rect(seg)
		row.add_child(seg)
		store.append(seg)


func _build_clock() -> void:
	_clock_label = Label.new()
	_clock_label.name = "MatchClockLabel"
	_clock_label.text = "6:00 PM"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_clock_label.set_anchors_preset(PRESET_TOP_LEFT)
	_clock_label.offset_left = 28
	_clock_label.offset_top = 44
	_clock_label.offset_right = 140
	_clock_label.offset_bottom = 70
	_clock_label.mouse_filter = MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.add_theme_color_override("font_color", Color(0.9, 0.91, 0.94))
	_phone_root.add_child(_clock_label)


func _build_prompt() -> void:
	_prompt_wrap = Control.new()
	_prompt_wrap.name = "InteractPrompt"
	_prompt_wrap.set_anchors_preset(PRESET_CENTER)
	_prompt_wrap.offset_left = -260
	_prompt_wrap.offset_top = 72
	_prompt_wrap.offset_right = 260
	_prompt_wrap.offset_bottom = 168
	_prompt_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	_prompt_wrap.visible = false
	add_child(_prompt_wrap)
	_prompt_overlay = _overlay("Overlay", _tex_prompt)
	_prompt_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_prompt_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_wrap.add_child(_prompt_overlay)
	_prompt_action = Label.new()
	_prompt_action.name = "Action"
	_prompt_action.set_anchors_preset(PRESET_TOP_WIDE)
	_prompt_action.offset_left = 88
	_prompt_action.offset_top = 18
	_prompt_action.offset_right = -88
	_prompt_action.offset_bottom = 48
	_prompt_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_action.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	_prompt_action.add_theme_font_size_override("font_size", 18)
	_prompt_action.mouse_filter = MOUSE_FILTER_IGNORE
	_prompt_wrap.add_child(_prompt_action)
	_prompt_sub = Label.new()
	_prompt_sub.name = "Sub"
	_prompt_sub.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_prompt_sub.offset_left = 88
	_prompt_sub.offset_top = -36
	_prompt_sub.offset_right = -88
	_prompt_sub.offset_bottom = -14
	_prompt_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_sub.add_theme_color_override("font_color", Color(1.0, 0.32, 0.72))
	_prompt_sub.add_theme_font_size_override("font_size", 12)
	_prompt_sub.mouse_filter = MOUSE_FILTER_IGNORE
	_prompt_wrap.add_child(_prompt_sub)
	_prompt_hold_bar = ProgressBar.new()
	_prompt_hold_bar.name = "HoldBar"
	_prompt_hold_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_prompt_hold_bar.offset_left = 72
	_prompt_hold_bar.offset_top = -18
	_prompt_hold_bar.offset_right = -72
	_prompt_hold_bar.offset_bottom = -10
	_prompt_hold_bar.max_value = 1.0
	_prompt_hold_bar.show_percentage = false
	_prompt_hold_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_prompt_hold_bar.add_theme_stylebox_override("background", _KIT.meter_bg(Color(0.35, 0.12, 0.28)))
	_prompt_hold_bar.add_theme_stylebox_override("fill", _KIT.meter_fill(Color(1.0, 0.28, 0.62)))
	_prompt_wrap.add_child(_prompt_hold_bar)


func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.name = "ItemRail"
	_rail.set_anchors_preset(PRESET_CENTER_RIGHT)
	_rail.offset_left = -(SLOT_PX + 10)
	_rail.offset_top = -((RAIL_SLOTS * SLOT_H + (RAIL_SLOTS - 1) * SLOT_GAP) * 0.5)
	_rail.offset_right = -10
	_rail.offset_bottom = (RAIL_SLOTS * SLOT_H + (RAIL_SLOTS - 1) * SLOT_GAP) * 0.5
	_rail.add_theme_constant_override("separation", SLOT_GAP)
	_rail.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rail)
	for i in RAIL_SLOTS:
		var cell := Control.new()
		cell.name = "RailSlot%d" % (i + 1)
		cell.custom_minimum_size = Vector2(SLOT_PX, SLOT_H)
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		var well := TextureRect.new()
		well.name = "Well"
		well.set_anchors_preset(PRESET_FULL_RECT)
		well.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		well.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		well.texture = _tex_slot_empty
		_K7.apply_overlay_rect(well)
		cell.add_child(well)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(PRESET_FULL_RECT)
		icon.offset_left = 14
		icon.offset_top = 12
		icon.offset_right = -14
		icon.offset_bottom = -12
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_LINEAR
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		_rail.add_child(cell)
		_rail_wells.append(well)
		_rail_icons.append(icon)


func _build_ability() -> void:
	_ability_panel = Panel.new()
	_ability_panel.name = "AbilityCooldown"
	_ability_panel.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_ability_panel.offset_left = 328
	_ability_panel.offset_top = -78
	_ability_panel.offset_right = 568
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
	_fill_segments(_stamina_segs, stamina_ratio)
	_refresh_flashlight()
	_refresh_signal()
	_refresh_ability()
	_refresh_prompt()
	_refresh_rail()
	_refresh_bpm()


func _refresh_bpm() -> void:
	if _bpm_label == null:
		return
	var bpm := int(round(52.0 + (1.0 - health_ratio) * 68.0 + fear_ratio * 36.0))
	_bpm_label.text = str(bpm)


func _refresh_ecg_wave() -> void:
	if _ecg_wave == null or _phone_root == null:
		return
	var origin := Vector2(36, 148)
	var w := 224.0
	var amp := 16.0 * maxf(health_ratio, 0.12)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps := 48
	for i in steps:
		var u := float(i) / float(steps - 1)
		var x := origin.x + u * w
		var phase := u * TAU * 2.2 + _wave_t * (2.4 + fear_ratio * 2.0)
		var y := origin.y
		var beat := fposmod(phase, TAU)
		if beat > 1.2 and beat < 1.7:
			var t := (beat - 1.2) / 0.5
			if t < 0.35:
				y -= amp * (t / 0.35)
			elif t < 0.55:
				y += amp * 1.15 * ((t - 0.35) / 0.2)
			else:
				y -= amp * 0.35 * (1.0 - (t - 0.55) / 0.45)
		else:
			y += sin(phase * 3.0) * 1.6
		pts.append(Vector2(x, y))
	_ecg_wave.points = pts


func _refresh_flashlight() -> void:
	if _flashlight == null:
		return
	_flashlight.texture = _tex_flash_on if phone_led_on else _tex_flash_off
	_flashlight.modulate = Color.WHITE if has_phone else Color(1, 1, 1, 0.55)


func _signal_fill() -> float:
	match signal_band:
		"full":
			return 1.0
		"weak":
			return 0.4
		"empty":
			return 0.15
		_:
			return 0.0


func _refresh_signal() -> void:
	if _signal_widget == null:
		return
	var band := signal_band
	if band.is_empty():
		band = _PACK.band_from_strength(tower_strength)
		signal_band = band
	_fill_segments(_signal_segs, _signal_fill())


func _fill_segments(rects: Array[TextureRect], ratio: float) -> void:
	var n := int(round(clampf(ratio, 0.0, 1.0) * float(SEGMENTS)))
	for i in rects.size():
		rects[i].visible = i < n
		rects[i].modulate = Color.WHITE


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
	if not interact_visible:
		return
	if interact_hold and _tex_prompt_hold:
		_prompt_overlay.texture = _tex_prompt_hold
	else:
		_prompt_overlay.texture = _tex_prompt
	_prompt_action.text = interact_action.to_upper()
	_prompt_sub.text = interact_sub
	_prompt_hold_bar.visible = interact_hold
	_prompt_hold_bar.value = interact_hold_ratio


func _rail_items() -> Array[String]:
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
		if selected and item.is_empty() and _tex_slot_empty_selected:
			_rail_wells[i].texture = _tex_slot_empty_selected
		elif selected:
			_rail_wells[i].texture = _tex_slot_selected
		else:
			_rail_wells[i].texture = _tex_slot_empty
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
