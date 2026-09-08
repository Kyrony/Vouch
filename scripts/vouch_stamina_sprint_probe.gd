extends SceneTree
## Headless smoke: sprint drains stamina on authority math; yellow HUD fill follows.
## Run: godot4 --headless --path . -s res://scripts/vouch_stamina_sprint_probe.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err: String = await _probe()
	if err.is_empty():
		print("STAMINA SPRINT PROBE OK")
		quit(0)
		return
	push_error("STAMINA SPRINT PROBE FAILED: %s" % err)
	quit(1)


func _probe() -> String:
	var check: GDScript = load("res://scripts/horror/world/horror_soft_go_validate.gd")
	var math_err: String = check.call("validate_sprint_stamina")
	if not math_err.is_empty():
		return math_err

	var fx: GDScript = load("res://scripts/horror/items/player_effects.gd")
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	var hud: Control = hud_script.new()
	root.add_child(hud)
	await process_frame
	await process_frame

	var start := 100.0
	var drained: float = float(fx.call("simulate_stamina", start, true, 2.0))
	var hud_err: String = check.call("validate_stamina_hud_fill", hud, drained)
	if not hud_err.is_empty():
		hud.queue_free()
		return hud_err

	var recovered: float = float(fx.call("simulate_stamina", drained, false, 1.0))
	if recovered <= drained:
		hud.queue_free()
		return "idle regen did not raise stamina (%.2f -> %.2f)" % [drained, recovered]
	hud_err = check.call("validate_stamina_hud_fill", hud, recovered)
	if not hud_err.is_empty():
		hud.queue_free()
		return hud_err

	var empty: float = float(fx.call("simulate_stamina", 100.0, true, 5.5))
	hud_err = check.call("validate_stamina_hud_fill", hud, empty)
	if not hud_err.is_empty():
		hud.queue_free()
		return hud_err

	print("  drain=%.1f%%/s regen=%.1f%%/s sprint_2s=%.1f idle_1s=%.1f empty_5.5s=%.1f hud=%.2f" % [
		float(fx.STAMINA_DRAIN_PER_SEC),
		float(fx.STAMINA_REGEN_PER_SEC),
		drained,
		recovered,
		empty,
		float(hud.get("stamina_ratio")),
	])
	hud.queue_free()
	return ""
