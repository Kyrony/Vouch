extends RefCounted
class_name NeighborhoodFromMasks
## Heightmap stays authored. Semantic masks dress roads, leftover pads, vegetation.
## Authored Outdoor/Roads + pads stay visible and colliding. Generation is cheap
## so Start Match can finish; a failed pass must never blank the farm.

const MASK_DIR := "res://assets/horror/farm/masks/"
const BUILDINGS_JSON := "res://assets/horror/farm/masks/buildings.json"
const ROADS_JSON := "res://assets/horror/farm/masks/roads.json"
const ROOT_NAME := "SemanticGenerated"
const SNAP_M: float = 18.0
const RNG_SEED: int = 17041
const CLIFF_SETBACK_M: float = 8.0
const CLIFF_X_WORLD: float = 64.0
const ROAD_WIDTH: float = 5.0
const VEG_STEP: float = 5.4
const VEG_MAX: int = 480
const ROAD_STEP_M: float = 3.0
const ROAD_MAX_LANES: int = 80
const TERRAIN_ORIGIN_X: float = -144.0
const TERRAIN_ORIGIN_Z: float = -120.0
const TERRAIN_SPAN_X: float = 288.0
const TERRAIN_SPAN_Z: float = 240.0

const SIZES := {
	"mansion": Vector3(20.0, 3.2, 16.0),
	"family": Vector3(13.5, 2.6, 11.0),
	"uncle": Vector3(10.0, 2.7, 8.0),
	"garage": Vector3(6.4, 2.5, 7.2),
	"utility": Vector3(8.0, 2.4, 6.0),
}

const COLORS := {
	"mansion": Color(0.42, 0.36, 0.32),
	"family": Color(0.55, 0.55, 0.52),
	"uncle": Color(0.55, 0.55, 0.52),
	"garage": Color(0.50, 0.48, 0.44),
	"utility": Color(0.48, 0.50, 0.46),
}

var maps
var rng_seed: int = RNG_SEED
var generate_roads: bool = true
var generate_buildings: bool = true
var generate_vegetation: bool = true
var _road_mat: StandardMaterial3D
var _trunk_mat: StandardMaterial3D
var _leaf_mat: StandardMaterial3D
var _bush_mat: StandardMaterial3D
var _grass_mat: StandardMaterial3D
var _boulder_mat: StandardMaterial3D
var _roads: Array = []


func run(world: Node3D) -> String:
	if world == null or not world.is_inside_tree():
		return "world not ready"
	var maps_script: GDScript = load("res://scripts/horror/world/semantic_maps.gd")
	if maps_script == null:
		return "semantic_maps.gd failed to load"
	maps = maps_script.new()
	if maps == null or not maps.has_method("load_all"):
		return "semantic maps unavailable"
	var err: String = str(maps.call("load_all"))
	if not err.is_empty():
		push_warning("[SemanticMaps] %s" % err)
		return err
	_make_shared_mats()
	var root := _ensure_root(world)
	_apply_cliff_exclusion(world)
	if generate_roads:
		_place_roads(world, root)
	if generate_buildings:
		_place_buildings(world, root)
	if generate_vegetation:
		_place_edge_blockers(world, root)
		_place_vegetation(world, root)
	_attach_debug(world, root)
	print("[SemanticMaps] generated roads=%s buildings=%s vegetation=%s" % [
		generate_roads, generate_buildings, generate_vegetation,
	])
	return ""


func _make_shared_mats() -> void:
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.11, 0.11, 0.13)
	_road_mat.roughness = 0.92
	_trunk_mat = StandardMaterial3D.new()
	_trunk_mat.albedo_color = Color(0.28, 0.18, 0.10)
	_leaf_mat = StandardMaterial3D.new()
	_leaf_mat.albedo_color = Color(0.18, 0.32, 0.12)
	_leaf_mat.emission_enabled = true
	_leaf_mat.emission = Color(0.08, 0.14, 0.05)
	_leaf_mat.emission_energy_multiplier = 0.18
	_bush_mat = StandardMaterial3D.new()
	_bush_mat.albedo_color = Color(0.22, 0.38, 0.14)
	_grass_mat = StandardMaterial3D.new()
	_grass_mat.albedo_color = Color(0.34, 0.48, 0.18)
	_grass_mat.emission_enabled = true
	_grass_mat.emission = Color(0.12, 0.18, 0.06)
	_grass_mat.emission_energy_multiplier = 0.12
	_boulder_mat = StandardMaterial3D.new()
	_boulder_mat.albedo_color = Color(0.38, 0.37, 0.36)
	_boulder_mat.roughness = 0.96


func _ensure_root(world: Node3D) -> Node3D:
	var outdoor := world.get_node_or_null("Outdoor") as Node3D
	if outdoor == null:
		outdoor = world
	var root := outdoor.get_node_or_null(ROOT_NAME) as Node3D
	if root:
		for child in root.get_children():
			child.queue_free()
	else:
		root = Node3D.new()
		root.name = ROOT_NAME
		outdoor.add_child(root)
	return root


func _apply_cliff_exclusion(_world: Node3D) -> void:
	## Heightmap already holds the east drop-off. Mask is the hard building ban.
	pass


func _place_roads(world: Node3D, root: Node3D) -> void:
	## Keep authored Lane_* visible and colliding. Overlay a short sampled set.
	var folder := Node3D.new()
	folder.name = "GenRoads"
	root.add_child(folder)
	_roads.clear()
	var polylines: Array = _read_json(ROADS_JSON)
	if polylines.is_empty():
		return
	var idx := 0
	for line in polylines:
		if idx >= ROAD_MAX_LANES:
			break
		var pts: Array = _resample_line(line, ROAD_STEP_M)
		for i in range(pts.size() - 1):
			if idx >= ROAD_MAX_LANES:
				break
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			if p0.distance_to(p1) < 1.2:
				continue
			if p0.x >= CLIFF_X_WORLD - 4.0 or p1.x >= CLIFF_X_WORLD - 4.0:
				continue
			if _road_hits_building(p0, p1):
				continue
			_roads.append({"a": p0, "b": p1})
			_spawn_lane(folder, idx, p0, p1, world)
			idx += 1


func _resample_line(line: Variant, step_m: float) -> Array:
	var out: Array = []
	if not (line is Array) or (line as Array).size() < 2:
		return out
	var raw: Array = []
	for item in line:
		if item is Array and (item as Array).size() >= 2:
			raw.append(Vector2(float(item[0]), float(item[1])))
		elif item is Dictionary:
			raw.append(Vector2(float(item.get("x", 0.0)), float(item.get("z", item.get("y", 0.0)))))
	if raw.size() < 2:
		return out
	out.append(raw[0])
	var carry := 0.0
	for i in range(raw.size() - 1):
		var a: Vector2 = raw[i]
		var b: Vector2 = raw[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		carry += seg
		if carry >= step_m:
			out.append(b)
			carry = 0.0
	var last: Vector2 = raw[raw.size() - 1]
	if out.is_empty() or (out[out.size() - 1] as Vector2).distance_to(last) > 1.0:
		out.append(last)
	return out


func _road_hits_building(a: Vector2, b: Vector2) -> bool:
	var mid := (a + b) * 0.5
	return bool(maps.call("is_building_world", mid.x, mid.y))


func _spawn_lane(folder: Node3D, idx: int, a: Vector2, b: Vector2, world: Node3D) -> void:
	var y0 := _ground_y(world, a.x, a.y)
	var y1 := _ground_y(world, b.x, b.y)
	var mid := (a + b) * 0.5
	var delta := b - a
	var length := maxf(delta.length(), 0.6)
	var yaw := atan2(delta.x, delta.y)
	var pitch := atan2(y0 - y1, length)
	var y := (y0 + y1) * 0.5 + 0.05
	var body := StaticBody3D.new()
	body.name = "GenLane_%02d" % idx
	body.position = Vector3(mid.x, y, mid.y)
	body.rotation = Vector3(pitch, yaw, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_WIDTH, 0.1, length)
	mesh.material = _road_mat
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	body.add_child(inst)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var box := BoxShape3D.new()
	box.size = mesh.size
	cs.shape = box
	body.add_child(cs)
	folder.add_child(body)


func _place_buildings(world: Node3D, root: Node3D) -> void:
	var folder := Node3D.new()
	folder.name = "GenBuildings"
	root.add_child(folder)
	var blobs: Array = _read_json(BUILDINGS_JSON)
	var pads := _authored_pads(world)
	var used: Dictionary = {}
	for blob in blobs:
		if not (blob is Dictionary):
			continue
		var kind := str(blob.get("kind", ""))
		var x := float(blob.get("x", 0.0))
		var z := float(blob.get("z", 0.0))
		if bool(maps.call("is_cliff_world", x, z)):
			continue
		if _near_cliff(x, z, CLIFF_SETBACK_M):
			continue
		if bool(maps.call("is_road_world", x, z)):
			continue
		var snap := _snap_pad(kind, x, z, pads, used)
		if snap != null:
			## Authored Kyle pad already sits on this zone — keep it.
			continue
		_spawn_pad(folder, kind, x, z, world)


func _authored_pads(world: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mapping := [
		["Outdoor/Pads/Pad_FamilyA", "family"],
		["Outdoor/Pads/Pad_FamilyB", "family"],
		["Outdoor/Pads/Pad_FamilyC", "family"],
		["Outdoor/Pads/Pad_FamilyD", "family"],
		["Outdoor/Pads/Pad_Uncle", "uncle"],
		["Outdoor/Pads/Pad_UncleGarage", "garage"],
		["Outdoor/MainHouse", "mansion"],
	]
	for row in mapping:
		var n := world.get_node_or_null(row[0]) as Node3D
		if n == null:
			continue
		out.append({"kind": row[1], "node": n, "xz": Vector2(n.global_position.x, n.global_position.z)})
	return out


func _snap_pad(kind: String, x: float, z: float, pads: Array[Dictionary], used: Dictionary) -> Node3D:
	var best: Dictionary = {}
	var best_d := SNAP_M
	var here := Vector2(x, z)
	for pad in pads:
		if str(pad["kind"]) != kind:
			continue
		var node: Node3D = pad["node"]
		if used.has(node.get_path()):
			continue
		var d: float = here.distance_to(pad["xz"])
		if d < best_d:
			best_d = d
			best = pad
	if best.is_empty():
		return null
	used[best["node"].get_path()] = true
	return best["node"]


func _spawn_pad(folder: Node3D, kind: String, x: float, z: float, world: Node3D) -> void:
	if kind.is_empty():
		kind = "utility"
	var size: Vector3 = SIZES.get(kind, SIZES["utility"])
	var y := _ground_y(world, x, z) + size.y * 0.5
	var body := StaticBody3D.new()
	body.name = "GenPad_%s_%d" % [kind, folder.get_child_count()]
	body.position = Vector3(x, y, z)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS.get(kind, COLORS["utility"])
	mat.roughness = 0.92
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	body.add_child(inst)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	folder.add_child(body)


func _place_vegetation(world: Node3D, root: Node3D) -> void:
	var folder := Node3D.new()
	folder.name = "GenVegetation"
	root.add_child(folder)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var counts := {"tree": 0, "bush": 0, "grass": 0}
	var planted := 0
	var x := TERRAIN_ORIGIN_X + 6.0
	while x < TERRAIN_ORIGIN_X + TERRAIN_SPAN_X - 6.0 and planted < VEG_MAX:
		var z := TERRAIN_ORIGIN_Z + 6.0
		while z < TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z - 6.0 and planted < VEG_MAX:
			var jx := x + rng.randf_range(-0.7, 0.7)
			var jz := z + rng.randf_range(-0.7, 0.7)
			if not _can_plant(jx, jz):
				z += VEG_STEP
				continue
			var dens := int(maps.call("vegetation_density_world", jx, jz))
			dens = maxi(dens, _outskirt_boost(jx, jz))
			if dens <= 0:
				z += VEG_STEP
				continue
			var skip := 0.38 / maxf(_edge_density_mult(jx, jz), 1.0)
			if rng.randf() < skip:
				z += VEG_STEP
				continue
			var roll := rng.randf()
			var y := _ground_y(world, jx, jz)
			if dens >= 3 and roll < 0.62:
				_spawn_tree(folder, jx, y, jz, rng)
				counts["tree"] += 1
				planted += 1
			elif dens >= 2 and roll < 0.48:
				_spawn_bush(folder, jx, y, jz, rng)
				counts["bush"] += 1
				planted += 1
			elif dens >= 1 and roll < 0.32:
				_spawn_grass(folder, jx, y, jz, rng)
				counts["grass"] += 1
				planted += 1
			z += VEG_STEP
		x += VEG_STEP
	print("[SemanticMaps] vegetation trees=%d bushes=%d grass=%d" % [
		counts["tree"], counts["bush"], counts["grass"],
	])


func _in_mask(x: float, z: float) -> bool:
	var uv: Vector2 = maps.coords.world_to_uv(x, z)
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0


func _can_plant(x: float, z: float) -> bool:
	if x >= CLIFF_X_WORLD - CLIFF_SETBACK_M:
		return false
	if _near_pad_world(x, z):
		return false
	if _near_gen_road(x, z):
		return false
	## Semantic masks cover the original plate only. Expanded 4x outskirts
	## are plantable greybox; do not treat out-of-mask as no-spawn.
	if _in_mask(x, z):
		if bool(maps.call("is_no_spawn_world", x, z)):
			return false
		if bool(maps.call("is_road_world", x, z)):
			return false
		if bool(maps.call("is_building_world", x, z)):
			return false
		if bool(maps.call("is_cliff_world", x, z)):
			return false
	return true


func _near_pad_world(x: float, z: float) -> bool:
	var here := Vector2(x, z)
	var pads := [
		Vector2(-76.0, -36.0),
		Vector2(-76.0, 4.0),
		Vector2(-76.0, 48.0),
		Vector2(-28.0, 48.0),
		Vector2(32.0, -56.0),
		Vector2(56.0, -56.0),
		Vector2(44.0, -12.0),
		Vector2(-116.0, 24.0),
	]
	for i in pads.size():
		var r := 16.0 if i == 6 else 10.5
		if here.distance_to(pads[i]) < r:
			return true
	for s in [Vector2(-76.0, -21.0), Vector2(-61.0, 4.0), Vector2(-76.0, 33.0), Vector2(-28.0, 33.0), Vector2(44.0, 2.0)]:
		if here.distance_to(s) < 6.5:
			return true
	return false


func _outskirt_boost(x: float, z: float) -> int:
	if x >= CLIFF_X_WORLD - 10.0:
		return 0
	var dist_n := z - TERRAIN_ORIGIN_Z
	var dist_s := (TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z) - z
	var dist_w := x - TERRAIN_ORIGIN_X
	var dist := minf(minf(dist_n, dist_s), dist_w)
	if dist < 16.0:
		return 3
	if dist < 34.0:
		return 2
	return 0


func _edge_density_mult(x: float, z: float) -> float:
	if x >= CLIFF_X_WORLD - 10.0:
		return 0.4
	var dist_n := z - TERRAIN_ORIGIN_Z
	var dist_s := (TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z) - z
	var dist_w := x - TERRAIN_ORIGIN_X
	var dist := minf(minf(dist_n, dist_s), dist_w)
	if dist < 16.0:
		return 3.4
	if dist < 34.0:
		return 1.9
	return 1.0


func _spawn_tree(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenTree_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	var h := rng.randf_range(2.4, 3.6)
	_add_cyl(n, "Trunk", 0.14, h, Vector3(0, h * 0.5, 0), _trunk_mat)
	_add_sphere(n, "Canopy", rng.randf_range(1.1, 1.6), Vector3(0, h + 0.4, 0), _leaf_mat)
	folder.add_child(n)


func _spawn_bush(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenBush_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	_add_sphere(n, "Body", rng.randf_range(0.45, 0.75), Vector3(0, 0.4, 0), _bush_mat)
	folder.add_child(n)


func _spawn_grass(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenGrass_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, rng.randf_range(0.18, 0.32), 0.08)
	mesh.material = _grass_mat
	var inst := MeshInstance3D.new()
	inst.name = "Blade"
	inst.mesh = mesh
	inst.position.y = mesh.size.y * 0.5
	n.add_child(inst)
	folder.add_child(n)


func _place_edge_blockers(world: Node3D, root: Node3D) -> void:
	## Greybox wall of colliding trees + boulders on N/S/W edges. East is the cliff.
	var folder := Node3D.new()
	folder.name = "GenEdgeBlockers"
	root.add_child(folder)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed ^ 0xB0A7DE
	var east_cut := CLIFF_X_WORLD - 8.0
	var planted := 0
	var wx := int(TERRAIN_ORIGIN_X) + 3
	while wx < int(east_cut):
		_edge_cluster(folder, world, float(wx), TERRAIN_ORIGIN_Z + 4.0 + rng.randf() * 6.0, rng)
		_edge_cluster(folder, world, float(wx), TERRAIN_ORIGIN_Z + 12.0 + rng.randf() * 6.0, rng)
		_edge_cluster(folder, world, float(wx), TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z - 5.0 - rng.randf() * 6.0, rng)
		_edge_cluster(folder, world, float(wx), TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z - 13.0 - rng.randf() * 6.0, rng)
		planted += 4
		wx += 4
	var wz := int(TERRAIN_ORIGIN_Z) + 6
	while wz < int(TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z) - 6:
		_edge_cluster(folder, world, TERRAIN_ORIGIN_X + 4.0 + rng.randf() * 7.0, float(wz), rng)
		_edge_cluster(folder, world, TERRAIN_ORIGIN_X + 12.0 + rng.randf() * 7.0, float(wz), rng)
		planted += 2
		wz += 4
	print("[SemanticMaps] edge blockers clusters~=%d" % planted)


func _edge_cluster(folder: Node3D, world: Node3D, x: float, z: float, rng: RandomNumberGenerator) -> void:
	if not _can_plant(x, z):
		return
	if _near_gen_road(x, z):
		return
	var y := _ground_y(world, x, z)
	if rng.randf() < 0.40:
		_spawn_boulder(folder, x, y, z, rng)
	else:
		_spawn_blocking_tree(folder, x, y, z, rng)
	var x2 := x + rng.randf_range(-2.2, 2.2)
	var z2 := z + rng.randf_range(-2.2, 2.2)
	if _can_plant(x2, z2):
		_spawn_blocking_tree(folder, x2, _ground_y(world, x2, z2), z2, rng)


func _near_gen_road(x: float, z: float) -> bool:
	var here := Vector2(x, z)
	for r in _roads:
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		var ab := b - a
		var denom := maxf(ab.length_squared(), 0.001)
		var t := clampf((here - a).dot(ab) / denom, 0.0, 1.0)
		if here.distance_to(a + ab * t) < 4.6:
			return true
	return false


func _spawn_blocking_tree(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "EdgeTree_%04d" % folder.get_child_count()
	body.position = Vector3(x, y, z)
	body.collision_layer = 1
	body.collision_mask = 0
	var h := rng.randf_range(3.2, 5.4)
	_add_cyl(body, "Trunk", rng.randf_range(0.22, 0.38), h, Vector3(0, h * 0.5, 0), _trunk_mat)
	_add_sphere(body, "Canopy", rng.randf_range(1.6, 2.4), Vector3(0, h + 0.55, 0), _leaf_mat)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.72
	cyl.height = h + 1.4
	cs.shape = cyl
	cs.position.y = cyl.height * 0.45
	body.add_child(cs)
	folder.add_child(body)


func _spawn_boulder(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "EdgeBoulder_%04d" % folder.get_child_count()
	body.position = Vector3(x, y, z)
	body.collision_layer = 1
	body.collision_mask = 0
	var size := Vector3(
		rng.randf_range(2.6, 5.4),
		rng.randf_range(1.8, 3.6),
		rng.randf_range(2.4, 5.0),
	)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _boulder_mat
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	inst.position.y = size.y * 0.42
	inst.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-8.0, 8.0))
	body.add_child(inst)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.42
	body.add_child(cs)
	folder.add_child(body)


func _add_cyl(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.15
	mesh.height = height
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)


func _add_sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)


func _attach_debug(world: Node3D, root: Node3D) -> void:
	var view_script: GDScript = load("res://scripts/horror/world/mask_debug_view.gd")
	if view_script == null:
		return
	var view: Node = view_script.new()
	view.name = "MaskDebugView"
	view.set("maps", maps)
	root.add_child(view)
	if view.has_method("bind_world"):
		view.call("bind_world", world)


func _near_cliff(x: float, z: float, setback: float) -> bool:
	if x >= CLIFF_X_WORLD - setback:
		return true
	for d in [0.0, setback, setback * 0.5]:
		if bool(maps.call("is_cliff_world", x + d, z)):
			return true
	return false


func _ground_y(world: Node3D, x: float, z: float) -> float:
	var terrain := world.get_node_or_null("Outdoor/Terrain") as Node3D
	if terrain == null:
		return 1.0
	var hm: HeightMapShape3D = null
	for child in terrain.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is HeightMapShape3D:
			hm = (child as CollisionShape3D).shape
			break
	if hm == null:
		return 1.0
	var data: PackedFloat32Array = hm.map_data
	var w := hm.map_width
	var d := hm.map_depth
	if w < 2 or d < 2 or data.size() < w * d:
		return 1.0
	var u := (x - TERRAIN_ORIGIN_X) / (TERRAIN_SPAN_X / float(w - 1))
	var v := (z - TERRAIN_ORIGIN_Z) / (TERRAIN_SPAN_Z / float(d - 1))
	var fx := clampf(u, 0.0, float(w - 1))
	var fz := clampf(v, 0.0, float(d - 1))
	var ix0 := clampi(int(floor(fx)), 0, w - 2)
	var iz0 := clampi(int(floor(fz)), 0, d - 2)
	var tx := fx - float(ix0)
	var tz := fz - float(iz0)
	var h00 := data[iz0 * w + ix0]
	var h10 := data[iz0 * w + ix0 + 1]
	var h01 := data[(iz0 + 1) * w + ix0]
	var h11 := data[(iz0 + 1) * w + ix0 + 1]
	return (h00 * (1.0 - tx) + h10 * tx) * (1.0 - tz) + (h01 * (1.0 - tx) + h11 * tx) * tz


func _read_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	return data if data is Array else []
