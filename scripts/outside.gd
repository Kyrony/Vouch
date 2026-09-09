extends Node3D
class_name Outside
## Outside
##
## Shared mountain clearing where every escape tunnel emerges. All escaped
## players roam the same exterior regardless of faction.
##
## Also hosts `TestRange_RemoveBeforeRelease` — dev-only gun range.

@onready var roam_spawn_points: Node3D = $RoamSpawnPoints

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _HORROR_MODE: GDScript = preload("res://scripts/autoload/horror_mode_settings.gd")


func _ready() -> void:
	## Live Classic Host Match is HorrorWorld (terrain/roads/markers).
	## This courtyard + mountain graybox must not share the viewport.
	if _HORROR_MODE.is_horror_mode():
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		for child in get_children():
			child.queue_free()
		return
	_build_mountain_graybox()
	_gate_test_range()
	if has_node("Ground"):
		$Ground.add_to_group("escape_outside_floor")
	if multiplayer.is_server():
		EscapeSystem.server_register_outside(self)


func _gate_test_range() -> void:
	# REMOVE test gun / dummy range entirely before retail launch.
	if not DebugBuild.enabled and has_node("TestRange_RemoveBeforeRelease"):
		get_node("TestRange_RemoveBeforeRelease").queue_free()


func get_roam_spawn_transform() -> Transform3D:
	var points := roam_spawn_points.get_children()
	if points.is_empty():
		return global_transform
	var marker: Marker3D = points[randi() % points.size()]
	return marker.global_transform


func _build_mountain_graybox() -> void:
	if has_node("MountainTerrain"):
		return

	var terrain := Node3D.new()
	terrain.name = "MountainTerrain"
	add_child(terrain)

	_add_sky(terrain)
	_add_clearing(terrain)
	_add_slopes(terrain)
	_add_peaks(terrain)
	_add_rock_scatter(terrain)

	if has_node("Ground"):
		$Ground.visible = false
	for wall_name in ["PerimeterNorth", "PerimeterSouth", "PerimeterEast", "PerimeterWest"]:
		if has_node(wall_name):
			get_node(wall_name).visible = false


func _add_sky(parent: Node3D) -> void:
	var env_root := WorldEnvironment.new()
	env_root.name = "MountainSky"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.55)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.72, 0.78)
	env.fog_density = 0.002
	env_root.environment = env
	parent.add_child(env_root)

	if has_node("DirectionalLight3D"):
		var sun: DirectionalLight3D = $DirectionalLight3D
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 1.15
		sun.shadow_enabled = true


func _add_clearing(parent: Node3D) -> void:
	var ground_mat := _rock_material(Color(0.42, 0.38, 0.32))
	parent.add_child(_terrain_box(Vector3(18, 0.35, 18), Vector3(0, -0.18, 0), ground_mat))

	var pad_mat := _rock_material(Color(0.36, 0.34, 0.3))
	parent.add_child(_terrain_box(Vector3(4.2, 0.12, 4.2), Vector3(0, 0.02, 0), pad_mat))


func _add_slopes(parent: Node3D) -> void:
	var slope_mat := _rock_material(Color(0.38, 0.35, 0.3))
	var dirs := [
		Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0),
		Vector3(-0.7, 0, -0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, 0.7),
	]
	for d: Vector3 in dirs:
		var pos: Vector3 = d * 11.0 + Vector3(0, 1.8, 0)
		var size: Vector3 = Vector3(8, 3.6, 8) if absf(d.x) > 0.1 and absf(d.z) > 0.1 else Vector3(14, 3.2, 6)
		var body := _terrain_box(size, pos, slope_mat)
		body.rotation.y = atan2(d.x, d.z)
		body.rotation.x = -0.32
		parent.add_child(body)


func _add_peaks(parent: Node3D) -> void:
	var peak_mat := _rock_material(Color(0.48, 0.46, 0.44))
	var placements := [
		{"pos": Vector3(-22, 6, -18), "size": Vector3(16, 12, 14)},
		{"pos": Vector3(24, 7, -16), "size": Vector3(18, 14, 12)},
		{"pos": Vector3(-20, 5, 22), "size": Vector3(14, 10, 16)},
		{"pos": Vector3(18, 8, 20), "size": Vector3(20, 16, 14)},
	]
	for p: Dictionary in placements:
		parent.add_child(_terrain_box(p["size"], p["pos"], peak_mat))


func _add_rock_scatter(parent: Node3D) -> void:
	var rock_mat := _rock_material(Color(0.34, 0.32, 0.28))
	var spots := [
		Vector3(-7, 0.35, -5), Vector3(6, 0.3, -6), Vector3(-5, 0.4, 7),
		Vector3(8, 0.35, 5), Vector3(-9, 0.25, 2), Vector3(3, 0.3, -8),
	]
	for pos: Vector3 in spots:
		var s := randf_range(0.7, 1.4)
		parent.add_child(_terrain_box(Vector3(s, s * 0.6, s * 0.9), pos, rock_mat))


func _rock_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


func _terrain_box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	return _GEOM.call("box", size, pos, mat, 1)
