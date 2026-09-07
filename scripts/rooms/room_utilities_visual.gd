extends RefCounted
class_name RoomUtilitiesVisual
## Visible pipe and gas line graybox runs along room walls/ceiling.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _NEON: GDScript = preload("res://scripts/rooms/neon_theme.gd")


static func build(parent: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	if parent.get_node_or_null("UtilityLines"):
		return
	var root := Node3D.new()
	root.name = "UtilityLines"
	parent.add_child(root)

	var w: float = layout["width"]
	var d: float = layout["depth"]
	var h: float = layout["height"]
	var hw := w * 0.5 - 0.2
	var hd := d * 0.5 - 0.2
	var neon: Color = _NEON.call("neon_for_theme", theme.get("id", "bedroom"))
	var pipe_mat := _pipe_mat(Color(0.42, 0.44, 0.46))
	var gas_mat := _pipe_mat(Color(0.9, 0.55, 0.15))
	var water_mat := _pipe_mat(Color(0.25, 0.45, 0.7))

	# Overhead water main along north wall
	root.add_child(_pipe(Vector3(w - 0.6, 0.08, 0.06), Vector3(0, h - 0.18, -hd + 0.08), water_mat))
	# Gas riser near east wall
	root.add_child(_pipe(Vector3(0.06, 0.06, h * 0.55), Vector3(hw - 0.12, h * 0.28, 0.8), gas_mat))
	# Floor drain line stub
	root.add_child(_pipe(Vector3(0.5, 0.05, 0.05), Vector3(-1.2, 0.04, 0.5), water_mat))
	# Accent valve glow ring
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 0.09
	torus.bottom_radius = 0.09
	torus.height = 0.03
	ring.mesh = torus
	ring.position = Vector3(-hw + 0.35, 1.0, hd - 0.15)
	ring.set_surface_override_material(0, _NEON.call("trim_material", neon))
	root.add_child(ring)


static func _pipe(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	return _GEOM.call("box", size, pos, mat, 0)


static func _pipe_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.65
	return mat
