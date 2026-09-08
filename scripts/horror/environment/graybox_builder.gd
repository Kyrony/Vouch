extends RefCounted
class_name HorrorGrayboxBuilder
## Primitive room/wall helpers shared by environment builders.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func add_room_box(
	parent: Node3D,
	size: Vector3,
	center: Vector3,
	mats,
	floor: bool = true,
	ceiling: bool = true,
) -> void:
	add_room_box_open(parent, size, center, mats, floor, ceiling, {})


## `doors` keys: plus_z / minus_z / plus_x / minus_x = gap width (0 = sealed).
## Optional *_off shifts the gap along the wall. `height` is the door cut (m).
static func add_room_box_open(
	parent: Node3D,
	size: Vector3,
	center: Vector3,
	mats,
	floor: bool = true,
	ceiling: bool = true,
	doors: Dictionary = {},
) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var door_h: float = float(doors.get("height", 2.1))
	if floor:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, -hy + 0.1, 0), mats.floor))
	if ceiling:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, hy - 0.1, 0), mats.ceiling))
	_wall_or_door(
		parent, center + Vector3(0, 0, hz), size.x, size.y, 0.25, true, mats.wall,
		float(doors.get("plus_z", 0.0)), door_h, float(doors.get("plus_z_off", 0.0)),
	)
	_wall_or_door(
		parent, center + Vector3(0, 0, -hz), size.x, size.y, 0.25, true, mats.wall,
		float(doors.get("minus_z", 0.0)), door_h, float(doors.get("minus_z_off", 0.0)),
	)
	_wall_or_door(
		parent, center + Vector3(hx, 0, 0), size.z, size.y, 0.25, false, mats.wall,
		float(doors.get("plus_x", 0.0)), door_h, float(doors.get("plus_x_off", 0.0)),
	)
	_wall_or_door(
		parent, center + Vector3(-hx, 0, 0), size.z, size.y, 0.25, false, mats.wall,
		float(doors.get("minus_x", 0.0)), door_h, float(doors.get("minus_x_off", 0.0)),
	)


static func _wall_or_door(
	parent: Node3D,
	center: Vector3,
	length: float,
	height: float,
	thick: float,
	along_x: bool,
	mat: Material,
	gap_w: float,
	gap_h: float,
	gap_offset: float,
) -> void:
	if gap_w <= 0.05:
		if along_x:
			parent.add_child(_GEOM.call("box", Vector3(length, height, thick), center, mat))
		else:
			parent.add_child(_GEOM.call("box", Vector3(thick, height, length), center, mat))
		return
	add_opening_wall(parent, center, length, height, thick, along_x, mat, gap_w, gap_h, gap_offset)


static func add_opening_wall(
	parent: Node3D,
	center: Vector3,
	length: float,
	height: float,
	thick: float,
	along_x: bool,
	mat: Material,
	gap_w: float,
	gap_h: float,
	gap_offset: float = 0.0,
) -> void:
	var half := length * 0.5
	var gap_lo: float = gap_offset - gap_w * 0.5
	var gap_hi: float = gap_offset + gap_w * 0.5
	var left_len: float = gap_lo - (-half)
	var right_len: float = half - gap_hi
	var lintel_h: float = height - gap_h
	var lintel_y: float = -height * 0.5 + gap_h + lintel_h * 0.5
	if along_x:
		if left_len > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(left_len, height, thick),
				center + Vector3(-half + left_len * 0.5, 0, 0),
				mat,
			))
		if right_len > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(right_len, height, thick),
				center + Vector3(half - right_len * 0.5, 0, 0),
				mat,
			))
		if lintel_h > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(gap_w, lintel_h, thick),
				center + Vector3(gap_offset, lintel_y, 0),
				mat,
			))
	else:
		if left_len > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(thick, height, left_len),
				center + Vector3(0, 0, -half + left_len * 0.5),
				mat,
			))
		if right_len > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(thick, height, right_len),
				center + Vector3(0, 0, half - right_len * 0.5),
				mat,
			))
		if lintel_h > 0.12:
			parent.add_child(_GEOM.call(
				"box",
				Vector3(thick, lintel_h, gap_w),
				center + Vector3(0, lintel_y, gap_offset),
				mat,
			))


static func add_walkable_exit(parent: Node3D, local_pos: Vector3, exit_name: String = "WalkableExit") -> Marker3D:
	var m := Marker3D.new()
	m.name = exit_name
	m.position = local_pos
	m.add_to_group("walkable_exits")
	parent.add_child(m)
	return m


static func add_wall_panel(
	parent: Node3D,
	center: Vector3,
	size: Vector3,
	mat: StandardMaterial3D,
	doorway: bool = false,
	gap: float = 0.0,
) -> void:
	if not doorway or gap <= 0.0:
		parent.add_child(_GEOM.call("box", size, center, mat))
		return
	if size.x <= size.z:
		var half := (size.x - gap) * 0.5
		if half > 0.2:
			parent.add_child(_GEOM.call("box", Vector3(half, size.y, size.z), center + Vector3(-(gap * 0.5 + half * 0.5), 0, 0), mat))
			parent.add_child(_GEOM.call("box", Vector3(half, size.y, size.z), center + Vector3(gap * 0.5 + half * 0.5, 0, 0), mat))
	else:
		var half := (size.z - gap) * 0.5
		if half > 0.2:
			parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, half), center + Vector3(0, 0, -(gap * 0.5 + half * 0.5)), mat))
			parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, half), center + Vector3(0, 0, gap * 0.5 + half * 0.5), mat))


static func add_spawn_marker(parent: Node3D, local_pos: Vector3, name_suffix: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = "Spawn_%s" % name_suffix
	m.position = local_pos
	parent.add_child(m)
	return m


static func add_dead_body_stub(parent: Node3D, local_pos: Vector3, family_id: int) -> Node3D:
	var stub := Node3D.new()
	stub.name = "DeadBody_Family%d" % family_id
	stub.position = local_pos
	stub.add_to_group("possession_targets")
	stub.set_meta("family_id", family_id)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.45, 0.35, 0.32)
	var body: StaticBody3D = _GEOM.call("box", Vector3(0.6, 0.25, 1.6), Vector3(0, 0.12, 0), mesh_mat, 0)
	stub.add_child(body)
	parent.add_child(stub)
	return stub
