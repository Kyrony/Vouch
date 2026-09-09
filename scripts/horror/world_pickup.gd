extends StaticBody3D
## WorldPickup — grabbable item in the horror map.
## StaticBody on the interactables layer so the player's InteractRay can hit it.

const _PHONE: GDScript = preload("res://scripts/horror/items/smartphone_visual.gd")
const _CATALOG: GDScript = preload("res://scripts/horror/items/item_catalog.gd")

@export var item_id: String = "medkit"
@export var prompt_text: String = "Pick up"

var _taken: bool = false
var _visual: Node3D
var _bob: float = 0.0


func _ready() -> void:
	add_to_group("world_pickups")
	collision_layer = 2
	collision_mask = 0
	input_ray_pickable = true
	_build_visual()


func _process(delta: float) -> void:
	if _visual == null:
		return
	_bob += delta
	_visual.position.y = 0.08 + sin(_bob * 2.6) * 0.05
	_visual.rotate_y(delta * 0.7)


func _build_visual() -> void:
	if item_id == "phone":
		_build_smartphone()
		return
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh_for(item_id)
	var mat := StandardMaterial3D.new()
	if _CATALOG.has_item(item_id):
		mat.albedo_color = _CATALOG.color(item_id)
	else:
		mat.albedo_color = Color(0.55, 0.55, 0.6)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.45
	mesh.set_surface_override_material(0, mat)
	_visual.add_child(mesh)
	_add_pickup_collision(Vector3(0.7, 0.9, 0.7))


func _mesh_for(id: String) -> Mesh:
	match id:
		"energy_drink", "adrenaline", "painkillers", "battery":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.09
			cyl.height = 0.28
			return cyl
		"scissors", "crowbar", "lockpick":
			var bar := BoxMesh.new()
			bar.size = Vector3(0.08, 0.08, 0.42)
			return bar
		"key", "keycard", "fuse":
			var slim := BoxMesh.new()
			slim.size = Vector3(0.22, 0.04, 0.14)
			return slim
		"flare":
			var stick := CylinderMesh.new()
			stick.top_radius = 0.035
			stick.bottom_radius = 0.035
			stick.height = 0.32
			return stick
		"puppet":
			var puppet := CapsuleMesh.new()
			puppet.radius = 0.12
			puppet.height = 0.42
			return puppet
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.32, 0.22, 0.28)
			return box


func _build_smartphone() -> void:
	_visual = _PHONE.attach(self, false)
	_visual.rotation_degrees = Vector3(12, -18, 8)
	_PHONE.update_screen(_visual, 100.0, "dead", false)
	_add_pickup_collision(Vector3(0.36, 0.46, 0.22))


func _add_pickup_collision(size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y * 0.35
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
		PuppetControlSystem.server_take_puppet(peer_id)
	elif not PlayerInventory.server_add_item(peer_id, item_id):
		return false
	_taken = true
	_client_hide.rpc()
	queue_free()
	return true


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
