extends Node3D
class_name EscapeHub
## Central collector + enclosed lit ramp corridor to the Outside clearing.
## Built once per match under Match (world origin).

const WALL_T: float = 0.25
const COLLECTOR_SIZE: float = 32.0
const COLLECTOR_CENTER_Z: float = 10.0
const COLLECTOR_FLOOR_Y: float = -10.6
const COLLECTOR_FILL_H: float = 3.6
const CORRIDOR_WIDTH: float = 3.6
const CORRIDOR_WALL_H: float = 3.0
const CORRIDOR_START_Z: float = 7.5
const CORRIDOR_END_Z: float = 18.0
const CLEARING_FLOOR_Y: float = 0.12

const _TUNNEL: GDScript = preload("res://scripts/rooms/tunnel_kit.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D


func build(room_count: int) -> void:
	_wall_mat = _TUNNEL.call("wall_material")
	_floor_mat = _TUNNEL.call("floor_material")

	_build_collector_landing()
	_build_enclosed_corridor()
	_build_clearing_pad()
	_add_escape_zone()
	_add_corridor_lights(room_count)
	_log_built_nodes()


func _build_collector_landing() -> void:
	# Thick walkable fill catches every tunnel mouth height (~y -12..-9 in world space).
	var fill_center_y := COLLECTOR_FLOOR_Y - COLLECTOR_FILL_H * 0.5 + 0.18
	var plate: StaticBody3D = _GEOM.call(
		"box",
		Vector3(COLLECTOR_SIZE, COLLECTOR_FILL_H, COLLECTOR_SIZE),
		Vector3(0, fill_center_y, COLLECTOR_CENTER_Z),
		_floor_mat,
		1
	)
	plate.name = "HubCollector"
	plate.add_to_group("escape_hub_ramp")
	plate.add_to_group("escape_path_node")
	add_child(plate)

	# Low perimeter rails so players cannot walk off into the shaft void.
	var half := COLLECTOR_SIZE * 0.5
	var rail_h := 1.1
	var rail_y := COLLECTOR_FLOOR_Y + rail_h * 0.5
	var cz := COLLECTOR_CENTER_Z
	add_child(_GEOM.call("box", Vector3(COLLECTOR_SIZE + 0.4, rail_h, WALL_T), Vector3(0, rail_y, cz - half), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(COLLECTOR_SIZE + 0.4, rail_h, WALL_T), Vector3(0, rail_y, cz + half), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, rail_h, COLLECTOR_SIZE), Vector3(-half, rail_y, cz), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, rail_h, COLLECTOR_SIZE), Vector3(half, rail_y, cz), _wall_mat, 1))

	var entry: Marker3D = Marker3D.new()
	entry.name = "HubCollectorEntry"
	entry.position = Vector3(0, COLLECTOR_FLOOR_Y + 0.2, CORRIDOR_START_Z - 0.5)
	entry.add_to_group("escape_path_node")
	add_child(entry)

	# Flat bridge from typical tunnel mouths (z≈8) into the ascent corridor.
	for i in range(5):
		var z := 5.5 + float(i) * 1.05
		var bridge: StaticBody3D = _GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH, 0.24, 1.05),
			Vector3(0, COLLECTOR_FLOOR_Y, z),
			_floor_mat,
			1
		)
		bridge.name = "HubApproachBridge_%d" % i
		bridge.add_to_group("escape_hub_ramp")
		add_child(bridge)


func _build_enclosed_corridor() -> void:
	var segments := 32
	var ramp_len := CORRIDOR_END_Z - CORRIDOR_START_Z
	var seg_len := ramp_len / float(segments)
	var rise_total := CLEARING_FLOOR_Y - COLLECTOR_FLOOR_Y
	var rise_per := rise_total / float(segments)
	var half_w := CORRIDOR_WIDTH * 0.5

	for i in range(segments):
		var y := COLLECTOR_FLOOR_Y + rise_per * (float(i) + 0.5)
		var z := CORRIDOR_START_Z + seg_len * (float(i) + 0.5)

		var floor: StaticBody3D = _GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH, 0.26, seg_len * 1.08),
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
			Vector3(WALL_T, CORRIDOR_WALL_H, seg_len * 1.08),
			Vector3(-half_w - WALL_T * 0.5, y + CORRIDOR_WALL_H * 0.5, z),
			_wall_mat,
			1
		))
		add_child(_GEOM.call(
			"box",
			Vector3(WALL_T, CORRIDOR_WALL_H, seg_len * 1.08),
			Vector3(half_w + WALL_T * 0.5, y + CORRIDOR_WALL_H * 0.5, z),
			_wall_mat,
			1
		))
		add_child(_GEOM.call(
			"box",
			Vector3(CORRIDOR_WIDTH + WALL_T * 2.0, WALL_T, seg_len * 1.08),
			Vector3(0, y + CORRIDOR_WALL_H, z),
			_wall_mat,
			0
		))


func _build_clearing_pad() -> void:
	for i in range(6):
		var t := float(i) / 5.0
		var z := CORRIDOR_END_Z - 1.2 + t * 2.8
		var y := lerpf(-2.9, CLEARING_FLOOR_Y, t)
		var step: StaticBody3D = _GEOM.call(
			"box",
			Vector3(5.0, 0.24, 0.95),
			Vector3(0, y, z),
			_floor_mat,
			1
		)
		step.name = "OutsideClearingStep_%d" % i
		step.add_to_group("escape_hub_ramp")
		step.add_to_group("escape_path_node")
		add_child(step)

	var pad: StaticBody3D = _GEOM.call(
		"box",
		Vector3(5.0, 0.22, 3.0),
		Vector3(0, CLEARING_FLOOR_Y, CORRIDOR_END_Z + 2.4),
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
	box.size = Vector3(5.0, 3.5, 5.0)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(0, 1.4, CORRIDOR_END_Z + 2.4)
	zone.add_to_group("escape_hub_zone")
	zone.add_to_group("escape_path_node")
	add_child(zone)


func _add_corridor_lights(room_count: int) -> void:
	var spacing := 4.0
	var z := CORRIDOR_START_Z
	while z <= CORRIDOR_END_Z + 1.0:
		var t := (z - CORRIDOR_START_Z) / (CORRIDOR_END_Z - CORRIDOR_START_Z)
		var y := lerpf(COLLECTOR_FLOOR_Y + 1.0, CLEARING_FLOOR_Y + 2.2, t)
		var light := OmniLight3D.new()
		light.name = "CorridorLight_%.0f" % z
		light.light_color = Color(1.0, 0.92, 0.72)
		light.light_energy = 1.35
		light.omni_range = 12.0
		light.position = Vector3(0, y, z)
		add_child(light)
		z += spacing

	# Collector fill + surface exit (OpenGL readability).
	var collector_light := OmniLight3D.new()
	collector_light.name = "CollectorFillLight"
	collector_light.light_color = Color(1.0, 0.9, 0.75)
	collector_light.light_energy = 1.5
	collector_light.omni_range = 22.0
	collector_light.position = Vector3(0, COLLECTOR_FLOOR_Y + 2.5, COLLECTOR_CENTER_Z)
	add_child(collector_light)

	var exit_light := OmniLight3D.new()
	exit_light.name = "SurfaceExitLight"
	exit_light.light_color = Color(0.95, 0.98, 1.0)
	exit_light.light_energy = 1.6
	exit_light.omni_range = 24.0
	exit_light.position = Vector3(0, 3.5, CORRIDOR_END_Z + 1.5)
	add_child(exit_light)

	var extra := maxi(0, room_count - 2)
	for i in range(extra):
		var angle := TAU * float(i) / float(maxi(extra, 1))
		var lx := cos(angle) * 8.0
		var lz := COLLECTOR_CENTER_Z + sin(angle) * 8.0
		var rim := OmniLight3D.new()
		rim.name = "CollectorRimLight_%d" % i
		rim.light_energy = 0.9
		rim.omni_range = 10.0
		rim.position = Vector3(lx, COLLECTOR_FLOOR_Y + 2.0, lz)
		add_child(rim)


func _log_built_nodes() -> void:
	for c in get_children():
		if c.is_in_group("escape_path_node"):
			print("ESCAPE_PATH build %s local_pos=%s" % [c.name, (c as Node3D).position])
