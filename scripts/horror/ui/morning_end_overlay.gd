extends CanvasLayer
## Morning match-end stub. Shown when the host clock hits 6:00 AM.


func _ready() -> void:
	name = "MorningEndOverlay"
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var title := Label.new()
	title.name = "Title"
	title.text = "MORNING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -280
	title.offset_top = -90
	title.offset_right = 280
	title.offset_bottom = -30
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.23, 1))
	add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "6:00 AM — the night is over."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.offset_left = -280
	sub.offset_top = -24
	sub.offset_right = 280
	sub.offset_bottom = 16
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72, 1))
	add_child(sub)
	var exit_btn := Button.new()
	exit_btn.name = "ExitButton"
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(200, 48)
	exit_btn.set_anchors_preset(Control.PRESET_CENTER)
	exit_btn.offset_left = -100
	exit_btn.offset_top = 40
	exit_btn.offset_right = 100
	exit_btn.offset_bottom = 88
	add_child(exit_btn)
	var theme: GDScript = load("res://scripts/horror/ui/vouch_menu_theme.gd")
	if theme:
		theme.call("apply_action_button", exit_btn, "gold")
	exit_btn.pressed.connect(_on_exit)


func _on_exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tree := get_tree()
	if tree:
		tree.paused = false
	GameState.request_return_to_lobby()
