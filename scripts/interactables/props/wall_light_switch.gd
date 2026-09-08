extends "res://scripts/interactables/interactable.gd"
class_name WallLightSwitch
## A physical wall light switch (prop, not a carried item). Interacting toggles
## the lights (power) for its room/circuit. Distinct from the mystery LightSwitch
## that secretly links to another room.
##
## Host-authoritative.

# ── TUNABLES ──
@export var room_index: int = -1  # circuit this switch controls


func _ready() -> void:
	super._ready()
	add_to_group("light_switches")
	prompt_text = "Light switch"


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		server_toggle(by_peer_id)
	else:
		_rpc_toggle.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_toggle() -> void:
	if multiplayer.is_server():
		server_toggle(multiplayer.get_remote_sender_id())


func server_toggle(_by_peer_id: int) -> bool:
	if not multiplayer.is_server() or room_index < 0:
		return false
	var on := RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_POWER)
	RoomUtilities.server_set_utility(room_index, RoomUtilities.UTILITY_POWER, not on)
	return true
