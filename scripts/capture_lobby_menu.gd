extends SceneTree
## Capture the F5 boot home (Main -> Lobby) for VouchMenu verification.


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
	print("BACKGROUND_COLOR=%s" % (bg as ColorRect).color)
	print("NAVCOLUMN=%s" % str(lobby.get_node_or_null("HomePanel/NavColumn") != null))
	print("ATMOSPHERE=%s" % str(lobby.get_node_or_null("MenuAtmosphere") != null))
	print("TITLE_BG=%s" % str(FileAccess.file_exists("res://assets/horror/ui/menu_title_bg.png")))
	print("BANNER_VISIBLE=%s" % str(lobby.get_node_or_null("HomePanel/Banner") != null and lobby.get_node("HomePanel/Banner").visible))
	print("SIGNAL_VISIBLE=%s" % str(lobby.get_node_or_null("HomePanel/SignalCluster") != null and lobby.get_node("HomePanel/SignalCluster").visible))
	print("PLAY_OPEN=%s" % str(lobby.get_node("HomePanel/SidePanel/PlayContent").visible))
	var mansion_tex := lobby.get_node_or_null("MansionPlaceholder/Texture") as TextureRect
	var mansion := lobby.get_node_or_null("MansionPlaceholder") as Control
	print("MANSION_HIDDEN=%s" % str(mansion == null or not mansion.visible))
	print("MANSION_BLANK=%s" % str(mansion_tex == null or mansion_tex.texture == null))
	print("THUMB_BLANK=%s" % str(lobby.get_node("HomePanel/SidePanel/PlayContent/ModeThumb/Texture").texture == null))
	for path in [
		"HomePanel/NavColumn/PlayButton",
		"HomePanel/SidePanel/PlayContent/ModeList/ClassicButton",
	]:
		var btn := lobby.get_node(path) as Button
		print("NAV %s visible=%s" % [path, btn.visible])
	var tex := root.get_viewport().get_texture()
	if tex == null:
		print("SCREENSHOT=skipped (headless viewport has no texture)")
		print("LOBBY MENU CAPTURE OK")
		quit(0)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("SCREENSHOT=skipped (dummy renderer)")
		print("LOBBY MENU CAPTURE OK")
		quit(0)
		return
	var out := "res://assets/horror/ui/_boot_capture.png"
	var err := img.save_png(out)
	if err != OK:
		push_error("screenshot save failed: %s" % err)
		quit(1)
		return
	print("SCREENSHOT=%s %dx%d" % [out, img.get_width(), img.get_height()])
	print("LOBBY MENU CAPTURE OK")
	quit(0)
