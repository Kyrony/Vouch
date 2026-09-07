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


func _build_visual(active: bool) -> void:
	var rust := _mat(Color(0.28, 0.22, 0.18))
	var brass := _mat(Color(0.52, 0.4, 0.2))
	var mast: StaticBody3D = _GEOM.call("box", Vector3(0.28, 7.2, 0.28), Vector3(0, 3.6, 0), rust, 0)
	mast.name = "Mast"
	add_child(mast)
	add_child(_GEOM.call("box", Vector3(2.4, 0.12, 0.12), Vector3(0, 6.6, 0), rust, 0))
	add_child(_GEOM.call("box", Vector3(0.12, 0.12, 2.4), Vector3(0, 6.6, 0), rust, 0))
	add_child(_GEOM.call("box", Vector3(0.8, 0.35, 0.8), Vector3(0, 0.18, 0), brass, 0))
	var lamp := OmniLight3D.new()
	lamp.name = "LiveLight"
	lamp.position = Vector3(0, 6.9, 0)
	lamp.light_color = Color(0.75, 0.45, 0.2)
	lamp.omni_range = 10.0
	lamp.light_energy = 0.15 if active else 0.02
	add_child(lamp)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 7.2, 1.2)
	col.shape = sh
	col.position = Vector3(0, 3.6, 0)
	add_child(col)


func _refresh_live_light() -> void:
	var lamp := get_node_or_null("LiveLight") as OmniLight3D
	if lamp:
		lamp.light_energy = 0.85 if is_tower_active else 0.02


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	return m
