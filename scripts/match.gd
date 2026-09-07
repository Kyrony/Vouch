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

const _ROOM_POD: GDScript = preload("res://scripts/room_pod.gd")

const ROOM_POD_SCENE_PATH: String = "res://scenes/Match/RoomPod.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/Player/Player.tscn"

var _room_pod_scene: PackedScene
var _player_scene: PackedScene

## Rooms are laid out on a simple grid, far enough apart that one player's
## room (plus its escape tunnel) doesn't visually bleed into the next.
const GRID_COLUMNS: int = 4

## How many camera/sabotage targets the Puppet Master is granted.
const PUPPET_MASTER_TARGET_COUNT: int = 2

@onready var rooms_container: Node3D = $RoomsContainer
@onready var rooms_spawner: MultiplayerSpawner = $RoomsContainer/RoomsSpawner
@onready var players_container: Node3D = $PlayersContainer
@onready var players_spawner: MultiplayerSpawner = $PlayersContainer/PlayersSpawner

## Central underground shaft — built once per match on every peer.
var _escape_hub: Node3D

## Server-only bookkeeping: room_index -> RoomPod node.
var _rooms: Dictionary = {}


## World position of a room's grid cell. Static so PM camera-feed UI
## (Player.gd) can compute a target room's world position without needing
## a live reference to this Match instance.
static func room_grid_position(index: int) -> Vector3:
	var col := index % GRID_COLUMNS
	var row := index / GRID_COLUMNS
	return Vector3(col * WorldScale.GRID_SPACING, -WorldScale.UNDERGROUND_DEPTH, row * WorldScale.GRID_SPACING)


## Inverse of `room_grid_position()` - which room's grid cell a world
## position currently falls within. Used purely client-side (e.g. to
## check "is MY current room flooded") so it deliberately doesn't need any
## server round-trip; it's just grid math.
static func world_position_to_room_index(world_pos: Vector3) -> int:
	var col := int(roundi(world_pos.x / WorldScale.GRID_SPACING))
	var row := int(roundi(world_pos.z / WorldScale.GRID_SPACING))
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
	WalkieSystem.reset()
	RoomUtilities.reset()

	var peer_ids: Array = GameState.players.keys()
	peer_ids.shuffle()

	for i in range(peer_ids.size()):
		GameState.server_set_room(peer_ids[i], i)

	WalkieSystem.server_pair_players(peer_ids)

	# Puzzle placement is decided BEFORE any room is spawned so it can be
	# baked into each room's deterministic spawn data (see RoomPod.configure).
	var puzzle_plan := _plan_puzzle(peer_ids.size())

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		var is_pm: bool = GameState.players[peer_id]["is_puppet_master"]
		_server_spawn_room(i, peer_id, is_pm, puzzle_plan, peer_ids.size(), i == 0)

	_ensure_flood_valve_in_match(peer_ids)

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


func _ensure_flood_valve_in_match(peer_ids: Array) -> void:
	if peer_ids.size() < 2:
		return
	for idx in _rooms.keys():
		var pod = _rooms[idx]
		if pod and pod.get("light_switch"):
			var map: Node = pod.get_child(0) if pod.get_child_count() > 0 else null
			if map and map.has_node("WaterValve"):
				return
	for idx in _rooms.keys():
		var pid := GameState.server_get_peer_by_room(idx)
		if pid != GameState.puppet_master_peer_id:
			push_warning("Match: no flood valve spawned — light-switch mystery links still active.")
			return


func _server_spawn_room(room_index: int, owner_peer_id: int, is_pm: bool, puzzle_plan: Dictionary, total_rooms: int, force_valve: bool = false) -> void:
	var recipe: Dictionary = _ROOM_POD.call("plan_recipe", is_pm)
	if force_valve and not is_pm and total_rooms >= 2:
		recipe["has_valve"] = true
	var data := {
		"room_index": room_index,
		"owner_peer_id": owner_peer_id,
		"rng_seed": randi(),
		"is_puppet_master": is_pm,
		"total_rooms": total_rooms,
		"requires_code": puzzle_plan.get("locked_index", -1) == room_index,
		"clue_kind": puzzle_plan.get("clue_kind", "") if puzzle_plan.get("clue_index", -1) == room_index else "",
		"clue_code": puzzle_plan.get("code", "") if puzzle_plan.get("clue_index", -1) == room_index else "",
	}
	data.merge(recipe)
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
	if data.get("has_binary_puzzle", false):
		var peek_candidates: Array = []
		for idx in _rooms.keys():
			if idx != room_index:
				peek_candidates.append(idx)
		if peek_candidates.is_empty() and total_rooms > 1:
			for j in range(total_rooms):
				if j != room_index:
					peek_candidates.append(j)
		if peek_candidates.is_empty():
			data["has_binary_puzzle"] = false
		else:
			data["binary_peek_room"] = peek_candidates[randi() % peek_candidates.size()]
			data["binary_target"] = randi_range(5, 200)
	RoomUtilities.server_init_room(room_index)
	var room: Node = rooms_spawner.spawn(data)
	if room == null:
		push_error("Match: failed to spawn room %d for peer %d" % [room_index, owner_peer_id])
		return
	_rooms[room_index] = room


func _server_spawn_player(peer_id: int, room_index: int) -> void:
	var room = _rooms.get(room_index)
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
	var scene = _get_room_pod_scene()
	if scene == null:
		push_error("Match: failed to load RoomPod scene at %s" % ROOM_POD_SCENE_PATH)
		return null
	var raw_node: Node = scene.instantiate()
	if raw_node == null:
		push_error("Match: RoomPod scene instantiate returned null (path=%s)" % scene.resource_path)
		return null
	var room = raw_node
	if not room.has_method("configure"):
		push_error("Match: RoomPod scene root is not a RoomPod (script=%s)" % str(raw_node.get_script()))
		raw_node.free()
		return null
	_ensure_escape_hub(int(data.get("total_rooms", 4)))
	var grid_pos: Vector3 = room_grid_position(data["room_index"])
	var to_hub := Vector3(-grid_pos.x, 0.0, -grid_pos.z)
	if to_hub.length() < 0.5:
		to_hub = Vector3(0.0, 0.0, 1.0)
	else:
		to_hub = to_hub.normalized()
	room.rotation.y = atan2(to_hub.x, to_hub.z)
	room.configure(data)
	room.position = grid_pos
	return room


func _ensure_escape_hub(room_count: int) -> void:
	if is_instance_valid(_escape_hub):
		return
	_escape_hub = Node3D.new()
	_escape_hub.set_script(preload("res://scripts/systems/escape_hub.gd"))
	_escape_hub.name = "EscapeHub"
	add_child(_escape_hub)
	_escape_hub.call("build", room_count)


## Runs on EVERY peer, same determinism requirement as `_spawn_room_pod`.
func _spawn_player(data: Dictionary) -> Node:
	var scene = _get_player_scene()
	if scene == null:
		push_error("Match: failed to load Player scene at %s" % PLAYER_SCENE_PATH)
		return null
	var player: Node = scene.instantiate()
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
