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
	if not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_GAS):
		print("[ExhaustVent] gas utility off — vent stalled")
		return
	if not RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_COMMS):
		print("[ExhaustVent] faint static on the comms line")
		return
	print("[ExhaustVent] air moves through the vent")
