extends Node
## ChildSpawnRNG — host picks 1 of 11 Leonardo L2 SoT pins (eng short ids).

## Alive-only hide sites. No grave pins. IDs match L2_child_rng_spawns.csv.
const SPAWN_IDS: Array[String] = [
	"pm_attic",
	"master_bedroom",
	"bunker_utility",
	"basement",
	"uncle_bedroom",
	"uncle_garage",
	"family_shed",
	"storm_drain",
	"under_porch_crawl",
	"garden_well",
	"car_trunk",
]

const EXPECTED_COUNT: int = 11

signal child_found(carrier_peer: int)
signal child_escaped(carrier_peer: int)

var _active_spawn_id: String = ""
var _active_global_pos: Vector3 = Vector3.ZERO
var _child_found: bool = false
var _child_carrier_peer: int = -1


func reset() -> void:
	_active_spawn_id = ""
	_active_global_pos = Vector3.ZERO
	_child_found = false
	_child_carrier_peer = -1
	var world := get_tree().get_first_node_in_group("horror_world") if is_inside_tree() else null
	if world:
		var marker := world.get_node_or_null("MissingChildMarker")
		if marker:
			marker.queue_free()


func server_roll(world: Node3D, rng_seed: int = -1) -> String:
	if not multiplayer.is_server():
		return ""
	if rng_seed >= 0:
		seed(rng_seed)
	else:
		randomize()
	var chosen: String = SPAWN_IDS[randi() % SPAWN_IDS.size()]
	var marker := _find_marker(world, chosen)
	if marker == null:
		for node in world.get_tree().get_nodes_in_group("child_spawn_points"):
			if not (node is Marker3D):
				continue
			var sid := str(node.get_meta("spawn_id", ""))
			if not SPAWN_IDS.has(sid):
				continue
			marker = node
			chosen = sid
			break
	if marker == null:
		push_error("[ChildSpawnRNG] no child spawn markers in world")
		return ""
	_active_spawn_id = chosen
	_active_global_pos = (marker as Node3D).global_position
	_client_set_spawn.rpc(_active_spawn_id, _active_global_pos)
	print("[ChildSpawnRNG] missing child at spawn_id=%s pos=%s" % [_active_spawn_id, _active_global_pos])
	return _active_spawn_id


func get_spawn_id() -> String:
	return _active_spawn_id


func get_spawn_position() -> Vector3:
	return _active_global_pos


@rpc("authority", "call_local", "reliable")
func _client_set_spawn(spawn_id: String, global_pos: Vector3) -> void:
	_active_spawn_id = spawn_id
	_active_global_pos = global_pos
	var world := get_tree().get_first_node_in_group("horror_world")
	if world is Node3D:
		ensure_marker(world as Node3D)


func ensure_marker(world: Node3D) -> void:
	if world == null or _active_spawn_id.is_empty() or _child_found:
		return
	_spawn_visual(world, _active_global_pos)


func server_try_pickup_child(peer_id: int, pickup_pos: Vector3) -> bool:
	if not multiplayer.is_server():
		return false
	if _child_found:
		return false
	if pickup_pos.distance_to(_active_global_pos) > 4.0:
		return false
	_child_found = true
	_child_carrier_peer = peer_id
	_client_child_found.rpc(peer_id)
	print("[ChildSpawnRNG] peer %d found child at %s" % [peer_id, _active_spawn_id])
	return true


func server_try_escape_with_child(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if _child_carrier_peer != peer_id:
		return false
	var faction := GameState.server_get_faction(peer_id)
	print("[ChildSpawnRNG] family %s escaped with the child (spawn was %s)" % [faction, _active_spawn_id])
	child_escaped.emit(peer_id)
	return true


func server_is_carrier(peer_id: int) -> bool:
	return _child_found and _child_carrier_peer == peer_id


func server_carrier_peer() -> int:
	return _child_carrier_peer


@rpc("authority", "call_local", "reliable")
func _client_child_found(carrier_peer: int) -> void:
	_child_found = true
	_child_carrier_peer = carrier_peer
	child_found.emit(carrier_peer)
	var world := get_tree().get_first_node_in_group("horror_world")
	if world:
		var marker := world.get_node_or_null("MissingChildMarker") as Node3D
		if marker:
			marker.visible = false
	_attach_carried_visual(carrier_peer)


func _attach_carried_visual(carrier_peer: int) -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if str(node.name).to_int() != carrier_peer:
			continue
		if node.get_node_or_null("CarriedChild"):
			return
		var vis := MeshInstance3D.new()
		vis.name = "CarriedChild"
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.42, 0.28)
		vis.mesh = box
		vis.position = Vector3(0.22, 1.15, -0.18)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.75, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.5, 0.15)
		mat.emission_energy_multiplier = 0.45
		vis.set_surface_override_material(0, mat)
		node.add_child(vis)
		return


func _find_marker(world: Node3D, spawn_id: String) -> Marker3D:
	if not SPAWN_IDS.has(spawn_id):
		return null
	for node in world.get_tree().get_nodes_in_group("child_spawn_points"):
		if node is Marker3D and str(node.get_meta("spawn_id", "")) == spawn_id:
			return node
	return null


func _spawn_visual(world: Node3D, at: Vector3) -> void:
	var existing := world.get_node_or_null("MissingChildMarker")
	if existing:
		existing.queue_free()
	var visual := Node3D.new()
	visual.name = "MissingChildMarker"
	world.add_child(visual)
	visual.global_position = at + Vector3(0, 0.6, 0)
	var _geom: GDScript = preload("res://scripts/rooms/geometry_util.gd")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.75, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.5, 0.15)
	mat.emission_energy_multiplier = 0.4
	visual.add_child(_geom.call("box", Vector3(0.35, 0.7, 0.35), Vector3.ZERO, mat, 0))


static func spawn_id_list() -> Array[String]:
	return SPAWN_IDS.duplicate()


static func expected_count() -> int:
	return EXPECTED_COUNT
