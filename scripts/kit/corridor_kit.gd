extends RefCounted
class_name CorridorKit
## Shared corridor segments from apartment CorridorOut socket to central hub.

const WALL_THICK: float = 0.12
const HUB_SHAFT_RADIUS: float = 1.45
const HUB_SHAFT_HEIGHT: float = 10.0
const HUB_HALL_WIDTH: float = 1.25
const HUB_HALL_HEIGHT: float = 2.5


static func build_escape_path(parent: Node3D, corridor_out_local: Vector3, room_index: int, theme: Dictionary, escape_kind: int) -> void:
	var wall_mat := _wall_mat(theme["wall_color"])
	var floor_mat := _wall_mat(theme["floor_color"])
	var grid_pos := Match.room_grid_position(room_index)
	var dist := Vector2(grid_pos.x, grid_pos.z).length()
	var pod_depth: float = 6.0
	if parent.get("depth") != null:
		pod_depth = float(parent.get("depth"))
	var horiz := clampf(dist - HUB_SHAFT_RADIUS - float(pod_depth) * 0.5, 18.0, 46.0)
	var start_z := corridor_out_local.z + WALL_THICK
	_build_run(parent, start_z, horiz, HUB_HALL_WIDTH, HUB_HALL_HEIGHT, wall_mat, floor_mat, true, true)
	_build_vertical(parent, start_z + horiz, HUB_SHAFT_HEIGHT, HUB_HALL_WIDTH, HUB_HALL_HEIGHT, wall_mat, floor_mat)
	_add_sconces(parent, start_z, horiz, HUB_HALL_WIDTH, theme.get("light_color", Color(0.9, 0.85, 0.7)))


static func _build_run(parent: Node3D, start_z: float, length: float, inner_w: float, inner_h: float, wall_mat: Material, floor_mat: Material, open_near: bool, open_far: bool) -> void:
	if length < 0.5:
		return
	var cz := start_z + length * 0.5
	parent.add_child(_box(Vector3(inner_w, WALL_THICK, length), Vector3(0, -WALL_THICK * 0.5, cz), floor_mat))
	parent.add_child(_box(Vector3(inner_w + WALL_THICK * 2.0, WALL_THICK, length + WALL_THICK * 2.0), Vector3(0, inner_h + WALL_THICK * 0.5, cz), wall_mat, false))
	parent.add_child(_box(Vector3(WALL_THICK, inner_h, length), Vector3(-inner_w / 2.0 - WALL_THICK / 2.0, inner_h / 2.0, cz), wall_mat))
	parent.add_child(_box(Vector3(WALL_THICK, inner_h, length), Vector3(inner_w / 2.0 + WALL_THICK / 2.0, inner_h / 2.0, cz), wall_mat))
	if not open_near:
		parent.add_child(_box(Vector3(inner_w, inner_h, WALL_THICK), Vector3(0, inner_h / 2.0, start_z - WALL_THICK / 2.0), wall_mat))
	if not open_far:
		parent.add_child(_box(Vector3(inner_w, inner_h, WALL_THICK), Vector3(0, inner_h / 2.0, start_z + length + WALL_THICK * 0.5), wall_mat))


static func _build_vertical(parent: Node3D, base_z: float, rise_h: float, inner_w: float, inner_h: float, wall_mat: Material, floor_mat: Material) -> void:
	var cz := base_z
	parent.add_child(_box(Vector3(inner_w, WALL_THICK, inner_w), Vector3(0, -WALL_THICK * 0.5, cz), floor_mat))
	parent.add_child(_box(Vector3(inner_w + WALL_THICK * 2.0, WALL_THICK, inner_w + WALL_THICK * 2.0), Vector3(0, rise_h + WALL_THICK * 0.5, cz), wall_mat, false))
	parent.add_child(_box(Vector3(WALL_THICK, rise_h, inner_w), Vector3(-inner_w / 2.0 - WALL_THICK / 2.0, rise_h / 2.0, cz), wall_mat))
	parent.add_child(_box(Vector3(WALL_THICK, rise_h, inner_w), Vector3(inner_w / 2.0 + WALL_THICK / 2.0, rise_h / 2.0, cz), wall_mat))
	parent.add_child(_box(Vector3(inner_w, rise_h, WALL_THICK), Vector3(0, rise_h / 2.0, cz - inner_w / 2.0 - WALL_THICK / 2.0), wall_mat))
	parent.add_child(_box(Vector3(inner_w, rise_h, WALL_THICK), Vector3(0, rise_h / 2.0, cz + inner_w / 2.0 + WALL_THICK / 2.0), wall_mat))


static func _add_sconces(parent: Node3D, start_z: float, length: float, inner_w: float, light_color: Color) -> void:
	var spacing := 6.0
	var count := maxi(int(length / spacing), 1)
	for i in range(count):
		var z := start_z + spacing * (i + 0.5)
		if z > start_z + length - 1.0:
			break
		for side in [-1.0, 1.0]:
			var sconce := Node3D.new()
			sconce.name = "Sconce"
			sconce.position = Vector3(side * (inner_w * 0.5 + 0.05), HUB_HALL_HEIGHT * 0.65, z)
			var light := OmniLight3D.new()
			light.light_color = light_color
			light.light_energy = 0.55
			light.omni_range = 4.0
			sconce.add_child(light)
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.15, 0.12)
			mesh.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = light_color
			mat.emission_enabled = true
			mat.emission = light_color
			mat.emission_energy_multiplier = 0.8
			mesh.set_surface_override_material(0, mat)
			sconce.add_child(mesh)
			parent.add_child(sconce)


static func _wall_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	return m


static func _box(size: Vector3, pos: Vector3, mat: Material, collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if collision else 0
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	if collision:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
	return body
