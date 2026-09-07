extends RefCounted
class_name GrayboxSpawnValidator
## Headless check: PlayerSpawn must sit inside the authored room interior AABB.


static func validate(room: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if room == null:
		return ["room is null"]

	var spawn := room.get_node_or_null("PlayerSpawn") as Marker3D
	if spawn == null:
		return ["PlayerSpawn marker missing"]

	var bounds := _interior_aabb(room)
	if bounds.size.length_squared() < 0.01:
		return ["could not derive interior AABB from Geometry"]

	var p := spawn.position
	var margin := 0.25
	if p.x < bounds.position.x + margin or p.x > bounds.position.x + bounds.size.x - margin:
		errors.append("PlayerSpawn x=%.2f outside interior [%.2f, %.2f]" % [
			p.x, bounds.position.x + margin, bounds.position.x + bounds.size.x - margin
		])
	if p.z < bounds.position.z + margin or p.z > bounds.position.z + bounds.size.z - margin:
		errors.append("PlayerSpawn z=%.2f outside interior [%.2f, %.2f]" % [
			p.z, bounds.position.z + margin, bounds.position.z + bounds.size.z - margin
		])
	if p.y < -0.05 or p.y > bounds.size.y + 0.5:
		errors.append("PlayerSpawn y=%.2f outside vertical range" % p.y)

	return errors


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
