extends SceneTree
## Capture the F5 boot home (Main -> Lobby) for hybrid-plate verification.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	var lobby := main.get_node_or_null("Lobby") as Control
	var ui_check: GDScript = load("res://scripts/horror/world/horror_soft_go_validate.gd")
	var menu_err: String = ui_check.call("validate_leonardo_menu", lobby)
	if not menu_err.is_empty():
		push_error("LOBBY MENU CAPTURE FAILED: %s" % menu_err)
		quit(1)
		return
	var bg := lobby.get_node("Background")
	print("BOOT_SCENE=res://scenes/Main.tscn")
	print("BOOT_HOME=res://scenes/Lobby/Lobby.tscn")
	print("BACKGROUND_TYPE=%s" % bg.get_class())
	print("STRETCH_MODE=%s" % (bg as TextureRect).stretch_mode)
	print("PLATE=%s" % (bg as TextureRect).texture.resource_path)
	print("NAVCOLUMN=%s" % str(lobby.get_node_or_null("HomePanel/NavColumn") != null))
	for path in [
		"HomePanel/HitboxRoot/MenuButtons/PlayButton",
		"HomePanel/HitboxRoot/GameModes/ClassicButton",
	]:
		var btn := lobby.get_node(path) as Button
		print("HITBOX %s text='%s' flat=%s" % [path, btn.text, btn.flat])
	var img: Image = root.get_viewport().get_texture().get_image()
	var out := "res://assets/horror/ui/_boot_capture.png"
	var err := img.save_png(out)
	if err != OK:
		push_error("screenshot save failed: %s" % err)
		quit(1)
		return
	print("SCREENSHOT=%s %dx%d" % [out, img.get_width(), img.get_height()])
	print("LOBBY MENU CAPTURE OK")
	quit(0)
