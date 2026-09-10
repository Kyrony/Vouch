extends SceneTree
## Headless probe for the Puppet Master's string tether + puppet possession.
## Run: godot4 --headless --path . -s res://scripts/vouch_pm_systems_probe.gd

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK  %s" % label)
	else:
		_failed = true
		push_error("PM PROBE FAIL: %s" % label)
		print("  FAIL %s" % label)


func _run() -> void:
	var mp := root.multiplayer
	mp.multiplayer_peer = OfflineMultiplayerPeer.new()
	var pm: int = 5
	var victim: int = 2

	var PSS := root.get_node("/root/PuppetStringSystem")
	var PCS := root.get_node("/root/PuppetControlSystem")
	PSS.reset()
	PCS.reset()

	# --- Strings: shoot, stack, slow, immobilize ---
	_check(PSS.server_shoot_string(pm, victim) == 1, "shooting a string attaches one")
	_check(is_equal_approx(PSS.server_tether_slow(victim), PSS.SLOW_PER_STRING), "one string applies its slow")
	PSS.server_shoot_string(pm, victim)
	_check(PSS.server_string_count(victim) == 2, "strings stack (shoot more)")
	_check(PSS.server_tether_slow(victim) > PSS.SLOW_PER_STRING, "more strings = more slow")
	_check(not PSS.server_is_immobilized(victim), "two strings don't immobilize")
	PSS.server_shoot_string(pm, victim)
	PSS.server_shoot_string(pm, victim)  # now 4
	_check(PSS.server_is_immobilized(victim), "enough strings immobilize the victim")
	_check(is_equal_approx(PSS.server_tether_slow(victim), PSS.IMMOBILIZE_SLOW), "immobilized slow applied")

	# --- Ghost strings persist through a release ---
	_check(PSS.server_make_ghost(pm, victim), "strings can be turned into ghost strings")
	_check(PSS.server_is_ghosted(victim), "victim is ghosted")
	PSS.server_release(pm, victim)
	_check(PSS.server_string_count(victim) > 0, "ghost strings survive the PM releasing")

	# --- Cutting clears everything ---
	_check(PSS.server_cut(victim, -1), "strings can be cut")
	_check(PSS.server_string_count(victim) == 0 and not PSS.server_is_ghosted(victim), "cut clears all strings + ghost")

	# --- Non-ghost release detaches ---
	PSS.server_shoot_string(pm, victim)
	PSS.server_release(pm, victim)
	_check(PSS.server_string_count(victim) == 0, "non-ghost strings detach on release")

	# --- Surface traps ---
	PSS.server_place_trap(pm, Vector3(10, 0, 10), 2.0)
	_check(not PSS.server_check_traps(victim, Vector3(20, 0, 20)), "far from a trap does nothing")
	_check(PSS.server_check_traps(victim, Vector3(10.5, 0, 10.0)), "walking into a trap snaps a string on")
	_check(PSS.server_string_count(victim) == 1, "trap attached exactly one string")
	_check(not PSS.server_check_traps(victim, Vector3(10.0, 0, 10.0)), "a trap only fires once")
	PSS.server_cut(victim, -1)

	# --- Puppet possession ---
	var GS := root.get_node("/root/GameState")
	GS.server_set_puppet_master(pm)
	_check(not PCS.server_take_puppet(victim), "survivors cannot don the puppet")
	_check(PCS.server_take_puppet(pm), "PM can don the puppet")
	_check(PCS.server_has_puppet(pm), "puppet is active")
	_check(not PCS.server_puppet_grab(pm, victim, 5.0), "puppet can't grab out of range")
	_check(PCS.server_puppet_grab(pm, victim, 1.0), "puppet grabs a survivor in range")
	_check(PCS.server_is_possessed(victim), "grabbed survivor is possessed")
	_check(PCS.server_possessor(victim) == pm, "possessor is the PM")
	_check(int(PCS.get("_controlling").get(pm, 0)) == victim, "PM is driving the captured body")
	_check(not PCS.server_puppet_grab(pm, victim, 1.0), "can't re-grab an already possessed player")

	# --- Freed by a teammate ---
	_check(PCS.server_free(victim), "a teammate can free the possessed player")
	_check(not PCS.server_is_possessed(victim), "freed player is no longer possessed")

	# --- Escape-the-mind minigame ---
	PCS.server_puppet_grab(pm, victim, 1.0)
	var freed := false
	for i in range(int(PCS.ESCAPE_STRUGGLE_NEEDED) + 1):
		if PCS.server_struggle(victim, PCS.STRUGGLE_PER_INPUT):
			freed = true
			break
	_check(freed, "mashing the struggle minigame breaks free")
	_check(not PCS.server_is_possessed(victim), "self-escape ends the possession")

	var player_script: GDScript = load("res://scripts/player.gd")
	_check(is_equal_approx(float(player_script.PUPPET_MODEL_SCALE), 0.25), "puppet is 1/4 PM size")
	_check(is_equal_approx(float(player_script.PUPPET_STAMINA_MAX), 20.0), "puppet stamina is 80% less")
	_check(is_equal_approx(float(player_script.PUPPET_SPRINT_MULTIPLIER), 2.0), "puppet sprint is 2x")
	_check(is_equal_approx(float(player_script.PUPPET_JUMP_MULTIPLIER), 2.0), "puppet jump is 2x")
	var walk: float = float(player_script.SPEED)
	var puppet_sprint: float = float(player_script.puppet_move_speed_for(true))
	_check(absf(puppet_sprint / walk - 2.0) < 0.001, "puppet sprint speed is 2x walk")

	if _failed:
		print("VOUCH PM SYSTEMS PROBE FAILED")
		quit(1)
	else:
		print("VOUCH PM SYSTEMS PROBE OK")
		quit(0)
