extends StaticBody3D
class_name Interactable
## Interactable
##
## Base class for every prop a player can "use" (E key). Subclasses
## override `interact()`. Kept as a StaticBody3D so Player.gd can find it
## with a simple forward raycast on the "interactables" physics layer.
##
## Also provides an optional shared "destroyable" mixin: any interactable
## can be marked `destroyable = true` (camera, phone, ...) and destroyed
## with the separate `destroy` input (default `F`), host-authoritative.
## Destruction just hides the prop and disables its collision/behavior -
## simple and clear rather than literally blowing anything up.

## Shown in the on-screen prompt when the player is looking at this prop.
@export var prompt_text: String = "Interact"

## If true, this prop can be destroyed via the `destroy` input instead of
## (or in addition to) the normal `interact` action.
@export var destroyable: bool = false

## Server-authoritative, replicated to everyone via `_client_apply_destroyed`.
var is_destroyed: bool = false


## Called on whichever client is looking at this prop and presses interact.
## Subclasses decide whether to resolve locally or ask the server via RPC.
func interact(_by_peer_id: int) -> void:
	pass


## Called by Player.gd when the local player presses the `destroy` input
## while looking at this prop. Routes to the server the same way every
## other trust-sensitive action in this project does.
func request_destroy(_by_peer_id: int) -> void:
	if not destroyable or is_destroyed:
		return
	if multiplayer.is_server():
		server_destroy()
	else:
		_rpc_request_destroy.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_destroy() -> void:
	if not multiplayer.is_server():
		return
	server_destroy()


func server_destroy() -> void:
	if not multiplayer.is_server() or is_destroyed:
		return
	is_destroyed = true
	_client_apply_destroyed.rpc()
	_apply_destroyed()


@rpc("authority", "call_remote", "reliable")
func _client_apply_destroyed() -> void:
	_apply_destroyed()


## Subclasses with extra state (e.g. a mesh they'd rather swap than hide)
## can override this, but the default of "hide + disable collision" is
## enough to make destruction read clearly in a graybox.
func _apply_destroyed() -> void:
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
