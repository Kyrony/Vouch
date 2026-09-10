extends "res://scripts/interactables/interactable.gd"
class_name FuseBox
## A wall fuse box. Insert a fuse (survivor item) to restore power to its
## circuit: room lights, motorised doors/garages, and the cell-phone tower
## for that area all come back online.
##
## Host-authoritative.

# ── TUNABLES — fuse box circuit ──
@export var room_index: int = -1  # which room/circuit this box powers
@export var has_fuse: bool = false  # starts empty (blown)

var powered: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("fuse_boxes")
	prompt_text = "Fuse box"
	collision_layer = 2
	collision_mask = 0
	if multiplayer.is_server() and has_fuse:
		_power_circuit(true)


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		_try_insert(by_peer_id)
	else:
		_rpc_try_insert.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_try_insert() -> void:
	if multiplayer.is_server():
		_try_insert(multiplayer.get_remote_sender_id())


func _try_insert(by_peer_id: int) -> void:
	if not PlayerInventory.server_has_item(by_peer_id, "fuse"):
		return
	if server_insert_fuse(by_peer_id):
		PlayerInventory.server_remove_item(by_peer_id, "fuse")


func needs_fuse() -> bool:
	return not has_fuse


## Called when a survivor uses a Fuse item next to this box. Returns true if a
## fuse was actually needed and inserted.
func server_insert_fuse(_by_peer_id: int) -> bool:
	if not multiplayer.is_server() or has_fuse:
		return false
	has_fuse = true
	_power_circuit(true)
	_client_set_fused.rpc(true)
	return true


func server_is_powered() -> bool:
	return powered


func _power_circuit(on: bool) -> void:
	powered = on
	if room_index >= 0:
		# Lights + comms (phone tower) for the circuit.
		RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_POWER, on)
		RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_COMMS, on)
	# Wake any cell towers wired to this circuit.
	for tower in get_tree().get_nodes_in_group("cell_towers"):
		if int(tower.get("circuit_room")) == room_index and tower.has_method("server_set_powered"):
			tower.call("server_set_powered", on)


@rpc("authority", "call_local", "reliable")
func _client_set_fused(fused: bool) -> void:
	has_fuse = fused
	prompt_text = "Fuse box (live)" if fused else "Fuse box"
