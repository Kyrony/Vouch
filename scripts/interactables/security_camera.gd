extends Interactable
class_name SecurityCamera
## SecurityCamera
##
## A decorative networked prop marking "the camera in this room" that the
## Puppet Master may be watching through (see PuppetMasterSystem's
## camera-feed grant + Player.gd's camera-feed HUD panel). Destroyable via
## the `destroy` input (default `F`) - once destroyed, anyone spying
## through it should see it go offline (the PM's camera-feed code checks
## this node's `is_destroyed` directly, since destruction is public,
## replicated state).

func _init() -> void:
	destroyable = true


func interact(_by_peer_id: int) -> void:
	pass
