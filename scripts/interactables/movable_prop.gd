extends Interactable
class_name MovableProp
## MovableProp
##
## A prop the player can slide out of the way (bookcase, bed, ladder,
## chains, ...) - e.g. a bookcase blocking a secret hallway opening.
## Host-authoritative: the move is a simple position tween replicated to
## everyone, and its collision is disabled once moved so the now-visible
## path is actually walkable.

@export var move_offset: Vector3 = Vector3(1.4, 0.0, 0.0)
@export var move_duration: float = 0.7
@export var moved_prompt: String = "Push back"
@export var unmoved_prompt: String = "Move it aside"

var moved: bool = false
var _base_position: Vector3
var _tween: Tween


func _ready() -> void:
	_base_position = position
	prompt_text = unmoved_prompt


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		server_toggle_moved()
	else:
		_rpc_request_move.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_move() -> void:
	if not multiplayer.is_server():
		return
	server_toggle_moved()


func server_toggle_moved() -> void:
	if not multiplayer.is_server():
		return
	moved = not moved
	_client_apply_moved.rpc(moved)
	_apply_moved(moved)


@rpc("authority", "call_remote", "reliable")
func _client_apply_moved(is_moved: bool) -> void:
	_apply_moved(is_moved)


func _apply_moved(is_moved: bool) -> void:
	moved = is_moved
	prompt_text = moved_prompt if is_moved else unmoved_prompt

	var target_position := _base_position + (move_offset if is_moved else Vector3.ZERO)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target_position, move_duration)

	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = is_moved
