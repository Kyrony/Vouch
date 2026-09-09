extends SceneTree
## Headless behavior probe for the survivor items.
## Run: godot4 --headless --path . -s res://scripts/vouch_items_probe.gd

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


func _new_prop(path: String, props: Dictionary, at: Vector3) -> Node:
	var node: Node = load(path).new()
	for k in props:
		node.set(k, props[k])
	root.add_child(node)
	if node is Node3D:
		(node as Node3D).global_position = at
	return node


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
	var PSS := root.get_node("/root/PuppetStringSystem")
	var CAT := load("res://scripts/horror/items/item_catalog.gd")

	GS.reset_for_new_match()
	GS.phase = PHASE_IN_MATCH
	GS.server_register_player(me, "Tester")
	GS.server_register_player(mate, "Mate")
	PH.server_init_peer(me)
	PH.server_init_peer(mate)
	PE.server_init_peer(me)
	PE.server_init_peer(mate)
	PI.server_init_peer(me)
	PSS.reset()

	var me_node := _make_player(me, Vector3.ZERO)
	_make_player(mate, Vector3(1.5, 0, 0))
	await process_frame

	# Heals.
	PH.server_apply_drain(me, 70.0)  # -> 30
	PI._apply_use_item(me, "medkit")
	_check(is_equal_approx(PH.server_get_health(me), 90.0), "medkit heals 60")
	PH.server_apply_drain(me, 40.0)  # -> 50
	PI._apply_use_item(me, "bandage")
	_check(is_equal_approx(PH.server_get_health(me), 75.0), "bandage heals 25")
	PH.server_apply_drain(me, 30.0)  # -> 45
	PE.server_set_fear(me, 80.0)
	PI._apply_use_item(me, "painkillers")
	_check(is_equal_approx(PH.server_get_health(me), 60.0), "painkillers heal 15")
	_check(is_equal_approx(PE.server_get_meters(me).z, 0.0), "painkillers clear fear")

	# Stamina.
	PE.server_set_stamina(me, 5.0, true)
	PI._apply_use_item(me, "energy_drink")
	_check(is_equal_approx(PE.server_get_stamina(me), 100.0), "energy drink refills stamina")

	# Adrenaline cuts your own strings.
	PE.server_set_stamina(me, 0.0, true)
	PSS.server_shoot_string(mate, me)
	PSS.server_shoot_string(mate, me)
	PI._apply_use_item(me, "adrenaline")
	_check(is_equal_approx(PE.server_get_stamina(me), 100.0), "adrenaline refills stamina")
	_check(PSS.server_string_count(me) == 0, "adrenaline snaps your own strings")

	# Scissors cut a tethered teammate.
	PSS.server_shoot_string(mate, mate)
	PSS.server_shoot_string(mate, mate)
	var scissors_consumed: bool = PI._apply_use_item(me, "scissors")
	_check(PSS.server_string_count(mate) == 0, "scissors cut teammate's strings")
	_check(scissors_consumed, "scissors consumed on a cut")
	_check(not bool(PI._apply_use_item(me, "scissors")), "scissors kept with nothing to cut")

	# Fuse -> fuse box restores that circuit's power.
	RU.server_init_room(3)
	RU.server_set_utility(3, UTIL_POWER, false)
	var box := _new_prop("res://scripts/interactables/props/fuse_box.gd", {"room_index": 3}, Vector3(1.0, 0, 0))
	var fused: bool = PI._apply_use_item(me, "fuse")
	_check(fused and box.server_is_powered(), "fuse box powers its circuit")
	_check(RU.is_enabled(3, UTIL_POWER), "fuse restores room power")
	_check(not bool(PI._apply_use_item(me, "fuse")), "fuse kept when no empty box in reach")

	# Crowbar: stun the PM AND pry a locked gate.
	GS.server_set_puppet_master(mate)
	var gate := _new_prop("res://scripts/interactables/props/locked_gate.gd", {"locked": true}, Vector3(1.2, 0, 0))
	var crowbar_consumed: bool = PI._apply_use_item(me, "crowbar")
	_check(PMS.server_is_pm_stunned(), "crowbar stuns the Puppet Master")
	_check(not gate.server_is_locked() and gate.server_is_open(), "crowbar pries a locked gate open")
	_check(not crowbar_consumed, "crowbar is reusable")

	# Key unlocks (consumed); lockpick unlocks (reusable).
	var gate2 := _new_prop("res://scripts/interactables/props/locked_gate.gd", {"locked": true}, Vector3(1.0, 0, 0))
	var key_consumed: bool = PI._apply_use_item(me, "key")
	_check(not gate2.server_is_locked(), "key unlocks a gate")
	_check(key_consumed, "key is consumed")
	var gate3 := _new_prop("res://scripts/interactables/props/locked_gate.gd", {"locked": true}, Vector3(1.0, 0, 0))
	var pick_consumed: bool = PI._apply_use_item(me, "lockpick")
	_check(not gate3.server_is_locked(), "lockpick unlocks a gate")
	_check(not pick_consumed, "lockpick is reusable")

	# Different use times.
	_check(is_equal_approx(CAT.use_time("medkit"), 3.0), "medkit use time 3s")
	_check(is_equal_approx(CAT.use_time("flare"), 0.5), "flare use time 0.5s")
	_check(CAT.use_time("medkit") > CAT.use_time("energy_drink"), "medkit takes longer than energy drink")

	# Light switch is no longer an item.
	_check(not CAT.has_item("light_switch"), "light switch is a prop, not an item")

	# Timed hotbar flow: start use -> complete -> consume (medkit) / keep (crowbar).
	PI.server_add_item(me, "medkit")
	PI.server_add_item(me, "crowbar")
	var mslot: int = (PI.server_get_slots(me) as Array).find("medkit")
	PI.server_set_selected(me, mslot)
	PH.server_apply_drain(me, 50.0)
	PI._server_use_selected(me)
	PI._complete_pending_use(me, "medkit")
	_check((PI.server_get_slots(me) as Array)[mslot] == "", "hotbar: medkit consumed after timed use")
	var cslot: int = (PI.server_get_slots(me) as Array).find("crowbar")
	PI.server_set_selected(me, cslot)
	PI._server_use_selected(me)
	PI._complete_pending_use(me, "crowbar")
	_check((PI.server_get_slots(me) as Array)[cslot] == "crowbar", "hotbar: crowbar stays after use")

	if _failed:
		print("VOUCH ITEMS PROBE FAILED")
		quit(1)
	else:
		print("VOUCH ITEMS PROBE OK")
		quit(0)
