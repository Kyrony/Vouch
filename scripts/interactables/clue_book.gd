extends Interactable
class_name ClueBook
## ClueBook
##
## Readable clue book. Can be ignited near flames (host-authoritative).

var revealed_text: String = ""
var is_burning: bool = false


func _ready() -> void:
	add_to_group("flammable_props")
	set_process(multiplayer.is_server())


func _process(_delta: float) -> void:
	if is_destroyed or is_burning:
		return
	var fire := get_node_or_null("/root/FireSystem")
	if fire:
		fire.server_scan_proximity(self)


func can_ignite() -> bool:
	return not is_destroyed and not is_burning


func get_burn_duration() -> float:
	return 5.0


func server_on_ignited() -> void:
	is_burning = true


func server_finish_burn() -> void:
	server_destroy()


func interact(_by_peer_id: int) -> void:
	pass


func get_display_text() -> String:
	return revealed_text
