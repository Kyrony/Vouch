extends Node
## NetworkManager
##
## Host-authoritative bootstrap for Godot's high-level MultiplayerAPI.
## The host runs an ENetMultiplayerPeer server; clients connect directly by
## IP. This is the MVP "host/join shell" - lobby codes and NAT-punching
## relay support are explicitly future work (see docs/MVP_GDD.md).
##
## Every RPC that must be trusted (faction assignment, mystery-link
## resolution, escape approval, ...) lives on an autoload singleton like
## this one rather than on a per-instance node. Autoload singletons default
## to multiplayer authority == 1 (the server), so `@rpc("authority", ...)`
## methods here are automatically "only the host may call this" without any
## extra setup - a simple, sensible pattern for a host-authoritative game.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_started
signal join_failed(reason: String)
signal joined_server
signal disconnected_from_server
signal faction_assigned(faction_id: String)
## Fired on every peer whenever the pre-match lobby roster changes -
## [{"peer_id": int, "name": String}, ...]. This is intentionally NOT
## privacy-sensitive (no faction/role info, just "who's connected"), so
## it's fine to broadcast to everyone, unlike faction assignment.
signal lobby_roster_updated(roster: Array)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8

var is_hosting: bool = false
## Client-side cache of the last roster broadcast, so late UI (e.g. a
## panel opened after the fact) can read the current state immediately.
var lobby_roster: Array = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		push_error("NetworkManager: failed to create server (err=%s)" % err)
		return err

	multiplayer.multiplayer_peer = peer
	is_hosting = true

	GameState.reset_for_new_match()
	# The host is always peer id 1 and plays as a normal participant in MVP
	# (no dedicated-server mode yet).
	GameState.server_register_player(1, "Host")

	server_started.emit()
	_broadcast_lobby_roster()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: failed to create client (err=%s)" % err)
		return err

	multiplayer.multiplayer_peer = peer
	is_hosting = false
	GameState.reset_for_new_match()
	return OK


func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_hosting = false
	lobby_roster = []
	GameState.reset_for_new_match()


func is_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


## Called by the host's Lobby UI once enough players are present.
func start_match() -> void:
	if not is_server():
		push_warning("NetworkManager: only the host can start the match.")
		return

	var all_peer_ids: Array = GameState.players.keys()

	# The Puppet Master is picked FIRST and excluded from the normal
	# faction pool entirely - they're a fifth, independent role. See
	# PuppetMasterSystem / docs/MVP_GDD.md.
	var pm_peer_id := PuppetMasterSystem.server_assign_puppet_master(all_peer_ids)

	_assign_factions(all_peer_ids, pm_peer_id)
	PhoneSystem.server_assign_line_ids(all_peer_ids)
	_client_match_started.rpc()


func _assign_factions(all_peer_ids: Array, excluded_peer_id: int) -> void:
	var peer_ids: Array = all_peer_ids.duplicate()
	peer_ids.erase(excluded_peer_id)
	peer_ids.shuffle()

	var factions := FactionData.get_active_factions()
	if factions.is_empty():
		push_error("NetworkManager: no active factions configured.")
		return

	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		var faction: Dictionary = factions[i % factions.size()]
		GameState.server_set_faction(peer_id, faction["id"])
		# Unicast only - this is the single most important privacy rule in
		# the whole project: nobody but the assigned player learns this.
		# `rpc_id()` targeting your own peer id is a no-op in Godot unless
		# the RPC is `call_local`, so the host's own assignment has to be
		# applied directly instead of round-tripping through the network.
		if peer_id == multiplayer.get_unique_id():
			_client_receive_faction(faction["id"])
		else:
			_client_receive_faction.rpc_id(peer_id, faction["id"])


func _on_peer_connected(peer_id: int) -> void:
	if is_server():
		GameState.server_register_player(peer_id, "Player %d" % peer_id)
		_broadcast_lobby_roster()
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_server():
		GameState.server_unregister_player(peer_id)
		_broadcast_lobby_roster()
	player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	joined_server.emit()


func _on_connection_failed() -> void:
	join_failed.emit("Could not reach host.")


func _on_server_disconnected() -> void:
	is_hosting = false
	disconnected_from_server.emit()


func _broadcast_lobby_roster() -> void:
	if not is_server():
		return
	var roster: Array = []
	for peer_id in GameState.players.keys():
		roster.append({"peer_id": peer_id, "name": GameState.players[peer_id]["name"]})
	_client_lobby_roster.rpc(roster)


## --- Trusted RPC endpoints (autoload authority defaults to peer 1) ---


@rpc("authority", "call_local", "reliable")
func _client_match_started() -> void:
	GameState.phase = GameState.Phase.IN_MATCH
	GameState.match_started.emit()


@rpc("authority", "call_remote", "reliable")
func _client_receive_faction(faction_id: String) -> void:
	GameState.local_faction_id = faction_id
	faction_assigned.emit(faction_id)


@rpc("authority", "call_local", "reliable")
func _client_lobby_roster(roster: Array) -> void:
	lobby_roster = roster
	lobby_roster_updated.emit(roster)
