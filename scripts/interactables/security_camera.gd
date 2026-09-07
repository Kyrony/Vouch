extends "res://scripts/interactables/interactable.gd"
class_name SecurityCamera
## SecurityCamera
##
## A decorative networked prop marking "the camera in this room" that the
## Puppet Master may be watching through (see PuppetMasterSystem's
## camera-feed grant + Player.gd's camera-feed HUD panel). Destroyable via
## a HELD `destroy` input (default `F`, see Player.gd's hold-to-destroy
## progress) - once destroyed, anyone spying through it should see it go
## offline (the PM's camera-feed code checks this node's `is_destroyed`
## directly, since destruction is public, replicated state).
##
## Mounted near the ceiling on purpose - `min_elevation_y` (a world-space
## Y threshold, set by RoomPod to match the mount height minus a bit of
## slack) is checked by Player.gd before it'll even start the destroy
## hold, so a player has to actually climb the room's ladder first
## instead of just tapping F from the floor.

func _init() -> void:
	destroyable = true

## World-space Y a player's feet must be at or above before they're
## allowed to start destroying this camera. -INF means no requirement.
var min_elevation_y: float = -INF


func interact(_by_peer_id: int) -> void:
	pass
