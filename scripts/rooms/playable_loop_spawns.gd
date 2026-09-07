extends RefCounted
## Dead-simple near-spawn Phone + Walkie for the friends-MVP loop.
## Called from RoomMap.configure() — does NOT depend on ItemSpawnSlot pools.

const _PATHS: GDScript = preload("res://scripts/interactable_script_paths.gd")
const _PHONE: Script = preload("res://scripts/interactables/phone.gd")
const _WALKIE_PATH := "res://scripts/interactables/walkie_talkie.gd"
const _ITEMS: GDScript = preload("res://scripts/rooms/item_spawn_system.gd")

const WALL_INSET: float = 0.5
const WALL_EMBED: float = 0.04
const MAX_PHONE_SPAWN_DISTANCE: float = 3.5
const MAX_WALKIE_SPAWN_DISTANCE: float = 1.25
const INTERACTABLE_LAYER: int = 2

const PHONE_SIZE := Vector3(0.22, 0.28, 0.08)
const WALKIE_SIZE := Vector3(0.18, 0.08, 0.24)


static func spawn_near_player(
	room: Node3D,
	spawn_local: Vector3,
	accent: Material,
	owner_peer_id: int,
	room_width: float = 6.0,
	room_depth: float = 6.0,
) -> Dictionary:
	_remove_old(room, "Phone")
	_remove_old(room, "WalkieTalkie")

	var hw := room_width * 0.5
	var hd := room_depth * 0.5
	var phone_placement := _phone_wall_placement(spawn_local, hw, hd)
	var walkie_pos := _walkie_floor_placement(spawn_local, WALKIE_SIZE.y)

	var phone: StaticBody3D = _ITEMS.call(
		"_make_interactable",
		_PHONE,
		PHONE_SIZE,
		phone_placement["position"],
		_accent_material(accent),
		"Use phone"
	)
	phone.name = "Phone"
	phone.rotation.y = phone_placement["rotation_y"]
	phone.set("owner_peer_id", owner_peer_id)
	phone.set_meta("attachment_surface", "wall")
	phone.set_meta("wall_normal", phone_placement["normal"])
	phone.add_to_group("playable_loop")
	room.add_child(phone)

	var walkie: StaticBody3D = _ITEMS.call(
		"_make_interactable",
		load(_WALKIE_PATH) as Script,
		WALKIE_SIZE,
		walkie_pos,
		_accent_material(accent),
		"Use walkie-talkie"
	)
	walkie.name = "WalkieTalkie"
	walkie.set("owner_peer_id", owner_peer_id)
	walkie.set_meta("attachment_surface", "floor")
	walkie.add_to_group("playable_loop")
	room.add_child(walkie)
	WalkieSystem.server_register_walkie(owner_peer_id, walkie)

	return {
		"phone": phone,
		"walkie": walkie,
		"phone_dist": spawn_local.distance_to(phone_placement["position"]),
		"walkie_dist": Vector2(spawn_local.x - walkie_pos.x, spawn_local.z - walkie_pos.z).length(),
	}


static func validate(room: Node3D, spawn_local: Vector3) -> Array[String]:
	var errors: Array[String] = []
	var phone := room.get_node_or_null("Phone")
	if phone == null:
		errors.append("Phone missing")
	elif not _PATHS.is_phone(phone):
		errors.append("Phone script not attached (path=%s)" % _PATHS.script_path(phone))
	elif int(phone.collision_layer) != INTERACTABLE_LAYER:
		errors.append("Phone collision_layer=%d expected %d" % [int(phone.collision_layer), INTERACTABLE_LAYER])
	elif phone.get_node_or_null("MeshInstance3D") == null or phone.get_node_or_null("CollisionShape3D") == null:
		errors.append("Phone missing mesh or collision")
	else:
		var phone_horiz := Vector2(spawn_local.x - phone.position.x, spawn_local.z - phone.position.z).length()
		if phone_horiz > MAX_PHONE_SPAWN_DISTANCE:
			errors.append("Phone too far from spawn (%.2fm > %.2fm)" % [phone_horiz, MAX_PHONE_SPAWN_DISTANCE])

	var walkie := room.get_node_or_null("WalkieTalkie")
	if walkie == null:
		errors.append("WalkieTalkie missing")
	elif _PATHS.script_path(walkie) != _WALKIE_PATH:
		errors.append("WalkieTalkie script not attached (path=%s)" % _PATHS.script_path(walkie))
	elif int(walkie.collision_layer) != INTERACTABLE_LAYER:
		errors.append("WalkieTalkie collision_layer=%d expected %d" % [int(walkie.collision_layer), INTERACTABLE_LAYER])
	elif walkie.get_node_or_null("MeshInstance3D") == null or walkie.get_node_or_null("CollisionShape3D") == null:
		errors.append("WalkieTalkie missing mesh or collision")
	else:
		var horiz := Vector2(spawn_local.x - walkie.position.x, spawn_local.z - walkie.position.z).length()
		if horiz > MAX_WALKIE_SPAWN_DISTANCE:
			errors.append("WalkieTalkie too far from spawn (%.2fm > %.2fm)" % [horiz, MAX_WALKIE_SPAWN_DISTANCE])
		var bottom_y := _node_bottom_y(walkie)
		if bottom_y > 0.08:
			errors.append("WalkieTalkie not on floor (bottom_y=%.3f)" % bottom_y)
	return errors


static func _phone_near_spawn(spawn_local: Vector3) -> Dictionary:
	# Fixed offset beside center spawn — no wall hunt (center-spawn graybox rooms).
	var pos := spawn_local + Vector3(0.55, 1.05, 0.0)
	return {"position": pos, "normal": Vector3(-1, 0, 0), "rotation_y": atan2(-1.0, 0.0)}


static func _phone_wall_placement(spawn_local: Vector3, hw: float, hd: float) -> Dictionary:
	var inner_hw := hw - WALL_INSET
	var inner_hd := hd - WALL_INSET
	var height := 1.05
	var best_pos := Vector3(spawn_local.x, height, inner_hd - WALL_EMBED)
	var best_horiz := INF
	var best_normal := Vector3(0, 0, -1)
	var best_rot := 0.0

	var walls: Array[Dictionary] = [
		{
			"position": Vector3(
				clampf(spawn_local.x, -inner_hw + 0.4, inner_hw - 0.4),
				height,
				inner_hd - WALL_EMBED
			),
			"normal": Vector3(0, 0, -1),
		},
		{
			"position": Vector3(
				clampf(spawn_local.x, -inner_hw + 0.4, inner_hw - 0.4),
				height,
				-inner_hd + WALL_EMBED
			),
			"normal": Vector3(0, 0, 1),
		},
		{
			"position": Vector3(
				inner_hw - WALL_EMBED,
				height,
				clampf(spawn_local.z, -inner_hd + 0.4, inner_hd - 0.4)
			),
			"normal": Vector3(-1, 0, 0),
		},
		{
			"position": Vector3(
				-inner_hw + WALL_EMBED,
				height,
				clampf(spawn_local.z, -inner_hd + 0.4, inner_hd - 0.4)
			),
			"normal": Vector3(1, 0, 0),
		},
	]

	for wall: Dictionary in walls:
		var pos: Vector3 = wall["position"]
		var horiz := Vector2(spawn_local.x - pos.x, spawn_local.z - pos.z).length()
		if horiz > MAX_PHONE_SPAWN_DISTANCE:
			continue
		if horiz < best_horiz:
			best_horiz = horiz
			best_pos = pos
			best_normal = wall["normal"]
			best_rot = atan2(best_normal.x, best_normal.z)

	return {"position": best_pos, "normal": best_normal, "rotation_y": best_rot}


static func _walkie_floor_placement(spawn_local: Vector3, mesh_height: float) -> Vector3:
	var half_h := mesh_height * 0.5
	var offset := Vector3(-0.45, 0.0, -0.85)
	if Vector2(offset.x, offset.z).length() > MAX_WALKIE_SPAWN_DISTANCE:
		offset = offset.normalized() * (MAX_WALKIE_SPAWN_DISTANCE - 0.1)
	# Floor is y=0; ignore spawn marker height (often 0.1).
	return Vector3(spawn_local.x + offset.x, half_h, spawn_local.z + offset.z)


static func _node_bottom_y(node: Node3D) -> float:
	var lowest := node.position.y
	for c in node.get_children():
		if c is MeshInstance3D:
			var mesh: Mesh = c.mesh
			if mesh is BoxMesh:
				var half: float = mesh.size.y * 0.5
				lowest = minf(lowest, node.position.y + c.position.y - half)
	return lowest


static func _remove_old(room: Node3D, node_name: String) -> void:
	var old := room.get_node_or_null(node_name)
	if old:
		old.queue_free()


static func _accent_material(base: Material) -> Material:
	if base is StandardMaterial3D:
		var mat: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.55, 0.85)
		mat.emission_energy_multiplier = 0.45
		return mat
	return base
