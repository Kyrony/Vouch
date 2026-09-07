extends Node3D
class_name EscapeHub
## Central shaft + straight walkable ramp to the Outside clearing.
## Built once per match under Match (world origin).

const WALL_T: float = 0.25
const _TUNNEL: GDScript = preload("res://scripts/rooms/tunnel_kit.gd")
const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _depth: float = WorldScale.UNDERGROUND_DEPTH


func build(room_count: int) -> void:
	_depth = WorldScale.UNDERGROUND_DEPTH
	_wall_mat = _TUNNEL.call("wall_material")
	_floor_mat = _TUNNEL.call("floor_material")

	_build_shaft_shell()
	_build_entry_platform()
	_build_straight_ramp()
	_build_surface_walkway()
	_add_escape_zone()
	_add_shaft_lights(room_count)


func _build_shaft_shell() -> void:
	var radius := WorldScale.HUB_SHAFT_RADIUS
	var inner := radius * 2.0
	var shaft_h := _depth
	var center_y := -_depth * 0.5

	# Pit floor
	add_child(_GEOM.call("box", Vector3(inner + 1.0, WALL_T, inner + 1.0), Vector3(0, -_depth - WALL_T, 0), _floor_mat, 1))
	# Side walls only (open toward +Z for ramp exit).
	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, inner + 1.0), Vector3(-radius - WALL_T, center_y, 0), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(WALL_T, shaft_h, inner + 1.0), Vector3(radius + WALL_T, center_y, 0), _wall_mat, 1))
	add_child(_GEOM.call("box", Vector3(inner + 1.0, shaft_h, WALL_T), Vector3(0, center_y, -radius - WALL_T), _wall_mat, 1))


func _build_entry_platform() -> void:
	# Wide landing where room tunnels meet the shaft (y ≈ tunnel rise).
	var radius := WorldScale.HUB_SHAFT_RADIUS
	add_child(_GEOM.call("box",
		Vector3(radius * 2.2, 0.2, radius * 1.6),
		Vector3(0, -_depth + 0.5, 0),
		_floor_mat,
		1
	))


func _build_straight_ramp() -> void:
	# One continuous ramp: pit → surface along +Z (easy to walk, hard to miss).
	var segments := 28
	var ramp_len := 10.0
	var seg_len := ramp_len / float(segments)
	var rise_per := _depth / float(segments)
	var start_z := -0.4
	for i in range(segments):
		var y := -_depth + rise_per * (float(i) + 0.5)
		var z := start_z + seg_len * (float(i) + 0.5)
		var ramp: StaticBody3D = _GEOM.call("box",
			Vector3(2.6, 0.22, seg_len * 1.08),
			Vector3(0, y, z),
			_floor_mat,
			1
		)
		ramp.name = "HubRampStep_%02d" % i
		ramp.add_to_group("escape_hub_ramp")
		add_child(ramp)


func _build_surface_walkway() -> void:
	var mat := _floor_mat
	var z_start := 9.5
	for i in range(6):
		var z := z_start + float(i) * 1.1
		var pad: StaticBody3D = _GEOM.call("box", Vector3(3.0, 0.18, 1.0), Vector3(0, 0.08, z), mat, 1)
		pad.name = "SurfaceWalkway_%d" % i
		pad.add_to_group("escape_hub_ramp")
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
	box.size = Vector3(4.0, 3.0, 4.0)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(0, 1.2, 14.0)
	zone.add_to_group("escape_hub_zone")
	add_child(zone)


func _add_shaft_lights(room_count: int) -> void:
	var count := maxi(5, room_count + 2)
	for i in range(count):
		var t := float(i) / float(count - 1) if count > 1 else 0.5
		var y := lerpf(-_depth + 1.0, 2.0, t)
		var z := lerpf(-0.5, 13.0, t)
		var light := OmniLight3D.new()
		light.name = "HubLight_%d" % i
		light.light_color = Color(1.0, 0.9, 0.7)
		light.light_energy = 1.1
		light.omni_range = 14.0
		light.position = Vector3(0, y, z)
		add_child(light)

	# Bright fill at surface exit so OpenGL doesn't show a void.
	var exit_light := OmniLight3D.new()
	exit_light.name = "SurfaceExitLight"
	exit_light.light_color = Color(0.95, 0.98, 1.0)
	exit_light.light_energy = 1.4
	exit_light.omni_range = 20.0
	exit_light.position = Vector3(0, 3.0, 14.0)
	add_child(exit_light)
