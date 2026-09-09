extends "res://scripts/interactables/interactable.gd"
class_name ElectricalBox
## ElectricalBox
##
## Small puzzle: one live wire and three broken wires. The player picks
## which broken wire to connect the live wire to, routing power to that
## target room via RoomUtilities. Host-authoritative; replicated visuals
## only (which wire is connected).

@export var wire_count: int = 3

var room_index: int = -1
## room_index each broken wire would power when connected.
var wire_targets: Array[int] = []
var connected_wire: int = -1

var _wire_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	prompt_text = "Connect live wire"
	_build_wire_visuals()


func configure(p_room_index: int, targets: Array[int]) -> void:
	room_index = p_room_index
	wire_targets = targets.slice(0, mini(wire_count, targets.size()))


func _build_wire_visuals() -> void:
	var colors := [Color(0.85, 0.2, 0.2), Color(0.2, 0.75, 0.3), Color(0.25, 0.45, 0.9)]
	for i in range(wire_count):
		var wire := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, 0.35)
		wire.mesh = box
		wire.position = Vector3(-0.18 + i * 0.18, 0.05, 0.12)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		wire.set_surface_override_material(0, mat)
		add_child(wire)
		_wire_meshes.append(wire)

	# Live wire (yellow) hanging to the side.
	var live := MeshInstance3D.new()
	var live_box := BoxMesh.new()
	live_box.size = Vector3(0.05, 0.05, 0.4)
	live.mesh = live_box
	live.position = Vector3(0.0, -0.08, 0.18)
	var live_mat := StandardMaterial3D.new()
	live_mat.albedo_color = Color(0.95, 0.85, 0.15)
	live_mat.emission_enabled = true
	live_mat.emission = Color(0.9, 0.75, 0.1)
	live_mat.emission_energy_multiplier = 0.6
	live.set_surface_override_material(0, live_mat)
	live.name = "LiveWire"
	add_child(live)


func interact(by_peer_id: int) -> void:
	if connected_wire >= 0:
		return
	# Cycle through wires on each interact for simplicity (E picks next slot).
	if multiplayer.is_server():
		server_connect_next_wire(by_peer_id)
	else:
		_rpc_request_connect.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_connect() -> void:
	if not multiplayer.is_server():
		return
	server_connect_next_wire(multiplayer.get_remote_sender_id())


func server_connect_next_wire(_by_peer_id: int) -> void:
	if not multiplayer.is_server() or connected_wire >= 0:
		return
	# First interact connects wire 0; player can look at different wires via
	# prompt cycling - for MVP we connect to the first target on first use.
	# Host picks wire 0 unless targets empty.
	if wire_targets.is_empty():
		return
	connected_wire = 0
	var target_room: int = wire_targets[connected_wire]
	RoomUtilities.server_set_utility(target_room, RoomUtilities.UTILITY_POWER, true)
	# Deliberately also turn OFF power in the other two target rooms to make
	# the choice meaningful (only one route gets restored).
	for i in range(wire_targets.size()):
		if i != connected_wire:
			RoomUtilities.server_set_utility(wire_targets[i], RoomUtilities.UTILITY_POWER, false)
	_client_apply_connected.rpc(connected_wire)
	_apply_connected(connected_wire)
	var player := _find_player(_by_peer_id)
	if player and player.has_method("_show_toast"):
		player._show_toast("Live wire routed — power restored somewhere.")


@rpc("authority", "call_remote", "reliable")
func _client_apply_connected(wire_idx: int) -> void:
	_apply_connected(wire_idx)


func _apply_connected(wire_idx: int) -> void:
	connected_wire = wire_idx
	prompt_text = "Connected (room %d powered)" % wire_targets[wire_idx] if wire_idx < wire_targets.size() else "Connected"
	for i in range(_wire_meshes.size()):
		var mat := _wire_meshes[i].get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = i == wire_idx
			mat.emission = Color(0.3, 0.9, 0.4) if i == wire_idx else Color.BLACK


func interact_wire_index(wire_idx: int, _by_peer_id: int) -> void:
	if connected_wire >= 0 or wire_idx < 0 or wire_idx >= wire_targets.size():
		return
	if multiplayer.is_server():
		connected_wire = wire_idx
		var target_room: int = wire_targets[wire_idx]
		RoomUtilities.server_set_utility(target_room, RoomUtilities.UTILITY_POWER, true)
		for i in range(wire_targets.size()):
			if i != wire_idx:
				RoomUtilities.server_set_utility(wire_targets[i], RoomUtilities.UTILITY_POWER, false)
		_client_apply_connected.rpc(wire_idx)
		_apply_connected(wire_idx)
	else:
		_rpc_request_wire.rpc_id(1, wire_idx)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_wire(wire_idx: int) -> void:
	if not multiplayer.is_server():
		return
	interact_wire_index(wire_idx, multiplayer.get_remote_sender_id())


func _find_player(peer_id: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node as Node3D
	return null
