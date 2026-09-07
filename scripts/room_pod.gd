extends Node3D
class_name RoomPod
## RoomPod
##
## One player's room - built from James's floor-plan templates (1 ft = 1
## Godot unit) or a simple box for the Puppet Master. A per-room seed picks
## theme and layout details; `floor_plan_id` and spawn odds are decided
## server-side in `plan_recipe()` and baked into replicated spawn data.
##
## TODO(post-MVP): richer decoration, hand-authored props per plan.

const _FPT_SCRIPT: GDScript = preload("res://scripts/systems/floor_plan_templates.gd")
const HEIGHT: float = 10.0
const DOOR_W: float = 3.5
const DOOR_H: float = 7.0
const WALL_THICK: float = 0.2
const SEAM_OVERLAP: float = 0.06
const PM_BOX_SIZE: float = 10.0

const THEMES: Array[Dictionary] = [
	{
		"id": "bedroom",
		"name": "Bedroom",
		"wall_color": Color(0.5, 0.38, 0.32),
		"floor_color": Color(0.32, 0.22, 0.16),
		"accent_color": Color(0.62, 0.5, 0.34),
		"light_color": Color(1.0, 0.88, 0.68),
	},
	{
		"id": "utility",
		"name": "Utility Room",
		"wall_color": Color(0.4, 0.44, 0.42),
		"floor_color": Color(0.24, 0.27, 0.26),
		"accent_color": Color(0.55, 0.62, 0.3),
		"light_color": Color(0.85, 0.95, 1.0),
	},
	{
		"id": "basement",
		"name": "Creepy Basement",
		"wall_color": Color(0.15, 0.14, 0.16),
		"floor_color": Color(0.08, 0.08, 0.09),
		"accent_color": Color(0.22, 0.26, 0.24),
		"light_color": Color(0.72, 0.85, 0.74),
	},
]

enum EscapeKind { DOOR, VENT, NONE }

const CRATE_SCENE: PackedScene = preload("res://scenes/Match/Props/Crate.tscn")
const SHELF_SCENE: PackedScene = preload("res://scenes/Match/Props/Shelf.tscn")
const BARREL_SCENE: PackedScene = preload("res://scenes/Match/Props/Barrel.tscn")
const LIGHT_SWITCH_SCRIPT: Script = preload("res://scripts/interactables/light_switch.gd")
const DOOR_SCRIPT: Script = preload("res://scripts/interactables/door.gd")
const PHONE_SCRIPT: Script = preload("res://scripts/interactables/phone.gd")
const ROOM_LIGHT_SCRIPT: Script = preload("res://scripts/interactables/room_light.gd")
const SECURITY_CAMERA_SCRIPT: Script = preload("res://scripts/interactables/security_camera.gd")
const CODE_KEYPAD_SCRIPT: Script = preload("res://scripts/interactables/code_keypad.gd")
const CLUE_BOOK_SCRIPT: Script = preload("res://scripts/interactables/clue_book.gd")
const CLUE_FLAME_PAPER_SCRIPT: Script = preload("res://scripts/interactables/clue_flame_paper.gd")
const FLAME_SCRIPT: Script = preload("res://scripts/interactables/flame.gd")
const MOVABLE_PROP_SCRIPT: Script = preload("res://scripts/interactables/movable_prop.gd")
const WATER_VALVE_SCRIPT: Script = preload("res://scripts/interactables/water_valve.gd")
const BROKEN_PIPE_SCRIPT: Script = preload("res://scripts/interactables/broken_pipe.gd")
const LADDER_SCENE: PackedScene = preload("res://scenes/Match/Interactables/Ladder.tscn")
const ELECTRICAL_BOX_SCRIPT: Script = preload("res://scripts/interactables/electrical_box.gd")
const GAS_VALVE_SCRIPT: Script = preload("res://scripts/interactables/gas_valve.gd")
const GAS_LEAK_SCRIPT: Script = preload("res://scripts/interactables/gas_leak.gd")

var room_index: int = 0
var owner_peer_id: int = -1
var rng_seed: int = 0
var is_puppet_master_room: bool = false
var floor_plan_id: String = "01"
var theme_id: String = ""
var theme_name: String = ""
var width: float = 6.0
var depth: float = 6.0

var spawn_point: Marker3D
var light_switch: Node
var _theme: Dictionary = THEMES[0]
var _plan: Dictionary = {}
var _zone_centers: Dictionary = {}


static func plan_recipe(is_pm: bool, _room_count: int = 8) -> Dictionary:
	var floor_plan_id := "01"
	if not is_pm:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		floor_plan_id = str(_FPT_SCRIPT.call("pick_id", rng))

	var has_valve := not is_pm and randf() < MatchSettings.flood_valve_chance
	var has_electrical_box := not is_pm and randf() < 0.35
	var wire_targets: Array = []

	return {
		"floor_plan_id": floor_plan_id,
		"has_valve": has_valve,
		"has_electrical_box": has_electrical_box,
		"wire_targets": wire_targets,
	}


func configure(data: Dictionary) -> void:
	room_index = data["room_index"]
	owner_peer_id = data["owner_peer_id"]
	rng_seed = data["rng_seed"]
	is_puppet_master_room = data.get("is_puppet_master", false)
	floor_plan_id = data.get("floor_plan_id", "01")
	name = "RoomPod_%d" % room_index

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var theme: Dictionary = THEMES[rng.randi() % THEMES.size()]
	_theme = theme
	theme_id = theme["id"]
	theme_name = theme["name"]

	var escape_kind: EscapeKind
	if is_puppet_master_room:
		escape_kind = EscapeKind.NONE
	elif rng.randf() < 0.6:
		escape_kind = EscapeKind.DOOR
	else:
		escape_kind = EscapeKind.VENT

	var has_valve: bool = data.get("has_valve", false)
	var has_electrical_box: bool = data.get("has_electrical_box", false)
	var wire_targets: Array = data.get("wire_targets", [])

	var has_pipes := rng.randf() < 0.5
	var has_wires := rng.randf() < 0.4

	if is_puppet_master_room:
		width = PM_BOX_SIZE
		depth = PM_BOX_SIZE
		_build_pm_shell(theme, escape_kind)
	else:
		_plan = _FPT_SCRIPT.call("get_plan", floor_plan_id)
		width = _plan["w"]
		depth = _plan["d"]
		_cache_zone_centers(_plan)
		_build_floor_plan_shell(theme, escape_kind)

	_build_decor(rng, theme, has_pipes, has_wires)
	_build_interactables(rng, theme, escape_kind, has_valve, has_electrical_box, wire_targets)
	_build_prop_scatter(rng)

	if is_puppet_master_room:
		_build_monitors(theme)

	var requires_code: bool = data.get("requires_code", false)
	if requires_code:
		mark_escape_locked()

	var clue_kind: String = data.get("clue_kind", "")
	if not clue_kind.is_empty():
		add_clue_prop(clue_kind, data.get("clue_code", ""))


func get_spawn_transform() -> Transform3D:
	return spawn_point.global_transform


func mark_escape_locked() -> void:
	if not has_node("EscapePoint"):
		return
	var escape_point: Door = get_node("EscapePoint")
	escape_point.prompt_text += " (locked - needs a code)"

	var living := _zone_center("living")
	var keypad_pos := living + Vector3(0.7, -0.3, 0.0)
	var keypad := _make_interactable(CODE_KEYPAD_SCRIPT, Vector3(0.24, 0.32, 0.06), keypad_pos, _accent_material(_theme["accent_color"]), "Enter code")
	var keypad_script: CodeKeypad = keypad
	keypad_script.room_index = room_index
	keypad.name = "CodeKeypad"
	add_child(keypad)


func add_clue_prop(kind: String, code: String) -> void:
	var nook := _zone_center("living") + Vector3(-1.0, 0.9, 1.0)
	if kind == "flame_paper":
		var flame := Node3D.new()
		flame.set_script(FLAME_SCRIPT)
		flame.name = "Flame"
		flame.add_to_group("flames")
		flame.position = nook + Vector3(0.4, -0.5, 0)
		var flame_light := OmniLight3D.new()
		flame_light.light_color = Color(1.0, 0.5, 0.15)
		flame_light.light_energy = 1.2
		flame_light.omni_range = 3.0
		flame.add_child(flame_light)
		var flame_area := Area3D.new()
		flame_area.name = "GlowArea"
		flame_area.monitoring = false
		flame_area.monitorable = false
		var flame_shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 2.5
		flame_shape.shape = sphere_shape
		flame_area.add_child(flame_shape)
		flame.add_child(flame_area)
		var flame_mesh := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.12
		cone.height = 0.3
		flame_mesh.mesh = cone
		flame_mesh.position = Vector3(0, 0.15, 0)
		var flame_mat := StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.45, 0.1)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.4, 0.05)
		flame_mat.emission_energy_multiplier = 2.5
		flame_mesh.set_surface_override_material(0, flame_mat)
		flame.add_child(flame_mesh)
		add_child(flame)

		var paper := _make_interactable(CLUE_FLAME_PAPER_SCRIPT, Vector3(0.3, 0.02, 0.4), nook, _accent_material(Color(0.85, 0.8, 0.65)), "Pick up paper")
		var paper_script: ClueFlamePaper = paper
		paper_script.revealed_code = code
		paper_script.flame = flame
		paper.name = "ClueFlamePaper"
		add_child(paper)
	else:
		var book := _make_interactable(CLUE_BOOK_SCRIPT, Vector3(0.3, 0.25, 0.35), nook, _accent_material(Color(0.5, 0.35, 0.22)), "Read book")
		var book_script: ClueBook = book
		book_script.revealed_text = "A page has a code scrawled in the corner: %s" % code
		book.name = "ClueBook"
		add_child(book)


# ---------------------------------------------------------------------
# Puppet Master simple box (unchanged from modular era)
# ---------------------------------------------------------------------

func _build_pm_shell(theme: Dictionary, escape_kind: EscapeKind) -> void:
	var wall_mat := _wall_material(theme["wall_color"])
	var floor_mat := _wall_material(theme["floor_color"])

	add_child(_make_box_body(Vector3(width, WALL_THICK, depth), Vector3(0, -WALL_THICK / 2.0, 0), floor_mat, 1))
	var ceiling := MeshInstance3D.new()
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = Vector3(width, WALL_THICK, depth)
	ceiling.mesh = ceiling_mesh
	ceiling.set_surface_override_material(0, wall_mat)
	ceiling.position = Vector3(0, HEIGHT + WALL_THICK / 2.0, 0)
	add_child(ceiling)

	var south_gap := 0.0 if escape_kind == EscapeKind.NONE else (DOOR_W if escape_kind == EscapeKind.DOOR else 0.9)
	_build_wall(true, depth / 2.0, width, south_gap, 0.0, wall_mat, HEIGHT)
	_build_wall(true, -depth / 2.0, width, 0.0, 0.0, wall_mat, HEIGHT)
	_build_wall(false, width / 2.0, depth, 0.0, 0.0, wall_mat, HEIGHT)
	_build_wall(false, -width / 2.0, depth, 0.0, 0.0, wall_mat, HEIGHT)

	spawn_point = Marker3D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = Vector3(0, 0.1, depth / 2.0 - 1.5)
	add_child(spawn_point)


# ---------------------------------------------------------------------
# Floor-plan shell (James templates)
# ---------------------------------------------------------------------

func _cache_zone_centers(plan: Dictionary) -> void:
	_zone_centers.clear()
	var pw: float = plan["w"]
	var pd: float = plan["d"]
	for zone in plan.get("zones", []):
		var role: String = zone.get("role", "")
		if role.is_empty():
			continue
		var cx: float = float(zone["x"]) + float(zone["w"]) * 0.5 - pw * 0.5
		var cz: float = pd * 0.5 - (float(zone["z"]) + float(zone["d"]) * 0.5)
		if not _zone_centers.has(role):
			_zone_centers[role] = Vector3(cx, 0.0, cz)
		else:
			_zone_centers[role] = (_zone_centers[role] + Vector3(cx, 0.0, cz)) * 0.5


func _zone_center(role: String) -> Vector3:
	if _zone_centers.has(role):
		return _zone_centers[role]
	return Vector3(0, 0, depth * 0.25)


func _plan_x_to_world(plan_x: float) -> float:
	return plan_x - width * 0.5


func _plan_z_to_world(plan_z: float) -> float:
	return depth * 0.5 - plan_z


func _build_floor_plan_shell(theme: Dictionary, escape_kind: EscapeKind) -> void:
	var wall_mat := _wall_material(theme["wall_color"])
	var floor_mat := _wall_material(theme["floor_color"])
	var pw: float = _plan["w"]
	var pd: float = _plan["d"]

	add_child(_make_box_body(Vector3(pw, WALL_THICK, pd), Vector3(0, -WALL_THICK / 2.0, 0), floor_mat, 1))

	var segments := _collect_wall_segments(_plan)
	for door in _plan.get("doors", []):
		_apply_door_gap(segments, door, pw, pd, escape_kind)

	for seg in segments:
		if seg.get("skip", false):
			continue
		var gap_w: float = seg.get("gap_w", 0.0)
		var gap_center: float = seg.get("gap_center", 0.0)
		if seg["axis"] == "x":
			_build_wall(true, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT)
		else:
			_build_wall(false, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT)

	_build_floor_plan_ceiling(wall_mat, pw, pd, null)

	if _plan.get("stories", 1) >= 2:
		_build_upper_floor(theme, wall_mat, floor_mat, escape_kind)

	var entry: Dictionary = _FPT_SCRIPT.call("entry_door", _plan)
	var spawn_x := _plan_x_to_world(entry.get("gap_start", pw * 0.5 - 2) + entry.get("gap_w", 4) * 0.5)
	spawn_point = Marker3D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = Vector3(spawn_x, 0.1, _plan_z_to_world(1.5))
	add_child(spawn_point)


func _build_floor_plan_ceiling(material: Material, pw: float, pd: float, stair: Variant) -> void:
	var ceiling_y := HEIGHT + WALL_THICK / 2.0
	if stair == null:
		var ceiling := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(pw, WALL_THICK, pd)
		ceiling.mesh = mesh
		ceiling.set_surface_override_material(0, material)
		ceiling.position = Vector3(0, ceiling_y, 0)
		add_child(ceiling)
		return

	var sx: float = stair["x"]
	var sz: float = stair["z"]
	var sw: float = stair["w"]
	var sd: float = stair["d"]
	var hole_x0 := _plan_x_to_world(sx)
	var hole_x1 := _plan_x_to_world(sx + sw)
	var hole_z0 := _plan_z_to_world(sz + sd)
	var hole_z1 := _plan_z_to_world(sz)

	_add_ceiling_strip(material, ceiling_y, -pw * 0.5, hole_x0, pd, -pd * 0.5)
	_add_ceiling_strip(material, ceiling_y, hole_x1, pw * 0.5, pd, -pd * 0.5)
	_add_ceiling_strip(material, ceiling_y, hole_x0, hole_x1, -pd * 0.5, hole_z1)
	_add_ceiling_strip(material, ceiling_y, hole_x0, hole_x1, hole_z0, pd * 0.5)


func _add_ceiling_strip(material: Material, y: float, x0: float, x1: float, z0: float, z1: float) -> void:
	var w := x1 - x0
	var d := z1 - z0
	if w < 0.05 or d < 0.05:
		return
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, WALL_THICK, d)
	strip.mesh = mesh
	strip.set_surface_override_material(0, material)
	strip.position = Vector3(x0 + w * 0.5, y, z0 + d * 0.5)
	add_child(strip)


func _collect_wall_segments(plan: Dictionary) -> Array:
	var pw: float = plan["w"]
	var pd: float = plan["d"]
	var zones: Array = plan.get("zones", [])
	var segments: Array = []
	var seen: Dictionary = {}

	for zone in zones:
		var x: float = zone["x"]
		var z: float = zone["z"]
		var w: float = zone["w"]
		var d: float = zone["d"]
		var role: String = zone.get("role", "")

		_try_add_edge(segments, seen, zones, zone, "s", x, x + w, z, role, pw, pd)
		_try_add_edge(segments, seen, zones, zone, "n", x, x + w, z + d, role, pw, pd)
		_try_add_edge(segments, seen, zones, zone, "w", z, z + d, x, role, pw, pd)
		_try_add_edge(segments, seen, zones, zone, "e", z, z + d, x + w, role, pw, pd)

	return segments


func _try_add_edge(segments: Array, seen: Dictionary, zones: Array, zone: Dictionary, side: String, span_a: float, span_b: float, fixed_plan: float, role: String, pw: float, pd: float) -> void:
	var is_exterior := false
	var neighbor: Dictionary = {}

	match side:
		"s":
			is_exterior = fixed_plan <= 0.001
			if not is_exterior:
				neighbor = _find_neighbor(zones, zone, 0, -1)
		"n":
			is_exterior = fixed_plan >= pd - 0.001
			if not is_exterior:
				neighbor = _find_neighbor(zones, zone, 0, 1)
		"w":
			is_exterior = fixed_plan <= 0.001
			if not is_exterior:
				neighbor = _find_neighbor(zones, zone, -1, 0)
		"e":
			is_exterior = fixed_plan >= pw - 0.001
			if not is_exterior:
				neighbor = _find_neighbor(zones, zone, 1, 0)

	if not is_exterior and not neighbor.is_empty():
		if role == "living" and neighbor.get("role", "") == "living":
			return

	var key := "%s_%.2f_%.2f_%.2f" % [side, fixed_plan, span_a, span_b]
	if seen.has(key):
		return
	seen[key] = true

	var seg: Dictionary = {"gap_w": 0.0, "gap_center": 0.0, "skip": false}
	if side == "s" or side == "n":
		seg["axis"] = "x"
		seg["fixed"] = _plan_z_to_world(fixed_plan)
		seg["span"] = span_b - span_a
		seg["gap_center"] = _plan_x_to_world((span_a + span_b) * 0.5) - (-(span_b - span_a) * 0.5)
		seg["plan_fixed"] = fixed_plan
		seg["plan_span_a"] = span_a
		seg["plan_span_b"] = span_b
		seg["plan_side"] = side
	else:
		seg["axis"] = "z"
		seg["fixed"] = _plan_x_to_world(fixed_plan)
		seg["span"] = span_b - span_a
		seg["gap_center"] = _plan_z_to_world((span_a + span_b) * 0.5) - (-(span_b - span_a) * 0.5)
		seg["plan_fixed"] = fixed_plan
		seg["plan_span_a"] = span_a
		seg["plan_span_b"] = span_b
		seg["plan_side"] = side

	segments.append(seg)


func _find_neighbor(zones: Array, zone: Dictionary, dx: int, dz: int) -> Dictionary:
	var x: float = zone["x"]
	var z: float = zone["z"]
	var w: float = zone["w"]
	var d: float = zone["d"]
	for other in zones:
		if other == zone:
			continue
		var ox: float = other["x"]
		var oz: float = other["z"]
		var ow: float = other["w"]
		var od: float = other["d"]
		if dx == 0 and dz == -1 and absf(oz + od - z) < 0.01:
			if ox < x + w - 0.01 and ox + ow > x + 0.01:
				return other
		if dx == 0 and dz == 1 and absf(oz - (z + d)) < 0.01:
			if ox < x + w - 0.01 and ox + ow > x + 0.01:
				return other
		if dx == -1 and absf(ox + ow - x) < 0.01:
			if oz < z + d - 0.01 and oz + od > z + 0.01:
				return other
		if dx == 1 and absf(ox - (x + w)) < 0.01:
			if oz < z + d - 0.01 and oz + od > z + 0.01:
				return other
	return {}


func _apply_door_gap(segments: Array, door: Dictionary, pw: float, pd: float, escape_kind: EscapeKind) -> void:
	var kind: String = door.get("kind", "")
	var gap_start: float = door.get("gap_start", 0.0)
	var gap_w: float = door.get("gap_w", DOOR_W)
	var is_escape: bool = door.get("exterior", false) and escape_kind == EscapeKind.DOOR
	if is_escape:
		gap_w = maxf(gap_w, DOOR_W)

	for seg in segments:
		if not _segment_matches_door(seg, kind, door.get("pos", 0.0), pw, pd):
			continue
		if gap_start + gap_w < seg["plan_span_a"] - 0.01 or gap_start > seg["plan_span_b"] + 0.01:
			continue
		var overlap_a := maxf(gap_start, seg["plan_span_a"])
		var overlap_b := minf(gap_start + gap_w, seg["plan_span_b"])
		if overlap_b - overlap_a < 0.5:
			continue
		if kind == "s" or kind == "n":
			seg["gap_w"] = overlap_b - overlap_a
			seg["gap_center"] = _plan_x_to_world(overlap_a + (overlap_b - overlap_a) * 0.5)
		else:
			seg["gap_w"] = overlap_b - overlap_a
			seg["gap_center"] = _plan_z_to_world(overlap_a + (overlap_b - overlap_a) * 0.5)


func _segment_matches_door(seg: Dictionary, kind: String, pos: float, pw: float, pd: float) -> bool:
	match kind:
		"s":
			return seg["axis"] == "x" and absf(seg["plan_fixed"]) < 0.01
		"n":
			return seg["axis"] == "x" and absf(seg["plan_fixed"] - pd) < 0.01
		"w":
			return seg["axis"] == "z" and absf(seg["plan_fixed"]) < 0.01
		"e":
			return seg["axis"] == "z" and absf(seg["plan_fixed"] - pw) < 0.01
		"v":
			return seg["axis"] == "z" and absf(seg["plan_fixed"] - pos) < 0.01
		"h":
			return seg["axis"] == "x" and absf(seg["plan_fixed"] - pos) < 0.01
	return false


func _build_upper_floor(theme: Dictionary, wall_mat: Material, floor_mat: Material, escape_kind: EscapeKind) -> void:
	var f2: Dictionary = _plan.get("floor2", {})
	if f2.is_empty():
		return
	var stair: Dictionary = _plan.get("stair", {})
	var pw: float = f2.get("w", _plan["w"])
	var pd2: float = f2.get("d", _plan["d"])
	var floor_y := HEIGHT
	var deck_z := depth * 0.5 - pd2 * 0.5

	var upper_plan := _plan.duplicate(true)
	upper_plan["w"] = pw
	upper_plan["d"] = pd2
	upper_plan["zones"] = f2.get("zones", [])
	upper_plan["doors"] = f2.get("doors", [])

	add_child(_make_box_body(Vector3(pw, WALL_THICK, pd2), Vector3(0, floor_y - WALL_THICK / 2.0, deck_z), floor_mat, 1))

	var segments := _collect_wall_segments(upper_plan)
	for door in f2.get("doors", []):
		_apply_door_gap(segments, door, pw, pd2, escape_kind)

	for seg in segments:
		if seg.get("skip", false):
			continue
		var gap_w: float = seg.get("gap_w", 0.0)
		var gap_center: float = seg.get("gap_center", 0.0)
		if seg["axis"] == "x":
			_build_wall_at_y(true, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, floor_y)
		else:
			_build_wall_at_y(false, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, floor_y)

	var ceiling := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(pw, WALL_THICK, pd2)
	ceiling.mesh = mesh
	ceiling.set_surface_override_material(0, wall_mat)
	ceiling.position = Vector3(0, floor_y + HEIGHT + WALL_THICK / 2.0, deck_z)
	add_child(ceiling)

	_build_floor_plan_ceiling(wall_mat, pw, _plan["d"], stair)
	_build_stair(stair, wall_mat, floor_mat)


func _build_stair(stair: Dictionary, wall_mat: Material, floor_mat: Material) -> void:
	if stair.is_empty():
		return
	var x0 := _plan_x_to_world(stair["x"])
	var x1 := _plan_x_to_world(stair["x"] + stair["w"])
	var z0 := _plan_z_to_world(stair["z"] + stair["d"])
	var z1 := _plan_z_to_world(stair["z"])
	var steps := 6
	var step_h := HEIGHT / steps
	var step_d := (z1 - z0) / steps
	for i in range(steps):
		var sy := i * step_h
		add_child(_make_box_body(
			Vector3(x1 - x0, step_h, step_d + SEAM_OVERLAP),
			Vector3((x0 + x1) * 0.5, sy + step_h * 0.5, z0 + step_d * (i + 0.5)),
			floor_mat, 1
		))
	var rail_h := HEIGHT
	add_child(_make_box_body(Vector3(WALL_THICK, rail_h, stair["d"]), Vector3(x0 - WALL_THICK * 0.5, rail_h * 0.5, (z0 + z1) * 0.5), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, rail_h, stair["d"]), Vector3(x1 + WALL_THICK * 0.5, rail_h * 0.5, (z0 + z1) * 0.5), wall_mat, 1))


func _build_wall_at_y(is_x_axis: bool, wall_offset: float, span: float, gap_width: float, gap_center: float, material: Material, wall_height: float, base_y: float) -> void:
	if gap_width <= 0.01:
		var size := Vector3(span, wall_height, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, wall_height, span)
		var pos := Vector3(0, base_y + wall_height / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, base_y + wall_height / 2.0, 0)
		add_child(_make_box_body(size, pos, material, 1))
		return

	var half_span := span / 2.0
	var seg1_len: float = (gap_center - gap_width / 2.0) - (-half_span)
	var seg2_len: float = half_span - (gap_center + gap_width / 2.0)

	if seg1_len > 0.05:
		var seg1_center := -half_span + seg1_len / 2.0
		var size1 := Vector3(seg1_len, wall_height, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, wall_height, seg1_len)
		var pos1 := Vector3(seg1_center, base_y + wall_height / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, base_y + wall_height / 2.0, seg1_center)
		add_child(_make_box_body(size1, pos1, material, 1))

	if seg2_len > 0.05:
		var seg2_center := gap_center + gap_width / 2.0 + seg2_len / 2.0
		var size2 := Vector3(seg2_len, wall_height, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, wall_height, seg2_len)
		var pos2 := Vector3(seg2_center, base_y + wall_height / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, base_y + wall_height / 2.0, seg2_center)
		add_child(_make_box_body(size2, pos2, material, 1))


func _build_wall(is_x_axis: bool, wall_offset: float, span: float, gap_width: float, gap_center: float, material: Material, gap_height: float = HEIGHT) -> void:
	_build_wall_at_y(is_x_axis, wall_offset, span, gap_width, gap_center, material, gap_height, 0.0)


# ---------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------

func _build_interactables(rng: RandomNumberGenerator, theme: Dictionary, escape_kind: EscapeKind, has_valve: bool, has_electrical_box: bool, wire_targets: Array) -> void:
	var accent := _accent_material(theme["accent_color"])
	var living := _zone_center("living")
	var bedroom := _zone_center("bedroom") if _zone_centers.has("bedroom") else living + Vector3(2, 0, -2)
	var bath := _zone_center("bath") if _zone_centers.has("bath") else living + Vector3(-2, 0, -2)

	var control_id := "room_%d_light_switch" % room_index
	var effect_id := "room_%d_room_light" % room_index

	var switch := _make_interactable(LIGHT_SWITCH_SCRIPT, Vector3(0.15, 0.2, 0.06), living + Vector3(-width * 0.4, 1.2, 0), accent, "Flip switch")
	var switch_script: LightSwitch = switch
	switch_script.control_id = control_id
	switch_script.room_index = room_index
	switch.name = "LightSwitch"
	add_child(switch)
	light_switch = switch

	if escape_kind != EscapeKind.NONE:
		var entry: Dictionary = _FPT_SCRIPT.call("entry_door", _plan) if not _plan.is_empty() else {}
		var escape_pos: Vector3
		var escape_size: Vector3
		var escape_prompt: String
		if escape_kind == EscapeKind.DOOR and not entry.is_empty():
			var mid_x := _plan_x_to_world(entry.get("gap_start", 0) + entry.get("gap_w", 4) * 0.5)
			escape_pos = Vector3(mid_x, DOOR_H * 0.5, _plan_z_to_world(0) - 0.06)
			escape_size = Vector3(entry.get("gap_w", 4) * 0.95, DOOR_H, 0.12)
			escape_prompt = "Open the door"
		elif escape_kind == EscapeKind.DOOR:
			escape_pos = Vector3(0, DOOR_H * 0.5, depth / 2.0 - 0.06)
			escape_size = Vector3(DOOR_W, DOOR_H, 0.12)
			escape_prompt = "Open the door"
		else:
			var vent_zone := bath if _zone_centers.has("bath") else living
			escape_pos = vent_zone + Vector3(0, 0.45, -depth * 0.35)
			escape_size = Vector3(0.7, 0.55, 0.1)
			escape_prompt = "Squeeze through the vent"
		var escape_point := _make_interactable(DOOR_SCRIPT, escape_size, escape_pos, accent, escape_prompt)
		escape_point.name = "EscapePoint"
		add_child(escape_point)

	var phone := _make_interactable(PHONE_SCRIPT, Vector3(0.16, 0.26, 0.1), living + Vector3(width * 0.35, 1.2, 0), accent, "Pick up phone")
	var phone_script: Phone = phone
	phone_script.owner_peer_id = owner_peer_id
	phone.name = "Phone"
	add_child(phone)

	var camera_mount_y := HEIGHT - 0.3
	var camera := _make_interactable(SECURITY_CAMERA_SCRIPT, Vector3(0.18, 0.18, 0.28), living + Vector3(width * 0.3, camera_mount_y, -depth * 0.35), accent, "Camera")
	var camera_script: SecurityCamera = camera
	camera_script.min_elevation_y = camera_mount_y - 1.2
	camera.name = "SecurityCamera"
	add_child(camera)

	var ladder := LADDER_SCENE.instantiate() as Ladder
	ladder.position = living + Vector3(-width * 0.35, 0, -depth * 0.2)
	ladder.rotation.y = PI
	if ladder.has_method("configure"):
		ladder.configure(camera_mount_y + 0.3, room_index)
	ladder.prompt_text = "Pick up ladder"
	add_child(ladder)

	if has_valve:
		var valve_zone := bath if _zone_centers.has("bath") else living
		var valve_control_id := "room_%d_water_valve" % room_index
		var valve := _make_interactable(WATER_VALVE_SCRIPT, Vector3(0.16, 0.16, 0.12), valve_zone + Vector3(-1.0, 0.9, 0), accent, "Turn valve")
		var valve_script: WaterValve = valve
		valve_script.control_id = valve_control_id
		valve_script.room_index = room_index
		valve.name = "WaterValve"
		add_child(valve)

	if theme_id == "utility" and rng.randf() < 0.5:
		var gas_control_id := "room_%d_gas_valve" % room_index
		var gas_valve := _make_interactable(GAS_VALVE_SCRIPT, Vector3(0.14, 0.14, 0.1), living + Vector3(-width * 0.4, 1.4, -1), accent, "Turn gas valve")
		var gas_valve_script: GasValve = gas_valve
		gas_valve_script.control_id = gas_control_id
		gas_valve_script.room_index = room_index
		gas_valve.name = "GasValve"
		add_child(gas_valve)

	if has_electrical_box and not wire_targets.is_empty():
		var box := _make_interactable(ELECTRICAL_BOX_SCRIPT, Vector3(0.35, 0.45, 0.12), living + Vector3(-width * 0.4, 0.9, -1.5), accent, "Electrical box")
		var box_script: ElectricalBox = box
		box_script.configure(room_index, wire_targets)
		box.name = "ElectricalBox"
		add_child(box)

	var room_light := Node3D.new()
	room_light.set_script(ROOM_LIGHT_SCRIPT)
	room_light.name = "RoomLight"
	room_light.position = living + Vector3(0, HEIGHT - 0.3, 0)
	var bulb_light := OmniLight3D.new()
	bulb_light.name = "OmniLight3D"
	bulb_light.light_color = theme["light_color"]
	bulb_light.light_energy = 1.6
	bulb_light.omni_range = maxf(width, depth) + 2.0
	room_light.add_child(bulb_light)
	var bulb_mesh := MeshInstance3D.new()
	bulb_mesh.name = "BulbMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	bulb_mesh.mesh = sphere
	bulb_mesh.set_surface_override_material(0, preload("res://assets/materials/bulb_emissive.tres"))
	room_light.add_child(bulb_mesh)
	var room_light_script: RoomLight = room_light
	room_light_script.effect_id = effect_id
	room_light_script.owner_peer_id = owner_peer_id
	room_light_script.room_index = room_index
	add_child(room_light)

	var pipe_effect_id := "room_%d_broken_pipe" % room_index
	var pipe := Node3D.new()
	pipe.set_script(BROKEN_PIPE_SCRIPT)
	pipe.name = "BrokenPipe"
	var water_mesh := MeshInstance3D.new()
	water_mesh.name = "WaterMesh"
	var water_box := BoxMesh.new()
	water_box.size = Vector3(width - WALL_THICK * 2.0, 1.0, depth - WALL_THICK * 2.0)
	water_mesh.mesh = water_box
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.4, 0.55, 0.55)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh.set_surface_override_material(0, water_mat)
	water_mesh.visible = false
	pipe.add_child(water_mesh)
	var pipe_script: BrokenPipe = pipe
	pipe_script.effect_id = pipe_effect_id
	pipe_script.owner_peer_id = owner_peer_id
	pipe_script.room_index = room_index
	pipe_script.room_height = HEIGHT
	add_child(pipe)

	var gas_effect_id := "room_%d_gas_leak" % room_index
	var gas_leak := Node3D.new()
	gas_leak.set_script(GAS_LEAK_SCRIPT)
	gas_leak.name = "GasLeak"
	gas_leak.position = bedroom + Vector3(-1, HEIGHT - 0.5, 1)
	var gas_leak_script: GasLeak = gas_leak
	gas_leak_script.effect_id = gas_effect_id
	gas_leak_script.owner_peer_id = owner_peer_id
	gas_leak_script.room_index = room_index
	add_child(gas_leak)


func _build_monitors(theme: Dictionary) -> void:
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.08, 0.07)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.55, 0.35)
	screen_mat.emission_energy_multiplier = 0.8

	var count := 3
	var spacing := 0.5
	var start_x := -(count - 1) * spacing / 2.0
	for i in range(count):
		var screen := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(0.4, 0.28, 0.03)
		screen.mesh = quad
		screen.position = Vector3(start_x + i * spacing, 1.6, -depth / 2.0 + 0.05)
		screen.set_surface_override_material(0, screen_mat)
		add_child(screen)


func _build_decor(rng: RandomNumberGenerator, theme: Dictionary, has_pipes: bool, has_wires: bool) -> void:
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.45, 0.46, 0.48)
	pipe_mat.metallic = 0.6
	pipe_mat.roughness = 0.4

	if has_pipes:
		var pipe_count := 1 + (1 if depth > 14.0 else 0)
		for i in range(pipe_count):
			var pipe := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.08
			cyl.height = depth + 0.3
			pipe.mesh = cyl
			pipe.rotation_degrees = Vector3(90, 0, 0)
			pipe.position = Vector3(-width / 2.0 + 0.5 + i * 0.3, HEIGHT - 0.15, 0)
			pipe.set_surface_override_material(0, pipe_mat)
			add_child(pipe)

	if has_wires:
		var wire_mat := StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.12, 0.12, 0.12)
		var segments := 5
		var start_x := -width / 2.0 - 0.05
		var end_x := width / 2.0 + 0.05
		for i in range(segments):
			var t0 := float(i) / segments
			var t1 := float(i + 1) / segments
			var wire := MeshInstance3D.new()
			var box := BoxMesh.new()
			var seg_len: float = (end_x - start_x) / segments
			box.size = Vector3(seg_len + 0.1, 0.03, 0.03)
			wire.mesh = box
			var y_offset: float = 0.08 if i % 2 == 0 else -0.05
			wire.position = Vector3(lerp(start_x, end_x, (t0 + t1) / 2.0), HEIGHT - 0.05 + y_offset, -depth / 2.0 + 0.15)
			wire.set_surface_override_material(0, wire_mat)
			add_child(wire)


func _build_prop_scatter(rng: RandomNumberGenerator) -> void:
	var prop_scenes: Array[PackedScene] = [CRATE_SCENE, SHELF_SCENE, BARREL_SCENE]
	var living := _zone_center("living")
	var scatter_w := minf(width * 0.6, 14.0)
	var scatter_d := minf(depth * 0.5, 10.0)
	var marker_count: int = clampi(int(width * depth / 40.0), 2, 6)
	var margin := 1.5

	for i in range(marker_count):
		if rng.randf() < 0.3:
			continue
		var x := living.x + rng.randf_range(-scatter_w * 0.5 + margin, scatter_w * 0.5 - margin)
		var z := living.z + rng.randf_range(-scatter_d * 0.5 + margin, scatter_d * 0.5 - margin)
		var scene: PackedScene = prop_scenes[rng.randi() % prop_scenes.size()]
		var prop := scene.instantiate()
		prop.position = Vector3(x, 0, z)
		prop.rotation.y = rng.randf_range(0.0, TAU)
		add_child(prop)


func _wall_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.05
	return mat


func _accent_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	return mat


func _make_box_body(size: Vector3, local_pos: Vector3, material: Material, layer_bits: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer_bits
	body.collision_mask = 0
	body.position = local_pos

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	if layer_bits != 0:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

	return body


func _make_interactable(script: Script, size: Vector3, local_pos: Vector3, material: Material, prompt: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_script(script)
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = local_pos
	body.prompt_text = prompt

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	return body
