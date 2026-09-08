extends "res://scripts/interactables/interactable.gd"
## World handset — limited-radius slate, not a voice or SMS line.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var phone_id: String = ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("signal_phones")
	prompt_text = "Lift the handset"
	if get_node_or_null("Body") == null:
		_build_visual()


func interact(_by_peer_id: int) -> void:
	pass


func get_display_text() -> String:
	return "A cold handset. The scratch only carries near a live mast."


func _build_visual() -> void:
	## Live farm has no handset props.
	pass


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m
