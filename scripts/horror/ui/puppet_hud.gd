extends Control
class_name PuppetHud
## Predator overlay for the Puppet Master / worn puppet / stolen body.
## Survivors keep the phone HUD; this sits on top when you are the hunter
## or when a puppet has taken your body.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")

var _role: String = ""
var _title: Label
var _sub: Label
var _hint: Label
var _bar: ProgressBar
var _vignette: ColorRect
var _frame: ColorRect


func _ready() -> void:
	name = "PuppetHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_build()
	visible = false


func set_role(role: String) -> void:
	_role = role
	visible = not role.is_empty()
	if not visible:
		return
	match role:
		"puppet":
			_title.text = "THE PUPPET"
			_sub.text = "Small. Fast. Hungry for a body."
			_hint.text = "LMB  ·  TAKE THEIR BODY"
			_bar.visible = false
			_tint(Color(0.28, 0.04, 0.12, 0.42), Color(0.72, 0.12, 0.22, 0.55))
		"driving":
			_title.text = "YOU WEAR THEIR SKIN"
			_sub.text = "They can only watch. Keep moving."
			_hint.text = "THEIR BODY  ·  YOUR HANDS"
			_bar.visible = false
			_tint(Color(0.18, 0.02, 0.08, 0.5), Color(0.85, 0.1, 0.18, 0.7))
		_:
			_title.text = "PUPPET MASTER"
			_sub.text = "The neighborhood is yours after dark."
			_hint.text = "FIND THE PUPPET  ·  LMB STRINGS  ·  R GHOST"
			_bar.visible = false
			_tint(Color(0.08, 0.02, 0.12, 0.38), Color(0.55, 0.12, 0.62, 0.5))


func set_trapped(possessed: bool, struggle: float, needed: float) -> void:
	if not possessed:
		if _role.is_empty():
			visible = false
		return
	visible = true
	_title.text = "SOMEONE ELSE IS DRIVING"
	_sub.text = "Mash E. Tear the strings. Get out."
	_hint.text = "STRUGGLE  %d / %d" % [int(struggle), int(needed)]
	_bar.visible = true
	_bar.max_value = maxf(needed, 1.0)
	_bar.value = struggle
	_tint(Color(0.02, 0.0, 0.0, 0.55), Color(0.9, 0.08, 0.12, 0.75))


func _tint(fill: Color, edge: Color) -> void:
	_vignette.color = fill
	_frame.color = edge
	for child in get_children():
		if str(child.name).begins_with("Edge") and child is ColorRect:
			(child as ColorRect).color = Color(edge.r, edge.g, edge.b, 0.78)


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_preset(PRESET_FULL_RECT)
	_vignette.mouse_filter = MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.08, 0.02, 0.12, 0.38)
	add_child(_vignette)

	_frame = ColorRect.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(PRESET_FULL_RECT)
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.color = Color(0.55, 0.12, 0.62, 0.5)
	# Hollow frame via four edge bars instead of a full tint.
	_frame.visible = false
	add_child(_frame)
	_edge("EdgeTop", PRESET_TOP_WIDE, Vector2(0, 0), Vector2(0, 8))
	_edge("EdgeBottom", PRESET_BOTTOM_WIDE, Vector2(0, -8), Vector2(0, 0))
	_edge("EdgeLeft", PRESET_LEFT_WIDE, Vector2(0, 0), Vector2(8, 0))
	_edge("EdgeRight", PRESET_RIGHT_WIDE, Vector2(-8, 0), Vector2(0, 0))
	_corner("VignetteTL", PRESET_TOP_LEFT, Vector2(0, 0), Vector2(280, 180))
	_corner("VignetteTR", PRESET_TOP_RIGHT, Vector2(-280, 0), Vector2(0, 180))
	_corner("VignetteBL", PRESET_BOTTOM_LEFT, Vector2(0, -220), Vector2(320, 0))
	_corner("VignetteBR", PRESET_BOTTOM_RIGHT, Vector2(-320, -220), Vector2(0, 0))

	var plate := Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(PRESET_CENTER_TOP)
	plate.offset_left = -280
	plate.offset_top = 18
	plate.offset_right = 280
	plate.offset_bottom = 118
	plate.add_theme_stylebox_override("panel", _T.box(Color(0.82, 0.08, 0.16, 0.95), Color(0.06, 0.01, 0.02, 0.88), 2, 2, true))
	add_child(plate)

	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 10
	col.offset_bottom = -10
	col.add_theme_constant_override("separation", 2)
	plate.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_T.apply_label(_title, "ui")
	_title.add_theme_font_size_override("font_size", _T.font_px(24))
	_title.add_theme_color_override("font_color", Color(0.96, 0.18, 0.22))
	col.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_T.apply_label(_sub, "stone")
	_sub.add_theme_font_size_override("font_size", 14)
	_sub.add_theme_color_override("font_color", Color(0.82, 0.7, 0.72))
	col.add_child(_sub)

	_hint = Label.new()
	_hint.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_hint.offset_left = -320
	_hint.offset_top = -64
	_hint.offset_right = 320
	_hint.offset_bottom = -28
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_T.apply_label(_hint, "ui")
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.94, 0.78, 0.28))
	add_child(_hint)

	_bar = ProgressBar.new()
	_bar.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_bar.offset_left = -180
	_bar.offset_top = -24
	_bar.offset_right = 180
	_bar.offset_bottom = -10
	_bar.show_percentage = false
	_bar.visible = false
	_bar.max_value = 12
	add_child(_bar)


func _edge(node_name: String, preset: LayoutPreset, off_tl: Vector2, off_br: Vector2) -> void:
	var bar := ColorRect.new()
	bar.name = node_name
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.color = Color(0.72, 0.06, 0.12, 0.78)
	bar.set_anchors_preset(preset)
	bar.offset_left = off_tl.x
	bar.offset_top = off_tl.y
	bar.offset_right = off_br.x
	bar.offset_bottom = off_br.y
	add_child(bar)


func _corner(node_name: String, preset: LayoutPreset, off_tl: Vector2, off_br: Vector2) -> void:
	var blot := ColorRect.new()
	blot.name = node_name
	blot.mouse_filter = MOUSE_FILTER_IGNORE
	blot.color = Color(0.02, 0.0, 0.0, 0.55)
	blot.set_anchors_preset(preset)
	blot.offset_left = off_tl.x
	blot.offset_top = off_tl.y
	blot.offset_right = off_br.x
	blot.offset_bottom = off_br.y
	add_child(blot)
