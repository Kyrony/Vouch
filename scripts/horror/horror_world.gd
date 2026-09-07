extends Node3D
class_name HorrorWorld
## Procedural graybox horror map: surface house, underground bunker, open field.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")
const _PICKUP_SCENE: PackedScene = preload("res://scenes/Horror/WorldPickup.tscn")

@export var bunker_origin: Vector3 = Vector3(0, -18, 0)
@export var house_origin: Vector3 = Vector3(0, 0, 0)

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _field_mat: StandardMaterial3D
var _spawn_points: Array[Marker3D] = []


func _ready() -> void:
	add_to_group("horror_world")
	_init_materials()
	_build_field()
	_build_house()
	_build_bunker()
	_build_shaft()
	_build_escape_zone()
	_scatter_pickups()
	_scatter_bunker_spawns()
	print("[HorrorWorld] built spawns=%d pickups=%d" % [_spawn_points.size(), get_node("Pickups").get_child_count()])


func get_random_spawn_transform() -> Transform3D:
	if _spawn_points.is_empty():
		return Transform3D(Basis.IDENTITY, bunker_origin + Vector3(0, 1.2, 0))
	var m: Marker3D = _spawn_points[randi() % _spawn_points.size()]
	return m.global_transform


func get_spawn_point_count() -> int:
	return _spawn_points.size()


func spawn_pickup(item_id: String, global_pos: Vector3) -> void:
	if get_node_or_null("Pickups") == null:
		return
	_spawn_pickup_local(item_id, global_pos)


func _spawn_pickup_local(item_id: String, pos: Vector3) -> void:
	var pickup: Node = _PICKUP_SCENE.instantiate()
	pickup.name = "Pickup_%s" % item_id
	pickup.set("item_id", item_id)
	get_node("Pickups").add_child(pickup)
	pickup.global_position = pos + Vector3(0, 0.35, 0)


func _init_materials() -> void:
	_wall_mat = _mat(Color(0.32, 0.31, 0.3))
	_floor_mat = _mat(Color(0.26, 0.25, 0.24))
	_ceiling_mat = _mat(Color(0.22, 0.22, 0.23))
	_field_mat = _mat(Color(0.38, 0.36, 0.32))


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m


func _build_field() -> void:
	var root := Node3D.new()
	root.name = "Field"
	add_child(root)

	root.add_child(_GEOM.call("box", Vector3(120, 0.4, 120), Vector3(0, -0.2, 0), _field_mat))

	var slope_mat := _mat(Color(0.34, 0.32, 0.28))
	var dirs := [
		Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0),
		Vector3(-0.75, 0, -0.75), Vector3(0.75, 0, -0.75),
	]
	for d: Vector3 in dirs:
		var pos: Vector3 = d * 55.0 + Vector3(0, 4.0, 0)
		var body: StaticBody3D = _GEOM.call("box", Vector3(40, 8, 18), pos, slope_mat)
		body.rotation.y = atan2(d.x, d.z)
		body.rotation.x = -0.28
		root.add_child(body)

	var peak_mat := _mat(Color(0.45, 0.43, 0.4))
	for p in [Vector3(-55, 14, -48), Vector3(58, 16, -44), Vector3(-50, 12, 52), Vector3(54, 18, 50)]:
		root.add_child(_GEOM.call("box", Vector3(28, 22, 24), p, peak_mat))


func _build_house() -> void:
	var root := Node3D.new()
	root.name = "SurfaceHouse"
	root.position = house_origin
	add_child(root)

	# Main footprint 16x12, wall height 3m
	_add_room_box(root, Vector3(16, 3, 12), Vector3.ZERO, true, true)
	# Interior walls -> 4 rooms
	_add_wall_panel(root, Vector3(0.25, 1.5, 0), Vector3(0.25, 3, 12)) # center split Z
	_add_wall_panel(root, Vector3(-4, 1.5, 3), Vector3(8, 3, 0.25))
	_add_wall_panel(root, Vector3(4, 1.5, -3), Vector3(8, 3, 0.25))
	# Front door opening (+Z)
	_add_wall_panel(root, Vector3(0, 1.5, 6), Vector3(16, 3, 0.25), true, 2.0)
	# Porch
	root.add_child(_GEOM.call("box", Vector3(4, 0.15, 2.5), Vector3(0, 0.08, 7.2), _floor_mat))
	# Kitchen counter stub
	root.add_child(_GEOM.call("box", Vector3(3, 0.9, 0.6), Vector3(-5.5, 0.45, -4), _wall_mat))
	# Table
	root.add_child(_GEOM.call("box", Vector3(2.2, 0.75, 1.2), Vector3(5, 0.38, 2), _mat(Color(0.4, 0.28, 0.18))))


func _build_bunker() -> void:
	var root := Node3D.new()
	root.name = "Bunker"
	root.position = bunker_origin
	add_child(root)

	# Main hall 48x36
	_add_room_box(root, Vector3(48, 4, 36), Vector3.ZERO, true, true)
	# Cross corridors
	_add_wall_panel(root, Vector3(-12, 2, 0), Vector3(0.3, 4, 36), true, 2.5)
	_add_wall_panel(root, Vector3(12, 2, 0), Vector3(0.3, 4, 36), true, 2.5)
	_add_wall_panel(root, Vector3(0, 2, -10), Vector3(48, 4, 0.3), true, 2.5)
	_add_wall_panel(root, Vector3(0, 2, 10), Vector3(48, 4, 0.3), true, 2.5)
	# Side rooms
	for offset in [Vector3(-20, 0, -14), Vector3(20, 0, -14), Vector3(-20, 0, 14), Vector3(20, 0, 14)]:
		_add_room_box(root, Vector3(10, 4, 8), offset, true, true)
	# Crates / cover
	var crate_mat := _mat(Color(0.35, 0.33, 0.3))
	for pos in [Vector3(-6, 0.5, 4), Vector3(8, 0.5, -6), Vector3(-18, 0.5, 12), Vector3(16, 0.5, 8)]:
		root.add_child(_GEOM.call("box", Vector3(1.2, 1, 1.2), pos + Vector3(0, 0.5, 0), crate_mat))
	# Dim emergency light
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.5, 0)
	light.light_color = Color(0.9, 0.35, 0.25)
	light.light_energy = 0.6
	light.omni_range = 22
	root.add_child(light)


func _build_shaft() -> void:
	var root := Node3D.new()
	root.name = "Shaft"
	add_child(root)
	var shaft_mat := _mat(Color(0.28, 0.27, 0.26))
	# Elevator/stair shaft from house to bunker
	var shaft_x := 6.0
	var top := house_origin.y - 0.5
	var bottom := bunker_origin.y + 4.0
	var height := top - bottom
	var center_y := bottom + height * 0.5
	root.add_child(_GEOM.call("box", Vector3(3, height, 3), Vector3(shaft_x, center_y, 0), shaft_mat))
	# Stairs as ramp steps
	var steps := int(height / 0.35)
	for i in steps:
		var y := bottom + i * 0.35
		root.add_child(_GEOM.call("box", Vector3(2.2, 0.12, 0.8), Vector3(shaft_x, y, -1.0 + (i % 2) * 0.4), _floor_mat))
	# Hole in house floor
	root.add_child(_GEOM.call("box", Vector3(2.8, 0.15, 2.8), Vector3(shaft_x, house_origin.y - 0.08, 0), _floor_mat))


func _build_escape_zone() -> void:
	var zone := Area3D.new()
	zone.name = "HorrorEscapeZone"
	zone.position = Vector3(0, 0.5, 42)
	zone.collision_layer = 0
	zone.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 4, 8)
	shape.shape = box
	zone.add_child(shape)
	var script := load("res://scripts/interactables/escape_zone.gd")
	zone.set_script(script)
	add_child(zone)
	# Visual marker
	var pole: StaticBody3D = _GEOM.call("box", Vector3(0.3, 3, 0.3), Vector3(-6, 1.5, 0), _mat(Color(0.2, 0.7, 0.35)))
	zone.add_child(pole)
	var sign: StaticBody3D = _GEOM.call("box", Vector3(4, 1, 0.2), Vector3(0, 2, 0), _mat(Color(0.15, 0.55, 0.25)))
	zone.add_child(sign)


func _scatter_bunker_spawns() -> void:
	var root := get_node("Bunker")
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	var positions := [
		Vector3(-20, 0.1, -12), Vector3(20, 0.1, -12), Vector3(-20, 0.1, 12), Vector3(20, 0.1, 12),
		Vector3(-6, 0.1, 0), Vector3(6, 0.1, 0), Vector3(0, 0.1, -8), Vector3(0, 0.1, 8),
		Vector3(-14, 0.1, 0), Vector3(14, 0.1, 0), Vector3(-8, 0.1, -14), Vector3(8, 0.1, 14),
	]
	for i in positions.size():
		var m := Marker3D.new()
		m.name = "Spawn_%02d" % i
		m.position = positions[i]
		spawns.add_child(m)
		_spawn_points.append(m)


func _scatter_pickups() -> void:
	var pickups := Node3D.new()
	pickups.name = "Pickups"
	add_child(pickups)
	var defs := [
		{"id": "medkit", "pos": Vector3(-18, -17.5, -10)},
		{"id": "flashlight", "pos": Vector3(18, -17.5, 10)},
		{"id": "keycard", "pos": Vector3(6, 0.5, 2)},
		{"id": "bandage", "pos": Vector3(-5, -17.5, 6)},
		{"id": "battery", "pos": Vector3(12, -17.5, -8)},
		{"id": "crowbar", "pos": Vector3(-8, 0.5, -3)},
	]
	for d in defs:
		_spawn_pickup_local(d["id"], d["pos"])


func _add_room_box(parent: Node3D, size: Vector3, center: Vector3, floor: bool, ceiling: bool) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	if floor:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, -hy + 0.1, 0), _floor_mat))
	if ceiling:
		parent.add_child(_GEOM.call("box", Vector3(size.x, 0.2, size.z), center + Vector3(0, hy - 0.1, 0), _ceiling_mat))
	# Walls
	parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, 0.25), center + Vector3(0, 0, -hz), _wall_mat))
	parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, 0.25), center + Vector3(0, 0, hz), _wall_mat))
	parent.add_child(_GEOM.call("box", Vector3(0.25, size.y, size.z), center + Vector3(-hx, 0, 0), _wall_mat))
	parent.add_child(_GEOM.call("box", Vector3(0.25, size.y, size.z), center + Vector3(hx, 0, 0), _wall_mat))


func _add_wall_panel(parent: Node3D, center: Vector3, size: Vector3, doorway: bool = false, gap: float = 0.0) -> void:
	if not doorway or gap <= 0.0:
		parent.add_child(_GEOM.call("box", size, center, _wall_mat))
		return
	# Split wall with doorway gap along X if wall is thin in X
	if size.x <= size.z:
		var half := (size.x - gap) * 0.5
		if half > 0.2:
			parent.add_child(_GEOM.call("box", Vector3(half, size.y, size.z), center + Vector3(-(gap * 0.5 + half * 0.5), 0, 0), _wall_mat))
			parent.add_child(_GEOM.call("box", Vector3(half, size.y, size.z), center + Vector3(gap * 0.5 + half * 0.5, 0, 0), _wall_mat))
	else:
		var half := (size.z - gap) * 0.5
		if half > 0.2:
			parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, half), center + Vector3(0, 0, -(gap * 0.5 + half * 0.5)), _wall_mat))
			parent.add_child(_GEOM.call("box", Vector3(size.x, size.y, half), center + Vector3(0, 0, gap * 0.5 + half * 0.5), _wall_mat))
