extends Node
## GameState
##
## Match-wide state, kept host-authoritative. The full `players` roster
## (faction, room, escaped flag, ...) only ever holds complete data on the
## host/server. Clients are deliberately NOT sent the full roster - each
## client only ever learns its own faction id (see `local_faction_id`) so a
## player can never see a teammate list mid-round, per the design lock.
##
## TODO(post-MVP): replace the plain Dictionary roster with a proper
## replicated resource once lobby settings (faction count, room count,
## timers) need to be synced too.

signal match_started
signal player_escaped(peer_id: int, faction_id: String)

enum Phase { LOBBY, IN_MATCH, MATCH_OVER }

var phase: Phase = Phase.LOBBY

## Server-only source of truth. Structure per peer_id:
## { "faction_id": String, "room_id": int, "escaped": bool, "name": String }
## Clients keep this dictionary empty except for a debug/host preview; do not
## read it from client code.
var players: Dictionary = {}

## Set on the local peer only, via NetworkManager's targeted RPC. This is the
## ONE piece of faction information a client is allowed to know about.
var local_faction_id: String = ""

## Winning faction id, set once the match ends. Empty while in progress.
var winning_faction_id: String = ""

## Set locally by Player.gd when it spawns its own authoritative instance.
## Used by systems (e.g. EscapeSystem) that need to move "the local player"
## without maintaining their own separate lookup.
var local_player_node: Node3D = null


func reset_for_new_match() -> void:
	phase = Phase.LOBBY
	players.clear()
	local_faction_id = ""
	winning_faction_id = ""
	local_player_node = null


func server_register_player(peer_id: int, display_name: String) -> void:
	players[peer_id] = {
		"faction_id": "",
		"room_id": -1,
		"escaped": false,
		"name": display_name,
	}


func server_unregister_player(peer_id: int) -> void:
	players.erase(peer_id)


func server_set_faction(peer_id: int, faction_id: String) -> void:
	if players.has(peer_id):
		players[peer_id]["faction_id"] = faction_id


func server_set_room(peer_id: int, room_id: int) -> void:
	if players.has(peer_id):
		players[peer_id]["room_id"] = room_id


func server_mark_escaped(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id]["escaped"] = true


func server_get_faction(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id]["faction_id"]
	return ""


func server_get_faction_roster(faction_id: String) -> Array[int]:
	var roster: Array[int] = []
	for peer_id in players.keys():
		if players[peer_id]["faction_id"] == faction_id:
			roster.append(peer_id)
	return roster


func server_is_faction_fully_escaped(faction_id: String) -> bool:
	var roster := server_get_faction_roster(faction_id)
	if roster.is_empty():
		return false
	for peer_id in roster:
		if not players[peer_id]["escaped"]:
			return false
	return true


func server_check_for_win() -> String:
	## Returns the winning faction id, or "" if nobody has fully escaped yet.
	if phase == Phase.MATCH_OVER:
		return winning_faction_id
	for faction in FactionData.get_active_factions():
		if server_is_faction_fully_escaped(faction["id"]):
			return faction["id"]
	return ""
