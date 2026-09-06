extends Interactable
class_name ClueBook
## ClueBook
##
## A puzzle clue that's always readable. Its text (usually a code found
## in `PuzzleSystem`) is baked in at spawn time by the Match director, the
## same way every other per-room prop is configured - it's not secret,
## it's meant to be found. See Player.gd's `_try_interact()` for how the
## text actually gets shown (a simple HUD toast).

var revealed_text: String = ""


func interact(_by_peer_id: int) -> void:
	pass


func get_display_text() -> String:
	return revealed_text
