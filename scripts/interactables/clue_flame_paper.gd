extends Interactable
class_name ClueFlamePaper
## ClueFlamePaper
##
## A GRABBABLE puzzle clue. Interacting picks it up (host-authoritative,
## like everything else); the actual "read the code" flow then happens
## entirely in Player.gd while it's held: walk close enough to a `Flame`
## and hold there for a moment to reveal the code, but get too close for
## too long and the paper catches fire - reusing the shared `Interactable`
## destroy mixin (`request_destroy()`) as the "burned up" action, so
## losing the clue this way behaves exactly like any other destroyed prop.
##
## The revealed code itself isn't secret at the netcode level (same trust
## model as ClueBook - it's meant to be found), so the reveal/burn
## countdown lives client-side in Player.gd; only the final pickup and
## burn-destroy actions are host-authoritative.

var revealed_code: String = ""
## Assigned by RoomPod at spawn time to the Flame prop placed alongside
## this paper.
var flame: Flame = null
var is_picked_up: bool = false


func _init() -> void:
	# "Catching fire" reuses the shared destroyable mixin - see
	# Player.gd's per-frame flame-proximity check while holding this.
	destroyable = true


func interact(_by_peer_id: int) -> void:
	if is_destroyed or is_picked_up:
		return
	if multiplayer.is_server():
		server_pickup()
	else:
		_rpc_request_pickup.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_pickup() -> void:
	if not multiplayer.is_server():
		return
	server_pickup()


func server_pickup() -> void:
	if not multiplayer.is_server() or is_destroyed or is_picked_up:
		return
	is_picked_up = true
	_client_apply_picked_up.rpc()
	_apply_picked_up()


@rpc("authority", "call_remote", "reliable")
func _client_apply_picked_up() -> void:
	_apply_picked_up()


func _apply_picked_up() -> void:
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
