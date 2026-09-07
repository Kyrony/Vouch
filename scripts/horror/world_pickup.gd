extends Area3D
## WorldPickup — grabbable item in the horror map.

@export var item_id: String = "medkit"
@export var prompt_text: String = "Pick up"

var _taken: bool = false


func _ready() -> void:
	add_to_group("world_pickups")
	collision_layer = 2
	collision_mask = 0
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	match item_id:
		"medkit":
			mat.albedo_color = Color(0.85, 0.2, 0.2)
		"flashlight":
			mat.albedo_color = Color(0.9, 0.85, 0.3)
		"keycard":
			mat.albedo_color = Color(0.2, 0.7, 0.9)
		_:
			mat.albedo_color = Color(0.55, 0.55, 0.6)
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	col.shape = shape
	add_child(col)


func get_prompt() -> String:
	return "%s (%s)" % [prompt_text, item_id]


func server_try_pickup(peer_id: int) -> bool:
	if _taken:
		return false
	if not PlayerInventory.server_add_item(peer_id, item_id):
		return false
	_taken = true
	_client_hide.rpc()
	queue_free()
	return true


@rpc("authority", "call_local", "reliable")
func _client_hide() -> void:
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true


func _on_body_entered(_body: Node) -> void:
	pass
