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
	var bakelite := _mat(Color(0.18, 0.14, 0.12))
	var brass := _mat(Color(0.55, 0.42, 0.22))
	var body: StaticBody3D = _GEOM.call("box", Vector3(0.28, 0.16, 0.42), Vector3(0, 0.08, 0), bakelite, 0)
	body.name = "Body"
	add_child(body)
	add_child(_GEOM.call("box", Vector3(0.34, 0.08, 0.1), Vector3(0, 0.22, 0), brass, 0))
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.45, 0.4, 0.5)
	col.shape = sh
	col.position = Vector3(0, 0.2, 0)
	add_child(col)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m
