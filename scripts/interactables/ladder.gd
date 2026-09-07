extends Area3D
class_name Ladder
## Ladder
##
## Independent grabbable ladder. Place on its feet, lean forward until the
## top hits a wall, then climb along the ladder's axis.

const LADDER_LENGTH: float = 2.4
const LEAN_SPEED: float = 2.2
const MAX_LEAN_DEG: float = 78.0

var top_y: float = 3.0
var room_index: int = -1
var is_carried: bool = false
var is_placed: bool = true
var is_leaning: bool = false
var is_leaning_anim: bool = false
var carrier_peer_id: int = -1
var lean_pitch: float = 0.0
var lean_yaw: float = 0.0

var prompt_text: String = "Pick up ladder"
var _base_scale: Vector3 = Vector3.ONE
var _feet_pos: Vector3 = Vector3.ZERO
var _wall_normal: Vector3 = Vector3.FORWARD


func configure(p_top_y: float, p_room_index: int = -1) -> void:
	top_y = p_top_y
	room_index = p_room_index


func _ready() -> void:
	add_to_group("flammable_props")
	add_to_group("wood_props")
	collision_layer = 0
	collision_mask = 4
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_scale = scale
	if is_placed and not is_leaning:
		monitoring = false
	set_process(true)


func _process(delta: float) -> void:
	if is_leaning_anim and multiplayer.is_server():
		_step_lean(delta)
	if is_leaning and multiplayer.is_server() and not is_carried:
		var fire := get_node_or_null("/root/FireSystem")
		if fire:
			fire.server_scan_proximity(self, 1.3)


func _step_lean(delta: float) -> void:
	var target_rad := deg_to_rad(MAX_LEAN_DEG)
	lean_pitch = minf(lean_pitch + LEAN_SPEED * delta, target_rad)
	_apply_lean_transform()
	var top := _ladder_top_world()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(top, top + _wall_normal * 0.6, 1)
	var hit := space.intersect_ray(query)
	if hit.has("position") or lean_pitch >= target_rad - 0.01:
		is_leaning_anim = false
		is_leaning = true
		lean_pitch = target_rad
		_apply_lean_transform()
		_client_finish_lean.rpc(_feet_pos, lean_yaw, lean_pitch)


func can_ignite() -> bool:
	return is_leaning and not is_carried


func get_burn_duration() -> float:
	return 6.0


func server_on_ignited() -> void:
	client_on_ignited(get_burn_duration())


func client_on_ignited(_duration: float) -> void:
	for c in get_children():
		if c is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.15, 0.08, 0.05)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.3, 0.05)
			c.set_surface_override_material(0, mat)


func server_finish_burn() -> void:
	_client_burned.rpc()


@rpc("authority", "call_remote", "reliable")
func _client_burned() -> void:
	visible = false
	monitoring = false
	is_placed = false


func get_climb_up() -> Vector3:
	if is_leaning:
		return (Basis.from_euler(Vector3(-lean_pitch, lean_yaw, 0)) * Vector3.UP).normalized()
	return Vector3.UP


func interact(by_peer_id: int) -> void:
	if is_leaning_anim:
		return
	if is_carried and carrier_peer_id == by_peer_id:
		if multiplayer.is_server():
			server_place(by_peer_id)
		else:
			_rpc_request_place.rpc_id(1)
	elif not is_carried and is_placed:
		if multiplayer.is_server():
			server_pickup(by_peer_id)
		else:
			_rpc_request_pickup.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_pickup() -> void:
	if multiplayer.is_server():
		server_pickup(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_place() -> void:
	if multiplayer.is_server():
		server_place(multiplayer.get_remote_sender_id())


func server_pickup(by_peer_id: int) -> void:
	if not multiplayer.is_server() or is_carried:
		return
	is_carried = true
	is_placed = false
	is_leaning = false
	is_leaning_anim = false
	lean_pitch = 0.0
	carrier_peer_id = by_peer_id
	monitoring = false
	_client_apply_carry.rpc(by_peer_id, true)
	_apply_carry(by_peer_id, true)


func server_place(by_peer_id: int) -> void:
	if not multiplayer.is_server() or not is_carried or carrier_peer_id != by_peer_id:
		return
	var player := _find_player(by_peer_id)
	if not player:
		return
	_feet_pos = player.global_position
	_feet_pos.y = 0.0
	_wall_normal = _find_wall_normal(player)
	lean_yaw = atan2(_wall_normal.x, _wall_normal.z)
	lean_pitch = 0.0
	is_carried = false
	is_placed = true
	is_leaning = false
	is_leaning_anim = true
	carrier_peer_id = -1
	monitoring = false
	var room := _find_room_parent(player)
	_client_start_lean.rpc(_feet_pos, lean_yaw, room.get_path() if room else NodePath())
	_apply_placed_feet(_feet_pos, lean_yaw, room)


@rpc("authority", "call_remote", "reliable")
func _client_apply_carry(by_peer_id: int, carrying: bool) -> void:
	_apply_carry(by_peer_id, carrying)


@rpc("authority", "call_remote", "reliable")
func _client_start_lean(feet: Vector3, yaw: float, room_path: NodePath = NodePath()) -> void:
	var room: Node = null
	if not room_path.is_empty():
		room = get_node_or_null(room_path)
	_apply_placed_feet(feet, yaw, room)
	is_leaning_anim = multiplayer.is_server()


@rpc("authority", "call_remote", "reliable")
func _client_finish_lean(feet: Vector3, yaw: float, pitch: float) -> void:
	_feet_pos = feet
	lean_yaw = yaw
	lean_pitch = pitch
	is_leaning = true
	is_leaning_anim = false
	monitoring = true
	_apply_lean_transform()


func _apply_carry(by_peer_id: int, carrying: bool) -> void:
	is_carried = carrying
	is_placed = not carrying
	carrier_peer_id = by_peer_id if carrying else -1
	prompt_text = "Place ladder" if carrying else "Pick up ladder"
	monitoring = false
	if carrying:
		var player := _find_player(by_peer_id)
		if player:
			reparent(player)
			position = Vector3(0.5, -0.3, -0.6)
			rotation = Vector3.ZERO
			lean_pitch = 0.0
			visible = true
	else:
		visible = true


func _apply_placed_feet(feet: Vector3, yaw: float, room: Node = null) -> void:
	is_carried = false
	is_placed = true
	carrier_peer_id = -1
	prompt_text = "Pick up ladder"
	if get_parent() != null and (get_parent() as Node).is_in_group("players"):
		if room:
			reparent(room)
		else:
			var world := get_tree().root.get_node_or_null("Main/World")
			if world:
				reparent(world)
	_feet_pos = feet
	lean_yaw = yaw
	global_position = feet
	rotation = Vector3(0, yaw, 0)
	scale = _base_scale
	visible = true


func _apply_lean_transform() -> void:
	global_position = _feet_pos
	rotation = Vector3(-lean_pitch, lean_yaw, 0)
	if is_leaning or is_leaning_anim:
		monitoring = is_leaning


func _ladder_top_world() -> Vector3:
	return global_position + get_climb_up() * LADDER_LENGTH


func _find_wall_normal(player: Node3D) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3(0, 1.0, 0)
	var forward := Vector3(sin(lean_yaw), 0, cos(lean_yaw))
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 5.0, 1)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.has("normal"):
		var n: Vector3 = hit["normal"]
		n.y = 0
		if n.length_squared() > 0.01:
			return n.normalized()
	return forward


func _find_player(peer_id: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node as Node3D
	return null


func _find_room_parent(player: Node3D) -> Node:
	var col := int(roundi(player.global_position.x / WorldScale.GRID_SPACING))
	var row := int(roundi(player.global_position.z / WorldScale.GRID_SPACING))
	var room_idx := row * 4 + col
	var match_node := get_tree().root.get_node_or_null("Main/World/Match")
	if match_node:
		var pod := match_node.get_node_or_null("RoomsContainer/RoomPod_%d" % room_idx)
		if pod:
			return pod
	return get_tree().root.get_node_or_null("Main/World")


func _on_body_entered(body: Node) -> void:
	if is_carried or not is_placed or not is_leaning:
		return
	if body.has_method("enter_ladder"):
		body.enter_ladder(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder(self)
