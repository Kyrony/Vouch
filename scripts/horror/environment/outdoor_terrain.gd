extends RefCounted
class_name OutdoorTerrain
## L1b farm-country heightfield: open rolling hills, streets + pads flattened.
## Hills are gaussian bumps (gentle walkable slopes, not cliff boxes).

const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

## Vertex counts (cells = n - 1). HeightMapShape3D uses 1 unit per cell; we scale XZ.
const MAP_WIDTH: int = 97
const MAP_DEPTH: int = 81
const CELL: float = 1.5
const TERRAIN_SPAN_X: float = (MAP_WIDTH - 1) * CELL
const TERRAIN_SPAN_Z: float = (MAP_DEPTH - 1) * CELL

## Small hub flatten only — fields stay rolling (L1b contours).
const FLAT_RADIUS: float = 7.0
const FLAT_BLEND: float = 5.0

## Farm hills sit in the fields and behind parcels. sigma keeps max slope walkable.
const HILLS: Array[Dictionary] = [
	{"id": "shed_nw", "pos": Vector2(-50.0, -40.0), "height": 4.4, "sigma": 14.0},
	{"id": "west_pasture", "pos": Vector2(-56.0, 12.0), "height": 2.8, "sigma": 12.0},
	{"id": "sw_field", "pos": Vector2(-40.0, 38.0), "height": 3.3, "sigma": 13.0},
	{"id": "north_ridge", "pos": Vector2(10.0, -48.0), "height": 3.5, "sigma": 13.0},
	{"id": "ne_behind_pm", "pos": Vector2(54.0, -36.0), "height": 3.9, "sigma": 14.0},
	{"id": "se_pasture", "pos": Vector2(46.0, 40.0), "height": 2.9, "sigma": 12.0},
	{"id": "east_rise", "pos": Vector2(64.0, 8.0), "height": 2.3, "sigma": 10.0},
]

const GRASS_COLOR := Color(0.30, 0.46, 0.22)
const DIRT_COLOR := Color(0.46, 0.33, 0.20)
const HILL_GRASS := Color(0.36, 0.40, 0.22)
const FIELD_COLOR := Color(0.42, 0.38, 0.22)


static func build(parent: Node3D) -> Dictionary:
	var root := StaticBody3D.new()
	root.name = "Terrain"
	root.collision_layer = 1
	root.collision_mask = 0
	root.set_meta("hill_count", HILLS.size())
	root.set_meta("span_x", TERRAIN_SPAN_X)
	root.set_meta("span_z", TERRAIN_SPAN_Z)
	parent.add_child(root)

	var heights: PackedFloat32Array = _build_heights()
	_add_mesh(root, heights)
	_add_collision(root, heights)

	var hills := Node3D.new()
	hills.name = "Hills"
	hills.set_meta("hill_count", HILLS.size())
	parent.add_child(hills)
	for spec in HILLS:
		var p: Vector2 = spec["pos"]
		var marker := Marker3D.new()
		marker.name = "Hill_%s" % spec["id"]
		marker.position = Vector3(p.x, float(spec["height"]), p.y)
		marker.set_meta("hill_id", spec["id"])
		hills.add_child(marker)

	return {
		"root": root,
		"hills": hills,
		"hill_count": HILLS.size(),
		"span_x": TERRAIN_SPAN_X,
		"span_z": TERRAIN_SPAN_Z,
	}


static func height_at(x: float, z: float) -> float:
	var raw: float = _hill_sum(x, z)
	var radial := Vector2(x, z).length()
	var basin: float = _smoothstep(FLAT_RADIUS, FLAT_RADIUS + FLAT_BLEND, radial)
	var flatten: float = maxf(_road_weight(x, z), _pad_weight(x, z))
	return raw * basin * (1.0 - flatten)


static func _build_heights() -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(MAP_WIDTH * MAP_DEPTH)
	var hx: float = float(MAP_WIDTH - 1) * 0.5
	var hz: float = float(MAP_DEPTH - 1) * 0.5
	for j in MAP_DEPTH:
		for i in MAP_WIDTH:
			var x: float = (float(i) - hx) * CELL
			var z: float = (float(j) - hz) * CELL
			data[j * MAP_WIDTH + i] = height_at(x, z)
	return data


static func _hill_sum(x: float, z: float) -> float:
	var h := 0.0
	for spec in HILLS:
		var p: Vector2 = spec["pos"]
		var dx: float = x - p.x
		var dz: float = z - p.y
		var sigma: float = float(spec["sigma"])
		var r2: float = dx * dx + dz * dz
		h += float(spec["height"]) * exp(-r2 / (2.0 * sigma * sigma))
	return h


static func _road_weight(x: float, z: float) -> float:
	var w := 0.0
	w = maxf(w, _disk_weight(Vector2(x, z), Vector2.ZERO, _V05.BULB_RADIUS + 1.6, 1.4))
	w = maxf(w, _disk_weight(Vector2(x, z), _V05.SHED_LOOP, _V05.SHED_LOOP_RADIUS + 0.4, 1.4))
	for spec in _V05.ROAD_SPANS:
		var a: Vector2 = spec["a"]
		var b: Vector2 = spec["b"]
		var r: float = float(spec["r"])
		w = maxf(w, _capsule_weight(Vector2(x, z), a, b, r, 1.5))
	return clampf(w, 0.0, 1.0)


static func _pad_weight(x: float, z: float) -> float:
	var w := 0.0
	for spec in _V05.BUILDING_PADS:
		var p: Vector2 = spec["pos"]
		w = maxf(w, _disk_weight(Vector2(x, z), p, float(spec["r"]), 3.0))
	for spawn_id in _V05.SPAWN_IDS:
		var pin: Vector3 = _V05.call("l2_world_pos", spawn_id)
		w = maxf(w, _disk_weight(Vector2(x, z), Vector2(pin.x, pin.z), 3.5, 2.0))
	return clampf(w, 0.0, 1.0)


static func _disk_weight(p: Vector2, center: Vector2, radius: float, feather: float) -> float:
	var d: float = p.distance_to(center)
	if d <= radius:
		return 1.0
	if d >= radius + feather:
		return 0.0
	return 1.0 - (d - radius) / feather


static func _capsule_weight(p: Vector2, a: Vector2, b: Vector2, radius: float, feather: float) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var t: float = 0.0 if len2 < 0.0001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	var d: float = p.distance_to(a + ab * t)
	if d <= radius:
		return 1.0
	if d >= radius + feather:
		return 0.0
	return 1.0 - (d - radius) / feather


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if edge1 <= edge0:
		return 1.0 if x >= edge1 else 0.0
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _add_mesh(root: StaticBody3D, heights: PackedFloat32Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	st.set_material(mat)

	var hx: float = float(MAP_WIDTH - 1) * 0.5
	var hz: float = float(MAP_DEPTH - 1) * 0.5
	for j in MAP_DEPTH - 1:
		for i in MAP_WIDTH - 1:
			var v00 := _vert(i, j, hx, hz, heights)
			var v10 := _vert(i + 1, j, hx, hz, heights)
			var v01 := _vert(i, j + 1, hx, hz, heights)
			var v11 := _vert(i + 1, j + 1, hx, hz, heights)
			_add_tri(st, v00, v10, v11)
			_add_tri(st, v00, v11, v01)

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = st.commit()
	root.add_child(mi)


static func _vert(i: int, j: int, hx: float, hz: float, heights: PackedFloat32Array) -> Dictionary:
	var x: float = (float(i) - hx) * CELL
	var z: float = (float(j) - hz) * CELL
	var y: float = heights[j * MAP_WIDTH + i]
	var slope: float = 0.0
	if i > 0 and i < MAP_WIDTH - 1 and j > 0 and j < MAP_DEPTH - 1:
		var dx: float = heights[j * MAP_WIDTH + i + 1] - heights[j * MAP_WIDTH + i - 1]
		var dz: float = heights[(j + 1) * MAP_WIDTH + i] - heights[(j - 1) * MAP_WIDTH + i]
		slope = sqrt(dx * dx + dz * dz) / (2.0 * CELL)
	var field_w: float = 0.0
	if absf(x + 38.0) < 10.0 and z > 16.0 and z < 36.0:
		field_w = 0.55
	if absf(x - 20.0) < 9.0 and z > 18.0 and z < 34.0:
		field_w = 0.45
	var dirt_w: float = clampf(y / 2.4 + slope * 3.2, 0.0, 1.0)
	var col: Color = GRASS_COLOR.lerp(HILL_GRASS, clampf(y / 3.0, 0.0, 1.0))
	col = col.lerp(FIELD_COLOR, field_w)
	col = col.lerp(DIRT_COLOR, dirt_w)
	return {
		"pos": Vector3(x, y, z),
		"uv": Vector2(float(i) / float(MAP_WIDTH - 1), float(j) / float(MAP_DEPTH - 1)) * 8.0,
		"color": col,
	}


static func _add_tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for v in [a, b, c]:
		st.set_color(v["color"])
		st.set_uv(v["uv"])
		st.add_vertex(v["pos"])


static func _add_collision(root: StaticBody3D, heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = MAP_WIDTH
	shape.map_depth = MAP_DEPTH
	shape.map_data = heights
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.scale = Vector3(CELL, 1.0, CELL)
	root.add_child(col)
