extends Node
## Host-authoritative dusk → morning clock.
## 6:00 PM → 6:00 AM in-game = 12 hours = 24 real minutes (1h = 2 min).

signal clock_updated(progress: float, label: String)
signal morning_reached

# ── TUNABLES — tweak these to balance gameplay ──
const START_HOUR := 18  # match starts at 6 PM
const MATCH_REAL_SECONDS := 1440.0  # real match length (24 min)
const IN_GAME_HOURS := 12.0  # dusk→morning span
const REAL_SECONDS_PER_GAME_HOUR := 120.0  # real secs per game hour
const SYNC_EVERY := 0.5

var elapsed_real: float = 0.0
var running: bool = false
var _sync_accum: float = 0.0
var _morning_fired: bool = false
var _overlay: CanvasLayer = null


func _ready() -> void:
	GameState.match_started.connect(_on_match_started)
	GameState.return_to_lobby_requested.connect(stop)


func _on_match_started() -> void:
	if GameState.practice_mode:
		stop()
		return
	reset_and_start()


func reset_and_start() -> void:
	elapsed_real = 0.0
	running = true
	_sync_accum = 0.0
	_morning_fired = false
	_hide_overlay()
	apply_lighting()
	clock_updated.emit(0.0, format_clock())


func stop() -> void:
	running = false
	_hide_overlay()


func progress() -> float:
	return clampf(elapsed_real / MATCH_REAL_SECONDS, 0.0, 1.0)


func format_clock() -> String:
	return clock_label_for_progress(progress())


static func clock_label_for_progress(p: float) -> String:
	var total := float(START_HOUR) * 60.0 + clampf(p, 0.0, 1.0) * IN_GAME_HOURS * 60.0
	var wrapped := fmod(total, 24.0 * 60.0)
	if wrapped < 0.0:
		wrapped += 24.0 * 60.0
	var mins_i := int(round(wrapped))
	if mins_i >= 24 * 60:
		mins_i = 0
	@warning_ignore("integer_division")
	var hour := mins_i / 60  # whole hours, remainder handled below
	var minute := mins_i % 60
	var suffix := "AM" if hour < 12 else "PM"
	var hour12 := hour % 12
	if hour12 == 0:
		hour12 = 12
	return "%d:%02d %s" % [hour12, minute, suffix]


static func sample_lighting(p: float) -> Dictionary:
	var stops: Array = [
		{"t": 0.00, "sky": Color(0.72, 0.38, 0.22), "amb": Color(0.58, 0.34, 0.22), "amb_e": 0.55, "lit": Color(1.00, 0.55, 0.28), "lit_e": 0.88, "rot": Vector3(-12, 110, 0), "fill": 0.34},
		{"t": 0.18, "sky": Color(0.26, 0.14, 0.28), "amb": Color(0.20, 0.14, 0.26), "amb_e": 0.26, "lit": Color(0.82, 0.38, 0.36), "lit_e": 0.22, "rot": Vector3(-3, 122, 0), "fill": 0.10},
		{"t": 0.40, "sky": Color(0.035, 0.045, 0.09), "amb": Color(0.07, 0.09, 0.15), "amb_e": 0.16, "lit": Color(0.52, 0.60, 0.84), "lit_e": 0.20, "rot": Vector3(-58, -18, 0), "fill": 0.04},
		{"t": 0.55, "sky": Color(0.018, 0.024, 0.055), "amb": Color(0.05, 0.06, 0.11), "amb_e": 0.13, "lit": Color(0.48, 0.56, 0.80), "lit_e": 0.16, "rot": Vector3(-72, -8, 0), "fill": 0.03},
		{"t": 0.82, "sky": Color(0.12, 0.14, 0.24), "amb": Color(0.16, 0.18, 0.28), "amb_e": 0.22, "lit": Color(0.55, 0.50, 0.66), "lit_e": 0.20, "rot": Vector3(-8, -102, 0), "fill": 0.08},
		{"t": 0.92, "sky": Color(0.74, 0.40, 0.34), "amb": Color(0.50, 0.32, 0.28), "amb_e": 0.42, "lit": Color(1.00, 0.60, 0.38), "lit_e": 0.72, "rot": Vector3(-11, -96, 0), "fill": 0.28},
		{"t": 1.00, "sky": Color(0.58, 0.70, 0.84), "amb": Color(0.55, 0.58, 0.64), "amb_e": 0.64, "lit": Color(1.00, 0.92, 0.78), "lit_e": 1.05, "rot": Vector3(-32, -86, 0), "fill": 0.50},
	]
	var t := clampf(p, 0.0, 1.0)
	var a: Dictionary = stops[0]
	var b: Dictionary = stops[stops.size() - 1]
	for i in range(stops.size() - 1):
		if t >= float(stops[i]["t"]) and t <= float(stops[i + 1]["t"]):
			a = stops[i]
			b = stops[i + 1]
			break
	var span := float(b["t"]) - float(a["t"])
	var u := 0.0 if span <= 0.0001 else (t - float(a["t"])) / span
	return {
		"sky": (a["sky"] as Color).lerp(b["sky"] as Color, u),
		"amb": (a["amb"] as Color).lerp(b["amb"] as Color, u),
		"amb_e": lerpf(float(a["amb_e"]), float(b["amb_e"]), u),
		"lit": (a["lit"] as Color).lerp(b["lit"] as Color, u),
		"lit_e": lerpf(float(a["lit_e"]), float(b["lit_e"]), u),
		"rot": (a["rot"] as Vector3).lerp(b["rot"] as Vector3, u),
		"fill": lerpf(float(a["fill"]), float(b["fill"]), u),
	}


func _process(delta: float) -> void:
	if not running:
		return
	if GameState.phase != GameState.Phase.IN_MATCH:
		if GameState.phase == GameState.Phase.LOBBY:
			running = false
			_hide_overlay()
		elif GameState.phase == GameState.Phase.MATCH_OVER and not GameState.morning_reached:
			running = false
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		elapsed_real += delta
		_sync_accum += delta
		if _sync_accum >= SYNC_EVERY:
			_sync_accum = 0.0
			_client_set_elapsed.rpc(elapsed_real)
		if elapsed_real >= MATCH_REAL_SECONDS and not _morning_fired:
			_fire_morning()
	else:
		elapsed_real = minf(elapsed_real + delta, MATCH_REAL_SECONDS)
	apply_lighting()
	clock_updated.emit(progress(), format_clock())


func apply_lighting() -> void:
	var worlds := get_tree().get_nodes_in_group("horror_world")
	for node in worlds:
		if node is Node3D:
			apply_to_world(node)


func apply_to_world(world: Node3D) -> void:
	if world == null:
		return
	var look := sample_lighting(progress())
	var sky := world.get_node_or_null("FarmSky") as WorldEnvironment
	if sky and sky.environment:
		var env := sky.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = look["sky"]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = look["amb"]
		env.ambient_light_energy = look["amb_e"]
	var sun := world.get_node_or_null("SunMoon") as DirectionalLight3D
	if sun:
		sun.light_color = look["lit"]
		sun.light_energy = look["lit_e"]
		sun.rotation_degrees = look["rot"]
		sun.shadow_enabled = true
	var fill := world.get_node_or_null("Outdoor/OutdoorFill") as OmniLight3D
	if fill:
		fill.light_color = (look["lit"] as Color).lerp(look["sky"] as Color, 0.35)
		fill.light_energy = look["fill"]


func _fire_morning() -> void:
	if _morning_fired:
		return
	_morning_fired = true
	elapsed_real = MATCH_REAL_SECONDS
	if GameState.phase == GameState.Phase.IN_MATCH:
		GameState.phase = GameState.Phase.MATCH_OVER
		GameState.morning_reached = true
		if GameState.winning_faction_id.is_empty():
			GameState.winning_faction_id = "puppet_master"
			GameState.puppet_master_won = true
	_client_morning.rpc()


@rpc("authority", "call_remote", "unreliable")
func _client_set_elapsed(t: float) -> void:
	elapsed_real = clampf(t, 0.0, MATCH_REAL_SECONDS)


@rpc("authority", "call_local", "reliable")
func _client_morning() -> void:
	elapsed_real = MATCH_REAL_SECONDS
	running = false
	GameState.phase = GameState.Phase.MATCH_OVER
	GameState.morning_reached = true
	apply_lighting()
	clock_updated.emit(1.0, format_clock())
	morning_reached.emit()
	var overlay_script: GDScript = load("res://scripts/horror/ui/match_end_overlay.gd")
	if GameState.puppet_master_won or GameState.winning_faction_id == "puppet_master":
		overlay_script.call("present", "MORNING", "The child was not brought home. The Puppet Master wins.")
	elif GameState.winning_faction_id == "survivors":
		overlay_script.call("present", "YOU GOT HER HOME", "The missing child is safe. Survivors win.")
	else:
		overlay_script.call("present", "MORNING", "6:00 AM — the night is over.")
	GameState.restore_menu_input()


func _show_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = true
		return
	var packed: GDScript = load("res://scripts/horror/ui/morning_end_overlay.gd")
	if packed == null:
		return
	_overlay = packed.new()
	get_tree().root.add_child(_overlay)


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
