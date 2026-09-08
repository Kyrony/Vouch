extends "res://scripts/interactables/interactable.gd"
## Neighborhood radio mast — limited-radius trust tool (soft-go stub).

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var tower_id: String = ""
var is_tower_active: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("tower_candidates")
	set_meta("tower_id", tower_id)
	prompt_text = "The mast is silent"
	if get_node_or_null("Mast") == null:
		_build_visual(false)


func set_tower_active(active: bool) -> void:
	is_tower_active = active
	set_meta("tower_id", tower_id)
	if active:
		add_to_group("active_towers")
		prompt_text = "Tap the tower line"
	else:
		if is_in_group("active_towers"):
			remove_from_group("active_towers")
		prompt_text = "The mast is silent"
	_refresh_live_light()


func interact(_by_peer_id: int) -> void:
	pass


func get_display_text() -> String:
	if is_tower_active:
		return "A faint scratch lives in the mast. Stay close."
	return "The mast is dark. Another one may be live."


func _build_visual(_active: bool) -> void:
	## Live farm has no mast meshes. Interactable stub only if instanced.
	pass


func _refresh_live_light() -> void:
	var lamp := get_node_or_null("LiveLight") as OmniLight3D
	if lamp:
		lamp.light_energy = 0.85 if is_tower_active else 0.02


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	return m
