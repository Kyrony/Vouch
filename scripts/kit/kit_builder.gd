extends RefCounted
class_name KitBuilder
## Builds sealed modular room pieces with trim, lights, furniture, and sockets.

const HEIGHT: float = 2.6
const WALL_THICK: float = 0.12
const DOOR_W: float = 0.85
const DOOR_H: float = 2.05
const TRIM_H: float = 0.08
const TRIM_D: float = 0.04
const SEAM: float = 0.02

const _KM: GDScript = preload("res://scripts/kit/kit_module.gd")
const _MATS: GDScript = preload("res://scripts/kit/kit_materials.gd")

const SIZES: Dictionary = {
	"living_large": Vector2(5.2, 4.8),
	"living": Vector2(4.2, 3.8),
	"bedroom": Vector2(3.6, 3.2),
	"bath": Vector2(2.6, 2.4),
	"closet": Vector2(1.6, 2.0),
	"hall": Vector2(1.9, 3.0),
	"utility": Vector2(3.2, 2.6),
	"fireplace_nook": Vector2(2.0, 1.8),
	"stairwell": Vector2(2.2, 2.8),
}


static func build(module_type: String, theme: Dictionary, options: Dictionary = {}) -> Node3D:
	var mod: Node3D = _KM.new()
	mod.name = "Module_%s" % module_type
	mod.module_type = module_type
	var size: Vector2 = SIZES.get(module_type, SIZES["living"])
	var w := size.x
	var d := size.y
	var mats: Dictionary = _MATS.call("for_module", module_type, theme)
	var open_n: bool = options.get("open_n", false)
	var open_s: bool = options.get("open_s", false)
	var open_e: bool = options.get("open_e", false)
	var open_w: bool = options.get("open_w", false)
	var role: String = options.get("role", module_type)

	var geo := Node3D.new()
	geo.name = "Geometry"
	mod.add_child(geo)

	_add_floor(geo, w, d, mats["floor"])
	_add_ceiling(geo, w, d, mats["ceiling"])
	if not open_s:
		_add_wall(geo, true, d * 0.5, w, 0.0, 0.0, mats["wall"], options.get("door_s", false), mats["frame"])
	if not open_n:
		_add_wall(geo, true, -d * 0.5, w, 0.0, 0.0, mats["wall"], options.get("door_n", false), mats["frame"])
	if not open_e:
		_add_wall(geo, false, w * 0.5, d, 0.0, 0.0, mats["wall"], options.get("door_e", false), mats["frame"])
	if not open_w:
		_add_wall(geo, false, -w * 0.5, d, 0.0, 0.0, mats["wall"], options.get("door_w", false), mats["frame"])

	_add_trim(geo, w, d, mats["trim"], open_n, open_s, open_e, open_w)
	_add_corner_posts(geo, w, d, mats["trim"])
	_add_furniture(geo, module_type, w, d, mats)
	_add_ceiling_light(mod, w, d, mats["light"])

	var sockets := Node3D.new()
	sockets.name = "Sockets"
	mod.add_child(sockets)
	_add_socket(sockets, "RoomCenter", Vector3.ZERO)
	if role == "living" or options.get("spawn_here", false):
		_add_socket(sockets, "SpawnPoint", Vector3(0, 0.1, d * 0.35))
	if not open_n:
		_add_socket(sockets, "Door_N", Vector3(0, DOOR_H * 0.5, -d * 0.5))
	if not open_s:
		_add_socket(sockets, "Door_S", Vector3(0, DOOR_H * 0.5, d * 0.5))
	if not open_e:
		_add_socket(sockets, "Door_E", Vector3(w * 0.5, DOOR_H * 0.5, 0))
	if not open_w:
		_add_socket(sockets, "Door_W", Vector3(-w * 0.5, DOOR_H * 0.5, 0))
	if options.get("corridor_out", false):
		_add_socket(sockets, "CorridorOut", Vector3(0, DOOR_H * 0.5, d * 0.5))
	if module_type == "bath":
		_add_socket(sockets, "Vent_Ceiling", Vector3(0, HEIGHT - 0.15, 0))
	if role == "living" or module_type.begins_with("living"):
		_add_socket(sockets, "Mount_Switch", Vector3(-w * 0.42, 1.25, 0.1))
		_add_socket(sockets, "Mount_Phone", Vector3(w * 0.42, 1.15, -0.1))
		_add_socket(sockets, "Mount_Camera", Vector3(w * 0.38, 2.35, -d * 0.38))
		_add_socket(sockets, "Mount_Fireplace", Vector3(-w * 0.22, 0.5, -d * 0.28))
	if module_type == "stairwell":
		_build_stairs(geo, w, d, mats)

	return mod


static func footprint(modules: Array) -> Vector2:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for entry in modules:
		var mod: Node3D = entry["node"]
		var module_type: String = mod.get("module_type")
		var size: Vector2 = SIZES.get(module_type, SIZES["living"])
		var hw := size.x * 0.5
		var hd := size.y * 0.5
		var p: Vector3 = mod.position
		min_x = minf(min_x, p.x - hw)
		max_x = maxf(max_x, p.x + hw)
		min_z = minf(min_z, p.z - hd)
		max_z = maxf(max_z, p.z + hd)
	if min_x == INF:
		return Vector2(6.0, 6.0)
	return Vector2(max_x - min_x, max_z - min_z)


static func _add_floor(parent: Node3D, w: float, d: float, mat: Material) -> void:
	parent.add_child(_box_body(Vector3(w + SEAM, WALL_THICK, d + SEAM), Vector3(0, -WALL_THICK * 0.5, 0), mat))


static func _add_ceiling(parent: Node3D, w: float, d: float, mat: Material) -> void:
	parent.add_child(_box_body(Vector3(w + SEAM, WALL_THICK, d + SEAM), Vector3(0, HEIGHT + WALL_THICK * 0.5, 0), mat, false))


static func _add_wall(parent: Node3D, is_x: bool, offset: float, span: float, gap_w: float, gap_center: float, mat: Material, has_door: bool, frame_mat: Material) -> void:
	var gap := DOOR_W if has_door else gap_w
	var center := gap_center
	if has_door:
		center = 0.0
	if gap <= 0.01:
		var size := Vector3(span, HEIGHT, WALL_THICK) if is_x else Vector3(WALL_THICK, HEIGHT, span)
		var pos := Vector3(0, HEIGHT * 0.5, offset) if is_x else Vector3(offset, HEIGHT * 0.5, 0)
		parent.add_child(_box_body(size, pos, mat))
		return

	var half := span * 0.5
	var seg1 := (center - gap * 0.5) - (-half)
	var seg2 := half - (center + gap * 0.5)
	if seg1 > 0.05:
		var c1 := -half + seg1 * 0.5
		var s1 := Vector3(seg1, HEIGHT, WALL_THICK) if is_x else Vector3(WALL_THICK, HEIGHT, seg1)
		var p1 := Vector3(c1, HEIGHT * 0.5, offset) if is_x else Vector3(offset, HEIGHT * 0.5, c1)
		parent.add_child(_box_body(s1, p1, mat))
	if seg2 > 0.05:
		var c2 := center + gap * 0.5 + seg2 * 0.5
		var s2 := Vector3(seg2, HEIGHT, WALL_THICK) if is_x else Vector3(WALL_THICK, HEIGHT, seg2)
		var p2 := Vector3(c2, HEIGHT * 0.5, offset) if is_x else Vector3(offset, HEIGHT * 0.5, c2)
		parent.add_child(_box_body(s2, p2, mat))
	if has_door and gap > 0.05:
		var lintel_h := HEIGHT - DOOR_H
		var lintel_y := DOOR_H + lintel_h * 0.5
		var ls := Vector3(gap, lintel_h, WALL_THICK) if is_x else Vector3(WALL_THICK, lintel_h, gap)
		var lp := Vector3(center, lintel_y, offset) if is_x else Vector3(offset, lintel_y, center)
		parent.add_child(_box_body(ls, lp, mat))
		_add_door_frame(parent, is_x, offset, center, frame_mat)


static func _add_door_frame(parent: Node3D, is_x: bool, wall_offset: float, gap_center: float, mat: Material) -> void:
	var ft := 0.06
	var side_h := DOOR_H
	var side_size := Vector3(ft, side_h, WALL_THICK + 0.02) if is_x else Vector3(WALL_THICK + 0.02, side_h, ft)
	var left_pos := Vector3(gap_center - DOOR_W * 0.5 - ft * 0.5, side_h * 0.5, wall_offset) if is_x else Vector3(wall_offset, side_h * 0.5, gap_center - DOOR_W * 0.5 - ft * 0.5)
	var right_pos := Vector3(gap_center + DOOR_W * 0.5 + ft * 0.5, side_h * 0.5, wall_offset) if is_x else Vector3(wall_offset, side_h * 0.5, gap_center + DOOR_W * 0.5 + ft * 0.5)
	parent.add_child(_box_body(side_size, left_pos, mat, false))
	parent.add_child(_box_body(side_size, right_pos, mat, false))
	var top_size := Vector3(DOOR_W + ft * 2.0, ft, WALL_THICK + 0.02) if is_x else Vector3(WALL_THICK + 0.02, ft, DOOR_W + ft * 2.0)
	var top_pos := Vector3(gap_center, DOOR_H + ft * 0.5, wall_offset) if is_x else Vector3(wall_offset, DOOR_H + ft * 0.5, gap_center)
	parent.add_child(_box_body(top_size, top_pos, mat, false))


static func _add_trim(parent: Node3D, w: float, d: float, mat: Material, open_n: bool, open_s: bool, open_e: bool, open_w: bool) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var y := TRIM_H * 0.5
	if not open_s:
		parent.add_child(_box_body(Vector3(w, TRIM_H, TRIM_D), Vector3(0, y, hd - TRIM_D * 0.5), mat, false))
	if not open_n:
		parent.add_child(_box_body(Vector3(w, TRIM_H, TRIM_D), Vector3(0, y, -hd + TRIM_D * 0.5), mat, false))
	if not open_e:
		parent.add_child(_box_body(Vector3(TRIM_D, TRIM_H, d), Vector3(hw - TRIM_D * 0.5, y, 0), mat, false))
	if not open_w:
		parent.add_child(_box_body(Vector3(TRIM_D, TRIM_H, d), Vector3(-hw + TRIM_D * 0.5, y, 0), mat, false))


static func _add_corner_posts(parent: Node3D, w: float, d: float, mat: Material) -> void:
	var hw := w * 0.5 - TRIM_D
	var hd := d * 0.5 - TRIM_D
	var post := Vector3(TRIM_D * 1.6, HEIGHT, TRIM_D * 1.6)
	for xz in [Vector3(-hw, HEIGHT * 0.5, -hd), Vector3(hw, HEIGHT * 0.5, -hd), Vector3(-hw, HEIGHT * 0.5, hd), Vector3(hw, HEIGHT * 0.5, hd)]:
		parent.add_child(_box_body(post, xz, mat, false))


static func _add_furniture(parent: Node3D, module_type: String, w: float, d: float, mats: Dictionary) -> void:
	var wood: Material = mats.get("trim", mats["floor"])
	match module_type:
		"living", "living_large":
			parent.add_child(_box_body(Vector3(1.8, 0.42, 0.9), Vector3(0.4, 0.21, -0.3), wood, false))
			parent.add_child(_box_body(Vector3(0.9, 0.38, 0.9), Vector3(-0.9, 0.19, 0.5), wood, false))
		"bedroom":
			parent.add_child(_box_body(Vector3(1.6, 0.55, 2.0), Vector3(0, 0.275, -0.2), wood, false))
			parent.add_child(_box_body(Vector3(0.5, 0.65, 0.4), Vector3(-0.9, 0.325, 0.6), wood, false))
		"bath":
			parent.add_child(_box_body(Vector3(0.55, 0.45, 0.7), Vector3(-0.5, 0.225, -0.4), mats["wall"], false))
			parent.add_child(_box_body(Vector3(0.35, 0.85, 0.35), Vector3(0.6, 0.425, 0.5), mats["wall"], false))
		"utility":
			parent.add_child(_box_body(Vector3(0.6, 1.4, 0.5), Vector3(-0.7, 0.7, 0), mats["wall"], false))
			parent.add_child(_box_body(Vector3(0.5, 0.9, 0.4), Vector3(0.7, 0.45, -0.5), mats["wall"], false))
		"closet":
			parent.add_child(_box_body(Vector3(0.9, 1.8, 0.35), Vector3(0, 0.9, -0.5), wood, false))
		"hall":
			parent.add_child(_box_body(Vector3(0.35, 0.9, 0.25), Vector3(0.5, 0.45, 0), wood, false))
		"fireplace_nook":
			var hearth := Vector3(1.2, 0.35, 0.5)
			parent.add_child(_box_body(hearth, Vector3(0, 0.175, -0.4), mats["frame"], false))
		_:
			pass


static func _add_ceiling_light(mod: Node3D, w: float, d: float, light_color: Color) -> void:
	var light_root := Node3D.new()
	light_root.name = "CeilingLight"
	light_root.position = Vector3(0, HEIGHT - 0.25, 0)
	var omni := OmniLight3D.new()
	omni.light_color = light_color
	omni.light_energy = 1.4
	omni.omni_range = maxf(w, d) + 1.5
	omni.shadow_enabled = true
	light_root.add_child(omni)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	bulb.mesh = sphere
	var bm := StandardMaterial3D.new()
	bm.albedo_color = light_color
	bm.emission_enabled = true
	bm.emission = light_color
	bm.emission_energy_multiplier = 1.5
	bulb.set_surface_override_material(0, bm)
	light_root.add_child(bulb)
	mod.add_child(light_root)


static func _build_stairs(parent: Node3D, w: float, d: float, mats: Dictionary) -> void:
	var steps := maxi(int(ceil(HEIGHT / 0.18)), 5)
	var step_h := HEIGHT / float(steps)
	var tread := 0.28
	var z0 := -d * 0.45
	for i in range(steps):
		var sy := i * step_h
		parent.add_child(_box_body(
			Vector3(w * 0.85, step_h, tread + SEAM),
			Vector3(0, sy + step_h * 0.5, z0 + tread * (i + 0.5)),
			mats["floor"]
		))
	parent.add_child(_box_body(Vector3(WALL_THICK, HEIGHT, d * 0.9), Vector3(-w * 0.45, HEIGHT * 0.5, 0), mats["wall"]))
	parent.add_child(_box_body(Vector3(WALL_THICK, HEIGHT, d * 0.9), Vector3(w * 0.45, HEIGHT * 0.5, 0), mats["wall"]))


static func _add_socket(parent: Node3D, socket_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = socket_name
	m.position = pos
	parent.add_child(m)


static func _box_body(size: Vector3, pos: Vector3, mat: Material, collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if collision else 0
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	if collision:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
	return body
