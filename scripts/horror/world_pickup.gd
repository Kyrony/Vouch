extends Area3D
## WorldPickup — grabbable item in the horror map.

const _PHONE: GDScript = preload("res://scripts/horror/items/smartphone_visual.gd")
const _CATALOG: GDScript = preload("res://scripts/horror/items/item_catalog.gd")

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
	if item_id == "phone":
		_build_smartphone()
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	if _CATALOG.has_item(item_id):
		mat.albedo_color = _CATALOG.color(item_id)
	else:
		match item_id:
			"battery":
				mat.albedo_color = Color(0.72, 0.58, 0.16)
			"keycard":
				mat.albedo_color = Color(0.2, 0.7, 0.9)
			_:
				mat.albedo_color = Color(0.55, 0.55, 0.6)
	# A faint glow so items read as "grabbable" in the dark.
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.25
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)
	_add_pickup_collision(Vector3(0.5, 0.5, 0.5))


func _build_smartphone() -> void:
	var visual: Node3D = _PHONE.attach(self, false)
	visual.rotation_degrees = Vector3(12, -18, 8)
	_PHONE.update_screen(visual, 100.0, "dead", false)
	_add_pickup_collision(Vector3(0.28, 0.36, 0.16))


func _add_pickup_collision(size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)


func get_prompt() -> String:
	if item_id == "phone":
		return "%s (smartphone LED)" % prompt_text
	if _CATALOG.has_item(item_id):
		return "%s %s" % [prompt_text, _CATALOG.label(item_id)]
	return "%s (%s)" % [prompt_text, item_id]


func server_try_pickup(peer_id: int) -> bool:
	if _taken:
		return false
	if item_id == "puppet":
		# The Puppet Master dons the puppet instead of pocketing it.
		PuppetControlSystem.server_take_puppet(peer_id)
	elif not PlayerInventory.server_add_item(peer_id, item_id):
		return false
	_taken = true
	_client_hide.rpc()
	queue_free()
	return true


## The PM picks up the puppet (survivor pickup RPC blocks the PM, so this is
## a dedicated path).
@rpc("any_peer", "call_remote", "reliable")
func rpc_pm_take() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if item_id == "puppet" and sender == GameState.puppet_master_peer_id:
		server_try_pickup(sender)


@rpc("authority", "call_local", "reliable")
func _client_hide() -> void:
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true


func _on_body_entered(_body: Node) -> void:
	pass
