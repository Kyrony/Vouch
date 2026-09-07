extends Area3D
class_name Ladder
## Ladder
##
## Climbable zone that can also be picked up and placed against the
## nearest wall. While placed and vertical against a wall, Player.gd
## switches to ladder-climbing physics via enter_ladder()/exit_ladder().

var top_y: float = 3.0
var room_index: int = -1
var is_carried: bool = false
var is_placed: bool = true
var carrier_peer_id: int = -1

var prompt_text: String = "Pick up ladder"
var _base_scale: Vector3 = Vector3.ONE


func configure(p_top_y: float, p_room_index: int = -1) -> void:
	top_y = p_top_y
	room_index = p_room_index


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_scale = scale


func interact(by_peer_id: int) -> void:
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
	carrier_peer_id = by_peer_id
	monitoring = false
	_client_apply_carry.rpc(by_peer_id, true)
	_apply_carry(by_peer_id, true)


func server_place(by_peer_id: int) -> void:
	if not multiplayer.is_server() or not is_carried or carrier_peer_id != by_peer_id:
		return
	var wall_xform := _find_nearest_wall_transform(by_peer_id)
	is_carried = false
	is_placed = true
	carrier_peer_id = -1
	monitoring = true
	_client_apply_placed.rpc(wall_xform.origin, wall_xform.basis.get_euler().y)
	_apply_placed(wall_xform.origin, wall_xform.basis.get_euler().y)


@rpc("authority", "call_remote", "reliable")
func _client_apply_carry(by_peer_id: int, carrying: bool) -> void:
	_apply_carry(by_peer_id, carrying)


@rpc("authority", "call_remote", "reliable")
func _client_apply_placed(pos: Vector3, rot_y: float) -> void:
	_apply_placed(pos, rot_y)


func _apply_carry(by_peer_id: int, carrying: bool) -> void:
	is_carried = carrying
	is_placed = not carrying
	carrier_peer_id = by_peer_id if carrying else -1
	prompt_text = "Place ladder" if carrying else "Pick up ladder"
	monitoring = not carrying
	if carrying:
		var player := _find_player(by_peer_id)
		if player:
			reparent(player)
			position = Vector3(0.5, -0.3, -0.6)
			rotation = Vector3.ZERO
	else:
		var world := get_tree().root.get_node_or_null("Main/World")
		if world:
			reparent(world)


func _apply_placed(pos: Vector3, rot_y: float) -> void:
	is_carried = false
	is_placed = true
	carrier_peer_id = -1
	prompt_text = "Pick up ladder"
	monitoring = true
	if get_parent() is Player:
		var world := get_tree().root.get_node_or_null("Main/World")
		if world:
			reparent(world)
	global_position = pos
	rotation = Vector3(0, rot_y, 0)
	scale = _base_scale


func _find_nearest_wall_transform(by_peer_id: int) -> Transform3D:
	var player := _find_player(by_peer_id)
	if not player:
		return global_transform
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3(0, 1.0, 0)
	var best_dist := INF
	var best_normal := Vector3.FORWARD
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.0, 1)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.get("normal", Vector3.ZERO).length_squared() > 0.01:
			var dist: float = origin.distance_to(hit["position"])
			if dist < best_dist:
				best_dist = dist
				best_normal = hit["normal"]
	var wall_pos := player.global_position + best_normal * 0.35
	wall_pos.y = 0.0
	var xform := Transform3D.IDENTITY
	xform.origin = wall_pos
	xform = xform.looking_at(wall_pos + best_normal, Vector3.UP)
	return xform


func _find_player(peer_id: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name) == str(peer_id):
			return node as Node3D
	return null


func _on_body_entered(body: Node) -> void:
	if is_carried or not is_placed:
		return
	if body.has_method("enter_ladder"):
		body.enter_ladder(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder(self)
