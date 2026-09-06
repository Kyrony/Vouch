extends Node3D
## Match
##
## Director for the "Match" phase: builds one RoomPod per connected player
## (host-authoritative), assigns each player their spawn point, and wires
## up LinkGraph's mystery-control graph. Room/player nodes are created via
## MultiplayerSpawner.spawn(data) so the same instantiation replicates
## consistently to every client - the standard Godot 4 pattern for
## host-authoritative spawning.
##
## TODO(post-MVP): actual varied room layouts (today every room reuses the
## same RoomPod template with randomized props/seed), mid-match
## reconnection handling, and support for uneven faction sizes.

const ROOM_POD_SCENE: PackedScene = preload("res://scenes/Match/RoomPod.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/Player/Player.tscn")

## Rooms are laid out on a simple grid, far enough apart that one player's
## room doesn't visually bleed into another's. Good enough for a graybox;
## a real level would hand-place these instead.
const GRID_SPACING: float = 12.0
const GRID_COLUMNS: int = 4

@onready var rooms_container: Node3D = $RoomsContainer
@onready var rooms_spawner: MultiplayerSpawner = $RoomsContainer/RoomsSpawner
@onready var players_container: Node3D = $PlayersContainer
@onready var players_spawner: MultiplayerSpawner = $PlayersContainer/PlayersSpawner

## Server-only bookkeeping: room_index -> RoomPod node.
var _rooms: Dictionary = {}


func _ready() -> void:
	rooms_spawner.spawn_function = _spawn_room_pod
	players_spawner.spawn_function = _spawn_player
	GameState.match_started.connect(_on_match_started)


func _on_match_started() -> void:
	if not multiplayer.is_server():
		return
	_server_build_match()


func _server_build_match() -> void:
	_rooms.clear()
	LinkGraph.reset()

	var peer_ids: Array = GameState.players.keys()
	peer_ids.shuffle()

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		GameState.server_set_room(peer_id, i)
		_server_spawn_room(i, peer_id)

	# Links must be built AFTER every room has registered its control/effect
	# nodes with LinkGraph.
	LinkGraph.server_build_links()

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		_server_spawn_player(peer_id, i)


func _server_spawn_room(room_index: int, owner_peer_id: int) -> void:
	var data := {
		"room_index": room_index,
		"owner_peer_id": owner_peer_id,
		"rng_seed": randi(),
	}
	var room: Node = rooms_spawner.spawn(data)
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
	var room := ROOM_POD_SCENE.instantiate() as RoomPod
	room.configure(data["room_index"], data["owner_peer_id"], data["rng_seed"])

	var room_index: int = data["room_index"]
	var col := room_index % GRID_COLUMNS
	var row := room_index / GRID_COLUMNS
	room.position = Vector3(col * GRID_SPACING, 0.0, row * GRID_SPACING)

	return room


## Runs on EVERY peer, same determinism requirement as `_spawn_room_pod`.
func _spawn_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(data["peer_id"])
	# Must happen here (before add_child), NOT in Player._ready() - the
	# MultiplayerSynchronizer child needs authority finalized before this
	# node enters the tree, or its pending spawn silently fails on clients.
	player.set_multiplayer_authority(data["peer_id"])
	player.faction_id = data["faction_id"]
	player.position = data["spawn_position"]
	player.rotation.y = data["spawn_rotation_y"]
	return player
