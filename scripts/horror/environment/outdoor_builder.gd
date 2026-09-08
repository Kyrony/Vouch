extends RefCounted
class_name OutdoorBuilder
## L1b farm yard: heightfield + lane network + Host Match pads. No prop kits.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _TERRAIN: GDScript = preload("res://scripts/horror/environment/outdoor_terrain.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const ROAD_Y: float = 0.02
const ROAD_THICK: float = 0.10
const CURB_H: float = 0.16


static func build(parent: Node3D, mats) -> Dictionary:
	var root := Node3D.new()
	root.name = "Outdoor"
	parent.add_child(root)

	var terrain_result: Dictionary = _TERRAIN.call("build", root)
	_build_roads(root, mats)
	_build_field_footprint(root, mats)

	var player_spawns: Array[Marker3D] = _build_player_spawns(root)
	var pm_spawn: Marker3D = _add_spawn_marker(
		root,
		_grounded(_V05.OUTDOOR_PM_SPAWN),
		"Outdoor_PM_Street",
		-PI / 2.0,
	)

	var zone := _build_soft_escape(_grounded(_V05.SOFT_ESCAPE_POS))
	root.add_child(zone)

	var fill := OmniLight3D.new()
	fill.name = "OutdoorFill"
	fill.position = Vector3(0, 16, 6)
	fill.light_color = Color(0.72, 0.78, 0.88)
	fill.light_energy = 0.58
	fill.omni_range = 90
	root.add_child(fill)

	return {
		"root": root,
		"escape_zone": zone,
		"outdoor_markers": [],
		"player_spawns": player_spawns,
		"pm_spawn": pm_spawn,
		"terrain": terrain_result.get("root"),
	}


static func _grounded(pos: Vector3) -> Vector3:
	var y: float = float(_TERRAIN.call("height_at", pos.x, pos.z))
	return Vector3(pos.x, maxf(y, 0.0) + 0.12, pos.z)


static func _build_player_spawns(root: Node3D) -> Array[Marker3D]:
	var folder := Node3D.new()
	folder.name = "PlayerSpawns"
	root.add_child(folder)
	var out: Array[Marker3D] = []
	var yaws: Array[float] = [0.45, -PI / 2.0, PI, PI]
	var letters: Array[String] = ["A", "B", "C", "D"]
	for i in _V05.OUTDOOR_FAMILY_SPAWNS.size():
		var pos: Vector3 = _grounded(_V05.OUTDOOR_FAMILY_SPAWNS[i])
		out.append(_add_spawn_marker(folder, pos, "Outdoor_Family_%s" % letters[i], yaws[i]))
	return out


static func _add_spawn_marker(parent: Node3D, pos: Vector3, marker_name: String, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	m.rotation.y = yaw
	m.add_to_group("outdoor_player_spawns")
	parent.add_child(m)
	return m


static func _build_roads(root: Node3D, mats) -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)

	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 1.2, ROAD_THICK, Vector3(0, ROAD_Y, 0), mats.asphalt))
	roads.add_child(_GEOM.call("cylinder", 1.6, 0.16, Vector3(0, ROAD_Y + 0.04, 0), mats.grass))
	## East loop interior pad (QA plate oval).
	roads.add_child(_GEOM.call("box", Vector3(12.0, ROAD_THICK, 8.0), Vector3(40.0, ROAD_Y, 10.0), mats.asphalt))

	for spec in _V05.ROAD_SPANS:
		_add_road_span(roads, spec["a"], spec["b"], float(spec["r"]) * 2.0, mats)

	_add_curbs(roads, mats)
	_add_road_paint(roads)


static func _add_road_span(roads: Node3D, a: Vector2, b: Vector2, width: float, mats) -> void:
	var mid := (a + b) * 0.5
	var delta: Vector2 = b - a
	var length: float = delta.length()
	if length < 0.2:
		return
	var body: StaticBody3D = _GEOM.call(
		"box",
		Vector3(width, ROAD_THICK, length + 0.15),
		Vector3(mid.x, ROAD_Y, mid.y),
		mats.asphalt,
	)
	body.rotation.y = atan2(delta.x, delta.y)
	roads.add_child(body)
	var curb_off: float = width * 0.5 + 0.12
	var nx: float = -delta.y / length
	var nz: float = delta.x / length
	for side in [-1.0, 1.0]:
		var curb: StaticBody3D = _GEOM.call(
			"box",
			Vector3(0.22, CURB_H, length + 0.1),
			Vector3(mid.x + nx * curb_off * side, ROAD_Y + 0.08, mid.y + nz * curb_off * side),
			mats.curb,
			0,
		)
		curb.rotation.y = atan2(delta.x, delta.y)
		roads.add_child(curb)


static func _add_curbs(roads: Node3D, mats) -> void:
	roads.add_child(_GEOM.call("cylinder", _V05.BULB_RADIUS + 1.45, CURB_H, Vector3(0, ROAD_Y + 0.04, 0), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(12.0, CURB_H, 0.26), Vector3(40.0, ROAD_Y + 0.08, 14.15), mats.curb, 0))
	roads.add_child(_GEOM.call("box", Vector3(12.0, CURB_H, 0.26), Vector3(40.0, ROAD_Y + 0.08, 5.85), mats.curb, 0))


static func _add_road_paint(roads: Node3D) -> void:
	var paint := _mat(Color(0.82, 0.72, 0.28))
	for i in 11:
		var x: float = -22.0 + float(i) * 5.0
		roads.add_child(_GEOM.call("box", Vector3(1.4, 0.03, 0.16), Vector3(x, ROAD_Y + 0.08, 0), paint, 0))
	for i in 9:
		var z: float = -20.0 + float(i) * 5.0
		roads.add_child(_GEOM.call("box", Vector3(0.16, 0.03, 1.4), Vector3(0, ROAD_Y + 0.08, z), paint, 0))


static func _build_field_footprint(root: Node3D, mats) -> void:
	## L1b agricultural rectangles — map footprint, not prop kits.
	var fields := Node3D.new()
	fields.name = "Fields"
	root.add_child(fields)
	fields.add_child(_GEOM.call("box", Vector3(18.0, 0.04, 14.0), Vector3(-38.0, 0.03, 24.0), mats.dirt, 0))
	fields.add_child(_GEOM.call("box", Vector3(16.0, 0.04, 12.0), Vector3(20.0, 0.03, 26.0), mats.dirt, 0))


static func _build_soft_escape(pos: Vector3) -> Area3D:
	var zone := Area3D.new()
	zone.name = "HorrorEscapeZone"
	zone.position = pos
	zone.collision_layer = 0
	zone.collision_mask = 4
	zone.set_meta("soft_gated", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3.2, 6)
	shape.shape = box
	zone.add_child(shape)
	zone.set_script(load("res://scripts/interactables/escape_zone.gd"))
	return zone


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m
