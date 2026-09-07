extends CharacterBody3D
## PMChaseAI — simple chase stub when no human Puppet Master is active.

const _PM: GDScript = preload("res://scripts/horror/characters/puppet_master_data.gd")

const CHASE_SPEED: float = 5.5

var _active: bool = false
var _target: Node3D = null


func _ready() -> void:
	add_to_group("pm_ai")
	add_to_group("puppet_master_entities")
	collision_layer = 4
	collision_mask = 1
	visible = false
	set_physics_process(false)


func server_activate(spawn_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	global_position = spawn_pos
	visible = true
	_active = true
	set_physics_process(true)
	print("[PMChaseAI] activated at %s" % spawn_pos)


func server_deactivate() -> void:
	_active = false
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _active:
		return
	_target = _pick_target()
	if _target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0
	var dist := to_target.length()
	if dist > 0.3:
		velocity = to_target.normalized() * CHASE_SPEED
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	var max_range: float = _PM.LIFE_STEAL_MAX_RANGE
	if dist <= max_range and _target != null:
		var peer := int(str(_target.name))
		if peer > 0:
			PlayerEffects.server_apply_life_steal(peer, -1, dist, max_range, delta)


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("players"):
		var peer := int(str(node.name))
		if peer <= 0:
			continue
		if GameState.players.get(peer, {}).get("is_puppet_master", false):
			continue
		if GameState.server_is_eliminated(peer):
			continue
		if GameState.players.get(peer, {}).get("escaped", false):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best
