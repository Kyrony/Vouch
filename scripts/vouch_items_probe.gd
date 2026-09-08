extends SceneTree
## Headless behavior probe for the 10 survivor items.
## Run: godot4 --headless --path . -s res://scripts/vouch_items_probe.gd
##
## Autoload names aren't global identifiers inside a `-s` script, so we grab
## the singletons via /root and call their server_* API directly.

const PHASE_IN_MATCH := 1  # GameState.Phase.IN_MATCH
const UTIL_POWER := "power"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK  %s" % label)
	else:
		_failed = true
		push_error("ITEMS PROBE FAIL: %s" % label)
		print("  FAIL %s" % label)


func _make_player(peer: int, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = str(peer)
	n.add_to_group("players")
	root.add_child(n)
	n.global_position = at
	return n


func _run() -> void:
	var mp := root.multiplayer
	mp.multiplayer_peer = OfflineMultiplayerPeer.new()
	var me: int = mp.get_unique_id()
	var mate: int = 2

	var GS := root.get_node("/root/GameState")
	var PH := root.get_node("/root/PlayerHealth")
	var PE := root.get_node("/root/PlayerEffects")
	var PI := root.get_node("/root/PlayerInventory")
	var RU := root.get_node("/root/RoomUtilities")
	var PMS := root.get_node("/root/PuppetMasterSystem")

	GS.reset_for_new_match()
	GS.phase = PHASE_IN_MATCH
	GS.server_register_player(me, "Tester")
	GS.server_register_player(mate, "Mate")
	PH.server_init_peer(me)
	PH.server_init_peer(mate)
	PE.server_init_peer(me)
	PE.server_init_peer(mate)
	PI.server_init_peer(me)

	var me_node := _make_player(me, Vector3.ZERO)
	var mate_node := _make_player(mate, Vector3(1.5, 0, 0))
	await process_frame

	# 1) Medkit — big heal, capped at max.
	PH.server_apply_drain(me, 70.0)  # 100 -> 30
	PI._apply_use_item(me, "medkit")
	_check(is_equal_approx(PH.server_get_health(me), 90.0), "medkit heals 60 (30 -> 90)")

	# 2) Bandage — small heal.
	PH.server_apply_drain(me, 40.0)  # 90 -> 50
	PI._apply_use_item(me, "bandage")
	_check(is_equal_approx(PH.server_get_health(me), 75.0), "bandage heals 25 (50 -> 75)")

	# 3) Energy drink — refill stamina.
	PE.server_set_stamina(me, 5.0, true)
	PI._apply_use_item(me, "energy_drink")
	_check(is_equal_approx(PE.server_get_stamina(me), 100.0), "energy drink refills stamina")

	# 4) Painkillers — heal + clear fear.
	PH.server_apply_drain(me, 30.0)  # 75 -> 45
	PE.server_set_fear(me, 80.0)
	PI._apply_use_item(me, "painkillers")
	_check(is_equal_approx(PH.server_get_health(me), 60.0), "painkillers heal 15 (45 -> 60)")
	_check(is_equal_approx(PE.server_get_meters(me).z, 0.0), "painkillers clear fear")

	# 5) Adrenaline — refill stamina, clear fear, snap own strings.
	PE.server_set_stamina(me, 0.0, true)
	PE.server_set_fear(me, 60.0)
	PE.server_set_stringed(me, true)
	PI._apply_use_item(me, "adrenaline")
	_check(is_equal_approx(PE.server_get_stamina(me), 100.0), "adrenaline refills stamina")
	_check(not PE.server_is_stringed(me), "adrenaline cuts own strings")

	# 6) Scissors — free a stringed teammate in reach.
	PE.server_set_stringed(mate, true)
	var scissors_consumed: bool = PI._apply_use_item(me, "scissors")
	_check(not PE.server_is_stringed(mate), "scissors cut teammate's strings")
	_check(scissors_consumed, "scissors consumed on a successful cut")
	var scissors_wasted: bool = PI._apply_use_item(me, "scissors")
	_check(not scissors_wasted, "scissors kept when there's nothing to cut")

	# 7) Fuse — restore power to a dark room.
	GS.server_set_room(me, 3)
	RU.server_init_room(3)
	RU.server_set_utility(3, UTIL_POWER, false)
	var fuse_consumed: bool = PI._apply_use_item(me, "fuse")
	_check(RU.is_enabled(3, UTIL_POWER), "fuse restores room power")
	_check(fuse_consumed, "fuse consumed when a room needed power")
	_check(not bool(PI._apply_use_item(me, "fuse")), "fuse kept when power already on")

	# 8) Light switch — toggle room lights on/off, reusable.
	var ls_consumed: bool = PI._apply_use_item(me, "light_switch")
	_check(not RU.is_enabled(3, UTIL_POWER), "light switch turns lights off")
	_check(not ls_consumed, "light switch is reusable (not consumed)")
	PI._apply_use_item(me, "light_switch")
	_check(RU.is_enabled(3, UTIL_POWER), "light switch turns lights back on")

	# 9) Flare — consumable.
	_check(bool(PI._apply_use_item(me, "flare")), "flare is consumed on use")

	# 10) Crowbar — stun the Puppet Master in reach; life-steal locks out.
	GS.server_set_puppet_master(mate)
	mate_node.global_position = me_node.global_position + Vector3(1.0, 0, 0)
	var crowbar_consumed: bool = PI._apply_use_item(me, "crowbar")
	_check(PMS.server_is_pm_stunned(), "crowbar stuns the Puppet Master")
	_check(not crowbar_consumed, "crowbar is a reusable tool (not consumed)")
	var victim_hp: float = PH.server_get_health(me)
	PE.server_apply_life_steal(me, mate, 0.5, 8.0, 1.0)
	_check(is_equal_approx(PH.server_get_health(me), victim_hp), "PM drain is blocked while stunned")

	# Hotbar consumption flow: medkit leaves the slot, crowbar stays.
	PI.server_add_item(me, "medkit")
	PI.server_add_item(me, "crowbar")
	var medkit_slot: int = (PI.server_get_slots(me) as Array).find("medkit")
	PI.server_set_selected(me, medkit_slot)
	PI._server_use_selected(me)
	_check((PI.server_get_slots(me) as Array)[medkit_slot] == "", "hotbar: medkit consumed on use")
	var crowbar_slot: int = (PI.server_get_slots(me) as Array).find("crowbar")
	PI.server_set_selected(me, crowbar_slot)
	PI._server_use_selected(me)
	_check((PI.server_get_slots(me) as Array)[crowbar_slot] == "crowbar", "hotbar: crowbar stays after use")

	if _failed:
		print("VOUCH ITEMS PROBE FAILED")
		quit(1)
	else:
		print("VOUCH ITEMS PROBE OK")
		quit(0)
