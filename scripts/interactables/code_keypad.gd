extends "res://scripts/interactables/interactable.gd"
class_name CodeKeypad
## CodeKeypad
##
## A puzzle prop that unlocks its own room's escape point once the
## correct code is entered. The code itself is never known client-side -
## submitting a guess round-trips through `PuzzleSystem` on the server.
## See Player.gd's `_try_interact()` / `_open_keypad_panel()` for the UI.

## Which room's escape this keypad unlocks - always this room's own index
## (the keypad and the lock it opens always live together).
var room_index: int = -1


func interact(_by_peer_id: int) -> void:
	pass
