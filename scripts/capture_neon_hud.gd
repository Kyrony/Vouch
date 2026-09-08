extends SceneTree
## Headless capture of Leonardo HUD v3 meters at known fill percents.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui: GDScript = load("res://scripts/horror/ui/leonardo_ui_validate.gd")
	var hud_err: String = ui.call("validate_hud")
	if not hud_err.is_empty():
		push_error("HUD V3 CAPTURE FAILED: %s" % hud_err)
		quit(1)
		return
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	var hud: Control = hud_script.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	hud.call("set_meters", 62.0, 100.0, 40.0, 25.0)
	hud.call("set_signal_band", "full")
	hud.call("set_phone_device", true, 88.0, true)
	hud.call("set_interact_prompt", true, "Open door", "Look / Talk")
	await process_frame
	if hud.get_node_or_null("Vitals/VBoxContainer") == null and hud.get_node_or_null("Vitals") == null:
		push_error("HUD V3 CAPTURE FAILED: Vitals missing")
		quit(1)
		return
	if str(hud.get("health_ratio")) != "0.62":
		push_error("HUD V3 CAPTURE FAILED: health_ratio=%s" % hud.get("health_ratio"))
		quit(1)
		return
	var img: Image = root.get_viewport().get_texture().get_image()
	var out := "res://assets/horror/hud/_hud_v3_capture.png"
	var err := img.save_png(out)
	if err != OK:
		push_error("HUD V3 screenshot save failed: %s" % err)
		quit(1)
		return
	print("HEALTH=%.2f STAMINA=%.2f FEAR=%.2f SIGNAL=%s PHONE_LED=%s" % [
		hud.get("health_ratio"), hud.get("stamina_ratio"), hud.get("fear_ratio"),
		hud.get("signal_band"), hud.get("phone_led_on"),
	])
	print("SCREENSHOT=%s %dx%d" % [out, img.get_width(), img.get_height()])
	print("HUD V3 CAPTURE OK")
	quit(0)
