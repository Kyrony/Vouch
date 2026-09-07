extends Interactable
class_name Door
## Door
##
## Escape / interior door with swing animation. Opens on interact; escape
## completes when the player reaches the shared Outside zone at the top of
## the central shaft (see EscapeZone.gd).

const OPEN_ANGLE: float = -1.35
const ANIM_TIME: float = 0.55

var is_open: bool = false
var is_vent: bool = false
var _pivot: Node3D
var _tween: Tween
var _vent_closed_y: float = 0.0


func _ready() -> void:
	_pivot = get_node_or_null("Pivot") as Node3D
	if _pivot and is_vent:
		_vent_closed_y = _pivot.position.y


func interact(by_peer_id: int) -> void:
	if multiplayer.is_server():
		if is_open:
			server_close(by_peer_id)
		else:
			server_open(by_peer_id)
	elif is_open:
		_rpc_close.rpc_id(1)
	else:
		_rpc_open.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_open() -> void:
	if multiplayer.is_server():
		server_open(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_close() -> void:
	if multiplayer.is_server():
		server_close(multiplayer.get_remote_sender_id())


func server_open(_by_peer_id: int) -> void:
	if not multiplayer.is_server() or is_open:
		return
	is_open = true
	_client_set_open.rpc(true)


func server_close(_by_peer_id: int) -> void:
	if not multiplayer.is_server() or not is_open:
		return
	is_open = false
	_client_set_open.rpc(false)


@rpc("authority", "call_remote", "reliable")
func _client_set_open(open: bool) -> void:
	_play_door_animation(open)


func _play_door_animation(open: bool) -> void:
	is_open = open
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	if _pivot:
		if is_vent:
			var target_y := _vent_closed_y + 0.45 if open else _vent_closed_y
			_tween.tween_property(_pivot, "position:y", target_y, ANIM_TIME)
		else:
			_tween.tween_property(_pivot, "rotation:y", OPEN_ANGLE if open else 0.0, ANIM_TIME)
		for child in _pivot.get_children():
			if child is CollisionShape3D:
				child.disabled = open
	else:
		var target := rotation.y + (OPEN_ANGLE if open else -OPEN_ANGLE)
		if not open:
			target = rotation.y
		_tween.tween_property(self, "rotation:y", target, ANIM_TIME)
