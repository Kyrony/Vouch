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
	hud.size = Vector2(1280, 720)
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
	if hud.get_node_or_null("ObjectiveBanner") != null:
		push_error("HUD RAIL CAPTURE FAILED: persistent MISSING CHILD banner still live")
		quit(1)
		return
	if hud.get_node_or_null("BatteryBar") != null or hud.get_node_or_null("TopRight") != null:
		push_error("HUD RAIL CAPTURE FAILED: battery widget still live")
		quit(1)
		return
	var signal_icon := hud.get_node_or_null("SignalWidget/Row/SignalIcon") as TextureRect
	var clock := hud.get_node_or_null("MatchClockLabel") as Label
	if signal_icon == null or clock == null:
		push_error("HUD RAIL CAPTURE FAILED: top-right signal/clock missing")
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
	if health.global_position.y < 400.0:
		push_error("HUD RAIL CAPTURE FAILED: vitals are not bottom-left")
		quit(1)
		return
	if signal_icon.global_position.x < health.global_position.x + 200.0:
		push_error("HUD RAIL CAPTURE FAILED: signal widget is not top-right")
		quit(1)
		return
	if signal_icon.global_position.y > 80.0:
		push_error("HUD RAIL CAPTURE FAILED: signal widget is not at the very top right")
		quit(1)
		return
	if clock.global_position.y < signal_icon.global_position.y + 8.0:
		push_error("HUD RAIL CAPTURE FAILED: match clock is not below the signal")
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
	print("HEALTH=%.2f STAMINA=%.2f SIGNAL=%s RAIL=%d" % [
		hud.get("health_ratio"), hud.get("stamina_ratio"),
		hud.get("signal_band"),
		rail.get_child_count(),
	])
	print("TRACKS=%s %s" % [health.texture_under.resource_path, stamina.texture_under.resource_path])
	var shot := _compose_plate(hud, health, stamina, signal_icon, rail)
	var out := "user://hud_rail_layout.png"
	var err := shot.save_png(out)
	if err != OK:
		push_error("HUD RAIL CAPTURE FAILED: could not write plate")
		quit(1)
		return
	print("SCREENSHOT=%s %dx%d" % [out, shot.get_width(), shot.get_height()])
	print("HUD RAIL CAPTURE OK")
	quit(0)


func _compose_plate(hud: Control, health: TextureProgressBar, stamina: TextureProgressBar, signal_icon: TextureRect, rail: VBoxContainer) -> Image:
	var plate := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	plate.fill(Color(0.024, 0.02, 0.031, 1.0))
	_blit(plate, health.texture_under, health.global_position, Vector2(280, 28))
	_fill_bar(plate, health, Color(0.55, 0.06, 0.10))
	_blit(plate, stamina.texture_under, stamina.global_position, Vector2(280, 28))
	_fill_bar(plate, stamina, Color(1.0, 0.70, 0.0))
	_blit(plate, signal_icon.texture, signal_icon.global_position, Vector2(48, 36))
	for cell in rail.get_children():
		var well := cell.get_node_or_null("Well") as TextureRect
		var icon := cell.get_node_or_null("Icon") as TextureRect
		if well and well.texture:
			_blit(plate, well.texture, well.global_position, Vector2(72, 72))
		if icon and icon.texture and icon.visible:
			_blit(plate, icon.texture, icon.global_position, Vector2(48, 48))
	# Reticle — HUD is full-rect on the 1280×720 plate.
	var c := hud.size * 0.5
	_rect(plate, int(c.x) - 2, int(c.y) - 10, 4, 8, Color(1, 1, 1, 0.75))
	_rect(plate, int(c.x) - 2, int(c.y) + 2, 4, 8, Color(1, 1, 1, 0.75))
	_rect(plate, int(c.x) - 10, int(c.y) - 2, 8, 4, Color(1, 1, 1, 0.75))
	_rect(plate, int(c.x) + 2, int(c.y) - 2, 8, 4, Color(1, 1, 1, 0.75))
	return plate


func _fill_bar(plate: Image, bar: TextureProgressBar, color: Color) -> void:
	var pos := bar.global_position
	var ratio := clampf(float(bar.value), 0.0, 1.0)
	_rect(plate, int(pos.x + 8), int(pos.y + 6), int(244.0 * ratio), 16, color)


func _blit(plate: Image, tex: Texture2D, pos: Vector2, size: Vector2) -> void:
	if tex == null:
		return
	var src: Image = tex.get_image()
	if src == null:
		return
	src = src.duplicate()
	src.resize(int(size.x), int(size.y), Image.INTERPOLATE_LANCZOS)
	var dest := Vector2i(int(pos.x), int(pos.y))
	plate.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), dest)


func _rect(plate: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, plate.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, plate.get_width())):
			var prev := plate.get_pixel(xx, yy)
			plate.set_pixel(xx, yy, prev.blend(color))

