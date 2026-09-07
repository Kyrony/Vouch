extends RefCounted
class_name RoomGeometry
## Builds sealed solid geometry for one fixed room layout.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _NEON: GDScript = preload("res://scripts/rooms/neon_theme.gd")

const WALL: float = WorldScale.WALL_THICK
const DOOR_W: float = WorldScale.DOOR_W
const DOOR_H: float = WorldScale.DOOR_H


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
	var trim_mat: Material = _NEON.call("trim_material", _NEON.call("neon_for_theme", theme.get("id", "bedroom")))
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

	if layout.get("loft", false):
		var loft_y := h * 0.55
		root.add_child(_box(Vector3(w * 0.55, WALL, d * 0.35), Vector3(-w * 0.12, loft_y, -d * 0.28), floor_mat))

	if layout.has("stairs"):
		_build_stairs(root, layout["stairs"], floor_mat, wall_mat, h)


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


static func _build_stairs(parent: Node3D, spec: Dictionary, floor_mat: Material, wall_mat: Material, room_h: float) -> void:
	var pos: Vector3 = spec["pos"]
	var width: float = spec["size"].x
	var riser := WorldScale.STAIR_RISER
	var tread := WorldScale.STAIR_TREAD
	var steps := maxi(1, int(round(room_h / riser)))
	for i in range(steps):
		var y := i * riser + riser * 0.5
		var z := pos.z + tread * (i + 0.5)
		parent.add_child(_box(
			Vector3(width, riser * 0.95, tread * 0.92),
			Vector3(pos.x, y, z),
			floor_mat
		))
	var run := tread * float(steps)
	parent.add_child(_box(Vector3(WALL, room_h, run), Vector3(pos.x - width * 0.5 - WALL * 0.5, room_h * 0.5, pos.z + run * 0.5), wall_mat))


static func _box(size: Vector3, pos: Vector3, mat: Material, collision: bool = true) -> StaticBody3D:
	return _GEOM.call("box", size, pos, mat, 1 if collision else 0)


static func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m
