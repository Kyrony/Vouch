extends RefCounted
class_name SettingsSidebox
## Tabbed Controls / Visual / Audio / Keybinds panel for the VouchMenu
## sidebox and the in-match pause menu. Same gold-blood nav look.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")
const DEFAULT_TAB := "controls"

const TABS: Array[Dictionary] = [
	{"id": "controls", "name": "ControlsButton", "label": "CONTROLS"},
	{"id": "visual", "name": "VisualButton", "label": "VISUAL"},
	{"id": "audio", "name": "AudioButton", "label": "AUDIO"},
	{"id": "keybinds", "name": "KeybindsButton", "label": "KEYBINDS"},
]

const TAB_NODES := {
	"keybinds": ["KeybindsPanel"],
	"audio": ["MasterVolumeRow", "SfxVolumeRow", "SaveButton"],
	"visual": ["FullscreenRow", "VsyncRow", "BrightnessRow"],
	"controls": ["SensitivityRow", "InvertYRow", "RumbleRow"],
}

const ACTION_LABELS := {
	"move_forward": "FORWARD",
	"move_back": "BACK",
	"move_left": "LEFT",
	"move_right": "RIGHT",
	"jump": "JUMP",
	"interact": "INTERACT",
	"destroy": "DESTROY",
	"crouch": "CROUCH",
	"sprint": "SPRINT",
}


static func ensure(root: Control) -> void:
	if root == null:
		return
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 16
	root.offset_right = -16
	root.offset_bottom = -16
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var heading := root.get_node_or_null("Heading") as Label
	if heading == null:
		heading = Label.new()
		heading.name = "Heading"
		root.add_child(heading)
	heading.text = "SETTINGS"
	heading.position = Vector2(0, 0)
	heading.size = Vector2(460, 26)
	_T.apply_label(heading, "ui")
	_ensure_tab_nav(root)
	_ensure_keybinds(root)
	_ensure_volume_row(root, "MasterVolumeRow", "MASTER VOLUME")
	_ensure_volume_row(root, "SfxVolumeRow", "SFX VOLUME")
	_ensure_toggle_row(root, "FullscreenRow", "FullscreenToggle", "FULLSCREEN")
	_ensure_toggle_row(root, "VsyncRow", "VsyncToggle", "VSYNC")
	_ensure_volume_row(root, "BrightnessRow", "BRIGHTNESS")
	_ensure_volume_row(root, "SensitivityRow", "MOUSE SENSITIVITY")
	_ensure_toggle_row(root, "InvertYRow", "InvertYToggle", "INVERT LOOK Y")
	_ensure_toggle_row(root, "RumbleRow", "RumbleToggle", "CONTROLLER RUMBLE")
	var save := root.get_node_or_null("SaveButton") as Button
	if save == null:
		save = Button.new()
		save.name = "SaveButton"
		root.add_child(save)
	save.text = "SAVE"
	save.position = Vector2(0, 232)
	save.size = Vector2(460, 42)
	_T.apply_action_button(save, "gold")
	_layout_tab_bodies(root)
	if not root.has_meta("settings_tab"):
		set_tab(root, DEFAULT_TAB)
	else:
		set_tab(root, str(root.get_meta("settings_tab")))


static func wire(root: Control, toast: Callable = Callable()) -> void:
	if root == null:
		return
	ensure(root)
	if root.get_meta("settings_wired", false):
		refresh(root)
		return
	root.set_meta("settings_wired", true)
	root.set_meta("settings_toast", toast)
	var nav := root.get_node_or_null("TabNav")
	if nav:
		for spec in TABS:
			var btn := nav.get_node_or_null(spec["name"]) as Button
			if btn and not btn.pressed.is_connected(_on_tab_pressed):
				btn.pressed.connect(_on_tab_pressed.bind(root, spec["id"]))
	var master := _slider(root, "MasterVolumeRow")
	if master and not master.value_changed.is_connected(_on_master_changed):
		master.value_changed.connect(_on_master_changed)
	var sfx := _slider(root, "SfxVolumeRow")
	if sfx and not sfx.value_changed.is_connected(_on_sfx_changed):
		sfx.value_changed.connect(_on_sfx_changed)
	var sense := _slider(root, "SensitivityRow")
	if sense and not sense.value_changed.is_connected(_on_sensitivity_changed):
		sense.value_changed.connect(_on_sensitivity_changed)
	var full := root.get_node_or_null("FullscreenRow/FullscreenToggle") as CheckButton
	if full and not full.toggled.is_connected(_on_fullscreen_toggled):
		full.toggled.connect(_on_fullscreen_toggled)
	var save := root.get_node_or_null("SaveButton") as Button
	if save and not save.pressed.is_connected(_on_save_pressed):
		save.pressed.connect(_on_save_pressed.bind(root))
	refresh(root)


static func set_tab(root: Control, tab_id: String) -> void:
	if root == null:
		return
	if not TAB_NODES.has(tab_id):
		tab_id = DEFAULT_TAB
	root.set_meta("settings_tab", tab_id)
	var visible_names: Array = TAB_NODES[tab_id]
	var all_names: Array[String] = []
	for key in TAB_NODES.keys():
		for node_name in TAB_NODES[key]:
			if not all_names.has(node_name):
				all_names.append(node_name)
	for node_name in all_names:
		var node := root.get_node_or_null(node_name) as CanvasItem
		if node:
			node.visible = visible_names.has(node_name)
	var nav := root.get_node_or_null("TabNav")
	if nav:
		for spec in TABS:
			var btn := nav.get_node_or_null(spec["name"]) as Button
			if btn:
				_T.apply_nav_button(btn, spec["id"] == tab_id)
				_shrink_tab_caption(btn)
	if tab_id == "keybinds":
		_refresh_keybinds(root)


static func refresh(root: Control) -> void:
	if root == null:
		return
	var master := _slider(root, "MasterVolumeRow")
	if master:
		master.value = SettingsManager.master_volume
	var sfx := _slider(root, "SfxVolumeRow")
	if sfx:
		sfx.value = SettingsManager.sfx_volume
	var sense := _slider(root, "SensitivityRow")
	if sense:
		sense.min_value = 0.1
		sense.max_value = 4.0
		sense.step = 0.1
		sense.value = SettingsManager.mouse_sensitivity
	var bright := _slider(root, "BrightnessRow")
	if bright:
		bright.value = 0.7
	var full := root.get_node_or_null("FullscreenRow/FullscreenToggle") as CheckButton
	if full:
		full.set_pressed_no_signal(SettingsManager.fullscreen)
	_refresh_keybinds(root)
	set_tab(root, str(root.get_meta("settings_tab", DEFAULT_TAB)))


static func _ensure_tab_nav(root: Control) -> void:
	var nav := root.get_node_or_null("TabNav") as HBoxContainer
	if nav == null:
		nav = HBoxContainer.new()
		nav.name = "TabNav"
		root.add_child(nav)
	nav.position = Vector2(0, 30)
	nav.size = Vector2(460, 40)
	nav.add_theme_constant_override("separation", 4)
	nav.mouse_filter = Control.MOUSE_FILTER_STOP
	var tab_index := 0
	for spec in TABS:
		var btn := nav.get_node_or_null(spec["name"]) as Button
		if btn == null:
			btn = Button.new()
			btn.name = spec["name"]
			nav.add_child(btn)
		nav.move_child(btn, tab_index)
		tab_index += 1
		btn.text = ""
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_ALL
		var row := btn.get_node_or_null("Row") as HBoxContainer
		if row == null:
			row = HBoxContainer.new()
			row.name = "Row"
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 4
			row.offset_right = -4
			row.add_theme_constant_override("separation", 2)
			btn.add_child(row)
		var caption := row.get_node_or_null("Caption") as Label
		if caption == null:
			caption = Label.new()
			caption.name = "Caption"
			row.add_child(caption)
		caption.text = spec["label"]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_T.apply_nav_button(btn, spec["id"] == DEFAULT_TAB)
		_shrink_tab_caption(btn)


static func _shrink_tab_caption(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 12)
	var caption := button.get_node_or_null("Row/Caption") as Label
	if caption:
		caption.add_theme_font_size_override("font_size", 12)


static func _ensure_keybinds(root: Control) -> void:
	var panel := root.get_node_or_null("KeybindsPanel") as VBoxContainer
	if panel == null:
		panel = VBoxContainer.new()
		panel.name = "KeybindsPanel"
		root.add_child(panel)
	panel.position = Vector2(0, 78)
	panel.size = Vector2(460, 320)
	panel.add_theme_constant_override("separation", 6)
	var hint := panel.get_node_or_null("Hint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "Hint"
		panel.add_child(hint)
	hint.text = "Current bindings. Remap ships in a later build."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_T.apply_label(hint, "stone")
	hint.add_theme_font_size_override("font_size", 13)
	for action_name in SettingsManager.REMAPPABLE_ACTIONS:
		var row := panel.get_node_or_null("Bind_%s" % action_name) as HBoxContainer
		if row == null:
			row = HBoxContainer.new()
			row.name = "Bind_%s" % action_name
			panel.add_child(row)
		row.add_theme_constant_override("separation", 8)
		var caption := row.get_node_or_null("Caption") as Label
		if caption == null:
			caption = Label.new()
			caption.name = "Caption"
			row.add_child(caption)
		caption.text = str(ACTION_LABELS.get(action_name, action_name.to_upper()))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_T.apply_label(caption, "ui")
		caption.add_theme_font_size_override("font_size", 13)
		var value := row.get_node_or_null("Value") as Label
		if value == null:
			value = Label.new()
			value.name = "Value"
			row.add_child(value)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_T.apply_label(value, "stone")
		value.add_theme_color_override("font_color", _T.GOLD)


static func _ensure_volume_row(root: Control, node_name: String, caption: String) -> void:
	var row := root.get_node_or_null(node_name) as VBoxContainer
	if row == null:
		row = VBoxContainer.new()
		row.name = node_name
		root.add_child(row)
	row.add_theme_constant_override("separation", 4)
	var label := row.get_node_or_null("Label") as Label
	if label == null:
		label = Label.new()
		label.name = "Label"
		row.add_child(label)
	label.text = caption
	_T.apply_label(label, "ui")
	label.add_theme_font_size_override("font_size", 13)
	var slider := row.get_node_or_null("Slider") as HSlider
	if slider == null:
		slider = HSlider.new()
		slider.name = "Slider"
		row.add_child(slider)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_T.apply_slider(slider)


static func _ensure_toggle_row(root: Control, node_name: String, toggle_name: String, caption: String) -> void:
	var row := root.get_node_or_null(node_name) as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = node_name
		root.add_child(row)
	row.add_theme_constant_override("separation", 8)
	var label := row.get_node_or_null("Label") as Label
	if label == null:
		label = Label.new()
		label.name = "Label"
		row.add_child(label)
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_T.apply_label(label, "ui")
	var toggle := row.get_node_or_null(toggle_name) as CheckButton
	if toggle == null:
		toggle = CheckButton.new()
		toggle.name = toggle_name
		row.add_child(toggle)


static func _layout_tab_bodies(root: Control) -> void:
	var y := 78.0
	var w := 460.0
	for node_name in ["MasterVolumeRow", "SensitivityRow", "BrightnessRow"]:
		var row := root.get_node_or_null(node_name) as Control
		if row:
			row.position = Vector2(0, y)
			row.size = Vector2(w, 56)
	for node_name in ["SfxVolumeRow"]:
		var row := root.get_node_or_null(node_name) as Control
		if row:
			row.position = Vector2(0, y + 66)
			row.size = Vector2(w, 56)
	var save := root.get_node_or_null("SaveButton") as Control
	if save:
		save.position = Vector2(0, y + 146)
		save.size = Vector2(w, 42)
	var stacked: PackedStringArray = ["FullscreenRow", "VsyncRow", "BrightnessRow", "InvertYRow", "RumbleRow"]
	var stack_y := y
	for node_name in stacked:
		var row := root.get_node_or_null(node_name) as Control
		if row == null:
			continue
		if node_name == "BrightnessRow":
			row.position = Vector2(0, stack_y)
			row.size = Vector2(w, 56)
			stack_y += 62
		else:
			row.position = Vector2(0, stack_y)
			row.size = Vector2(w, 36)
			stack_y += 42
	# Visual tab stacks fullscreen / vsync / brightness from the same origin.
	# Re-apply visual-only positions so they don't inherit the controls stack.
	var visual_y := y
	for node_name in ["FullscreenRow", "VsyncRow", "BrightnessRow"]:
		var row := root.get_node_or_null(node_name) as Control
		if row == null:
			continue
		row.position = Vector2(0, visual_y)
		row.size = Vector2(w, 56 if node_name == "BrightnessRow" else 36)
		visual_y += 48 if node_name != "BrightnessRow" else 62
	var control_y := y
	for node_name in ["SensitivityRow", "InvertYRow", "RumbleRow"]:
		var row := root.get_node_or_null(node_name) as Control
		if row == null:
			continue
		row.position = Vector2(0, control_y)
		row.size = Vector2(w, 56 if node_name == "SensitivityRow" else 36)
		control_y += 62 if node_name == "SensitivityRow" else 42


static func _slider(root: Control, row_name: String) -> HSlider:
	return root.get_node_or_null("%s/Slider" % row_name) as HSlider


static func _refresh_keybinds(root: Control) -> void:
	var panel := root.get_node_or_null("KeybindsPanel")
	if panel == null:
		return
	for action_name in SettingsManager.REMAPPABLE_ACTIONS:
		var value := panel.get_node_or_null("Bind_%s/Value" % action_name) as Label
		if value:
			value.text = SettingsManager.get_binding_label(action_name)


static func _on_tab_pressed(root: Control, tab_id: String) -> void:
	set_tab(root, tab_id)


static func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)


static func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)


static func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)


static func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)


static func _on_save_pressed(root: Control) -> void:
	var master := _slider(root, "MasterVolumeRow")
	var sfx := _slider(root, "SfxVolumeRow")
	var sense := _slider(root, "SensitivityRow")
	var full := root.get_node_or_null("FullscreenRow/FullscreenToggle") as CheckButton
	if master:
		SettingsManager.set_master_volume(master.value)
	if sfx:
		SettingsManager.set_sfx_volume(sfx.value)
	if sense:
		SettingsManager.set_mouse_sensitivity(sense.value)
	if full:
		SettingsManager.set_fullscreen(full.button_pressed)
	var toast: Variant = root.get_meta("settings_toast", Callable())
	if toast is Callable and (toast as Callable).is_valid():
		(toast as Callable).call("Settings saved.")
