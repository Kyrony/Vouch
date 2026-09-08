extends SceneTree
## Headless check of Leonardo HUD v3 meters at known fill percents.


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
	if hud.get_node_or_null("Vitals") == null or hud.get_node_or_null("Vitals/MeterColumn") == null:
		push_error("HUD V3 CAPTURE FAILED: Vitals/MeterColumn missing")
		quit(1)
		return
	var health := hud.get_node_or_null("Vitals/MeterColumn/HealthRow/HealthBar") as TextureProgressBar
	var stamina := hud.get_node_or_null("Vitals/MeterColumn/StaminaRow/StaminaBar") as TextureProgressBar
	var fear := hud.get_node_or_null("Vitals/MeterColumn/FearRow/FearBar") as TextureProgressBar
	if health == null or stamina == null or fear == null:
		push_error("HUD V3 CAPTURE FAILED: TextureProgressBar meters missing")
		quit(1)
		return
	if health.texture_under == null or stamina.texture_under == null or fear.texture_under == null:
		push_error("HUD V3 CAPTURE FAILED: empty track textures missing")
		quit(1)
		return
	if health.texture_progress == null:
		push_error("HUD V3 CAPTURE FAILED: programmatic fill texture missing")
		quit(1)
		return
	if not is_equal_approx(float(health.value), 0.62) or not is_equal_approx(float(stamina.value), 0.4) or not is_equal_approx(float(fear.value), 0.25):
		push_error("HUD V3 CAPTURE FAILED: fill ratios health=%.2f stamina=%.2f fear=%.2f" % [health.value, stamina.value, fear.value])
		quit(1)
		return
	if hud.get_node_or_null("Vitals/MeterColumn/HealthRow/HealthChip") == null:
		push_error("HUD V3 CAPTURE FAILED: health chip missing")
		quit(1)
		return
	if str(hud.get("signal_band")) != "full" or not bool(hud.get("phone_led_on")):
		push_error("HUD V3 CAPTURE FAILED: phone/signal hooks not applied")
		quit(1)
		return
	print("HEALTH=%.2f STAMINA=%.2f FEAR=%.2f SIGNAL=%s PHONE_LED=%s" % [
		hud.get("health_ratio"), hud.get("stamina_ratio"), hud.get("fear_ratio"),
		hud.get("signal_band"), hud.get("phone_led_on"),
	])
	print("TRACKS=%s %s %s" % [
		health.texture_under.resource_path, stamina.texture_under.resource_path, fear.texture_under.resource_path,
	])
	print("HUD V3 CAPTURE OK")
	quit(0)
