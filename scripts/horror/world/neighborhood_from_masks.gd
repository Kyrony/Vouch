extends RefCounted
class_name NeighborhoodFromMasks
## Heightmap stays authored. Semantic masks drive roads, buildings, vegetation.
## Order: cliff/exclusion → roads → buildings → vegetation → cleanup.

const MASK_DIR := "res://assets/horror/farm/masks/"
const BUILDINGS_JSON := "res://assets/horror/farm/masks/buildings.json"
const ROADS_JSON := "res://assets/horror/farm/masks/roads.json"
const ROOT_NAME := "SemanticGenerated"
const SNAP_M: float = 18.0
const SEED: int = 17041
const CLIFF_SETBACK_M: float = 6.0
const ROAD_WIDTH: float = 5.0
const VEG_STEP: float = 3.6

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

var maps: SemanticMaps
var seed: int = SEED
var generate_roads: bool = true
var generate_buildings: bool = true
var generate_vegetation: bool = true


func run(world: Node3D) -> String:
	maps = SemanticMaps.new()
	var err := maps.load_all()
	if not err.is_empty():
		push_warning("[SemanticMaps] %s" % err)
		return err
	var root := _ensure_root(world)
	_apply_cliff_exclusion(world)
	if generate_roads:
		_place_roads(world, root)
	if generate_buildings:
		_place_buildings(world, root)
	if generate_vegetation:
		_place_vegetation(world, root)
	_attach_debug(world, root)
	print("[SemanticMaps] generated roads=%s buildings=%s vegetation=%s" % [
		generate_roads, generate_buildings, generate_vegetation,
	])
	return ""


func _ensure_root(world: Node3D) -> Node3D:
	var outdoor := world.get_node_or_null("Outdoor") as Node3D
	if outdoor == null:
		outdoor = world
	var root := outdoor.get_node_or_null(ROOT_NAME) as Node3D
	if root:
		for child in root.get_children():
			child.free()
	else:
		root = Node3D.new()
		root.name = ROOT_NAME
		outdoor.add_child(root)
	return root


func _apply_cliff_exclusion(_world: Node3D) -> void:
	## Heightmap already holds the east drop-off. Mask is the hard building ban.
	pass


func _place_roads(world: Node3D, root: Node3D) -> void:
	var authored := world.get_node_or_null("Outdoor/Roads")
	if authored:
		for lane in authored.get_children():
			_mute_body(lane)
	var folder := Node3D.new()
	folder.name = "GenRoads"
	root.add_child(folder)
	var polylines: Array = _read_json(ROADS_JSON)
	if polylines.is_empty():
		return
	var idx := 0
	for line in polylines:
		if not (line is Array) or line.size() < 2:
			continue
		for i in range(line.size() - 1):
			var a: Array = line[i]
			var b: Array = line[i + 1]
			if a.size() < 2 or b.size() < 2:
				continue
			var p0 := Vector2(float(a[0]), float(a[1]))
			var p1 := Vector2(float(b[0]), float(b[1]))
			if p0.distance_to(p1) < 1.2:
				continue
			if _road_hits_building(p0, p1):
				continue
			_spawn_lane(folder, idx, p0, p1, world)
			idx += 1


func _road_hits_building(a: Vector2, b: Vector2) -> bool:
	var mid := (a + b) * 0.5
	return maps.is_building_world(mid.x, mid.y)


func _spawn_lane(folder: Node3D, idx: int, a: Vector2, b: Vector2, world: Node3D) -> void:
	var mid := (a + b) * 0.5
	var delta := b - a
	var length := maxf(delta.length(), 1.5)
	var yaw := atan2(delta.x, delta.y)
	var y := _ground_y(world, mid.x, mid.y) + 0.05
	var body := StaticBody3D.new()
	body.name = "GenLane_%02d" % idx
	body.position = Vector3(mid.x, y, mid.y)
	body.rotation.y = yaw
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_WIDTH, 0.1, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.11, 0.13)
	mat.roughness = 0.92
	mesh.material = mat
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
		if maps.is_cliff_world(x, z):
			continue
		if _near_cliff(x, z, CLIFF_SETBACK_M):
			continue
		if maps.is_road_world(x, z):
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
	rng.seed = seed
	var counts := {"tree": 0, "bush": 0, "grass": 0}
	var x := MapCoords.TERRAIN_ORIGIN_X + 4.0
	while x < MapCoords.TERRAIN_ORIGIN_X + MapCoords.TERRAIN_SPAN_X - 4.0:
		var z := MapCoords.TERRAIN_ORIGIN_Z + 4.0
		while z < MapCoords.TERRAIN_ORIGIN_Z + MapCoords.TERRAIN_SPAN_Z - 4.0:
			var jx := x + rng.randf_range(-0.7, 0.7)
			var jz := z + rng.randf_range(-0.7, 0.7)
			if not _can_plant(jx, jz):
				z += VEG_STEP
				continue
			var dens := maps.vegetation_density_world(jx, jz)
			if dens <= 0:
				z += VEG_STEP
				continue
			var roll := rng.randf()
			var y := _ground_y(world, jx, jz)
			if dens >= 3 and roll < 0.55:
				_spawn_tree(folder, jx, y, jz, rng)
				counts["tree"] += 1
			elif dens >= 2 and roll < 0.50:
				_spawn_bush(folder, jx, y, jz, rng)
				counts["bush"] += 1
			elif dens >= 1 and roll < 0.45:
				_spawn_grass(folder, jx, y, jz, rng)
				counts["grass"] += 1
			z += VEG_STEP
		x += VEG_STEP
	print("[SemanticMaps] vegetation trees=%d bushes=%d grass=%d" % [
		counts["tree"], counts["bush"], counts["grass"],
	])


func _can_plant(x: float, z: float) -> bool:
	if maps.is_no_spawn_world(x, z):
		return false
	if maps.is_road_world(x, z):
		return false
	if maps.is_building_world(x, z):
		return false
	if maps.is_cliff_world(x, z):
		return false
	return true


func _spawn_tree(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenTree_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.18, 0.10)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.32, 0.12)
	leaf_mat.emission_enabled = true
	leaf_mat.emission = Color(0.08, 0.14, 0.05)
	leaf_mat.emission_energy_multiplier = 0.18
	var h := rng.randf_range(2.4, 3.6)
	_add_cyl(n, "Trunk", 0.14, h, Vector3(0, h * 0.5, 0), trunk_mat)
	_add_sphere(n, "Canopy", rng.randf_range(1.1, 1.6), Vector3(0, h + 0.4, 0), leaf_mat)
	folder.add_child(n)


func _spawn_bush(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenBush_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.38, 0.14)
	_add_sphere(n, "Body", rng.randf_range(0.45, 0.75), Vector3(0, 0.4, 0), mat)
	folder.add_child(n)


func _spawn_grass(folder: Node3D, x: float, y: float, z: float, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.name = "GenGrass_%04d" % folder.get_child_count()
	n.position = Vector3(x, y, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.48, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.18, 0.06)
	mat.emission_energy_multiplier = 0.12
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, rng.randf_range(0.18, 0.32), 0.08)
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.name = "Blade"
	inst.mesh = mesh
	inst.position.y = mesh.size.y * 0.5
	n.add_child(inst)
	folder.add_child(n)


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


func _mute_body(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _near_cliff(x: float, z: float, setback: float) -> bool:
	for d in [0.0, setback, setback * 0.5]:
		if maps.is_cliff_world(x + d, z):
			return true
	return false


func _ground_y(world: Node3D, x: float, z: float) -> float:
	if world.get_world_3d() == null:
		return 1.0
	var space := world.get_world_3d().direct_space_state
	if space == null:
		return 1.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -4.0, z))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		return float((hit["position"] as Vector3).y)
	return 1.0


func _read_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	return data if data is Array else []
