extends Node3D
class_name RoomPod
## RoomPod
##
## One player's "randomly generated small room". MVP ships a single room
## template with randomized prop placement (deterministic per-room seed),
## which satisfies "each player spawns alone in a small room with
## procedural props" without yet doing full procedural layout generation.
##
## TODO(post-MVP): multiple room shapes/templates, randomized wall
## openings, and richer prop variety.

@export var prop_scenes: Array[PackedScene] = []
@export var empty_slot_chance: float = 0.35

## NOTE: deliberately NOT using `@onready` for anything read inside
## `configure()` below - `@onready` vars only populate once this node
## enters the SceneTree, but `configure()` is called by the Match
## director's spawn_function BEFORE this node is added as a child (so
## every descendant's own `_ready()` sees fully-configured data instead of
## racing it). `get_node()` works fine on a detached tree at any time, so
## we just fetch children directly where needed.
@onready var prop_spawn_points: Node3D = $PropSpawnPoints
@onready var spawn_point: Marker3D = $SpawnPoint

var room_index: int = 0
var owner_peer_id: int = -1
var rng_seed: int = 0


func configure(p_room_index: int, p_owner_peer_id: int, p_rng_seed: int) -> void:
	room_index = p_room_index
	owner_peer_id = p_owner_peer_id
	rng_seed = p_rng_seed

	var light_switch: LightSwitch = get_node("LightSwitch")
	var room_light: RoomLight = get_node("RoomLight")
	var phone: Phone = get_node("Phone")

	light_switch.control_id = "room_%d_light_switch" % room_index
	room_light.effect_id = "room_%d_room_light" % room_index
	room_light.owner_peer_id = owner_peer_id
	phone.owner_peer_id = owner_peer_id
	name = "RoomPod_%d" % room_index


func get_spawn_transform() -> Transform3D:
	return spawn_point.global_transform


func _ready() -> void:
	_scatter_props()


func _scatter_props() -> void:
	if prop_scenes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	for marker in prop_spawn_points.get_children():
		if rng.randf() < empty_slot_chance:
			continue
		var scene: PackedScene = prop_scenes[rng.randi() % prop_scenes.size()]
		var prop := scene.instantiate()
		marker.add_child(prop)
		prop.rotation.y = rng.randf_range(0.0, TAU)
