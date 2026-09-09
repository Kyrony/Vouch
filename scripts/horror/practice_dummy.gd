extends CharacterBody3D
class_name PracticeDummy
## Training pawn. Registers as a fake peer so strings, crowbar, and heals
## resolve the same way they do against a real survivor / Puppet Master.

const DUMMY_PEER: int = 9001

signal reading_changed(text: String)

var last_event: String = "Waiting for a hit or item."
var last_signal: String = "DEAD"
var _poll: float = 0.0
var _last_text: String = ""


func _ready() -> void:
	name = str(DUMMY_PEER)
	add_to_group("players")
	add_to_group("practice_dummy")
	collision_layer = 4
	collision_mask = 1
	PlayerHealth.health_changed.connect(_on_health_changed)
	set_process(true)
	_refresh_reading("Spawned. Shoot strings, crowbar, or use items.")


func configure_as_role(as_survivor: bool) -> void:
	PlayerHealth.server_init_peer(DUMMY_PEER)
	PlayerEffects.server_init_peer(DUMMY_PEER)
	if as_survivor:
		PlayerInventory.server_init_peer(DUMMY_PEER)
	_refresh_reading("Ready as %s." % ("survivor" if as_survivor else "puppet master"))


func apply_event(kind: String, amount: float = 0.0) -> void:
	match kind:
		"damage":
			PlayerHealth.server_apply_drain(DUMMY_PEER, amount)
			last_event = "Took %.0f damage." % amount
		"heal":
			PlayerHealth.server_heal(DUMMY_PEER, amount)
			last_event = "Healed %.0f HP." % amount
		"fear":
			PlayerEffects.server_set_fear(DUMMY_PEER, amount)
			last_event = "Fear set to %.0f." % amount
		"stamina":
			PlayerEffects.server_set_stamina(DUMMY_PEER, amount, true)
			last_event = "Stamina set to %.0f." % amount
		_:
			last_event = kind
	_refresh_reading(last_event)


func _on_health_changed(peer_id: int, _hp: float, _cap: float) -> void:
	if peer_id != DUMMY_PEER:
		return
	_refresh_reading(last_event)


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_poll += delta
	if _poll < 0.2:
		return
	_poll = 0.0
	var strings := PuppetStringSystem.server_string_count(DUMMY_PEER)
	if strings > 0:
		last_event = "Strings=%d ghost=%s immobile=%s" % [
			strings,
			PuppetStringSystem.server_is_ghosted(DUMMY_PEER),
			PuppetStringSystem.server_is_immobilized(DUMMY_PEER),
		]
	var player := GameState.local_player_node
	if player:
		var d: float = global_position.distance_to(player.global_position)
		last_signal = "FULL" if d < 3.0 else ("WEAK" if d < 7.0 else "EMPTY")
	_refresh_reading(last_event)


func _refresh_reading(event: String) -> void:
	last_event = event
	var hp := PlayerHealth.server_get_health(DUMMY_PEER)
	var strings := PuppetStringSystem.server_string_count(DUMMY_PEER)
	var meters: Vector3 = PlayerEffects.server_get_meters(DUMMY_PEER)
	var text := "DUMMY  HP %.0f  STM %.0f  FEAR %.0f  STR %d  SIG %s\n%s" % [
		hp, meters.y, meters.z, strings, last_signal, last_event,
	]
	if text == _last_text:
		return
	_last_text = text
	reading_changed.emit(text)
	var label := get_node_or_null("Reading") as Label3D
	if label:
		label.text = text
