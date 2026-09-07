extends Interactable
class_name ExhaustVent
## ExhaustVent
##
## Wall exhaust vent — stub hooks for gas venting and comms static.

@export var room_index: int = -1


func configure(p_room_index: int) -> void:
	room_index = p_room_index
	prompt_text = "Exhaust vent"


func interact(_by_peer_id: int) -> void:
	var msg := "Air moves through the vent."
	if not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_GAS):
		msg = "Gas line is dead — vent does nothing."
	elif not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_COMMS):
		msg = "Static crackles through the vent grille."
	var player := GameState.local_player_node
	if player and player.has_method("_show_toast"):
		player._show_toast(msg)
