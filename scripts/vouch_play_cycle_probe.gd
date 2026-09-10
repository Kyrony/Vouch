extends SceneTree
## Headless probe for the horror play cycle: child → carry → escape win,
## empty-handed escape lock, farm props, morning PM win.
## Run: godot4 --headless --path . -s res://scripts/vouch_play_cycle_probe.gd

const PHASE_IN_MATCH := 1
const PHASE_MATCH_OVER := 2

var _failed := false
var _locked_msg := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK  %s" % label)
	else:
		_failed = true
		push_error("PLAY CYCLE PROBE FAIL: %s" % label)
		print("  FAIL %s" % label)


func _make_player(peer: int, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = str(peer)
	n.add_to_group("players")
	root.add_child(n)
	n.global_position = at
	return n


func _on_escape_locked(msg: String) -> void:
	_locked_msg = msg


func _run() -> void:
	var mp := root.multiplayer
	mp.multiplayer_peer = OfflineMultiplayerPeer.new()
	var me: int = mp.get_unique_id()

	var GS := root.get_node("/root/GameState")
	var ES := root.get_node("/root/EscapeSystem")
	var RNG := root.get_node("/root/ChildSpawnRNG")
	var CAT := load("res://scripts/horror/items/item_catalog.gd")
	var PROPS := load("res://scripts/horror/world/farm_props.gd")
	var CLOCK := root.get_node("/root/MatchClock")
	var OVERLAY := load("res://scripts/horror/ui/match_end_overlay.gd")

	GS.reset_for_new_match()
	GS.phase = PHASE_IN_MATCH
	GS.server_register_player(me, "Carrier")
	GS.players[me]["faction_id"] = "survivors"
	GS.players[me]["room_id"] = 0
	RNG.reset()
	ES.reset()

	var me_node := _make_player(me, Vector3.ZERO)
	ES.server_register_player_node(me, me_node)
	ES.escape_locked.connect(_on_escape_locked)
	await process_frame

	_check(CAT.has_item("shovel") and CAT.has_item("rope") and CAT.has_item("firearm"), "carry-cycle tools exist")

	RNG.set("_active_spawn_id", "garden_well")
	RNG.set("_active_global_pos", Vector3.ZERO)
	RNG.set("_child_found", false)
	RNG.set("_child_carrier_peer", -1)

	ES.server_handle_escape_request(me)
	_check(not bool(GS.players[me]["escaped"]), "empty-handed escape is refused")
	_check(_locked_msg.find("child") >= 0, "empty-handed escape tells you to bring the child")
	_check(GS.winning_faction_id.is_empty(), "match continues without the child")

	_check(RNG.server_try_pickup_child(me, Vector3(0.5, 0, 0)), "survivor can pick up the child")
	_check(RNG.server_is_carrier(me), "finder is the carrier")
	_check(not RNG.server_try_pickup_child(me, Vector3.ZERO), "child cannot be picked up twice")

	ES.server_handle_escape_request(me)
	_check(bool(GS.players[me]["escaped"]), "carrier reaching the zone escapes")
	_check(GS.winning_faction_id == "survivors", "carrying the child home wins for survivors")
	_check(GS.phase == PHASE_MATCH_OVER, "match ends when the child is home")
	_check(not bool(CLOCK.get("running")), "match clock stops on a child-home win")

	var world := Node3D.new()
	world.name = "PropFarm"
	root.add_child(world)
	PROPS.call("install_on_world", world)
	_check(world.get_node_or_null("PlayableProps") != null, "farm props folder exists")
	_check(world.get_node_or_null("PlayableProps/FuseBox") != null, "fuse box spawned")
	_check(world.get_node_or_null("PlayableProps/LockedGate") != null, "locked gate spawned")
	_check(world.get_node_or_null("PlayableProps/DigSiteKey") != null, "shovel dig site spawned")
	_check(world.get_node_or_null("PlayableProps/RopeAnchor") != null, "rope anchor spawned")
	_check(PROPS.has_method("install_at"), "FarmProps.install_at can drop props at a test origin")
	var cmds: GDScript = load("res://scripts/debug/debug_commands.gd")
	_check(cmds.has_method("spawn_farm_props") and cmds.has_method("wear_puppet"), "debug GUI can spawn farm props and wear the puppet")
	_check(cmds.has_method("spawn_debug_pawn"), "debug GUI can spawn a capturable dummy")
	var hud_script: GDScript = load("res://scripts/horror/ui/puppet_hud.gd")
	_check(hud_script != null, "predator HUD script loads")
	var tscn := FileAccess.get_file_as_string("res://scenes/Horror/HorrorWorld.tscn")
	_check(not tscn.contains("FogVolume") and not tscn.contains("FogMaterial"), "farm scene has no OpenGL FogVolume")

	var practice := Node3D.new()
	practice.name = "PracticeRoot"
	root.add_child(practice)
	PROPS.call("install_on_practice", practice)
	_check(practice.get_node_or_null("PlayableProps/LockedGate") != null, "practice gate spawned")

	OVERLAY.call("present", "YOU GOT HER HOME", "The missing child is safe. Survivors win.")
	await process_frame
	_check(root.get_node_or_null("MatchEndOverlay") != null, "match-end overlay presents")

	GS.reset_for_new_match()
	GS.phase = PHASE_IN_MATCH
	CLOCK.reset_and_start()
	CLOCK.elapsed_real = CLOCK.MATCH_REAL_SECONDS
	CLOCK.call("_fire_morning")
	await process_frame
	_check(GS.winning_faction_id == "puppet_master" or GS.puppet_master_won, "morning without a child-home win is a PM win")

	if _failed:
		print("VOUCH PLAY CYCLE PROBE FAILED")
		quit(1)
	else:
		print("VOUCH PLAY CYCLE PROBE OK")
		quit(0)
