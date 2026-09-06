extends Node
## LinkGraph
##
## The "mystery control" backbone. A control (light switch, valve, breaker,
## ...) in one player's room is secretly wired to an effect (a light, a
## door lock, a buzzer, ...) in a DIFFERENT player's room. Nobody is ever
## told the wiring:
##   - The activator only gets ambiguous LOCAL feedback (a tick/buzz) that
##     something happened - not what, not who.
##   - The affected player only gets a clear LOCAL event at their own prop -
##     they feel the effect, but don't know who caused it.
##
## This keeps the server as the only place that ever knows the full graph,
## which is exactly what a "mystery" system requires.
##
## TODO(post-MVP): more effect types (doors, breakers, alarms), multi-hop
## chains, and per-round graph reshuffles. Today every control maps to
## exactly one effect for the whole match.

## control_id -> Node (LightSwitch, etc). Server-only registry.
var _control_nodes: Dictionary = {}
## effect_id -> Node (RoomLight, etc). Server-only registry.
var _effect_nodes: Dictionary = {}
## effect_id -> owning peer_id, so we know who to notify. Server-only.
var _effect_owner: Dictionary = {}

## control_id -> effect_id. Built once at match start. Server-only, and
## NEVER sent to clients.
var _links: Dictionary = {}


func reset() -> void:
	_control_nodes.clear()
	_effect_nodes.clear()
	_effect_owner.clear()
	_links.clear()


## Registration - interactable props call these from `_ready()`. Only the
## server keeps the data; clients no-op so we don't leak the graph.
func server_register_control(control_id: String, node: Node) -> void:
	if not multiplayer.is_server():
		return
	_control_nodes[control_id] = node


func server_register_effect(effect_id: String, node: Node, owner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_effect_nodes[effect_id] = node
	_effect_owner[effect_id] = owner_peer_id


## Called once by the Match director (server-only) after every room/prop has
## registered itself. Randomly pairs every control with an effect, rotating
## the shuffled effect list so nothing is trivially self-linked when there's
## more than one room.
func server_build_links() -> void:
	if not multiplayer.is_server():
		return
	_links.clear()

	var control_ids: Array = _control_nodes.keys()
	var effect_ids: Array = _effect_nodes.keys()
	if control_ids.is_empty() or effect_ids.is_empty():
		return

	effect_ids.shuffle()
	for i in range(control_ids.size()):
		var effect_id: String = effect_ids[i % effect_ids.size()]
		_links[control_ids[i]] = effect_id


## Client entry point for activating a control they don't have server
## authority over (i.e. every client that isn't the host).
@rpc("any_peer", "call_remote", "reliable")
func request_activate(control_id: String) -> void:
	if not multiplayer.is_server():
		return
	var activator_peer := multiplayer.get_remote_sender_id()
	server_handle_activation(control_id, activator_peer)


## Shared server-side logic, also called directly by the host's own local
## Player instance (see Player.gd) to avoid RPC-to-self edge cases.
func server_handle_activation(control_id: String, activator_peer: int) -> void:
	if not multiplayer.is_server():
		return

	if not _links.has(control_id):
		push_warning("LinkGraph: unknown control_id '%s'" % control_id)
		return

	var effect_id: String = _links[control_id]
	# Deliberately untyped/dynamic: any future effect prop only needs to
	# implement `server_apply_effect()`, it doesn't need to be a specific
	# class, so we duck-type it rather than statically declaring `Node`
	# (which would make the static analyzer reject the dynamic call below).
	var effect_node = _effect_nodes.get(effect_id)
	var effect_owner: int = _effect_owner.get(effect_id, -1)

	if is_instance_valid(effect_node) and effect_node.has_method("server_apply_effect"):
		effect_node.server_apply_effect()

	# Ambiguous local feedback to whoever pulled the lever - they know
	# *something* happened, never what or to whom.
	_notify_feedback(activator_peer, "tick")

	# Unambiguous local event to whoever got affected - they feel it
	# directly at their own prop, but never learn who caused it.
	if effect_owner != -1:
		_notify_effect(effect_owner, effect_id)


func _notify_feedback(peer_id: int, feedback_kind: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_local_feedback(feedback_kind)
	else:
		_client_local_feedback.rpc_id(peer_id, feedback_kind)


func _notify_effect(peer_id: int, effect_id: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_client_effect_triggered(effect_id)
	else:
		_client_effect_triggered.rpc_id(peer_id, effect_id)


@rpc("authority", "call_remote", "reliable")
func _client_local_feedback(feedback_kind: String) -> void:
	# MVP: just log it. TODO: hook up a tick/buzzer SFX + a subtle UI ping.
	print("[LinkGraph] local feedback: %s (something happened somewhere)" % feedback_kind)


@rpc("authority", "call_remote", "reliable")
func _client_effect_triggered(effect_id: String) -> void:
	# MVP: just log it. TODO: hook up per-effect local presentation
	# (flicker the light, buzz the door, etc). The receiving prop node
	# itself already changed state via server_apply_effect() replication;
	# this signal is for extra "you've been hit" framing/SFX.
	print("[LinkGraph] your prop was affected: %s" % effect_id)
