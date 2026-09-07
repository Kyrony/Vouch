extends RefCounted
class_name EscapePathValidator
## Headless checks: continuous walkable floor from tunnel mouth → OutsideEscapeZone.

const SAMPLE_SPACING: float = 1.0
const MAX_FLOOR_STEP: float = 1.25


static func validate(match_root: Node3D) -> Array[String]:
	var errors: Array[String] = []

	var hub: Node3D = match_root.get_node_or_null("EscapeHub") as Node3D
	if hub == null:
		errors.append("EscapeHub missing")
		return errors

	var zone: Area3D = hub.get_node_or_null("OutsideEscapeZone") as Area3D
	if zone == null:
		errors.append("OutsideEscapeZone missing")
		return errors
	if int(zone.collision_layer) != 1:
		errors.append("OutsideEscapeZone collision_layer=%d expected 1" % int(zone.collision_layer))
	if (int(zone.collision_mask) & 4) == 0:
		errors.append("OutsideEscapeZone collision_mask=%d missing player layer 4" % int(zone.collision_mask))
	var player_mask := 1
	if (player_mask & int(zone.collision_layer)) == 0:
		errors.append("Player mask=%d cannot overlap zone layer %d" % [player_mask, int(zone.collision_layer)])

	var mouths: Array[Node3D] = _collect_tunnel_mouths(match_root)
	if mouths.is_empty():
		errors.append("No escape_tunnel_mouth markers under Match")
		return errors

	var floors: Array[StaticBody3D] = _collect_floor_bodies(match_root)
	if floors.is_empty():
		errors.append("No walkable floor StaticBody3D nodes on escape path")
		return errors

	var zone_pos: Vector3 = zone.global_transform.origin
	for mouth in mouths:
		var mouth_pos: Vector3 = mouth.global_transform.origin
		var floor_err := _validate_floor_samples(floors, mouth_pos, zone_pos, mouth.name)
		errors.append_array(floor_err)

	return errors


static func log_path_nodes(match_root: Node3D) -> void:
	print("ESCAPE_PATH trace (global transforms):")
	for n: Node in match_root.find_children("*", "", true, false):
		if n is Node3D and n.is_in_group("escape_path_node"):
			var node3d: Node3D = n as Node3D
			print("  %s pos=%s" % [node3d.name, node3d.global_transform.origin])
	for n: Node in match_root.find_children("*", "Marker3D", true, false):
		if n.is_in_group("escape_tunnel_mouth") and n is Node3D:
			var node3d: Node3D = n as Node3D
			print("  %s pos=%s" % [node3d.name, node3d.global_transform.origin])


static func _collect_tunnel_mouths(match_root: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in match_root.find_children("*", "Marker3D", true, false):
		if n.is_in_group("escape_tunnel_mouth") and n is Node3D:
			out.append(n as Node3D)
	return out


static func _collect_floor_bodies(match_root: Node3D) -> Array[StaticBody3D]:
	var roots: Array[Node] = [match_root]
	var parent := match_root.get_parent()
	if parent != null and parent.has_node("Outside"):
		roots.append(parent.get_node("Outside"))
	var out: Array[StaticBody3D] = []
	for root in roots:
		for n: Node in root.find_children("*", "StaticBody3D", true, false):
			if not n is StaticBody3D:
				continue
			if n.is_in_group("escape_hub_ramp") or n.is_in_group("escape_tunnel_floor") or n.is_in_group("escape_outside_floor"):
				out.append(n as StaticBody3D)
	return out


static func _validate_floor_samples(
	floors: Array[StaticBody3D],
	start: Vector3,
	end: Vector3,
	label: String
) -> Array[String]:
	var errors: Array[String] = []
	var delta: Vector3 = end - start
	var horiz_len: float = Vector2(delta.x, delta.z).length()
	var steps: int = maxi(1, int(ceil(horiz_len / SAMPLE_SPACING)))
	var prev_y: float = NAN

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var sample := start.lerp(end, t)
		var floor_y := _floor_top_y_at_xz(floors, Vector2(sample.x, sample.z))
		if is_nan(floor_y):
			errors.append("%s floor missing at step %d/%d xz=(%.1f, %.1f)" % [label, i, steps, sample.x, sample.z])
			continue
		if not is_nan(prev_y) and absf(floor_y - prev_y) > MAX_FLOOR_STEP:
			errors.append("%s floor step %.2fm too steep at step %d (%.2f → %.2f)" % [
				label, absf(floor_y - prev_y), i, prev_y, floor_y
			])
		prev_y = floor_y

	return errors


static func _floor_top_y_at_xz(floors: Array[StaticBody3D], xz: Vector2) -> float:
	var best_top := NAN
	for body in floors:
		for ch in body.get_children():
			if not ch is CollisionShape3D:
				continue
			var shape := (ch as CollisionShape3D).shape
			if shape == null:
				continue
			var top_y: float = _shape_top_y_at_xz(body, ch as CollisionShape3D, xz)
			if is_nan(top_y):
				continue
			if is_nan(best_top) or top_y > best_top:
				best_top = top_y
	return best_top


static func _shape_top_y_at_xz(body: StaticBody3D, col: CollisionShape3D, xz: Vector2) -> float:
	var gt := body.global_transform
	var local := gt.affine_inverse() * Vector3(xz.x, 0.0, xz.y)
	var shape := col.shape
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		var half := box.size * 0.5
		var shape_origin: Vector3 = col.transform.origin
		var min_x := shape_origin.x - half.x
		var max_x := shape_origin.x + half.x
		var min_z := shape_origin.z - half.z
		var max_z := shape_origin.z + half.z
		if local.x < min_x or local.x > max_x or local.z < min_z or local.z > max_z:
			return NAN
		var top_local: float = shape_origin.y + half.y
		return (gt * Vector3(0.0, top_local, 0.0)).y
	return NAN


static func spawn_rooms_like_live(match_node: Node, room_specs: Array) -> String:
	if not match_node.has_method("teardown_match_geometry"):
		return "node is not Match"
	if not match_node.is_node_ready():
		return "Match not ready — await ready before spawn"
	match_node.teardown_match_geometry()
	var spawner: MultiplayerSpawner = match_node.get_node("RoomsContainer/RoomsSpawner")
	for spec: Dictionary in room_specs:
		var room: Node = spawner.spawn(spec)
		if room == null:
			return "RoomsSpawner.spawn failed for room_index=%s" % str(spec.get("room_index", "?"))
	return ""
