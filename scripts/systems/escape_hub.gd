extends Node3D
class_name EscapeHub
## EscapeHub
##
## Central underground shaft where every room's concrete escape tunnel converges.
## A walkable stairwell rises to the shared mountain clearing on the surface.

const WALL_T: float = 0.25
const _TUNNEL: GDScript = preload("res://scripts/rooms/tunnel_kit.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _depth: float = WorldScale.UNDERGROUND_DEPTH


func build(room_count: int) -> void:
	_depth = WorldScale.UNDERGROUND_DEPTH
	_wall_mat = _TUNNEL.call("wall_material")
	_floor_mat = _TUNNEL.call("floor_material")

	_build_vertical_shaft()
	_build_stairwell()
	_build_surface_hatch()
	_add_escape_zone()
	_add_shaft_lights(room_count)


func _build_vertical_shaft() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var inner := radius * 2.0
	var shaft_h := _depth
	var center_y := -_depth * 0.5

	add_child(_GEOM.call("box", Vector3(inner, WALL_T, inner), Vector3(0, -_depth - WALL_T * 0.5, 0), _floor_mat, 1))
	add_child(_GEOM.call("box", Vector3(inner, WALL_T, inner + WALL_T * 2), Vector3(0, WALL_T * 0.5, 0), _floor_mat, 1))

	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, inner + WALL_T * 2), Vector3(-radius - WALL_T * 0.5, center_y, 0), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, inner + WALL_T * 2), Vector3(radius + WALL_T * 0.5, center_y, 0), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(inner + WALL_T * 2, shaft_h, WALL_T), Vector3(0, center_y, -radius - WALL_T * 0.5), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(inner + WALL_T * 2, shaft_h, WALL_T), Vector3(0, center_y, radius + WALL_T * 0.5), _wall_mat, 1))


func _build_stairwell() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var steps := int(_depth / WorldScale.STAIR_RISER)
	var riser := _depth / float(steps)
	var tread := WorldScale.STAIR_TREAD
	var start_x := radius - 0.55
	var start_z := 0.35

	for i in range(steps):
		var y := -_depth + riser * (i + 0.5)
		var z := start_z + tread * i
		add_child(_GEOM.call("box",
			Vector3(tread * 0.95, riser * 0.92, tread * 0.85),
			Vector3(start_x, y, z),
			_floor_mat,
			1
		))


func _build_surface_hatch() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var frame := MeshInstance3D.new()
	frame.name = "SurfaceHatch"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 2.4, 0.18, radius * 2.4)
	frame.mesh = mesh
	frame.position = Vector3(0, 0.09, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.34, 0.32)
	mat.metallic = 0.15
	mat.roughness = 0.75
	frame.set_surface_override_material(0, mat)
	add_child(frame)

	var lip := MeshInstance3D.new()
	var lip_mesh := CylinderMesh.new()
	lip_mesh.top_radius = radius + 0.35
	lip_mesh.bottom_radius = radius + 0.2
	lip_mesh.height = 0.25
	lip.mesh = lip_mesh
	lip.position = Vector3(0, -0.05, 0)
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.4, 0.38, 0.35)
	lip.set_surface_override_material(0, lip_mat)
	add_child(lip)


func _add_escape_zone() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/interactables/escape_zone.gd"))
	zone.name = "OutsideEscapeZone"
	zone.collision_layer = 0
	zone.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(radius * 3.0, 3.0, radius * 3.0)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(0, 1.2, 0)
	add_child(zone)


func _add_shaft_lights(room_count: int) -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var spacing := _depth / maxf(3.0, float(room_count) + 1.0)
	for i in range(maxi(3, room_count)):
		var y := -_depth + spacing * (i + 0.5)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.62)
		light.light_energy = 0.45
		light.omni_range = 6.5
		light.position = Vector3(-radius + 0.35, y, 0)
		add_child(light)
