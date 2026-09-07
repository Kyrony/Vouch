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
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	if floor:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, -hy + 0.1, 0), mats.floor))
	if ceiling:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, hy - 0.1, 0), mats.ceiling))
	parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, 0.25), center + Vector3(0, 0, -hz), mats.wall))
	parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, 0.25), center + Vector3(0, 0, hz), mats.wall))
	parent.add_child(_GEOM.call("box", Vector3(0.25, size.y, size.z), center + Vector3(-hx, 0, 0), mats.wall))
	parent.add_child(_GEOM.call("box", Vector3(0.25, size.y, size.z), center + Vector3(hx, 0, 0), mats.wall))


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
