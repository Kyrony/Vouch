extends Node3D
class_name EscapeHub
## EscapeHub
##
## Central underground shaft where every room's concrete escape tunnel converges.
## A walkable stairwell rises inside the shaft, then a surface ramp leads onto
## the shared Outside clearing (World/Outside).

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
	_build_surface_exit()
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
	# North wall — lower half only; upper opening for surface exit ramp (+Z).
	add_child(_GEOM.call("box", Vector3(inner + WALL_T * 2, shaft_h * 0.55, WALL_T), Vector3(0, center_y - shaft_h * 0.22, -radius - WALL_T * 0.5), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, WALL_T), Vector3(-radius - WALL_T * 0.5, center_y, radius + WALL_T * 0.5), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, WALL_T), Vector3(radius + WALL_T * 0.5, center_y, radius + WALL_T * 0.5), _wall_mat, 1))


func _build_stairwell() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var steps := int(_depth / WorldScale.STAIR_RISER)
	var riser := _depth / float(steps)
	var inner_radius := radius - 0.65
	var angle_step := TAU / maxf(8.0, float(steps) / 8.0)

	# Entry ramp from tunnel floor into the rising spiral.
	for i in range(4):
		var y := riser * 0.35 * (i + 0.5)
		var angle := -PI * 0.5 + angle_step * float(i) * 0.35
		var x := cos(angle) * inner_radius
		var z := sin(angle) * inner_radius
		add_child(_GEOM.call("box",
			Vector3(0.55, riser * 0.55, 0.42),
			Vector3(x, -_depth + y, z),
			_floor_mat,
			1
		))

	for i in range(steps):
		var angle := -PI * 0.5 + angle_step * float(i)
		var y := -_depth + riser * (i + 0.5)
		var x := cos(angle) * inner_radius
		var z := sin(angle) * inner_radius
		add_child(_GEOM.call("box",
			Vector3(0.52, riser * 0.92, 0.38),
			Vector3(x, y, z),
			_floor_mat,
			1
		))


func _build_surface_exit() -> void:
	# Walkable ramp from shaft lip onto the Outside clearing pad (+Z).
	var ramp_len := 7.5
	var segments := 8
	var seg_len := ramp_len / float(segments)
	var start_z := WorldScale.HUB_SHAFT_RADIUS + 0.15
	for i in range(segments):
		var z := start_z + seg_len * (float(i) + 0.5)
		var y := 0.05 + 0.08 * float(i)
		var ramp: Node = _GEOM.call("box",
			Vector3(2.2, WorldScale.WALL_THICK, seg_len * 1.05),
			Vector3(0, y, z),
			_floor_mat,
			1
		)
		ramp.rotation.x = -0.06
		add_child(ramp)

	# Side rails so players don't fall off the ramp.
	var rail_mat := _wall_mat
	add_child(_GEOM.call("box", Vector3(0.12, 0.9, ramp_len), Vector3(-1.15, 0.55, start_z + ramp_len * 0.5), rail_mat, 1))
	add_child(_GEOM.call("box", Vector3(0.12, 0.9, ramp_len), Vector3(1.15, 0.55, start_z + ramp_len * 0.5), rail_mat, 1))


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
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/interactables/escape_zone.gd"))
	zone.name = "OutsideEscapeZone"
	# Layer 1 (world) so CharacterBody3D collision_mask=1 detects the overlap.
	zone.collision_layer = 1
	zone.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.6, 4.0)
	shape.shape = box
	zone.add_child(shape)
	# End of surface ramp on the Outside clearing.
	zone.position = Vector3(0, 1.0, WorldScale.HUB_SHAFT_RADIUS + 5.5)
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
