extends Interactable
class_name ClueFlamePaper
## ClueFlamePaper
##
## Same idea as ClueBook, but only readable while the LOCAL player is
## standing near a paired `Flame`. This is a client-side-only gate - the
## text itself isn't secret at the netcode level (same trust model as
## ClueBook), it's just narratively "too dark to read" until you're near
## light, so there's no need for a server round-trip here.

var revealed_text: String = ""
## Assigned by RoomPod at spawn time to the Flame prop placed alongside
## this paper.
var flame: Flame = null


func interact(_by_peer_id: int) -> void:
	pass


func get_display_text() -> String:
	if is_readable():
		return revealed_text
	return "The writing is too faint to make out in the dark. Maybe find some light..."


func is_readable() -> bool:
	if not is_instance_valid(flame):
		return false
	var local_player: Node3D = GameState.local_player_node
	if not is_instance_valid(local_player):
		return false
	return flame.global_position.distance_to(local_player.global_position) <= flame.glow_radius
