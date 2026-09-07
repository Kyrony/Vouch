extends Node3D
class_name EscapeHub
## Shared escape collector + lit ramp — exits at world origin on Outside.tscn ground.
## Built on every peer under Match (direct child, not MultiplayerSpawner-replicated).

const WALL_T: float = 0.25
const COLLECTOR_SIZE: float = 36.0
const COLLECTOR_CENTER: Vector3 = Vector3.ZERO
const COLLECTOR_FLOOR_Y: float = -10.6
const COLLECTOR_FILL_H: float = 3.6
const CORRIDOR_WIDTH: float = 4.0
const CORRIDOR_WALL_H: float = 3.0
const CORRIDOR_START_Z: float = 8.0
const CORRIDOR_END_Z: float = 0.0
const CLEARING_FLOOR_Y: float = 0.0

const _TUNNEL: GDScript = preload("res://scripts/rooms/tunnel_kit.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D


func build(room_count: int) -> void:
	_clear_children()
	_wall_mat = _TUNNEL.call("wall_material")
	_floor_mat = _TUNNEL.call("floor_material")

	_build_collector_landing()
	_build_enclosed_corridor()
	_build_surface_clearing()
	_add_escape_zone()
	_add_corridor_lights(room_count)


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


func _build_collector_landing() -> void:
	var fill_center_y := COLLECTOR_FLOOR_Y - COLLECTOR_FILL_H * 0.5 + 0.18
	var plate: StaticBody3D = _GEOM.call(
		"box",
		Vector3(COLLECTOR_SIZE, COLLECTOR_FILL_H, COLLECTOR_SIZE),
		Vector3(COLLECTOR_CENTER.x, fill_center_y, COLLECTOR_CENTER.z),
		_floor_mat,
		1
	)
	plate.name = "HubCollector"
	plate.add_to_group("escape_hub_ramp")
	plate.add_to_group("escape_path_node")
	add_child(plate)

	var half := COLLECTOR_SIZE * 0.5
	var rail_h := 1.1
	var rail_y := COLLECTOR_FLOOR_Y + rail_h * 0.5
	add_child(_GEOM.call("box", Vector3(COLLECTOR_SIZE + 0.4, rail_h, WALL_T), Vector3(0, rail_y, -half), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(COLLECTOR_SIZE + 0.4, rail_h, WALL_T), Vector3(0, rail_y, half), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, rail_h, COLLECTOR_SIZE), Vector3(-half, rail_y, 0), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, rail_h, COLLECTOR_SIZE), Vector3(half, rail_y, 0), _wall_mat, 1))

	var entry: Marker3D = Marker3D.new()
	entry.name = "HubCollectorEntry"
	entry.position = Vector3(0, COLLECTOR_FLOOR_Y + 0.2, CORRIDOR_START_Z - 0.4)
	entry.add_to_group("escape_path_node")
	add_child(entry)

	for i in range(8):
		var z := 3.0 + float(i) * 0.85
		var bridge: StaticBody3D = _GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH, 0.26, 0.85),
			Vector3(0, COLLECTOR_FLOOR_Y, z),
			_floor_mat,
			1
		)
		bridge.name = "HubApproachBridge_%d" % i
		bridge.add_to_group("escape_hub_ramp")
		add_child(bridge)


func _build_enclosed_corridor() -> void:
	var segments := 36
	var ramp_len := CORRIDOR_START_Z - CORRIDOR_END_Z
	var seg_len := ramp_len / float(segments)
	var rise_total := CLEARING_FLOOR_Y - COLLECTOR_FLOOR_Y
	var rise_per := rise_total / float(segments)
	var half_w := CORRIDOR_WIDTH * 0.5

	for i in range(segments):
		var y := COLLECTOR_FLOOR_Y + rise_per * (float(i) + 0.5)
		var z := CORRIDOR_START_Z - seg_len * (float(i) + 0.5)

		var floor: StaticBody3D = _GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH, 0.28, seg_len * 1.1),
			Vector3(0, y, z),
			_floor_mat,
			1
		)
		floor.name = "HubCorridorFloor_%02d" % i
		floor.add_to_group("escape_hub_ramp")
		floor.add_to_group("escape_path_node")
		add_child(floor)

		add_child(_GEOM.call(
			"box",
			Vector3(WALL_T, CORRIDOR_WALL_H, seg_len * 1.1),
			Vector3(-half_w - WALL_T * 0.5, y + CORRIDOR_WALL_H * 0.5, z),
			_wall_mat,
			1
		))
		add_child(_GEOM.call(
			"box",
			Vector3(WALL_T, CORRIDOR_WALL_H, seg_len * 1.1),
			Vector3(half_w + WALL_T * 0.5, y + CORRIDOR_WALL_H * 0.5, z),
			_wall_mat,
			1
		))
		add_child(_GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH + WALL_T * 2.0, WALL_T, seg_len * 1.1),
			Vector3(0, y + CORRIDOR_WALL_H, z),
			_wall_mat,
			0
		))


func _build_surface_clearing() -> void:
	var pad: StaticBody3D = _GEOM.call(
		"box",
		Vector3(10.0, 0.24, 10.0),
		Vector3(0, CLEARING_FLOOR_Y, 0),
		_floor_mat,
		1
	)
	pad.name = "OutsideClearingPad"
	pad.add_to_group("escape_hub_ramp")
	pad.add_to_group("escape_path_node")
	add_child(pad)


func _add_escape_zone() -> void:
	var zone := Area3D.new()
	zone.set_script(preload("res://scripts/interactables/escape_zone.gd"))
	zone.name = "OutsideEscapeZone"
	zone.collision_layer = 1
	zone.collision_mask = 4
	zone.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.5, 6.0)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(0, 1.5, 0)
	zone.add_to_group("escape_hub_zone")
	zone.add_to_group("escape_path_node")
	add_child(zone)


func _add_corridor_lights(room_count: int) -> void:
	var spacing := 3.5
	var z := CORRIDOR_START_Z
	while z >= CORRIDOR_END_Z - 0.5:
		var t := 1.0 - (z - CORRIDOR_END_Z) / (CORRIDOR_START_Z - CORRIDOR_END_Z)
		var y := lerpf(COLLECTOR_FLOOR_Y + 1.0, CLEARING_FLOOR_Y + 2.5, t)
		var light := OmniLight3D.new()
		light.name = "CorridorLight_%.0f" % z
		light.light_color = Color(1.0, 0.92, 0.72)
		light.light_energy = 1.5
		light.omni_range = 14.0
		light.position = Vector3(0, y, z)
		add_child(light)
		z -= spacing

	var collector_light := OmniLight3D.new()
	collector_light.name = "CollectorFillLight"
	collector_light.light_color = Color(1.0, 0.9, 0.75)
	collector_light.light_energy = 1.8
	collector_light.omni_range = 26.0
	collector_light.position = Vector3(0, COLLECTOR_FLOOR_Y + 2.5, 0)
	add_child(collector_light)

	var exit_light := OmniLight3D.new()
	exit_light.name = "SurfaceExitLight"
	exit_light.light_color = Color(0.95, 0.98, 1.0)
	exit_light.light_energy = 2.0
	exit_light.omni_range = 28.0
	exit_light.position = Vector3(0, 4.0, 0)
	add_child(exit_light)

	for i in range(maxi(4, room_count)):
		var angle := TAU * float(i) / float(maxi(4, room_count))
		var lx := cos(angle) * 10.0
		var lz := sin(angle) * 10.0
		var rim := OmniLight3D.new()
		rim.name = "CollectorRimLight_%d" % i
		rim.light_energy = 1.0
		rim.omni_range = 12.0
		rim.position = Vector3(lx, COLLECTOR_FLOOR_Y + 2.0, lz)
		add_child(rim)


func log_live_debug() -> void:
	print("LIVE_ESCAPE hub_path=%s peer=%d server=%s" % [
		get_path(),
		multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0,
		str(multiplayer.is_server()) if multiplayer.multiplayer_peer != null else "offline",
	])
	for n: Node in find_children("*", "StaticBody3D", false, false):
		if not n.is_in_group("escape_hub_ramp"):
			continue
		var body := n as StaticBody3D
		var aabb := _global_collision_aabb(body)
		print("LIVE_ESCAPE floor %s aabb=%s" % [body.name, aabb])
	var zone := get_node_or_null("OutsideEscapeZone")
	if zone is Node3D:
		var zaabb := _global_collision_aabb(zone as Node3D)
		print("LIVE_ESCAPE zone path=%s pos=%s layer=%d mask=%d aabb=%s" % [
			zone.get_path(),
			(zone as Node3D).global_transform.origin,
			int(zone.collision_layer),
			int(zone.collision_mask),
			zaabb,
		])
	else:
		print("LIVE_ESCAPE zone=MISSING")


static func _global_collision_aabb(node: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	for ch in node.get_children():
		if ch is CollisionShape3D:
			var col := ch as CollisionShape3D
			if col.shape == null:
				continue
			var gt: Transform3D = node.global_transform * col.transform
			var local_aabb: AABB = col.shape.get_aabb()
			var world_aabb: AABB = gt * local_aabb
			if first:
				merged = world_aabb
				first = false
			else:
				merged = merged.merge(world_aabb)
	if first:
		return AABB(node.global_position, Vector3(0.01, 0.01, 0.01))
	return merged
