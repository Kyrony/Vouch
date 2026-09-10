extends Control
class_name NeonHud
## K7 diegetic phone HUD. The phone IS the HUD (chrome v2).
## Holstered PhoneRoot sits bottom-left. Hold E with the phone in-hand
## inspects it center-screen. Right ItemRail wells are 88×80.
## InteractPrompt is a phone-toast. Rear/Front camera chrome is visual only.

const _PACK: GDScript = preload("res://scripts/horror/ui/hud_icon_pack.gd")
const _KIT: GDScript = preload("res://scripts/horror/ui/ui_kit.gd")
const _K7: GDScript = preload("res://scripts/horror/ui/k7_overlays.gd")

const RAIL_SLOTS := 5
const SLOT_PX := 88
const SLOT_H := 80
const SLOT_GAP := 12
const PHONE_W := 348
const PHONE_H := 620
const INSPECT_W := 430
const INSPECT_H := 680
const SEGMENTS := 10
const ECG_SAMPLES := 320
## Seconds of ECG paper on-screen. ~2 beats at rest so the TP flatline reads.
const ECG_WINDOW := 2.15
const PINK := Color(1.0, 0.28, 0.62)
const CARD := Color(0.07, 0.07, 0.09, 0.96)

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
var inspecting: bool = false

var _built: bool = false
var _phone_root: Control
var _inspect_dim: ColorRect
var _health_bar: TextureProgressBar
var _stamina_bar: TextureProgressBar
var _stamina_segs: Array[Control] = []
var _signal_segs: Array[Control] = []
var _signal_widget: Control
var _flashlight: TextureRect
var _flash_state: Label
var _flash_track: Panel
var _flash_knob: Panel
var _status_battery: Label
var _status_wifi: Control
var _header_signal: Control
var _signal_state: Label
var _tex_flash_on: Texture2D
var _tex_flash_off: Texture2D
var _bpm_label: Label
var _ecg_wave: Line2D
var _ecg_glow: Line2D
var _ecg_plot: Control
var _ecg_baseline: ColorRect
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
var _inspect_tween: Tween


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
	_refresh_ecg_wave(delta)
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


func set_phone_inspect(on: bool) -> void:
	inspecting = on
	if not _built:
		_build()
	if _inspect_dim:
		_inspect_dim.visible = on
	if _rail:
		_rail.visible = not on
	if _prompt_wrap and on:
		_prompt_wrap.visible = false
	_layout_phone(on)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_phone(inspecting)


func _inspect_phone_size() -> Vector2:
	## Hold-E read mode: scale the phone up, keep tall-phone aspect, fill height.
	var vp := get_viewport_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return Vector2(INSPECT_W, INSPECT_H)
	var aspect := float(PHONE_W) / float(PHONE_H)
	var s := minf(vp.y * 0.96 / float(PHONE_H), vp.x * 0.52 / float(PHONE_W))
	s = maxf(s, 1.15)
	var w := float(PHONE_W) * s
	var h := float(PHONE_H) * s
	if h > vp.y * 0.94:
		h = vp.y * 0.94
		w = h * aspect
	if w > vp.x * 0.55:
		w = vp.x * 0.55
		h = w / aspect
	return Vector2(w, h)


func _layout_phone(inspect: bool) -> void:
	if _phone_root == null:
		return
	if inspect:
		var sz := _inspect_phone_size()
		var s := sz.y / float(PHONE_H)
		_phone_root.scale = Vector2(s, s)
		_phone_root.pivot_offset = Vector2(PHONE_W * 0.5, PHONE_H * 0.5)
		_phone_root.z_index = 40
		_phone_root.set_anchors_preset(PRESET_CENTER)
		_phone_root.offset_left = -PHONE_W * 0.5
		_phone_root.offset_top = -PHONE_H * 0.5
		_phone_root.offset_right = PHONE_W * 0.5
		_phone_root.offset_bottom = PHONE_H * 0.5
	else:
		_phone_root.scale = Vector2.ONE
		_phone_root.pivot_offset = Vector2.ZERO
		_phone_root.z_index = 0
		_phone_root.set_anchors_preset(PRESET_BOTTOM_LEFT)
		_phone_root.offset_left = 16
		_phone_root.offset_top = -PHONE_H - 16
		_phone_root.offset_right = 16 + PHONE_W
		_phone_root.offset_bottom = -16


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
	_inspect_dim = ColorRect.new()
	_inspect_dim.name = "InspectDim"
	_inspect_dim.set_anchors_preset(PRESET_FULL_RECT)
	_inspect_dim.color = Color(0, 0, 0, 0.72)
	_inspect_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_inspect_dim.visible = false
	add_child(_inspect_dim)
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
	_phone_root.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.texture_filter = TEXTURE_FILTER_LINEAR
	_phone_root.clip_contents = true
	_layout_phone(false)
	add_child(_phone_root)

	var bezel := Panel.new()
	bezel.name = "PhoneFrame"
	bezel.set_anchors_preset(PRESET_FULL_RECT)
	bezel.mouse_filter = MOUSE_FILTER_IGNORE
	bezel.add_theme_stylebox_override("panel", _phone_bezel())
	_phone_root.add_child(bezel)

	var island := Panel.new()
	island.name = "IslandNotch"
	island.set_anchors_preset(PRESET_CENTER_TOP)
	island.offset_left = -42
	island.offset_top = 10
	island.offset_right = 42
	island.offset_bottom = 24
	island.mouse_filter = MOUSE_FILTER_IGNORE
	island.add_theme_stylebox_override("panel", _pill(Color(0.04, 0.04, 0.05)))
	_phone_root.add_child(island)

	var screen := MarginContainer.new()
	screen.name = "Screen"
	screen.set_anchors_preset(PRESET_FULL_RECT)
	screen.add_theme_constant_override("margin_left", 14)
	screen.add_theme_constant_override("margin_right", 14)
	screen.add_theme_constant_override("margin_top", 26)
	screen.add_theme_constant_override("margin_bottom", 14)
	screen.mouse_filter = MOUSE_FILTER_IGNORE
	_phone_root.add_child(screen)

	var col := VBoxContainer.new()
	col.name = "ScreenColumn"
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	screen.add_child(col)

	_build_status_row(col)
	_build_camera_header(col)
	_build_camera_card(col)
	_build_flashlight_card(col)
	_build_vitals_row(col)
	_build_phone_vitals()
	var spacer := Control.new()
	spacer.name = "NavSpacer"
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_build_bottom_nav(col)


func _build_status_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "StatusBar"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)
	_clock_label = Label.new()
	_clock_label.name = "MatchClockLabel"
	_clock_label.text = "6:00 PM"
	_clock_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	_clock_label.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_clock_label)
	var status_right := HBoxContainer.new()
	status_right.add_theme_constant_override("separation", 6)
	status_right.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(status_right)
	_status_wifi = _glyph("wifi", Color(0.78, 0.8, 0.84), Vector2(16, 12))
	_status_wifi.name = "StatusWifi"
	status_right.add_child(_status_wifi)
	_status_battery = Label.new()
	_status_battery.name = "StatusBattery"
	_status_battery.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_battery.add_theme_font_size_override("font_size", 12)
	_status_battery.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	_status_battery.mouse_filter = MOUSE_FILTER_IGNORE
	status_right.add_child(_status_battery)


func _build_camera_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "CameraHeader"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	left.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(left)
	var cam := _phone_label("CAMERA", 16, Color.WHITE)
	cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(cam)
	var live := _phone_label("● LIVE", 10, PINK)
	live.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(live)
	var right := VBoxContainer.new()
	right.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(right)
	var rear := _phone_label("REAR CAMERA", 10, Color(0.7, 0.72, 0.76))
	rear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(rear)
	_header_signal = _glyph("signal", Color(0.35, 0.95, 0.45), Vector2(16, 12))
	_header_signal.name = "HeaderSignal"
	_header_signal.size_flags_horizontal = SIZE_SHRINK_END
	right.add_child(_header_signal)


func _build_camera_card(parent: VBoxContainer) -> void:
	var card := _phone_card("CameraSwitch")
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	copy.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(_phone_label("CAMERA SWITCH", 12, Color.WHITE))
	copy.add_child(_phone_label("Toggle rear and front camera", 10, Color(0.55, 0.56, 0.6)))
	row.add_child(_cam_chip("REAR", "camera", true))
	row.add_child(_cam_chip("FRONT", "person", false))


func _build_flashlight_card(parent: VBoxContainer) -> void:
	var card := _phone_card("FlashlightCard")
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	copy.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(_phone_label("FLASHLIGHT", 12, Color.WHITE))
	copy.add_child(_phone_label("Hold phone · press R", 10, Color(0.55, 0.56, 0.6)))
	var switch_wrap := Control.new()
	switch_wrap.name = "LedSwitch"
	switch_wrap.custom_minimum_size = Vector2(64, 30)
	switch_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(switch_wrap)
	_flash_track = Panel.new()
	_flash_track.name = "Track"
	_flash_track.set_anchors_preset(PRESET_FULL_RECT)
	_flash_track.offset_top = 2
	_flash_track.offset_bottom = -2
	_flash_track.mouse_filter = MOUSE_FILTER_IGNORE
	switch_wrap.add_child(_flash_track)
	_flash_knob = Panel.new()
	_flash_knob.name = "Knob"
	_flash_knob.mouse_filter = MOUSE_FILTER_IGNORE
	switch_wrap.add_child(_flash_knob)
	_flashlight = TextureRect.new()
	_flashlight.name = "Flashlight"
	_flashlight.set_anchors_preset(PRESET_FULL_RECT)
	_flashlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flashlight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flashlight.mouse_filter = MOUSE_FILTER_IGNORE
	switch_wrap.add_child(_flashlight)
	_flash_state = _phone_label("OFF", 14, Color.WHITE)
	_flash_state.name = "FlashState"
	row.add_child(_flash_state)


func _build_vitals_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "VitalsRow"
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var ecg_card := _phone_card("EcgChrome")
	ecg_card.size_flags_horizontal = SIZE_EXPAND_FILL
	ecg_card.custom_minimum_size = Vector2(0, 86)
	row.add_child(ecg_card)
	var ecg_col := VBoxContainer.new()
	ecg_col.add_theme_constant_override("separation", 2)
	ecg_col.mouse_filter = MOUSE_FILTER_IGNORE
	ecg_card.add_child(ecg_col)
	var ecg_head := HBoxContainer.new()
	ecg_head.mouse_filter = MOUSE_FILTER_IGNORE
	ecg_col.add_child(ecg_head)
	ecg_head.add_child(_phone_label("ECG", 10, PINK))
	_bpm_label = _phone_label("72 BPM", 12, PINK)
	_bpm_label.name = "BpmLabel"
	_bpm_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ecg_head.add_child(_bpm_label)
	_ecg_plot = Control.new()
	_ecg_plot.name = "EcgPlot"
	_ecg_plot.custom_minimum_size = Vector2(0, 52)
	_ecg_plot.size_flags_vertical = SIZE_FILL
	_ecg_plot.clip_contents = true
	_ecg_plot.mouse_filter = MOUSE_FILTER_IGNORE
	ecg_col.add_child(_ecg_plot)
	_ecg_baseline = ColorRect.new()
	_ecg_baseline.name = "Isoelectric"
	_ecg_baseline.color = Color(PINK.r, PINK.g, PINK.b, 0.16)
	_ecg_baseline.mouse_filter = MOUSE_FILTER_IGNORE
	_ecg_plot.add_child(_ecg_baseline)
	_ecg_glow = Line2D.new()
	_ecg_glow.name = "EcgGlow"
	_ecg_glow.width = 5.5
	_ecg_glow.default_color = Color(1.0, 0.28, 0.62, 0.22)
	_ecg_glow.antialiased = true
	_ecg_glow.joint_mode = Line2D.LINE_JOINT_SHARP
	_ecg_plot.add_child(_ecg_glow)
	_ecg_wave = Line2D.new()
	_ecg_wave.name = "EcgWave"
	_ecg_wave.width = 2.15
	_ecg_wave.default_color = PINK
	_ecg_wave.antialiased = true
	_ecg_wave.joint_mode = Line2D.LINE_JOINT_SHARP
	_ecg_plot.add_child(_ecg_wave)

	var stam_card := _phone_card("StaminaTrack")
	stam_card.custom_minimum_size = Vector2(78, 78)
	row.add_child(stam_card)
	var stam_col := VBoxContainer.new()
	stam_col.mouse_filter = MOUSE_FILTER_IGNORE
	stam_card.add_child(stam_col)
	stam_col.add_child(_phone_label("STAMINA", 10, Color(1.0, 0.82, 0.2)))
	_place_segments(_stamina_segs, stam_col, null, "StaminaSeg")

	_build_phone_signal()
	_signal_widget.custom_minimum_size = Vector2(72, 78)
	row.add_child(_signal_widget)


func _phone_bezel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.07, 0.97)
	box.border_color = Color(0.18, 0.18, 0.22)
	box.set_border_width_all(2)
	box.set_corner_radius_all(28)
	box.shadow_color = Color(1.0, 0.2, 0.55, 0.18)
	box.shadow_size = 8
	return box


func _pill(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(10)
	return box


func _phone_card(node_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.mouse_filter = MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = CARD
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", box)
	return card


func _phone_label(text: String, size: int, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = MOUSE_FILTER_IGNORE
	return lab


func _cam_chip(text: String, icon: String, on: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.08, 0.12)
	box.border_color = PINK if on else Color(0.22, 0.22, 0.26)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	chip.add_child(col)
	var ink := PINK if on else Color(0.7, 0.7, 0.74)
	var glyph := _glyph(icon, ink, Vector2(22, 16))
	glyph.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(glyph)
	var lab := _phone_label(text, 9, ink)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lab)
	return chip


func _glyph(kind: String, ink: Color, px: Vector2) -> Control:
	var g := Control.new()
	g.custom_minimum_size = px
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.set_meta("kind", kind)
	g.set_meta("ink", ink)
	g.draw.connect(_draw_glyph.bind(g))
	return g


func _draw_glyph(g: Control) -> void:
	if g == null:
		return
	var kind := str(g.get_meta("kind"))
	var ink: Color = g.get_meta("ink")
	var w := g.size.x
	var h := g.size.y
	match kind:
		"grid":
			var s := minf(w, h) * 0.32
			var gap := minf(w, h) * 0.14
			var ox := (w - s * 2.0 - gap) * 0.5
			var oy := (h - s * 2.0 - gap) * 0.5
			g.draw_rect(Rect2(ox, oy, s, s), ink, false, 1.4)
			g.draw_rect(Rect2(ox + s + gap, oy, s, s), ink, false, 1.4)
			g.draw_rect(Rect2(ox, oy + s + gap, s, s), ink, false, 1.4)
			g.draw_rect(Rect2(ox + s + gap, oy + s + gap, s, s), ink, false, 1.4)
		"heart":
			var c := Vector2(w * 0.5, h * 0.42)
			g.draw_circle(c + Vector2(-w * 0.16, 0.0), h * 0.18, ink)
			g.draw_circle(c + Vector2(w * 0.16, 0.0), h * 0.18, ink)
			var pts := PackedVector2Array([
				Vector2(w * 0.18, h * 0.48),
				Vector2(w * 0.5, h * 0.92),
				Vector2(w * 0.82, h * 0.48),
			])
			g.draw_colored_polygon(pts, ink)
		"person":
			g.draw_circle(Vector2(w * 0.5, h * 0.28), h * 0.16, ink)
			g.draw_arc(Vector2(w * 0.5, h * 1.05), w * 0.32, PI * 1.15, PI * 1.85, 12, ink, 1.6, true)
		"gear":
			g.draw_arc(Vector2(w * 0.5, h * 0.5), minf(w, h) * 0.22, 0.0, TAU, 16, ink, 1.5, true)
			for i in 4:
				var a := float(i) * TAU * 0.25
				var inner := Vector2(w, h) * 0.5 + Vector2(cos(a), sin(a)) * minf(w, h) * 0.18
				var outer := Vector2(w, h) * 0.5 + Vector2(cos(a), sin(a)) * minf(w, h) * 0.42
				g.draw_line(inner, outer, ink, 1.6, true)
		"camera":
			g.draw_rect(Rect2(w * 0.12, h * 0.28, w * 0.76, h * 0.52), ink, false, 1.4)
			g.draw_circle(Vector2(w * 0.5, h * 0.54), h * 0.16, ink)
			g.draw_rect(Rect2(w * 0.58, h * 0.16, w * 0.18, h * 0.14), ink)
		"wifi", "signal":
			var n := 4
			var bar_w := w / 7.0
			for i in n:
				var bh := h * (0.35 + 0.22 * float(i))
				var x := 2.0 + (bar_w * 1.6) * float(i)
				g.draw_rect(Rect2(x, h - bh, bar_w, bh), ink)
		_:
			pass


func _build_bottom_nav(parent: VBoxContainer) -> void:
	var nav := HBoxContainer.new()
	nav.name = "BottomNav"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	nav.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(nav)
	for item in [["GRID", "grid", true], ["ECG", "heart", false], ["PROFILE", "person", false], ["SETTINGS", "gear", false]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		nav.add_child(cell)
		var on := bool(item[2])
		var ink := PINK if on else Color(0.55, 0.56, 0.6)
		var icon := _glyph(str(item[1]), ink, Vector2(20, 18))
		icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var lab := _phone_label(str(item[0]), 9, ink)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(lab)
		if on:
			var underline := ColorRect.new()
			underline.custom_minimum_size = Vector2(28, 2)
			underline.color = PINK
			underline.mouse_filter = MOUSE_FILTER_IGNORE
			cell.add_child(underline)


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
	box.visible = false


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


func _build_phone_signal() -> void:
	_signal_widget = _phone_card("SignalWidget")
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_signal_widget.add_child(col)
	col.add_child(_phone_label("SIGNAL", 10, Color(0.35, 0.95, 0.45)))
	_place_segments(_signal_segs, col, null, "SignalSeg")
	_signal_state = _phone_label("DEAD", 10, Color(0.55, 0.56, 0.6))
	_signal_state.name = "SignalState"
	_signal_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_signal_state)


func _place_segments(store: Array[Control], parent: Control, _tex: Texture2D, stem: String) -> void:
	var row := HBoxContainer.new()
	row.name = "%sRow" % stem
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)
	store.clear()
	var on := Color(1.0, 0.82, 0.2) if stem.begins_with("Stamina") else Color(0.25, 0.92, 0.38)
	for i in SEGMENTS:
		var seg := ColorRect.new()
		seg.name = "%s%d" % [stem, i + 1]
		seg.custom_minimum_size = Vector2(6, 16)
		seg.color = on
		seg.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(seg)
		store.append(seg)


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
	if _status_battery:
		_status_battery.text = "%d%%" % int(round(phone_battery))


func _bpm_value() -> float:
	return clampf(72.0 + (1.0 - health_ratio) * 48.0 + fear_ratio * 28.0, 42.0, 170.0)


func _refresh_bpm() -> void:
	if _bpm_label == null:
		return
	if health_ratio <= 0.04:
		_bpm_label.text = "FLAT"
		return
	_bpm_label.text = "%d BPM" % int(round(_bpm_value()))


func _refresh_ecg_wave(_delta: float = 0.016) -> void:
	## Scrolling lead-II paper: sharp QRS, then a long isoelectric TP flatline.
	if _ecg_wave == null or _ecg_plot == null:
		return
	var bpm := _bpm_value()
	var sz := _ecg_plot.size
	if sz.x < 8.0 or sz.y < 8.0:
		sz = Vector2(160, 56)
	var baseline := sz.y * 0.64
	var amp := sz.y * 0.46
	if _ecg_baseline:
		_ecg_baseline.position = Vector2(0, baseline)
		_ecg_baseline.size = Vector2(sz.x, 1)
	var pts: PackedVector2Array = PackedVector2Array()
	var last := float(ECG_SAMPLES - 1)
	for i in ECG_SAMPLES:
		var t := _wave_t - ECG_WINDOW * (1.0 - float(i) / last)
		var x := sz.x * float(i) / last
		var y := baseline - _lead_ii_sample(t, bpm, health_ratio) * amp
		pts.append(Vector2(x, y))
	_ecg_wave.points = pts
	if _ecg_glow:
		_ecg_glow.points = pts


func _lead_ii_sample(time_s: float, bpm: float, hp: float) -> float:
	## Resting lead II. Intervals in seconds, then TP isoelectric until the next P.
	## R peak is at 0.20s into the RR at 72 BPM so probes can lock the shape.
	if hp <= 0.04:
		return 0.0
	var period := 60.0 / maxf(bpm, 30.0)
	var t := fposmod(time_s, period)
	var p_dur := 0.08
	var qrs_start := 0.16
	var qrs_dur := 0.10
	var st_dur := 0.10
	var t_dur := 0.16
	var complex_end := qrs_start + qrs_dur + st_dur + t_dur
	if complex_end > period * 0.70:
		var scale := (period * 0.70) / complex_end
		p_dur *= scale
		qrs_start *= scale
		qrs_dur *= scale
		st_dur *= scale
		t_dur *= scale
		complex_end = qrs_start + qrs_dur + st_dur + t_dur
	var y := 0.0
	if t < qrs_start:
		var p_mu := p_dur * 0.5
		y = 0.11 * _gauss(t, p_mu, p_dur * 0.24)
	elif t < qrs_start + qrs_dur:
		var u := (t - qrs_start) / qrs_dur
		if u < 0.16:
			y = lerpf(0.0, -0.16, u / 0.16)
		elif u < 0.40:
			y = lerpf(-0.16, 1.12, (u - 0.16) / 0.24)
		elif u < 0.62:
			y = lerpf(1.12, -0.38, (u - 0.40) / 0.22)
		else:
			y = lerpf(-0.38, 0.0, (u - 0.62) / 0.38)
	elif t < qrs_start + qrs_dur + st_dur:
		y = 0.0
	elif t < complex_end:
		var u := (t - (qrs_start + qrs_dur + st_dur)) / maxf(t_dur, 0.001)
		var sig := 0.20 if u < 0.45 else 0.28
		y = 0.24 * _gauss(u, 0.45, sig)
	else:
		y = 0.0
	if hp < 0.28:
		y *= 0.45 + hp
	return y


func _gauss(t: float, mu: float, sigma: float) -> float:
	var d := (t - mu) / maxf(sigma, 0.001)
	return exp(-0.5 * d * d)


func _refresh_flashlight() -> void:
	var on := phone_led_on
	if _flashlight:
		_flashlight.texture = _tex_flash_on if on else _tex_flash_off
		_flashlight.visible = _flashlight.texture != null
		_flashlight.modulate = Color.WHITE if has_phone else Color(1, 1, 1, 0.55)
	if _flash_track:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.72, 0.22, 0.85) if on else Color(0.22, 0.22, 0.26)
		track.set_corner_radius_all(14)
		_flash_track.add_theme_stylebox_override("panel", track)
		_flash_track.visible = _flashlight == null or _flashlight.texture == null
	if _flash_knob:
		var knob := StyleBoxFlat.new()
		knob.bg_color = Color.WHITE
		knob.set_corner_radius_all(11)
		_flash_knob.add_theme_stylebox_override("panel", knob)
		var wrap_w := 64.0
		if _flash_track and _flash_track.get_parent() is Control:
			wrap_w = maxf((_flash_track.get_parent() as Control).size.x, 64.0)
		_flash_knob.size = Vector2(24, 24)
		_flash_knob.position = Vector2(wrap_w - 28 if on else 4, 3)
		_flash_knob.visible = _flash_track.visible if _flash_track else true
	if _flash_state:
		_flash_state.text = "ON" if on else "OFF"
		_flash_state.add_theme_color_override("font_color", PINK if on else Color(0.75, 0.76, 0.8))


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
	var ink := Color(0.42, 0.44, 0.48)
	if _signal_state:
		match band:
			"full":
				_signal_state.text = "STRONG"
				ink = Color(0.35, 0.95, 0.45)
			"weak":
				_signal_state.text = "WEAK"
				ink = Color(0.98, 0.82, 0.2)
			"empty":
				_signal_state.text = "LOW"
				ink = Color(1.0, 0.45, 0.2)
			_:
				_signal_state.text = "DEAD"
				ink = Color(1.0, 0.25, 0.28)
		_signal_state.add_theme_color_override("font_color", ink)
	if _status_wifi:
		_status_wifi.set_meta("ink", ink)
		_status_wifi.queue_redraw()
	if _header_signal:
		_header_signal.set_meta("ink", ink)
		_header_signal.queue_redraw()


func _fill_segments(rects: Array[Control], ratio: float) -> void:
	var n := int(round(clampf(ratio, 0.0, 1.0) * float(SEGMENTS)))
	for i in rects.size():
		rects[i].modulate.a = 1.0 if i < n else 0.18


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
	if inspecting:
		_prompt_wrap.visible = false
		return
	_prompt_wrap.visible = interact_visible
	if not interact_visible:
		return
	if interact_hold and _tex_prompt_hold:
		_prompt_overlay.texture = _tex_prompt_hold
	else:
		_prompt_overlay.texture = _tex_prompt
	_prompt_overlay.visible = _prompt_overlay.texture != null and interact_action.to_upper().contains("SEARCH")
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
	if inspecting:
		return
	var c := size * 0.5
	if _tex_reticle:
		draw_texture_rect(_tex_reticle, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
		return
	draw_line(c + Vector2(0, -10), c + Vector2(0, -4), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 10), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), Color(1, 1, 1, 0.75), 1.2)
	draw_line(c + Vector2(4, 0), c + Vector2(10, 0), Color(1, 1, 1, 0.75), 1.2)
