extends CanvasLayer
class_name DebugOverlay
## Isolated debug overlay. Toggle with Home. Never referenced by gameplay
## systems — they query DebugCheats flags only.
##
## *** DEV ONLY — REMOVE OR GATE BEFORE FULL RELEASE ***

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")

var _open: bool = false
var _panel: PanelContainer
var _status: Label
var _invincible: CheckBox
var _infinite_jump: CheckBox
var _character: OptionButton
var _host_only: Array[Control] = []


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dbg: Node = get_node_or_null("/root/DebugBuild")
	if dbg == null or not bool(dbg.get("enabled")):
		queue_free()
		return
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_HOME:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_open = not _open
	visible = _open
	if _open:
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_restore_mouse()


func _restore_mouse() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and int(gs.get("phase")) == 1:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -340
	_panel.offset_top = 14
	_panel.offset_right = -14
	_panel.offset_bottom = 14 + 540
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.add_theme_stylebox_override("panel", _T.box(Color(_T.GOLD.r, _T.GOLD.g, _T.GOLD.b, 0.55), _T.PANEL, 1, 2, false))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "DEBUG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_T.apply_label(title, "ui")
	title.add_theme_color_override("font_color", _T.GOLD)
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "HOME"
	close_btn.custom_minimum_size = Vector2(72, 28)
	_T.apply_action_button(close_btn, "gold")
	close_btn.pressed.connect(_toggle)
	header.add_child(close_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_T.apply_label(_status, "stone")
	_status.add_theme_color_override("font_color", _T.STONE)
	root.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	_add_section(body, "CHEATS")
	_invincible = _add_check(body, "Invincible", _on_invincible)
	_infinite_jump = _add_check(body, "Infinite jump", _on_infinite_jump)

	_add_section(body, "CHARACTER")
	_character = OptionButton.new()
	_character.add_item("Survivor", 0)
	_character.add_item("Puppet Master", 1)
	_style_option(_character)
	body.add_child(_character)
	_add_button(body, "Apply character", _apply_character)

	_add_section(body, "SPAWN")
	_host(_add_button(body, "Spawn survivor", func() -> void: DebugCommands.spawn_debug_pawn(false)))
	_host(_add_button(body, "Spawn puppet master", func() -> void: DebugCommands.spawn_debug_pawn(true)))
	_host(_add_button(body, "Spawn test items", DebugCommands.spawn_test_items))
	_host(_add_button(body, "Spawn test props", DebugCommands.spawn_playtest_kit))

	_add_section(body, "WORLD")
	_host(_add_button(body, "Toggle room power", _toggle_power))
	_host(_add_button(body, "Toggle room water", _toggle_water))
	_host(_add_button(body, "Reset match spawn odds", _reset_odds))


func _add_section(parent: Control, text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var line := ColorRect.new()
	line.color = Color(_T.GOLD.r, _T.GOLD.g, _T.GOLD.b, 0.35)
	line.custom_minimum_size = Vector2(18, 1)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	var lab := Label.new()
	lab.text = text
	_T.apply_label(lab, "ui")
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", _T.GOLD_DIM)
	row.add_child(lab)


func _add_check(parent: Control, text: String, cb: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_override("font", _T.stone_font())
	box.add_theme_font_size_override("font_size", 14)
	box.add_theme_color_override("font_color", _T.WHITE)
	box.add_theme_color_override("font_hover_color", _T.GOLD)
	box.add_theme_color_override("font_pressed_color", _T.GOLD)
	box.toggled.connect(cb)
	parent.add_child(box)
	return box


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	_T.apply_action_button(btn, "gold")
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn


func _style_option(opt: OptionButton) -> void:
	opt.custom_minimum_size = Vector2(0, 34)
	_T.apply_action_button(opt, "gold")


func _host(ctrl: Control) -> void:
	_host_only.append(ctrl)


func _refresh() -> void:
	var net: Node = get_node_or_null("/root/NetworkManager")
	var is_host: bool = net != null and net.has_method("is_server") and bool(net.call("is_server"))
	if is_host:
		_status.text = "Host tools — Home to close"
	else:
		_status.text = "Client — cheats are local, spawns need host"
	var cheats: Node = get_node_or_null("/root/DebugCheats")
	if cheats:
		_invincible.set_pressed_no_signal(bool(cheats.get("invincible")))
		_infinite_jump.set_pressed_no_signal(bool(cheats.get("infinite_jump")))
	for ctrl in _host_only:
		if ctrl is Button and not (ctrl is CheckBox):
			ctrl.disabled = not is_host
	_character.disabled = false
	_invincible.disabled = false
	_infinite_jump.disabled = false


func _on_invincible(on: bool) -> void:
	DebugCheats.set_invincible(on)
	_status.text = "Invincible %s" % ("on" if on else "off")


func _on_infinite_jump(on: bool) -> void:
	DebugCheats.set_infinite_jump(on)
	_status.text = "Infinite jump %s" % ("on" if on else "off")


func _apply_character() -> void:
	DebugCommands.apply_local_character(_character.get_selected_id() == 1)
	_status.text = "Character set to %s" % _character.get_item_text(_character.selected)


func _toggle_power() -> void:
	if not _is_host() or GameState.local_player_node == null:
		return
	var room := _room_at_player()
	var enabled := not RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_POWER)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_POWER, enabled)
	_status.text = "Power room %d: %s" % [room, "ON" if enabled else "OFF"]


func _toggle_water() -> void:
	if not _is_host() or GameState.local_player_node == null:
		return
	var room := _room_at_player()
	var enabled := not RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_WATER)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_WATER, enabled)
	_status.text = "Water room %d: %s" % [room, "ON" if enabled else "OFF"]


func _reset_odds() -> void:
	if not _is_host():
		return
	MatchSettings.reset_to_defaults()
	_status.text = "Spawn odds reset"


func _room_at_player() -> int:
	var pos := GameState.local_player_node.global_position
	var col := int(roundi(pos.x / WorldScale.GRID_SPACING))
	var row := int(roundi(pos.z / WorldScale.GRID_SPACING))
	return row * 4 + col


func _is_host() -> bool:
	var net: Node = get_node_or_null("/root/NetworkManager")
	return net != null and bool(net.call("is_server"))
