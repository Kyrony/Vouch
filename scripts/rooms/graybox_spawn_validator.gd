extends RefCounted
class_name GrayboxSpawnValidator
## Headless checks: PlayerSpawn at room geometric center, inside floor AABB globally.

const CENTER_EPS: float = 0.02
const FLOOR_MARGIN: float = 0.2
const PLAYER_MARKER_EPS: float = 0.08


static func validate(room: Node3D) -> Array[String]:
	return validate_local(room)


static func validate_local(room: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if room == null:
		return ["room is null"]

	var spawn := room.get_node_or_null("PlayerSpawn") as Marker3D
	if spawn == null:
		return ["PlayerSpawn marker missing"]

	var p := spawn.position
	if absf(p.x) > CENTER_EPS or absf(p.z) > CENTER_EPS:
		errors.append("PlayerSpawn not at room center (pos=%s expected xz≈0)" % p)
	if absf(p.y - _feet_y()) > CENTER_EPS:
		errors.append("PlayerSpawn y=%.3f expected feet y=%.3f" % [p.y, _feet_y()])

	var bounds := _interior_aabb(room)
	if bounds.size.length_squared() < 0.01:
		return errors + ["could not derive interior AABB"]

	if not bounds.has_point(p):
		errors.append("PlayerSpawn %s outside interior AABB %s" % [p, bounds])
	return errors


static func validate_global(room: Node3D, player: Node3D = null) -> Array[String]:
	var errors: Array[String] = validate_local(room)
	if room == null:
		return errors

	var spawn := room.get_node_or_null("PlayerSpawn") as Marker3D
	if spawn == null:
		return errors

	var floor_aabb := _floor_top_aabb_global(room)
	if floor_aabb.size.length_squared() < 0.01:
		errors.append("Floor collision AABB missing under Geometry/Floor")
	else:
		var gp := spawn.global_position
		var inset := Vector3(FLOOR_MARGIN, 0.0, FLOOR_MARGIN)
		var usable := floor_aabb
		usable.position += inset
		usable.size -= inset * 2.0
		if usable.size.x < 0.1 or usable.size.z < 0.1:
			errors.append("Floor AABB too small after margin")
		elif not usable.has_point(Vector3(gp.x, floor_aabb.position.y, gp.z)):
			errors.append(
				"PlayerSpawn global xz=(%.2f, %.2f) outside floor top AABB pos=%s size=%s"
				% [gp.x, gp.z, floor_aabb.position, floor_aabb.size]
			)

	if player != null and is_instance_valid(player):
		var delta := player.global_position.distance_to(spawn.global_position)
		if delta > PLAYER_MARKER_EPS:
			errors.append(
				"player global pos %s != PlayerSpawn global %s (delta=%.3fm)"
				% [player.global_position, spawn.global_position, delta]
			)
	return errors


static func _feet_y() -> float:
	return 0.0


static func _interior_aabb(room: Node3D) -> AABB:
	var w: float = float(room.get("width")) if room.get("width") else 6.0
	var d: float = float(room.get("depth")) if room.get("depth") else 6.0
	var h: float = WorldScale.CEILING_H
	if room.get("_layout") is Dictionary:
		h = room._layout.get("height", h)
	var inset := WorldScale.WALL_THICK + 0.05
	return AABB(
		Vector3(-w * 0.5 + inset, 0.0, -d * 0.5 + inset),
		Vector3(w - inset * 2.0, h, d - inset * 2.0)
	)


static func _floor_top_aabb_global(room: Node3D) -> AABB:
	var floor := room.get_node_or_null("Geometry/Floor") as StaticBody3D
	if floor == null:
		return AABB()
	var col := floor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or not col.shape is BoxShape3D:
		return AABB()
	var box: BoxShape3D = col.shape as BoxShape3D
	var gt := floor.global_transform * col.transform
	var half := box.size * 0.5
	var out := AABB(gt * Vector3(-half.x, -half.y, -half.z), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out = out.expand(gt * Vector3(sx * half.x, sy * half.y, sz * half.z))
	return out
