extends Node
## PlayerInventory — host-authoritative hotbar (8 slots) for horror survivors.

const _CATALOG: GDScript = preload("res://scripts/horror/items/item_catalog.gd")

signal inventory_changed(slots: Array, selected: int)
signal local_inventory_changed(slots: Array, selected: int)

const SLOT_COUNT: int = 8
const EMPTY: String = ""

var _inventories: Dictionary = {}
var _selected: Dictionary = {}


func reset() -> void:
	_inventories.clear()
	_selected.clear()


func server_init_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var slots: Array = []
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = EMPTY
	_inventories[peer_id] = slots
	_selected[peer_id] = 0
	PhoneDevice.server_init_peer(peer_id)
	_broadcast(peer_id)


func server_add_item(peer_id: int, item_id: String) -> bool:
	if not multiplayer.is_server():
		return false
	if not _inventories.has(peer_id):
		server_init_peer(peer_id)
	var slots: Array = _inventories[peer_id]
	for i in SLOT_COUNT:
		if str(slots[i]) == EMPTY:
			slots[i] = item_id
			_inventories[peer_id] = slots
			_broadcast(peer_id)
			return true
	return false


func server_remove_slot(peer_id: int, slot_index: int) -> String:
	if not multiplayer.is_server():
		return EMPTY
	if not _inventories.has(peer_id):
		return EMPTY
	var slots: Array = _inventories[peer_id]
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return EMPTY
	var item: String = str(slots[slot_index])
	slots[slot_index] = EMPTY
	_inventories[peer_id] = slots
	_broadcast(peer_id)
	return item


func server_get_selected(peer_id: int) -> int:
	return int(_selected.get(peer_id, 0))


func server_set_selected(peer_id: int, index: int) -> void:
	if not multiplayer.is_server():
		return
	index = clampi(index, 0, SLOT_COUNT - 1)
	_selected[peer_id] = index
	_broadcast(peer_id)


func server_get_slots(peer_id: int) -> Array:
	if _inventories.has(peer_id):
		return (_inventories[peer_id] as Array).duplicate()
	var empty: Array = []
	empty.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		empty[i] = EMPTY
	return empty


func server_has_item(peer_id: int, item_id: String) -> bool:
	for slot in server_get_slots(peer_id):
		if str(slot) == item_id:
			return true
	return false


func server_selected_item(peer_id: int) -> String:
	var slots := server_get_slots(peer_id)
	var sel := server_get_selected(peer_id)
	if sel < 0 or sel >= slots.size():
		return EMPTY
	return str(slots[sel])


func _broadcast(peer_id: int) -> void:
	var slots: Array = server_get_slots(peer_id)
	var sel: int = server_get_selected(peer_id)
	inventory_changed.emit(peer_id, slots, sel)
	if peer_id == multiplayer.get_unique_id():
		local_inventory_changed.emit(slots, sel)
	else:
		_client_inventory.rpc_id(peer_id, slots, sel)


@rpc("authority", "call_remote", "reliable")
func _client_inventory(slots: Array, selected: int) -> void:
	local_inventory_changed.emit(slots, selected)


@rpc("any_peer", "call_remote", "reliable")
func request_pickup(pickup_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if GameState.players.get(sender, {}).get("is_puppet_master", false):
		return
	var node := get_node_or_null(pickup_path)
	if node == null or not node.has_method("server_try_pickup"):
		return
	node.call("server_try_pickup", sender)


func request_use_selected() -> void:
	if multiplayer.is_server():
		_server_use_selected(multiplayer.get_unique_id())
	else:
		_rpc_use_selected.rpc_id(1)


func request_drop_selected() -> void:
	if multiplayer.is_server():
		_server_drop_selected(multiplayer.get_unique_id())
	else:
		_rpc_drop_selected.rpc_id(1)


func _server_use_selected(sender: int) -> void:
	var sel := server_get_selected(sender)
	var item := server_selected_item(sender)
	if item.is_empty():
		return
	# Smartphone is a tool: R toggles the camera LED. Do not consume it.
	if item == "phone":
		PhoneDevice.server_toggle_led(sender)
		return
	if item == "battery":
		if PhoneDevice.server_recharge(sender):
			server_remove_slot(sender, sel)
		return
	# Consume the item only if the use actually did something / it's a
	# one-shot. Reusable tools (crowbar, light switch) stay in the slot.
	if _apply_use_item(sender, item):
		server_remove_slot(sender, sel)


func _server_drop_selected(sender: int) -> void:
	var sel := server_get_selected(sender)
	var item := server_remove_slot(sender, sel)
	if item.is_empty():
		return
	_spawn_dropped_item(sender, item)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_use_selected() -> void:
	if not multiplayer.is_server():
		return
	_server_use_selected(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop_selected() -> void:
	if not multiplayer.is_server():
		return
	_server_drop_selected(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func request_select_slot(index: int) -> void:
	if not multiplayer.is_server():
		return
	server_set_selected(multiplayer.get_remote_sender_id(), index)


## Applies an item's effect. Returns true if the item should be consumed
## (removed from the hotbar). Reusable tools return false.
func _apply_use_item(peer_id: int, item_id: String) -> bool:
	var def: Dictionary = _CATALOG.get_item(item_id)
	match item_id:
		"medkit", "bandage", "painkillers":
			var heal := float(def.get("heal", 0.0))
			if heal > 0.0:
				PlayerHealth.server_heal(peer_id, heal)
			if float(def.get("fear_relief", 0.0)) > 0.0:
				PlayerEffects.server_set_fear(peer_id, 0.0)
			return true
		"energy_drink":
			PlayerEffects.server_set_stamina(peer_id, float(def.get("stamina", 100.0)), true)
			return true
		"adrenaline":
			PlayerEffects.server_set_stamina(peer_id, float(def.get("stamina", 100.0)), true)
			PlayerEffects.server_set_fear(peer_id, 0.0)
			PlayerEffects.server_set_stringed(peer_id, false)  # snap your own strings
			return true
		"scissors":
			return _use_scissors(peer_id, float(def.get("cut_range", 4.0)))
		"fuse":
			return _use_fuse(peer_id)
		"light_switch":
			_toggle_room_lights(peer_id)
			return false  # reusable switch
		"flare":
			_drop_flare(peer_id, def)
			return true
		"crowbar":
			_swing_crowbar(peer_id, def)
			return false  # reusable tool
		"keycard":
			return true
		_:
			print("[Inventory] used %s (stub)" % item_id)
			return true


## Scissors: free the nearest stringed survivor in reach (or cut your own).
func _use_scissors(peer_id: int, reach: float) -> bool:
	var me := _find_player(peer_id) as Node3D
	if me == null:
		return false
	var best_peer: int = -1
	var best_dist: float = reach
	for node in get_tree().get_nodes_in_group("players"):
		var pid := str(node.name).to_int()
		if pid == peer_id or not PlayerEffects.server_is_stringed(pid):
			continue
		var d := me.global_position.distance_to((node as Node3D).global_position)
		if d <= best_dist:
			best_dist = d
			best_peer = pid
	if best_peer != -1:
		PlayerEffects.server_set_stringed(best_peer, false)
		return true
	if PlayerEffects.server_is_stringed(peer_id):
		PlayerEffects.server_set_stringed(peer_id, false)
		return true
	return false  # nothing to cut — keep the scissors


## Fuse: restore power (+comms) to your room, only if it was actually out.
func _use_fuse(peer_id: int) -> bool:
	var room := int(GameState.players.get(peer_id, {}).get("room_id", -1))
	if room < 0 or RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_POWER):
		return false
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_POWER, true)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_COMMS, true)
	return true


## Light switch: flip your room's lights (power) on/off.
func _toggle_room_lights(peer_id: int) -> void:
	var room := int(GameState.players.get(peer_id, {}).get("room_id", -1))
	if room < 0:
		return
	var on := RoomUtilities.is_enabled(room, RoomUtilities.UTILITY_POWER)
	RoomUtilities.server_set_utility(room, RoomUtilities.UTILITY_POWER, not on)


## Flare: drop a temporary light at your feet.
func _drop_flare(peer_id: int, def: Dictionary) -> void:
	var me := _find_player(peer_id) as Node3D
	var world := get_tree().get_first_node_in_group("horror_world")
	if me == null or world == null or not world.has_method("spawn_flare"):
		return
	world.call("spawn_flare", me.global_position,
		float(def.get("light_range", 9.0)), float(def.get("light_seconds", 30.0)))


## Crowbar: strike the Puppet Master if they're right in front, locking out
## their abilities briefly.
func _swing_crowbar(peer_id: int, def: Dictionary) -> void:
	var pm := GameState.puppet_master_peer_id
	if pm <= 0:
		return
	var me := _find_player(peer_id) as Node3D
	var pm_node := _find_player(pm) as Node3D
	if me == null or pm_node == null:
		return
	if me.global_position.distance_to(pm_node.global_position) <= float(def.get("stun_range", 3.0)):
		PuppetMasterSystem.server_stun(float(def.get("stun_seconds", 3.0)))


func _spawn_dropped_item(peer_id: int, item_id: String) -> void:
	var player := _find_player(peer_id)
	if player == null:
		return
	var world := get_tree().get_first_node_in_group("horror_world")
	if world == null:
		return
	var drop_pos: Vector3 = (player as Node3D).global_position + (player as Node3D).global_transform.basis.z * 0.8
	world.call("spawn_pickup", item_id, drop_pos)


func _find_player(peer_id: int) -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node
	return null
