extends Node3D
class_name Match
## Match
##
## Director for the "Match" phase: builds one RoomPod per connected player
## (host-authoritative), assigns each player their spawn point, wires up
## LinkGraph's mystery-control graph, plans the (optional) code-lock
## puzzle placement, and grants the Puppet Master their camera/sabotage
## targets. Room/player nodes are created via MultiplayerSpawner.spawn(data)
## so the same instantiation replicates consistently to every client - the
## standard Godot 4 pattern for host-authoritative spawning.
##
## TODO(post-MVP): mid-match reconnection handling, and support for
## uneven faction sizes.

const ROOM_POD_SCENE_PATH: String = "res://scenes/Match/RoomPod.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/Player/Player.tscn"

var _room_pod_scene: PackedScene
var _player_scene: PackedScene

## Rooms are laid out on a simple grid, far enough apart that one player's
## room (plus its optional hallway extension) doesn't visually bleed into
## the next. Good enough for a graybox; a real level would hand-place these.
## Floor-plan pods are up to ~34×18 ft; keep cells far enough apart.
const GRID_SPACING: float = 40.0
const GRID_COLUMNS: int = 4

## How many camera/sabotage targets the Puppet Master is granted.
const PUPPET_MASTER_TARGET_COUNT: int = 2

@onready var rooms_container: Node3D = $RoomsContainer
@onready var rooms_spawner: MultiplayerSpawner = $RoomsContainer/RoomsSpawner
@onready var players_container: Node3D = $PlayersContainer
@onready var players_spawner: MultiplayerSpawner = $PlayersContainer/PlayersSpawner

## Server-only bookkeeping: room_index -> RoomPod node.
var _rooms: Dictionary = {}


## World position of a room's grid cell. Static so PM camera-feed UI
## (Player.gd) can compute a target room's world position without needing
## a live reference to this Match instance.
static func room_grid_position(index: int) -> Vector3:
	var col := index % GRID_COLUMNS
	var row := index / GRID_COLUMNS
	return Vector3(col * GRID_SPACING, 0.0, row * GRID_SPACING)


## Inverse of `room_grid_position()` - which room's grid cell a world
## position currently falls within. Used purely client-side (e.g. to
## check "is MY current room flooded") so it deliberately doesn't need any
## server round-trip; it's just grid math.
static func world_position_to_room_index(world_pos: Vector3) -> int:
	var col := int(roundi(world_pos.x / GRID_SPACING))
	var row := int(roundi(world_pos.z / GRID_SPACING))
	return row * GRID_COLUMNS + col


func _ready() -> void:
	rooms_spawner.spawn_function = _spawn_room_pod
	players_spawner.spawn_function = _spawn_player
	GameState.match_started.connect(_on_match_started)


func _get_room_pod_scene() -> PackedScene:
	if _room_pod_scene == null or _room_pod_scene.resource_path.is_empty():
		_room_pod_scene = load(ROOM_POD_SCENE_PATH) as PackedScene
	return _room_pod_scene


func _get_player_scene() -> PackedScene:
	if _player_scene == null or _player_scene.resource_path.is_empty():
		_player_scene = load(PLAYER_SCENE_PATH) as PackedScene
	return _player_scene


func _on_match_started() -> void:
	if not multiplayer.is_server():
		return
	_server_build_match()


func _server_build_match() -> void:
	_rooms.clear()
	LinkGraph.reset()
	PuzzleSystem.reset()
	PuppetMasterSystem.reset()
	PhoneSystem.reset()
	RoomUtilities.reset()

	var peer_ids: Array = GameState.players.keys()
	peer_ids.shuffle()

	for i in range(peer_ids.size()):
		GameState.server_set_room(peer_ids[i], i)

	# Puzzle placement is decided BEFORE any room is spawned so it can be
	# baked into each room's deterministic spawn data (see RoomPod.configure).
	var puzzle_plan := _plan_puzzle(peer_ids.size())

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		var is_pm: bool = GameState.players[peer_id]["is_puppet_master"]
		_server_spawn_room(i, peer_id, is_pm, puzzle_plan)

	# Links must be built AFTER every room has registered its control/effect
	# nodes with LinkGraph.
	LinkGraph.server_build_links()

	if not puzzle_plan.is_empty():
		PuzzleSystem.server_register_lock(puzzle_plan["locked_index"], puzzle_plan["code"])

	_grant_puppet_master_targets(peer_ids)

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		_server_spawn_player(peer_id, i)


## Decides whether this match has a code-locked escape and, if so, which
## room is locked and which (different) room holds the clue. Returns {}
## if there aren't enough rooms to make that interesting (needs at least
## 2, and at least 1 non-Puppet-Master room to lock).
func _plan_puzzle(room_count: int) -> Dictionary:
	if room_count < 2:
		return {}
	if randf() >= MatchSettings.code_lock_chance:
		return {}

	var lockable: Array = []
	for i in range(room_count):
		var pid := GameState.server_get_peer_by_room(i)
		if pid != GameState.puppet_master_peer_id:
			lockable.append(i)
	if lockable.is_empty():
		return {}

	var locked_index: int = lockable[randi() % lockable.size()]
	var clue_candidates: Array = []
	for i in range(room_count):
		if i != locked_index:
			clue_candidates.append(i)
	if clue_candidates.is_empty():
		return {}

	var clue_index: int = clue_candidates[randi() % clue_candidates.size()]
	var code := "%04d" % (randi() % 10000)
	var clue_kind := "flame_paper" if randf() < MatchSettings.flame_paper_chance else "book"
	return {
		"locked_index": locked_index,
		"clue_index": clue_index,
		"code": code,
		"clue_kind": clue_kind,
	}


func _grant_puppet_master_targets(peer_ids: Array) -> void:
	var pm_peer_id: int = GameState.puppet_master_peer_id
	if pm_peer_id == -1:
		return

	var all_other_rooms: Array = []
	for peer_id in peer_ids:
		if peer_id != pm_peer_id:
			all_other_rooms.append(GameState.players[peer_id]["room_id"])

	var shuffled_rooms: Array = all_other_rooms.duplicate()
	shuffled_rooms.shuffle()
	var camera_targets: Array = shuffled_rooms.slice(0, mini(PUPPET_MASTER_TARGET_COUNT, shuffled_rooms.size()))

	# Elimination is deliberately NOT limited to the camera/sabotage set -
	# "kill everyone" would be impossible otherwise. See
	# PuppetMasterSystem's header comment for the full reasoning.
	PuppetMasterSystem.server_grant_targets(pm_peer_id, camera_targets, all_other_rooms)


func _server_spawn_room(room_index: int, owner_peer_id: int, is_pm: bool, puzzle_plan: Dictionary) -> void:
	var data := {
		"room_index": room_index,
		"owner_peer_id": owner_peer_id,
		"rng_seed": randi(),
		"is_puppet_master": is_pm,
		"requires_code": puzzle_plan.get("locked_index", -1) == room_index,
		"clue_kind": puzzle_plan.get("clue_kind", "") if puzzle_plan.get("clue_index", -1) == room_index else "",
		"clue_code": puzzle_plan.get("code", "") if puzzle_plan.get("clue_index", -1) == room_index else "",
	}
	data.merge(RoomPod.plan_recipe(is_pm, _rooms.size() + 1))
	if data.get("has_electrical_box", false):
		var targets: Array = []
		var candidates: Array = []
		for idx in _rooms.keys():
			if idx != room_index:
				candidates.append(idx)
		candidates.shuffle()
		for j in range(mini(3, candidates.size())):
			targets.append(candidates[j])
		data["wire_targets"] = targets
	RoomUtilities.server_init_room(room_index)
	var room: Node = rooms_spawner.spawn(data)
	if room == null:
		push_error("Match: failed to spawn room %d for peer %d" % [room_index, owner_peer_id])
		return
	_rooms[room_index] = room


func _server_spawn_player(peer_id: int, room_index: int) -> void:
	var room: RoomPod = _rooms.get(room_index)
	var spawn_xform: Transform3D = room.get_spawn_transform() if room else Transform3D.IDENTITY
	var faction_id: String = GameState.server_get_faction(peer_id)

	var data := {
		"peer_id": peer_id,
		"faction_id": faction_id,
		"spawn_position": spawn_xform.origin,
		"spawn_rotation_y": spawn_xform.basis.get_euler().y,
	}
	var player: Node = players_spawner.spawn(data)
	EscapeSystem.server_register_player_node(peer_id, player)


## Runs on EVERY peer (server calls it locally when spawning; clients run
## it in response to the replicated spawn message) - must stay
## deterministic given identical `data`.
func _spawn_room_pod(data: Dictionary) -> Node:
	var scene := _get_room_pod_scene()
	if scene == null:
		push_error("Match: failed to load RoomPod scene at %s" % ROOM_POD_SCENE_PATH)
		return null
	var raw_node := scene.instantiate()
	if raw_node == null:
		push_error("Match: RoomPod scene instantiate returned null (path=%s)" % scene.resource_path)
		return null
	var room := raw_node as RoomPod
	if room == null:
		push_error("Match: RoomPod scene root is not a RoomPod (script=%s)" % str(raw_node.get_script()))
		raw_node.free()
		return null
	room.configure(data)
	room.position = room_grid_position(data["room_index"])
	return room


## Runs on EVERY peer, same determinism requirement as `_spawn_room_pod`.
func _spawn_player(data: Dictionary) -> Node:
	var scene := _get_player_scene()
	if scene == null:
		push_error("Match: failed to load Player scene at %s" % PLAYER_SCENE_PATH)
		return null
	var player := scene.instantiate() as Player
	if player == null:
		push_error("Match: Player scene instantiate returned null (path=%s)" % scene.resource_path)
		return null
	player.name = str(data["peer_id"])
	# Must happen here (before add_child), NOT in Player._ready() - the
	# MultiplayerSynchronizer child needs authority finalized before this
	# node enters the tree, or its pending spawn silently fails on clients.
	player.set_multiplayer_authority(data["peer_id"])
	player.faction_id = data["faction_id"]
	player.position = data["spawn_position"]
	player.rotation.y = data["spawn_rotation_y"]
	return player
