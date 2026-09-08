extends SceneTree
## Headless check + screenshot of Kyle-locked item-rail HUD plate.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui: GDScript = load("res://scripts/horror/ui/leonardo_ui_validate.gd")
	var hud_err: String = ui.call("validate_hud")
	if not hud_err.is_empty():
		push_error("HUD RAIL CAPTURE FAILED: %s" % hud_err)
		quit(1)
		return
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	var hud: Control = hud_script.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	hud.call("set_meters", 62.0, 100.0, 40.0, 25.0)
	hud.call("set_signal_band", "weak")
	hud.call("set_phone_device", true, 68.0, true)
	hud.call("set_interact_prompt", true, "Open door", "Look / Talk")
	hud.call("apply_example_rail")
	await process_frame
	if hud.get_node_or_null("Vitals/MeterColumn") == null:
		push_error("HUD RAIL CAPTURE FAILED: Vitals/MeterColumn missing")
		quit(1)
		return
	var health := hud.get_node_or_null("Vitals/MeterColumn/HealthRow/HealthBar") as TextureProgressBar
	var stamina := hud.get_node_or_null("Vitals/MeterColumn/StaminaRow/StaminaBar") as TextureProgressBar
	if health == null or stamina == null:
		push_error("HUD RAIL CAPTURE FAILED: stacked health/stamina bars missing")
		quit(1)
		return
	if hud.get_node_or_null("Vitals/MeterColumn/FearRow") != null:
		push_error("HUD RAIL CAPTURE FAILED: fear bar still live")
		quit(1)
		return
	if hud.get_node_or_null("Hotbar") != null:
		push_error("HUD RAIL CAPTURE FAILED: bottom hotbar still live")
		quit(1)
		return
	if hud.get_node_or_null("DeviceRow") != null:
		push_error("HUD RAIL CAPTURE FAILED: old device row still live")
		quit(1)
		return
	var battery := hud.get_node_or_null("TopRight/SignalBattery/BatteryRow/BatteryBar") as TextureProgressBar
	var signal_icon := hud.get_node_or_null("TopRight/SignalBattery/SignalWidget/SignalIcon") as TextureRect
	if battery == null or signal_icon == null:
		push_error("HUD RAIL CAPTURE FAILED: top-right signal/battery missing")
		quit(1)
		return
	if battery.texture_under == null or battery.texture_progress == null:
		push_error("HUD RAIL CAPTURE FAILED: battery empty track or fill missing")
		quit(1)
		return
	if not is_equal_approx(float(battery.value), 0.68):
		push_error("HUD RAIL CAPTURE FAILED: battery fill=%.2f" % battery.value)
		quit(1)
		return
	var rail := hud.get_node_or_null("ItemRail") as VBoxContainer
	if rail == null or rail.get_child_count() != 5:
		push_error("HUD RAIL CAPTURE FAILED: ItemRail must have 5 wells")
		quit(1)
		return
	var selected_well := hud.get_node_or_null("ItemRail/RailSlot3/Well") as TextureRect
	var empty_well := hud.get_node_or_null("ItemRail/RailSlot4/Well") as TextureRect
	var key_icon := hud.get_node_or_null("ItemRail/RailSlot1/Icon") as TextureRect
	if selected_well == null or empty_well == null or key_icon == null or key_icon.texture == null:
		push_error("HUD RAIL CAPTURE FAILED: example rail icons/wells missing")
		quit(1)
		return
	if health.texture_under == null or stamina.texture_under == null or health.texture_progress == null:
		push_error("HUD RAIL CAPTURE FAILED: empty track or programmatic fill missing")
		quit(1)
		return
	if not is_equal_approx(float(health.value), 0.62) or not is_equal_approx(float(stamina.value), 0.4):
		push_error("HUD RAIL CAPTURE FAILED: fill ratios health=%.2f stamina=%.2f" % [health.value, stamina.value])
		quit(1)
		return
	if health.global_position.y > stamina.global_position.y:
		push_error("HUD RAIL CAPTURE FAILED: health must stack over stamina")
		quit(1)
		return
	if signal_icon.global_position.x < health.global_position.x + 200.0:
		push_error("HUD RAIL CAPTURE FAILED: signal widget is not top-right")
		quit(1)
		return
	if rail.global_position.x < 1000.0:
		push_error("HUD RAIL CAPTURE FAILED: item rail is not on the right edge")
		quit(1)
		return
	if str(hud.get("signal_band")) != "weak":
		push_error("HUD RAIL CAPTURE FAILED: signal band not applied")
		quit(1)
		return
	print("HEALTH=%.2f STAMINA=%.2f BATTERY=%.2f SIGNAL=%s RAIL=%d" % [
		hud.get("health_ratio"), hud.get("stamina_ratio"),
		float(hud.get("phone_battery")) / 100.0, hud.get("signal_band"),
		rail.get_child_count(),
	])
	print("TRACKS=%s %s" % [health.texture_under.resource_path, stamina.texture_under.resource_path])
	print("BATTERY=%s" % battery.texture_under.resource_path)
	var tex := root.get_viewport().get_texture()
	if tex:
		var img: Image = tex.get_image()
		if img:
			var out := "res://assets/horror/hud/_rail_capture.png"
			var err := img.save_png(out)
			if err == OK:
				print("SCREENSHOT=%s %dx%d" % [out, img.get_width(), img.get_height()])
	print("HUD RAIL CAPTURE OK")
	quit(0)
