extends RefCounted
## Dead-simple near-spawn Phone + Walkie for the friends-MVP loop.
## Called from RoomMap.configure() — does NOT depend on ItemSpawnSlot pools.

const _PATHS: GDScript = preload("res://scripts/interactable_script_paths.gd")
const _PHONE: Script = preload("res://scripts/interactables/phone.gd")
const _WALKIE_PATH := "res://scripts/interactables/walkie_talkie.gd"
const _ITEMS: GDScript = preload("res://scripts/rooms/item_spawn_system.gd")

const MAX_SPAWN_DISTANCE: float = 2.2
const INTERACTABLE_LAYER: int = 2


static func spawn_near_player(room: Node3D, spawn_local: Vector3, accent: Material, owner_peer_id: int) -> Dictionary:
	_remove_old(room, "Phone")
	_remove_old(room, "WalkieTalkie")

	# Player default forward is -Z; place props in front of spawn marker.
	var phone_pos := spawn_local + Vector3(0.0, 1.05, -1.35)
	var walkie_pos := spawn_local + Vector3(-0.45, 0.06, -0.85)

	var phone: StaticBody3D = _ITEMS.call(
		"_make_interactable",
		_PHONE,
		Vector3(0.22, 0.28, 0.08),
		phone_pos,
		_accent_material(accent),
		"Use phone"
	)
	phone.name = "Phone"
	phone.set("owner_peer_id", owner_peer_id)
	phone.add_to_group("playable_loop")
	room.add_child(phone)

	var walkie: StaticBody3D = _ITEMS.call(
		"_make_interactable",
		load(_WALKIE_PATH) as Script,
		Vector3(0.18, 0.08, 0.24),
		walkie_pos,
		_accent_material(accent),
		"Use walkie-talkie"
	)
	walkie.name = "WalkieTalkie"
	walkie.set("owner_peer_id", owner_peer_id)
	walkie.add_to_group("playable_loop")
	room.add_child(walkie)
	WalkieSystem.server_register_walkie(owner_peer_id, walkie)

	return {
		"phone": phone,
		"walkie": walkie,
		"phone_dist": spawn_local.distance_to(phone_pos),
		"walkie_dist": spawn_local.distance_to(walkie_pos),
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
	elif spawn_local.distance_to(phone.position) > MAX_SPAWN_DISTANCE:
		errors.append("Phone too far from spawn (%.2fm)" % spawn_local.distance_to(phone.position))

	var walkie := room.get_node_or_null("WalkieTalkie")
	if walkie == null:
		errors.append("WalkieTalkie missing")
	elif _PATHS.script_path(walkie) != _WALKIE_PATH:
		errors.append("WalkieTalkie script not attached (path=%s)" % _PATHS.script_path(walkie))
	elif int(walkie.collision_layer) != INTERACTABLE_LAYER:
		errors.append("WalkieTalkie collision_layer=%d expected %d" % [int(walkie.collision_layer), INTERACTABLE_LAYER])
	elif spawn_local.distance_to(walkie.position) > MAX_SPAWN_DISTANCE:
		errors.append("WalkieTalkie too far from spawn (%.2fm)" % spawn_local.distance_to(walkie.position))
	return errors


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
