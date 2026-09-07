extends "res://scripts/interactables/interactable.gd"
class_name WalkieTalkie
## Room walkie-talkie — opens paired faction text channel (see WalkieSystem).

@export var owner_peer_id: int = -1


func interact(by_peer_id: int) -> void:
	if is_destroyed:
		return
	var player := GameState.local_player_node
	if player and player.has_method("open_walkie_panel"):
		player.open_walkie_panel()
