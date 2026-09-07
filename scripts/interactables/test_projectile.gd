extends Area3D
class_name TestProjectile
## TestProjectile
##
## *** TEST-ONLY - REMOVE BEFORE FULL RELEASE ***
## Visible projectile fired by the test gun. Host-authoritative hit
## detection against DummyTarget props.

const SPEED: float = 45.0
const MAX_LIFETIME: float = 3.0

var direction: Vector3 = Vector3.FORWARD
var _alive: float = 0.0


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 3 # world + interactables
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Small visible tracer.
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = 0.08
	shape.shape = cs
	add_child(shape)


func launch(from: Vector3, dir: Vector3) -> void:
	global_position = from
	direction = dir.normalized()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	global_position += direction * SPEED * delta
	_alive += delta
	if _alive >= MAX_LIFETIME:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body is DummyTarget:
		body.server_register_hit()
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if not multiplayer.is_server():
		return
	if area.get_parent() is DummyTarget:
		(area.get_parent() as DummyTarget).server_register_hit()
		queue_free()
