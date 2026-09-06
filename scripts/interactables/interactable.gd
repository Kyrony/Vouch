extends StaticBody3D
class_name Interactable
## Interactable
##
## Base class for every prop a player can "use" (E key). Subclasses
## override `interact()`. Kept as a StaticBody3D so Player.gd can find it
## with a simple forward raycast on the "interactables" physics layer.

## Shown in the on-screen prompt when the player is looking at this prop.
@export var prompt_text: String = "Interact"


## Called on whichever client is looking at this prop and presses interact.
## Subclasses decide whether to resolve locally or ask the server via RPC.
func interact(_by_peer_id: int) -> void:
	pass
