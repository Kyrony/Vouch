extends RefCounted
class_name HorrorModularKit
## Soft-go modular graybox pieces for Leonardo environment kits.
## Neighborhood footprint stays v0.5; these are kit-language primitives.

const _GEOM: GDScript = preload("res://scripts/rooms/geometry_util.gd")


static func add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, layer: int = 1) -> StaticBody3D:
	var body: StaticBody3D = _GEOM.call("box", size, pos, mat, layer)
	parent.add_child(body)
	return body


static func add_cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, layer: int = 1) -> StaticBody3D:
	var body: StaticBody3D = _GEOM.call("cylinder", radius, height, pos, mat, layer)
	parent.add_child(body)
	return body


static func add_foundation_pillar(parent: Node3D, pos: Vector3, height: float, mats) -> void:
	add_box(parent, Vector3(0.32, height, 0.32), pos + Vector3(0, height * 0.5, 0), mats.concrete)


static func add_stairs(parent: Node3D, origin: Vector3, steps: int, width: float, rise: float, run: float, mat: Material) -> void:
	for i in steps:
		add_box(
			parent,
			Vector3(width, rise, run),
			origin + Vector3(0, rise * 0.5 + float(i) * rise, float(i) * run),
			mat,
		)


static func add_railing(parent: Node3D, start: Vector3, length: float, along_x: bool, mat: Material) -> void:
	var rail_h := 0.42
	if along_x:
		add_box(parent, Vector3(length, 0.06, 0.06), start + Vector3(0, rail_h, 0), mat)
		for i in 4:
			var t: float = -length * 0.5 + (length / 3.0) * float(i)
			add_box(parent, Vector3(0.05, rail_h, 0.05), start + Vector3(t, rail_h * 0.5, 0), mat)
	else:
		add_box(parent, Vector3(0.06, 0.06, length), start + Vector3(0, rail_h, 0), mat)
		for i in 4:
			var t2: float = -length * 0.5 + (length / 3.0) * float(i)
			add_box(parent, Vector3(0.05, rail_h, 0.05), start + Vector3(0, rail_h * 0.5, t2), mat)


static func add_window(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.15, 1.05, 0.08), pos, mats.wood)
	add_box(parent, Vector3(0.95, 0.85, 0.04), pos + Vector3(0, 0, 0.04), mats.glass)
	add_box(parent, Vector3(0.04, 0.85, 0.06), pos, mats.wood)
	add_box(parent, Vector3(0.95, 0.04, 0.06), pos, mats.wood)
	add_box(parent, Vector3(0.18, 1.1, 0.08), pos + Vector3(-0.68, 0, 0), mats.siding)
	add_box(parent, Vector3(0.18, 1.1, 0.08), pos + Vector3(0.68, 0, 0), mats.siding)


static func add_door(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.05, 2.15, 0.1), pos, mats.wood)
	add_box(parent, Vector3(0.28, 0.28, 0.04), pos + Vector3(0.0, 0.55, 0.07), mats.glass)
	add_box(parent, Vector3(1.22, 0.1, 0.16), pos + Vector3(0, 1.15, 0), mats.wood)
	add_box(parent, Vector3(0.1, 2.15, 0.16), pos + Vector3(-0.58, 0, 0), mats.wood)
	add_box(parent, Vector3(0.1, 2.15, 0.16), pos + Vector3(0.58, 0, 0), mats.wood)


static func add_roof_slopes(parent: Node3D, size: Vector3, y: float, mats) -> void:
	var left: StaticBody3D = add_box(parent, Vector3(size.x * 0.56, 0.16, size.z + 0.4), Vector3(-size.x * 0.18, y, 0), mats.shingle)
	left.rotation.z = 0.32
	var right: StaticBody3D = add_box(parent, Vector3(size.x * 0.56, 0.16, size.z + 0.4), Vector3(size.x * 0.18, y, 0), mats.shingle)
	right.rotation.z = -0.32


static func add_shed(parent: Node3D, origin: Vector3, mats, spawn_id: String = "") -> Node3D:
	var shed := Node3D.new()
	shed.name = "ShedModule"
	shed.position = origin
	parent.add_child(shed)
	add_box(shed, Vector3(2.1, 1.7, 1.8), Vector3(0, 0.85, 0), mats.siding)
	var roof: StaticBody3D = add_box(shed, Vector3(2.3, 0.12, 2.05), Vector3(0, 1.82, 0), mats.shingle)
	roof.rotation.z = 0.18
	add_box(shed, Vector3(0.7, 1.2, 0.08), Vector3(0, 0.7, 0.92), mats.wood)
	if not spawn_id.is_empty():
		var m := Marker3D.new()
		m.name = "ChildSpawn_%s" % spawn_id
		m.position = Vector3(0, 0.3, 0)
		m.add_to_group("child_spawn_points")
		m.set_meta("spawn_id", spawn_id)
		shed.add_child(m)
	return shed


static func add_pipe_run(parent: Node3D, from: Vector3, to: Vector3, radius: float, mats) -> void:
	var delta: Vector3 = to - from
	var mid: Vector3 = (from + to) * 0.5
	var body: StaticBody3D = add_cyl(parent, radius, maxf(delta.length(), 0.1), mid, mats.metal)
	if absf(delta.y) < 0.05 and absf(delta.x) >= absf(delta.z):
		body.rotation.z = PI * 0.5
	elif absf(delta.y) < 0.05:
		body.rotation.x = PI * 0.5


static func add_shelf(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.35, 1.9, 0.38), pos + Vector3(0, 0.95, 0), mats.metal)
	for i in 3:
		add_box(parent, Vector3(1.25, 0.05, 0.34), pos + Vector3(0, 0.4 + float(i) * 0.5, 0), mats.wood)
		add_box(parent, Vector3(0.18, 0.22, 0.16), pos + Vector3(-0.35, 0.52 + float(i) * 0.5, 0), mats.concrete)
		add_box(parent, Vector3(0.16, 0.26, 0.14), pos + Vector3(0.32, 0.54 + float(i) * 0.5, 0), mats.metal)


static func add_workbench(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.9, 0.08, 0.72), pos + Vector3(0, 0.78, 0), mats.wood)
	add_box(parent, Vector3(0.1, 0.78, 0.1), pos + Vector3(-0.8, 0.39, -0.26), mats.metal)
	add_box(parent, Vector3(0.1, 0.78, 0.1), pos + Vector3(0.8, 0.39, -0.26), mats.metal)
	add_box(parent, Vector3(0.1, 0.78, 0.1), pos + Vector3(-0.8, 0.39, 0.26), mats.metal)
	add_box(parent, Vector3(0.1, 0.78, 0.1), pos + Vector3(0.8, 0.39, 0.26), mats.metal)
	add_box(parent, Vector3(0.45, 0.22, 0.28), pos + Vector3(-0.4, 0.92, 0), mats.metal)


static func add_crate(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(0.55, 0.45, 0.45), pos + Vector3(0, 0.22, 0), mats.wood)


static func add_neon_strip(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	add_box(parent, size, pos, mat, 0)


static func add_fluorescent(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.7, 0.06, 0.1), pos, mats.fluorescent, 0)
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0, -0.15, 0)
	lamp.light_color = Color(0.95, 0.88, 0.55)
	lamp.light_energy = 0.55
	lamp.omni_range = 7.5
	parent.add_child(lamp)


static func add_grate(parent: Node3D, pos: Vector3, mats) -> void:
	add_box(parent, Vector3(1.1, 0.06, 1.1), pos, mats.metal)
	add_box(parent, Vector3(0.9, 0.04, 0.08), pos + Vector3(0, 0.04, 0), mats.metal)
	add_box(parent, Vector3(0.08, 0.04, 0.9), pos + Vector3(0, 0.04, 0), mats.metal)
