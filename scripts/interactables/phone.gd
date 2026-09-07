extends "res://scripts/interactables/interactable.gd"
class_name Phone
## Phone
##
## Unknown/random line stub. Interacting opens the local player's phone
## panel (see Player.gd) so they can type a short text. PhoneSystem then
## routes it server-side to a random other living player - the caller
## never picks (or learns) the recipient.
##
## TODO(post-MVP): voice calls, PA announcements, and window/note comms all
## plug into the same PhoneSystem routing core.

var owner_peer_id: int = -1


func _init() -> void:
	destroyable = true


func _ready() -> void:
	if multiplayer.is_server():
		PhoneSystem.server_register_phone(owner_peer_id, self)


func interact(_by_peer_id: int) -> void:
	# Actual send happens from the HUD panel (Player._on_phone_send_pressed);
	# this just needs to exist so Player._try_interact() recognizes a Phone
	# was targeted and opens the panel.
	pass
