extends Node
## LinkGraph
##
## The "mystery control" backbone. A control (light switch, water valve,
## ...) in one player's room is secretly wired to an effect (a light, a
## broken pipe, ...) in a DIFFERENT player's room. Nobody is ever told the
## wiring:
##   - The activator only gets ambiguous LOCAL feedback (a tick/buzz) that
##     something happened - not what, not who.
##   - The affected player only gets a clear LOCAL event at their own prop -
##     they feel the effect, but don't know who caused it.
##
## Controls/effects are grouped into "channels" (e.g. "light", "flood") -
## a control only ever links to an effect in the SAME channel, so a light
## switch never accidentally "controls" a broken pipe. Within each
## channel, pairing uses a guaranteed derangement (rotate-by-one over a
## shuffled room order) so **no control ever links to its own room's
## effect** - this isn't just "usually avoided", it's mathematically
## guaranteed whenever a channel has 2+ rooms, which is exactly what the
## Puppet Master rule ("his controls must never affect his own room")
## needs, and it's a nicer guarantee for everyone else too.
##
## This keeps the server as the only place that ever knows the full graph,
## which is exactly what a "mystery" system requires.
##
## TODO(post-MVP): multi-hop chains, per-round graph reshuffles.

## control_id -> {"node": Node, "room_index": int, "channel": String}. Server-only.
var _control_nodes: Dictionary = {}
## effect_id -> {"node": Node, "room_index": int, "owner_peer_id": int, "channel": String}. Server-only.
var _effect_nodes: Dictionary = {}

## control_id -> effect_id. Built once at match start. Server-only, and
## NEVER sent to clients.
var _links: Dictionary = {}


func reset() -> void:
	_control_nodes.clear()
	_effect_nodes.clear()
	_links.clear()


## Registration - interactable props call these from `_ready()` (or
## RoomPod calls them at construction time). Only the server keeps the
## data; clients no-op so we don't leak the graph.
func server_register_control(control_id: String, node: Node, room_index: int, channel: String = "light") -> void:
	if not multiplayer.is_server():
		return
	_control_nodes[control_id] = {"node": node, "room_index": room_index, "channel": channel}


func server_register_effect(effect_id: String, node: Node, owner_peer_id: int, room_index: int, channel: String = "light") -> void:
	if not multiplayer.is_server():
		return
	_effect_nodes[effect_id] = {"node": node, "room_index": room_index, "owner_peer_id": owner_peer_id, "channel": channel}


## Exposed so other trusted server systems (e.g. PuppetMasterSystem's
## sabotage action) can reuse the same registered effect props instead of
## keeping a second parallel registry. Deliberately untyped - see the note
## on `server_handle_activation` below.
func server_get_effect_node(effect_id: String):
	var entry: Dictionary = _effect_nodes.get(effect_id, {})
	return entry.get("node")


## Exposed so other trusted server systems can send the same "your prop was
## affected" local event LinkGraph itself would send for a normal mystery
## link (e.g. when Puppet Master sabotage - not a LightSwitch - triggers
## the same effect prop).
func notify_room_affected(peer_id: int, effect_id: String) -> void:
	if not multiplayer.is_server():
		return
	_notify_effect(peer_id, effect_id)


## Called once by the Match director (server-only) after every room/prop has
## registered itself. Within each channel, guarantees a derangement (no
## control ever maps to an effect in its OWN room_index).
func server_build_links() -> void:
	if not multiplayer.is_server():
		return
	_links.clear()

	var channels: Dictionary = {}
	for control_id in _control_nodes.keys():
		var channel: String = _control_nodes[control_id]["channel"]
		channels.get_or_add(channel, []).append(control_id)

	for channel in channels.keys():
		_link_channel(channel, channels[channel])


func _link_channel(channel: String, control_ids: Array) -> void:
	var effect_ids: Array = []
	for effect_id in _effect_nodes.keys():
		if _effect_nodes[effect_id]["channel"] == channel:
			effect_ids.append(effect_id)
	if control_ids.is_empty() or effect_ids.is_empty():
		return

	# Order controls by a shuffled room sequence so pairing isn't
	# predictable, then rotate-by-one through the SAME shuffled sequence
	# of effects. Rotating a sequence by one guarantees position i never
	# maps back to position i, i.e. no room's control ever links to that
	# same room's effect (the whole point of this exercise) - true for
	# any channel with 2+ distinct rooms; a 1-room channel has no other
	# room to link to and is left unlinked rather than self-linked.
	var rooms_with_control: Array = control_ids.duplicate()
	rooms_with_control.shuffle()
	var rooms_with_effect: Array = effect_ids.duplicate()
	rooms_with_effect.shuffle()

	var control_room_order: Array = []
	for control_id in rooms_with_control:
		control_room_order.append(_control_nodes[control_id]["room_index"])

	var n := rooms_with_control.size()
	var m := rooms_with_effect.size()
	for i in range(n):
		var control_id: String = rooms_with_control[i]
		var control_room: int = control_room_order[i]

		var chosen_effect: String = ""
		# Try each rotation offset until we find an effect NOT owned by
		# this control's own room. With m >= 2 distinct rooms represented
		# in the effect pool this always succeeds on offset 1; with a
		# single-room effect pool for this channel, self-linking is
		# unavoidable and we skip linking entirely instead.
		for offset in range(1, m + 1):
			var candidate: String = rooms_with_effect[(i + offset) % m]
			if _effect_nodes[candidate]["room_index"] != control_room:
				chosen_effect = candidate
				break

		if not chosen_effect.is_empty():
			_links[control_id] = chosen_effect


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
		push_warning("LinkGraph: unknown or unlinked control_id '%s'" % control_id)
		_notify_feedback(activator_peer, "tick")
		return

	var effect_id: String = _links[control_id]
	var effect_entry: Dictionary = _effect_nodes.get(effect_id, {})
	# Deliberately untyped/dynamic: any future effect prop only needs to
	# implement `server_apply_effect()`, it doesn't need to be a specific
	# class, so we duck-type it rather than statically declaring `Node`
	# (which would make the static analyzer reject the dynamic call below).
	var effect_node = effect_entry.get("node")
	var effect_owner: int = effect_entry.get("owner_peer_id", -1)

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
	var player := GameState.local_player_node
	if player and player.has_method("_show_toast"):
		match feedback_kind:
			"tick":
				player._show_toast("Something clicked into place somewhere…")
			_:
				player._show_toast("Feedback: %s" % feedback_kind)
	else:
		print("[LinkGraph] local feedback: %s" % feedback_kind)


@rpc("authority", "call_remote", "reliable")
func _client_effect_triggered(effect_id: String) -> void:
	var player := GameState.local_player_node
	if player and player.has_method("_show_toast"):
		player._show_toast("Something changed in your room.")
	_pulse_local_effect(effect_id)
	print("[LinkGraph] your prop was affected: %s" % effect_id)


func _pulse_local_effect(effect_id: String) -> void:
	for node in get_tree().get_nodes_in_group("link_effects"):
		if node.get("effect_id") == effect_id and node.has_method("client_link_pulse"):
			node.client_link_pulse()
