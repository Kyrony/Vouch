extends CanvasLayer
## Shared match-over plate (child home, morning, or PM wipe).


func _ready() -> void:
	name = "MatchEndOverlay"
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func configure(title: String, sub: String) -> void:
	var title_n := get_node_or_null("Title") as Label
	var sub_n := get_node_or_null("Sub") as Label
	if title_n:
		title_n.text = title
	if sub_n:
		sub_n.text = sub


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var title := Label.new()
	title.name = "Title"
	title.text = "MORNING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -320
	title.offset_top = -90
	title.offset_right = 320
	title.offset_bottom = -30
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.23, 1))
	add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "6:00 AM — the night is over."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.offset_left = -320
	sub.offset_top = -24
	sub.offset_right = 320
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


static func present(title: String, sub: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var existing := tree.root.get_node_or_null("MatchEndOverlay") as CanvasLayer
	if existing == null:
		existing = tree.root.get_node_or_null("MorningEndOverlay") as CanvasLayer
	if existing and existing.has_method("configure"):
		existing.call("configure", title, sub)
		existing.visible = true
		GameState.restore_menu_input()
		return
	var overlay: CanvasLayer = load("res://scripts/horror/ui/match_end_overlay.gd").new()
	tree.root.add_child(overlay)
	overlay.call("configure", title, sub)
	GameState.restore_menu_input()
