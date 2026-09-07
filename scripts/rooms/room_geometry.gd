extends RefCounted
class_name RoomGeometry
## Builds sealed solid geometry for one fixed room layout.

const WALL: float = 0.12
const DOOR_W: float = 0.85
const DOOR_H: float = 2.05
const HEIGHT: float = 2.6


static func build(parent: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	if parent.get_node_or_null("Geometry"):
		return
	var root := Node3D.new()
	root.name = "Geometry"
	parent.add_child(root)

	var w: float = layout["width"]
	var d: float = layout["depth"]
	var h: float = layout["height"]
	var hw := w * 0.5
	var hd := d * 0.5

	var floor_mat := _mat(theme["floor_color"], 0.85)
	var wall_mat := _mat(theme["wall_color"], 0.88)
	var trim_mat := _mat(theme["accent_color"], 0.7)
	var ceil_mat := _mat(theme["wall_color"].lerp(Color.WHITE, 0.1), 0.95)

	root.add_child(_box(Vector3(w, WALL, d), Vector3(0, -WALL * 0.5, 0), floor_mat))
	root.add_child(_box(Vector3(w, WALL, d), Vector3(0, h + WALL * 0.5, 0), ceil_mat, false))

	_wall_x(root, hd, w, DOOR_W, 0.0, wall_mat, h)
	_wall_x(root, -hd, w, 0.0, 0.0, wall_mat, h)
	_wall_z(root, hw, d, 0.0, 0.0, wall_mat, h)
	_wall_z(root, -hw, d, 0.0, 0.0, wall_mat, h)

	for part in layout.get("partitions", []):
		root.add_child(_box(part["size"], part["pos"], wall_mat))

	for prop in layout.get("props", []):
		root.add_child(_box(prop["size"], prop["pos"], trim_mat, false))

	_add_trim(root, w, d, trim_mat)
	_add_ceiling_light(root, layout, theme)

	if layout.get("loft", false):
		var loft_y := h * 0.55
		root.add_child(_box(Vector3(w * 0.55, WALL, d * 0.35), Vector3(-w * 0.12, loft_y, -d * 0.28), floor_mat))

	if layout.has("stairs"):
		_build_stairs(root, layout["stairs"], floor_mat, wall_mat)


static func _wall_x(parent: Node3D, z: float, span: float, gap_w: float, gap_center: float, mat: Material, h: float) -> void:
	_add_wall_segment(parent, true, z, span, gap_w, gap_center, mat, h)


static func _wall_z(parent: Node3D, x: float, span: float, gap_w: float, gap_center: float, mat: Material, h: float) -> void:
	_add_wall_segment(parent, false, x, span, gap_w, gap_center, mat, h)


static func _add_wall_segment(parent: Node3D, is_x: bool, fixed: float, span: float, gap_w: float, gap_center: float, mat: Material, h: float) -> void:
	if gap_w <= 0.01:
		var size := Vector3(span, h, WALL) if is_x else Vector3(WALL, h, span)
		var pos := Vector3(0, h * 0.5, fixed) if is_x else Vector3(fixed, h * 0.5, 0)
		parent.add_child(_box(size, pos, mat))
		return
	var half := span * 0.5
	var seg1 := (gap_center - gap_w * 0.5) - (-half)
	var seg2 := half - (gap_center + gap_w * 0.5)
	if seg1 > 0.05:
		var c1 := -half + seg1 * 0.5
		var s1 := Vector3(seg1, h, WALL) if is_x else Vector3(WALL, h, seg1)
		var p1 := Vector3(c1, h * 0.5, fixed) if is_x else Vector3(fixed, h * 0.5, c1)
		parent.add_child(_box(s1, p1, mat))
	if seg2 > 0.05:
		var c2 := gap_center + gap_w * 0.5 + seg2 * 0.5
		var s2 := Vector3(seg2, h, WALL) if is_x else Vector3(WALL, h, seg2)
		var p2 := Vector3(c2, h * 0.5, fixed) if is_x else Vector3(fixed, h * 0.5, c2)
		parent.add_child(_box(s2, p2, mat))
	if gap_w > 0.05:
		var lintel_h := h - DOOR_H
		var ls := Vector3(gap_w, lintel_h, WALL) if is_x else Vector3(WALL, lintel_h, gap_w)
		var lp := Vector3(gap_center, DOOR_H + lintel_h * 0.5, fixed) if is_x else Vector3(fixed, DOOR_H + lintel_h * 0.5, gap_center)
		parent.add_child(_box(ls, lp, mat))
		_add_door_frame(parent, is_x, fixed, gap_center, mat)


static func _add_door_frame(parent: Node3D, is_x: bool, fixed: float, center: float, mat: Material) -> void:
	var ft := 0.06
	var frame_mat := _mat(Color(0.3, 0.28, 0.26), 0.75)
	var side := Vector3(ft, DOOR_H, WALL + 0.02) if is_x else Vector3(WALL + 0.02, DOOR_H, ft)
	var lp := Vector3(center - DOOR_W * 0.5 - ft * 0.5, DOOR_H * 0.5, fixed) if is_x else Vector3(fixed, DOOR_H * 0.5, center - DOOR_W * 0.5 - ft * 0.5)
	var rp := Vector3(center + DOOR_W * 0.5 + ft * 0.5, DOOR_H * 0.5, fixed) if is_x else Vector3(fixed, DOOR_H * 0.5, center + DOOR_W * 0.5 + ft * 0.5)
	parent.add_child(_box(side, lp, frame_mat, false))
	parent.add_child(_box(side, rp, frame_mat, false))


static func _add_trim(parent: Node3D, w: float, d: float, mat: Material) -> void:
	var th := 0.08
	var td := 0.04
	var hw := w * 0.5
	var hd := d * 0.5
	parent.add_child(_box(Vector3(w, th, td), Vector3(0, th * 0.5, hd - td * 0.5), mat, false))
	parent.add_child(_box(Vector3(w, th, td), Vector3(0, th * 0.5, -hd + td * 0.5), mat, false))
	parent.add_child(_box(Vector3(td, th, d), Vector3(hw - td * 0.5, th * 0.5, 0), mat, false))
	parent.add_child(_box(Vector3(td, th, d), Vector3(-hw + td * 0.5, th * 0.5, 0), mat, false))


static func _add_ceiling_light(parent: Node3D, layout: Dictionary, theme: Dictionary) -> void:
	var light_root := Node3D.new()
	light_root.name = "RoomCeilingLight"
	light_root.position = Vector3(0, layout["height"] - 0.2, 0)
	var omni := OmniLight3D.new()
	omni.light_color = theme["light_color"]
	omni.light_energy = 1.5
	omni.omni_range = maxf(layout["width"], layout["depth"]) + 2.0
	omni.shadow_enabled = true
	light_root.add_child(omni)
	var bulb := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.11
	sp.height = 0.22
	bulb.mesh = sp
	var bm := StandardMaterial3D.new()
	bm.emission_enabled = true
	bm.emission = theme["light_color"]
	bm.emission_energy_multiplier = 1.4
	bulb.set_surface_override_material(0, bm)
	light_root.add_child(bulb)
	parent.add_child(light_root)


static func _build_stairs(parent: Node3D, spec: Dictionary, floor_mat: Material, wall_mat: Material) -> void:
	var pos: Vector3 = spec["pos"]
	var size: Vector2 = spec["size"]
	var steps := 6
	var rise := HEIGHT / float(steps)
	var tread := size.y / float(steps)
	for i in range(steps):
		parent.add_child(_box(
			Vector3(size.x, rise, tread),
			Vector3(pos.x, i * rise + rise * 0.5, pos.z + tread * (i + 0.5)),
			floor_mat
		))
	parent.add_child(_box(Vector3(WALL, HEIGHT, size.y), Vector3(pos.x - size.x * 0.5 - WALL * 0.5, HEIGHT * 0.5, pos.z + size.y * 0.5), wall_mat))


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


static func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m
