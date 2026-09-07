extends Node3D
class_name EscapeHub
## EscapeHub
##
## Central underground shaft where every room's escape hall converges.
## The shared Outside courtyard sits on top. Built once per match on every
## peer from the same room count / grid layout.

const SHAFT_RADIUS: float = 4.0
const SHAFT_HEIGHT: float = 45.0
const HALL_WIDTH: float = 2.8
const HALL_HEIGHT: float = 3.2

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D


func build(room_count: int) -> void:
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.38, 0.36, 0.34)
	_wall_mat.roughness = 0.9
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.22, 0.21, 0.2)
	_floor_mat.roughness = 0.85

	_build_vertical_shaft()
	_build_surface_cap()
	_add_escape_zone()


func _build_vertical_shaft() -> void:
	var inner := SHAFT_RADIUS * 2.0
	add_child(_box(Vector3(inner, SHAFT_HEIGHT, inner), Vector3(0, SHAFT_HEIGHT * 0.5, 0), _floor_mat, 1))
	var wall_t := 0.25
	add_child(_box(Vector3(wall_t, SHAFT_HEIGHT, inner + wall_t * 2), Vector3(-SHAFT_RADIUS - wall_t * 0.5, SHAFT_HEIGHT * 0.5, 0), _wall_mat, 1))
	add_child(_box(Vector3(wall_t, SHAFT_HEIGHT, inner + wall_t * 2), Vector3(SHAFT_RADIUS + wall_t * 0.5, SHAFT_HEIGHT * 0.5, 0), _wall_mat, 1))
	add_child(_box(Vector3(inner + wall_t * 2, SHAFT_HEIGHT, wall_t), Vector3(0, SHAFT_HEIGHT * 0.5, -SHAFT_RADIUS - wall_t * 0.5), _wall_mat, 1))
	add_child(_box(Vector3(inner + wall_t * 2, SHAFT_HEIGHT, wall_t), Vector3(0, SHAFT_HEIGHT * 0.5, SHAFT_RADIUS + wall_t * 0.5), _wall_mat, 1))

	var ladder := MeshInstance3D.new()
	var rail := BoxMesh.new()
	rail.size = Vector3(0.08, SHAFT_HEIGHT - 2.0, 0.08)
	ladder.mesh = rail
	ladder.position = Vector3(SHAFT_RADIUS - 0.5, SHAFT_HEIGHT * 0.5, 0.6)
	add_child(ladder)


func _build_surface_cap() -> void:
	var cap := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = SHAFT_RADIUS + 1.5
	mesh.bottom_radius = SHAFT_RADIUS + 1.0
	mesh.height = 0.4
	cap.mesh = mesh
	cap.position = Vector3(0, SHAFT_HEIGHT, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	cap.set_surface_override_material(0, mat)
	add_child(cap)


func _add_escape_zone() -> void:
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/interactables/escape_zone.gd"))
	zone.name = "OutsideEscapeZone"
	zone.collision_layer = 0
	zone.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SHAFT_RADIUS * 2.0, 3.0, SHAFT_RADIUS * 2.0)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(0, SHAFT_HEIGHT - 1.0, 0)
	add_child(zone)


func _box(size: Vector3, pos: Vector3, mat: Material, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	if layer != 0:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
	return body
