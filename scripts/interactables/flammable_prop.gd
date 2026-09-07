extends RigidBody3D
class_name FlammableProp
## FlammableProp
##
## Physics prop that can be picked up, dropped, and ignited near flames.

const DEFAULT_BURN_TIME: float = 4.0

@export var prompt_text: String = "Pick up"
@export var burn_time: float = DEFAULT_BURN_TIME

var is_carried: bool = false
var carrier_peer_id: int = -1
var is_burning: bool = false
var is_charred: bool = false

var _mesh: MeshInstance3D
var _base_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("flammable_props")
	collision_layer = 2
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	_mesh = _find_mesh()
	if _mesh:
		var mat := _mesh.get_surface_override_material(0)
		if mat:
			_base_mat = mat.duplicate()
	set_process(multiplayer.is_server())


func _find_mesh() -> MeshInstance3D:
	for c in get_children():
		if c is MeshInstance3D:
			return c
	return null


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or is_carried or is_charred or is_burning:
		return
	var fire := get_node_or_null("/root/FireSystem")
	if fire:
		fire.server_scan_proximity(self)


func can_ignite() -> bool:
	return not is_carried and not is_charred and not is_burning


func get_burn_duration() -> float:
	return burn_time


func interact(by_peer_id: int) -> void:
	if is_charred or is_burning:
		return
	if is_carried and carrier_peer_id == by_peer_id:
		_request_drop(by_peer_id)
	elif not is_carried:
		_request_pickup(by_peer_id)


func _request_pickup(by_peer_id: int) -> void:
	if multiplayer.is_server():
		server_pickup(by_peer_id)
	else:
		_rpc_pickup.rpc_id(1)


func _request_drop(by_peer_id: int) -> void:
	if multiplayer.is_server():
		server_drop(by_peer_id)
	else:
		_rpc_drop.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pickup() -> void:
	if multiplayer.is_server():
		server_pickup(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop() -> void:
	if multiplayer.is_server():
		server_drop(multiplayer.get_remote_sender_id())


func server_pickup(by_peer_id: int) -> void:
	if not multiplayer.is_server() or is_carried or is_charred:
		return
	var player := _find_player(by_peer_id)
	if not player:
		return
	is_carried = true
	carrier_peer_id = by_peer_id
	freeze = true
	_client_carry.rpc(by_peer_id, true)
	_apply_carry(by_peer_id, true)


func server_drop(by_peer_id: int) -> void:
	if not multiplayer.is_server() or not is_carried or carrier_peer_id != by_peer_id:
		return
	is_carried = false
	carrier_peer_id = -1
	freeze = false
	var drop_pos := global_position
	if _find_player(by_peer_id):
		drop_pos = _find_player(by_peer_id).global_position + _find_player(by_peer_id).transform.basis * Vector3(0.3, 0.2, -0.8)
	_client_carry.rpc(by_peer_id, false)
	_apply_carry(by_peer_id, false)
	global_position = drop_pos
	apply_central_impulse(Vector3(0, 0.5, -1.0))


@rpc("authority", "call_remote", "reliable")
func _client_carry(by_peer_id: int, carrying: bool) -> void:
	_apply_carry(by_peer_id, carrying)


func _apply_carry(by_peer_id: int, carrying: bool) -> void:
	is_carried = carrying
	carrier_peer_id = by_peer_id if carrying else -1
	prompt_text = "Drop" if carrying else "Pick up"
	freeze = carrying
	if carrying:
		var player := _find_player(by_peer_id)
		if player:
			reparent(player)
			position = Vector3(0.35, -0.1, -0.7)
			rotation = Vector3.ZERO
	else:
		var world := get_tree().root.get_node_or_null("Main/World")
		if world:
			reparent(world)


func server_on_ignited() -> void:
	is_burning = true
	client_on_ignited(burn_time)


func client_on_ignited(_duration: float) -> void:
	is_burning = true
	if _mesh and _base_mat:
		var hot := _base_mat.duplicate()
		hot.emission_enabled = true
		hot.emission = Color(1.0, 0.35, 0.05)
		hot.emission_energy_multiplier = 1.5
		_mesh.set_surface_override_material(0, hot)


func server_set_burn_progress(progress: float) -> void:
	_client_burn_progress.rpc(clampf(progress, 0.0, 1.0))


@rpc("authority", "call_remote", "reliable")
func _client_burn_progress(progress: float) -> void:
	if _mesh and _base_mat:
		var mat := _base_mat.duplicate()
		mat.albedo_color = _base_mat.albedo_color.lerp(Color(0.08, 0.06, 0.05), progress)
		mat.emission = Color(1.0, 0.25, 0.02) * progress
		mat.emission_enabled = progress > 0.05
		_mesh.set_surface_override_material(0, mat)


func server_finish_burn() -> void:
	is_charred = true
	is_burning = false
	_client_charred.rpc()


@rpc("authority", "call_remote", "reliable")
func _client_charred() -> void:
	is_charred = true
	is_burning = false
	visible = false
	collision_layer = 0
	freeze = true


func _find_player(peer_id: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node as Node3D
	return null
