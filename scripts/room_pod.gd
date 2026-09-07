extends Node3D
class_name RoomPod
## Multiplayer wrapper — instances one complete RoomMap scene per player.

const _LAYOUTS: GDScript = preload("res://scripts/rooms/room_layouts.gd")

var room_index: int = 0
var owner_peer_id: int = -1
var rng_seed: int = 0
var is_puppet_master_room: bool = false
var room_scene_id: int = 1
var width: float = 6.0
var depth: float = 6.0

var spawn_point: Marker3D
var light_switch: Node

var _map: Node3D


static func plan_recipe(is_pm: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var room_scene_id: int = 0 if is_pm else int(_LAYOUTS.call("pick_id", rng))

	var has_valve := not is_pm and randf() < MatchSettings.flood_valve_chance
	var has_electrical_box := not is_pm and randf() < 0.35

	return {
		"room_scene_id": room_scene_id,
		"has_valve": has_valve,
		"has_electrical_box": has_electrical_box,
		"wire_targets": [],
		"has_fireplace": not is_pm,
		"has_drain": not is_pm and randf() < 0.45,
		"has_exhaust": not is_pm and randf() < 0.4,
		"clue_in_fireplace": not is_pm and randf() < 0.35,
		"has_binary_puzzle": not is_pm and randf() < 0.4,
	}


func configure(data: Dictionary) -> void:
	room_index = data["room_index"]
	owner_peer_id = data["owner_peer_id"]
	rng_seed = data["rng_seed"]
	is_puppet_master_room = data.get("is_puppet_master", false)
	room_scene_id = int(data.get("room_scene_id", 1))
	name = "RoomPod_%d" % room_index

	var path: String = _LAYOUTS.call("scene_path", 0 if is_puppet_master_room else room_scene_id)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("RoomPod: failed to load room scene %s" % path)
		return

	_map = packed.instantiate()
	if _map == null or not _map.has_method("configure"):
		push_error("RoomPod: scene root is not RoomMap at %s" % path)
		_map = null
		return

	_map.set("room_id", room_scene_id if not is_puppet_master_room else 0)
	_map.set("is_puppet_master", is_puppet_master_room)
	add_child(_map)

	data["clue_in_fireplace"] = data.get("clue_in_fireplace", false)
	_map.call("configure", data)

	width = _map.get("width")
	depth = _map.get("depth")
	spawn_point = _map.get("spawn_point")
	light_switch = _map.get("light_switch")


func get_spawn_transform() -> Transform3D:
	if _map:
		return _map.call("get_spawn_transform")
	if spawn_point:
		return spawn_point.global_transform
	return global_transform


func mark_escape_locked() -> void:
	if _map:
		_map.call("mark_escape_locked")


func add_clue_prop(kind: String, code: String, in_fireplace: bool = false) -> void:
	if _map:
		_map.call("add_clue_prop", kind, code, in_fireplace)
