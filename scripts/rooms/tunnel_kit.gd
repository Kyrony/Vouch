extends RefCounted
class_name TunnelKit
## Procedural bunker concrete tunnels — horizontal runs + hub connectors with sconce lighting.

const WALL_T: float = WorldScale.WALL_THICK
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func wall_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.41, 0.39)
	mat.roughness = 0.92
	return mat


static func floor_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.27, 0.26)
	mat.roughness = 0.88
	return mat


static func ceiling_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.35, 0.33)
	mat.roughness = 0.9
	return mat


static func build_horizontal(
	parent: Node3D,
	start_z: float,
	length: float,
	inner_w: float,
	inner_h: float,
	open_near: bool,
	open_far: bool
) -> void:
	if length < 0.5:
		return
	var wall_mat := wall_material()
	var floor_mat := floor_material()
	var ceil_mat := ceiling_material()
	var cz := start_z + length * 0.5

	parent.add_child(_GEOM.call("box", Vector3(inner_w, WALL_T, length), Vector3(0, -WALL_T * 0.5, cz), floor_mat))
	parent.add_child(_GEOM.call("box", Vector3(inner_w + WALL_T * 2.0, WALL_T, length + WALL_T * 2.0), Vector3(0, inner_h + WALL_T * 0.5, cz), ceil_mat, 0))
	parent.add_child(_GEOM.call("box", Vector3(WALL_T, inner_h, length), Vector3(-inner_w / 2.0 - WALL_T / 2.0, inner_h / 2.0, cz), wall_mat))
	parent.add_child(_GEOM.call("box", Vector3(WALL_T, inner_h, length), Vector3(inner_w / 2.0 + WALL_T / 2.0, inner_h / 2.0, cz), wall_mat))
	if not open_near:
		parent.add_child(_GEOM.call("box", Vector3(inner_w, inner_h, WALL_T), Vector3(0, inner_h / 2.0, start_z - WALL_T / 2.0), wall_mat))
	if not open_far:
		parent.add_child(_GEOM.call("box", Vector3(inner_w, inner_h, WALL_T), Vector3(0, inner_h / 2.0, start_z + length + WALL_T * 0.5), wall_mat))

	_add_run_lights(parent, start_z, length, inner_w, inner_h)


static func build_hub_connector(
	parent: Node3D,
	local_z: float,
	inner_w: float,
	inner_h: float
) -> void:
	var wall_mat := wall_material()
	var floor_mat := floor_material()
	var ceil_mat := ceiling_material()
	var depth := inner_w * 0.85
	var cz := local_z + depth * 0.5

	parent.add_child(_GEOM.call("box", Vector3(inner_w, WALL_T, depth), Vector3(0, -WALL_T * 0.5, cz), floor_mat))
	parent.add_child(_GEOM.call("box", Vector3(inner_w + WALL_T * 2.0, WALL_T, depth + WALL_T), Vector3(0, inner_h + WALL_T * 0.5, cz), ceil_mat, 0))
	parent.add_child(_GEOM.call("box", Vector3(WALL_T, inner_h, depth), Vector3(-inner_w / 2.0 - WALL_T / 2.0, inner_h / 2.0, cz), wall_mat))
	parent.add_child(_GEOM.call("box", Vector3(WALL_T, inner_h, depth), Vector3(inner_w / 2.0 + WALL_T / 2.0, inner_h / 2.0, cz), wall_mat))
	_add_sconce(parent, Vector3(-inner_w * 0.35, inner_h - 0.35, cz), inner_h)


static func _add_run_lights(parent: Node3D, start_z: float, length: float, inner_w: float, inner_h: float) -> void:
	var spacing: float = WorldScale.TUNNEL_LIGHT_SPACING
	var count := maxi(1, int(length / spacing))
	for i in range(count):
		var t := (i + 0.5) / float(count)
		var z := start_z + length * t
		_add_sconce(parent, Vector3(-inner_w * 0.38, inner_h - 0.35, z), inner_h)


static func _add_sconce(parent: Node3D, pos: Vector3, _inner_h: float) -> void:
	var root := Node3D.new()
	root.name = "TunnelLight"
	root.position = pos

	var fixture := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.08, 0.06)
	fixture.mesh = box
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.52, 0.48)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.85, 0.55)
	fm.emission_energy_multiplier = 0.35
	fixture.set_surface_override_material(0, fm)
	root.add_child(fixture)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.88, 0.65)
	light.light_energy = 0.55
	light.omni_range = 7.0
	light.position = Vector3(0.08, 0, 0)
	root.add_child(light)

	parent.add_child(root)

