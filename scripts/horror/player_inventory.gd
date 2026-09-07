extends Node
## PlayerInventory — host-authoritative hotbar (8 slots) for horror survivors.

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
	var slots := server_get_slots(sender)
	if sel < 0 or sel >= slots.size():
		return
	var item := str(slots[sel])
	if item.is_empty():
		return
	_apply_use_item(sender, item)
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


func _apply_use_item(peer_id: int, item_id: String) -> void:
	match item_id:
		"medkit", "bandage":
			PlayerHealth.server_heal(peer_id, 40.0)
		"phone":
			pass
		"keycard":
			pass
		_:
			print("[Inventory] used %s (stub)" % item_id)


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
