extends RefCounted
class_name CollisionDebug
## Trustworthy collision AABB + shape logging for LIVE_ESCAPE / probes.


static func box_shape_size(col: CollisionShape3D) -> Vector3:
	if col.shape is BoxShape3D:
		return (col.shape as BoxShape3D).size
	return Vector3.ZERO


static func global_aabb(node: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	for ch in node.get_children():
		if not ch is CollisionShape3D:
			continue
		var col := ch as CollisionShape3D
		if col.shape == null:
			continue
		var piece := global_aabb_for_shape(node, col)
		if piece.size.length_squared() < 0.000001:
			continue
		if first:
			merged = piece
			first = false
		else:
			merged = merged.merge(piece)
	if first:
		return AABB(node.global_position, Vector3(0.01, 0.01, 0.01))
	return merged


static func global_aabb_for_shape(body: Node3D, col: CollisionShape3D) -> AABB:
	if col.shape is BoxShape3D:
		return _box_global_aabb(body.global_transform * col.transform, (col.shape as BoxShape3D).size)
	if col.shape != null:
		var local: AABB = col.shape.get_aabb()
		return _aabb_from_corners(body.global_transform * col.transform, local)
	return AABB()


static func _box_global_aabb(gt: Transform3D, size: Vector3) -> AABB:
	var half := size * 0.5
	var out := AABB(gt * Vector3(-half.x, -half.y, -half.z), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out = out.expand(gt * Vector3(sx * half.x, sy * half.y, sz * half.z))
	return out


static func _aabb_from_corners(_gt: Transform3D, local: AABB) -> AABB:
	var half := local.size * 0.5
	var center := local.position + half
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(_gt * (center + Vector3(sx * half.x, sy * half.y, sz * half.z)))
	var out := AABB(corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		out = out.expand(corners[i])
	return out


static func log_floor_body(body: Node3D, prefix: String = "LIVE_ESCAPE") -> void:
	var col: CollisionShape3D = _first_collision_shape(body)
	if col == null:
		print("%s floor %s body_pos=%s NO_COLLISION_SHAPE" % [prefix, body.name, body.global_position])
		return
	var shape_size := box_shape_size(col)
	var world := global_aabb(body)
	print("%s floor %s body_pos=%s shape_size=%s world_aabb_pos=%s world_aabb_size=%s" % [
		prefix,
		body.name,
		body.global_position,
		shape_size,
		world.position,
		world.size,
	])
	if shape_size.length_squared() < 0.0001:
		push_warning("%s floor %s has zero BoxShape3D.size" % [prefix, body.name])


static func validate_floor_collision_shapes(match_root: Node3D) -> Array[String]:
	const MIN_THICKNESS := 0.18
	var errors: Array[String] = []
	for body: StaticBody3D in _floor_bodies(match_root):
		var col := _first_collision_shape(body)
		if col == null:
			errors.append("%s missing CollisionShape3D" % body.name)
			continue
		if not col.shape is BoxShape3D:
			errors.append("%s collision is not BoxShape3D" % body.name)
			continue
		var size: Vector3 = (col.shape as BoxShape3D).size
		if size.x < MIN_THICKNESS or size.y < MIN_THICKNESS or size.z < MIN_THICKNESS:
			errors.append("%s BoxShape3D.size=%s below min %.2fm" % [body.name, size, MIN_THICKNESS])
	return errors


static func _floor_bodies(match_root: Node3D) -> Array[StaticBody3D]:
	var roots: Array[Node] = [match_root]
	var parent := match_root.get_parent()
	if parent != null and parent.has_node("Outside"):
		roots.append(parent.get_node("Outside"))
	var out: Array[StaticBody3D] = []
	for root in roots:
		for n: Node in root.find_children("*", "StaticBody3D", true, false):
			if n is StaticBody3D and (
				n.is_in_group("escape_hub_ramp")
				or n.is_in_group("escape_tunnel_floor")
				or n.is_in_group("escape_outside_floor")
			):
				out.append(n as StaticBody3D)
	return out


static func _first_collision_shape(body: Node3D) -> CollisionShape3D:
	for ch in body.get_children():
		if ch is CollisionShape3D:
			return ch as CollisionShape3D
	return null
