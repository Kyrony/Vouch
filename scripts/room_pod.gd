extends Node3D
class_name RoomPod
## RoomPod
##
## One player's room - built from James's floor-plan templates (feet → meters)
## or a simple box for the Puppet Master.

const _FPT_SCRIPT: GDScript = preload("res://scripts/systems/floor_plan_templates.gd")
const _KIT_ASSEMBLER: GDScript = preload("res://scripts/systems/room_kit_assembler.gd")
const _CORRIDOR_KIT: GDScript = preload("res://scripts/kit/corridor_kit.gd")
const HEIGHT: float = 2.6
const DOOR_W: float = 0.85
const DOOR_H: float = 2.05
const WALL_THICK: float = 0.12
const SEAM_OVERLAP: float = 0.02
const PM_BOX_SIZE: float = 6.0
const HUB_SHAFT_RADIUS: float = 1.45
const HUB_SHAFT_HEIGHT: float = 10.0
const HUB_HALL_WIDTH: float = 1.25
const HUB_HALL_HEIGHT: float = 2.5
const STAIR_RISER: float = 0.18
const STAIR_TREAD: float = 0.28
## Metric human scale — canonical list in scripts/world_scale.gd (autoload)

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
const DRAIN_SCRIPT: Script = preload("res://scripts/interactables/drain.gd")
const EXHAUST_VENT_SCRIPT: Script = preload("res://scripts/interactables/exhaust_vent.gd")
const _FIREPLACE_SCRIPT: GDScript = preload("res://scripts/interactables/fireplace.gd")
const PHYSICS_BOOK_SCRIPT: Script = preload("res://scripts/interactables/physics_book.gd")
const BINARY_TERMINAL_SCRIPT: Script = preload("res://scripts/interactables/binary_terminal.gd")
const ROOM_PEEK_MONITOR_SCRIPT: Script = preload("res://scripts/interactables/room_peek_monitor.gd")

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
var _kit_sockets: Dictionary = {}
var _corridor_out: Vector3 = Vector3.ZERO
var _fireplace: Node3D = null


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
		"has_fireplace": not is_pm,
		"has_drain": not is_pm and randf() < 0.45,
		"has_exhaust": not is_pm and randf() < 0.4,
		"clue_in_fireplace": not is_pm and randf() < 0.35,
		"has_binary_puzzle": not is_pm and randf() < 0.4,
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
	var has_fireplace: bool = data.get("has_fireplace", false) and not is_puppet_master_room
	var has_drain: bool = data.get("has_drain", false) and not is_puppet_master_room
	var has_exhaust: bool = data.get("has_exhaust", false) and not is_puppet_master_room
	var clue_in_fireplace: bool = data.get("clue_in_fireplace", false)
	var has_binary_puzzle: bool = data.get("has_binary_puzzle", false) and not is_puppet_master_room
	var binary_target: int = int(data.get("binary_target", 0))
	var binary_peek_room: int = int(data.get("binary_peek_room", -1))

	if is_puppet_master_room:
		width = PM_BOX_SIZE
		depth = PM_BOX_SIZE
		_build_pm_shell(theme, escape_kind)
	else:
		_plan = _FPT_SCRIPT.call("get_plan", floor_plan_id)
		var kit_result: Dictionary = _KIT_ASSEMBLER.call("assemble", self, floor_plan_id, theme, escape_kind, rng)
		width = kit_result.get("width", _plan["w"])
		depth = kit_result.get("depth", _plan["d"])
		_zone_centers = kit_result.get("zone_centers", {})
		_kit_sockets = kit_result.get("mount_sockets", {})
		_corridor_out = kit_result.get("corridor_out", Vector3(0, DOOR_H * 0.5, depth * 0.5))
		spawn_point = kit_result.get("spawn_point") as Marker3D

	_build_decor(rng, theme, has_pipes, has_wires)
	_build_interactables(rng, theme, escape_kind, has_valve, has_electrical_box, wire_targets, has_fireplace, has_drain, has_exhaust, has_binary_puzzle, binary_target, binary_peek_room)
	if escape_kind != EscapeKind.NONE:
		_CORRIDOR_KIT.call("build_escape_path", self, _corridor_out, room_index, theme, escape_kind)
	_build_prop_scatter(rng)

	if is_puppet_master_room:
		_build_monitors(theme)

	var requires_code: bool = data.get("requires_code", false)
	if requires_code:
		mark_escape_locked()

	var clue_kind: String = data.get("clue_kind", "")
	if not clue_kind.is_empty():
		add_clue_prop(clue_kind, data.get("clue_code", ""), clue_in_fireplace and has_fireplace)


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


func add_clue_prop(kind: String, code: String, in_fireplace: bool = false) -> void:
	if kind == "flame_paper":
		var spawn_pos: Vector3
		var flame: Node3D = null
		if in_fireplace and is_instance_valid(_fireplace):
			spawn_pos = _fireplace.position + Vector3(0, 0.5, 0.2)
			flame = _fireplace.get_flame()
		else:
			spawn_pos = _zone_center("living") + Vector3(-1.0, 0.9, 1.0)
			flame = _spawn_standalone_flame(spawn_pos + Vector3(0.4, -0.5, 0))

		var paper := _make_interactable(CLUE_FLAME_PAPER_SCRIPT, Vector3(0.3, 0.02, 0.4), spawn_pos, _accent_material(Color(0.85, 0.8, 0.65)), "Pick up paper")
		var paper_script: ClueFlamePaper = paper
		paper_script.revealed_code = code
		paper_script.flame = flame
		paper.name = "ClueFlamePaper"
		add_child(paper)
	else:
		var book_pos: Vector3
		if in_fireplace and is_instance_valid(_fireplace) and _fireplace.has_node("ClueSlot"):
			book_pos = _fireplace.get_node("ClueSlot").position + _fireplace.position
		else:
			book_pos = _zone_center("living") + Vector3(-1.0, 0.35, 1.0)
		var book := _make_interactable(CLUE_BOOK_SCRIPT, Vector3(0.3, 0.25, 0.35), book_pos, _accent_material(Color(0.5, 0.35, 0.22)), "Read book")
		var book_script: ClueBook = book
		book_script.revealed_text = "A page has a code scrawled in the corner: %s" % code
		book.name = "ClueBook"
		add_child(book)


func _spawn_standalone_flame(at: Vector3) -> Node3D:
	var flame := Node3D.new()
	flame.set_script(FLAME_SCRIPT)
	flame.name = "Flame"
	flame.add_to_group("flames")
	flame.position = at
	var flame_light := OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.5, 0.15)
	flame_light.light_energy = 1.2
	flame_light.omni_range = 3.0
	flame.add_child(flame_light)
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
	return flame


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

	var south_gap := 0.0 if escape_kind == EscapeKind.NONE else (DOOR_W if escape_kind == EscapeKind.DOOR else 0.55)
	var south_open := DOOR_H if south_gap > 0.01 else -1.0
	_build_wall(true, depth / 2.0, width, south_gap, 0.0, wall_mat, HEIGHT, south_open)
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


func _socket_pos(key: String, fallback: Vector3) -> Vector3:
	if _kit_sockets.has(key):
		return _kit_sockets[key] as Vector3
	return fallback


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
		var gap_open_h: float = seg.get("gap_open_h", HEIGHT)
		if seg["axis"] == "x":
			_build_wall_at_y(true, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, 0.0, gap_open_h)
		else:
			_build_wall_at_y(false, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, 0.0, gap_open_h)

	_build_floor_plan_ceiling(wall_mat, pw, pd, null)

	if _plan.get("stories", 1) >= 2:
		_build_upper_floor(theme, wall_mat, floor_mat, escape_kind)

	_build_plan_doors(theme, escape_kind, 0.0)

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
		if is_escape and escape_kind == EscapeKind.VENT:
			seg["gap_open_h"] = 0.6
		elif gap_w > 0.01:
			seg["gap_open_h"] = DOOR_H


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
			_build_wall_at_y(true, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, floor_y, seg.get("gap_open_h", HEIGHT))
		else:
			_build_wall_at_y(false, seg["fixed"], seg["span"], gap_w, gap_center, wall_mat, HEIGHT, floor_y, seg.get("gap_open_h", HEIGHT))

	var ceiling := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(pw, WALL_THICK, pd2)
	ceiling.mesh = mesh
	ceiling.set_surface_override_material(0, wall_mat)
	ceiling.position = Vector3(0, floor_y + HEIGHT + WALL_THICK / 2.0, deck_z)
	add_child(ceiling)

	_build_plan_doors(theme, escape_kind, floor_y, f2.get("doors", []))

	_build_floor_plan_ceiling(wall_mat, pw, _plan["d"], stair)
	_build_stair(stair, wall_mat, floor_mat)


func _build_stair(stair: Dictionary, wall_mat: Material, floor_mat: Material) -> void:
	if stair.is_empty():
		return
	var x0 := _plan_x_to_world(stair["x"])
	var x1 := _plan_x_to_world(stair["x"] + stair["w"])
	var z0 := _plan_z_to_world(stair["z"] + stair["d"])
	var z1 := _plan_z_to_world(stair["z"])
	var steps := maxi(int(ceil(HEIGHT / STAIR_RISER)), 4)
	var step_h := HEIGHT / float(steps)
	var step_d := STAIR_TREAD
	var run_len := z1 - z0
	for i in range(steps):
		var sy := i * step_h
		add_child(_make_box_body(
			Vector3(x1 - x0, step_h, step_d + SEAM_OVERLAP),
			Vector3((x0 + x1) * 0.5, sy + step_h * 0.5, z0 + step_d * (i + 0.5)),
			floor_mat, 1
		))
	var rail_h := HEIGHT
	add_child(_make_box_body(Vector3(WALL_THICK, rail_h, run_len + SEAM_OVERLAP), Vector3(x0 - WALL_THICK * 0.5, rail_h * 0.5, (z0 + z1) * 0.5), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, rail_h, run_len + SEAM_OVERLAP), Vector3(x1 + WALL_THICK * 0.5, rail_h * 0.5, (z0 + z1) * 0.5), wall_mat, 1))


func _build_wall_at_y(is_x_axis: bool, wall_offset: float, span: float, gap_width: float, gap_center: float, material: Material, wall_height: float, base_y: float, gap_open_height: float = -1.0) -> void:
	var open_h := gap_open_height if gap_open_height >= 0.0 else wall_height
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

	if open_h < wall_height - 0.05 and gap_width > 0.05:
		var lintel_h := wall_height - open_h
		var lintel_y := base_y + open_h + lintel_h / 2.0
		var lintel_size := Vector3(gap_width, lintel_h, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, lintel_h, gap_width)
		var lintel_pos := Vector3(gap_center, lintel_y, wall_offset) if is_x_axis else Vector3(wall_offset, lintel_y, gap_center)
		add_child(_make_box_body(lintel_size, lintel_pos, material, 1))


func _build_wall(is_x_axis: bool, wall_offset: float, span: float, gap_width: float, gap_center: float, material: Material, gap_height: float = HEIGHT, gap_open_height: float = -1.0) -> void:
	_build_wall_at_y(is_x_axis, wall_offset, span, gap_width, gap_center, material, gap_height, 0.0, gap_open_height)


func _build_shape_accents(rng: RandomNumberGenerator, theme: Dictionary) -> void:
	if is_puppet_master_room or _plan.is_empty():
		return
	var wall_mat := _wall_material(theme["wall_color"])
	var floor_mat := _wall_material(theme["floor_color"])
	_build_exterior_chamfers(rng, wall_mat)
	if floor_plan_id in ["08", "09", "13"]:
		_build_l_corner_diagonal(wall_mat)
	if rng.randf() < 0.45:
		_build_angled_partition(rng, wall_mat)
	if rng.randf() < 0.35:
		_build_wide_hall_niche(rng, theme, wall_mat, floor_mat)


func _build_exterior_chamfers(rng: RandomNumberGenerator, material: Material) -> void:
	var cut := clampf(minf(width, depth) * 0.07, 0.35, 0.9)
	var corners := [
		Vector3(-width / 2.0, 0, depth / 2.0),
		Vector3(width / 2.0, 0, depth / 2.0),
		Vector3(-width / 2.0, 0, -depth / 2.0),
		Vector3(width / 2.0, 0, -depth / 2.0),
	]
	for i in range(corners.size()):
		if rng.randf() > 0.55:
			continue
		var c: Vector3 = corners[i]
		var dx := -1.0 if c.x < 0 else 1.0
		var dz := -1.0 if c.z < 0 else 1.0
		var diag := Vector3(dx, 0, dz).normalized()
		var block_center := c - diag * cut * 0.35
		add_child(_make_box_body(Vector3(cut, HEIGHT, cut), Vector3(block_center.x, HEIGHT / 2.0, block_center.z), material, 1))
		var slant := MeshInstance3D.new()
		var slant_mesh := BoxMesh.new()
		slant_mesh.size = Vector3(cut * 1.4, HEIGHT, WALL_THICK)
		slant.mesh = slant_mesh
		slant.position = Vector3(c.x - dx * cut * 0.5, HEIGHT / 2.0, c.z - dz * cut * 0.5)
		slant.rotation.y = atan2(dz, dx) + PI * 0.25
		slant.set_surface_override_material(0, material)
		add_child(slant)


func _build_l_corner_diagonal(material: Material) -> void:
	var living := _zone_center("living")
	var cut := 0.75
	var pos := living + Vector3(cut * 0.35, HEIGHT / 2.0, -cut * 0.35)
	var diag := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WALL_THICK, HEIGHT, cut * 1.6)
	diag.mesh = mesh
	diag.position = pos
	diag.rotation.y = PI * 0.25
	diag.set_surface_override_material(0, material)
	add_child(diag)


func _build_angled_partition(rng: RandomNumberGenerator, material: Material) -> void:
	var living := _zone_center("living")
	var len := rng.randf_range(1.0, 1.8)
	var ang := rng.randf_range(-0.6, 0.6)
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WALL_THICK, HEIGHT, len)
	part.mesh = mesh
	part.position = living + Vector3(rng.randf_range(-1.5, 1.5), HEIGHT / 2.0, rng.randf_range(-1.0, 1.0))
	part.rotation.y = ang
	part.set_surface_override_material(0, material)
	add_child(part)
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.position = part.position
	col_body.rotation.y = part.rotation.y
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = mesh.size
	col.shape = sh
	col_body.add_child(col)
	add_child(col_body)


func _build_wide_hall_niche(rng: RandomNumberGenerator, theme: Dictionary, wall_mat: Material, floor_mat: Material) -> void:
	var living := _zone_center("living")
	var w := rng.randf_range(1.4, 2.2)
	var d := rng.randf_range(0.8, 1.4)
	var offset := Vector3(rng.randf_range(-1.2, 1.2), 0, depth * 0.22)
	add_child(_make_box_body(Vector3(w, WALL_THICK, d), living + offset + Vector3(0, -WALL_THICK / 2.0, 0), floor_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, HEIGHT, d), living + offset + Vector3(-w / 2.0, HEIGHT / 2.0, 0), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, HEIGHT, d), living + offset + Vector3(w / 2.0, HEIGHT / 2.0, 0), wall_mat, 1))


func _build_fireplace_nook(pos: Vector3, material: Material) -> void:
	var r := 0.75
	for i in range(8):
		var a0 := TAU * float(i) / 8.0
		var a1 := TAU * float(i + 1) / 8.0
		var p0 := pos + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := pos + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1)
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(seg_len, 0.55, WALL_THICK)
		seg.mesh = mesh
		seg.position = Vector3(mid.x, 0.28, mid.z)
		seg.rotation.y = atan2(p1.z - p0.z, p1.x - p0.x)
		seg.set_surface_override_material(0, material)
		add_child(seg)


func _build_perimeter_shell(material: Material, pw: float, pd: float, escape_kind: EscapeKind) -> void:
	var entry: Dictionary = _FPT_SCRIPT.call("entry_door", _plan)
	var south_gap := 0.0
	var south_center := 0.0
	var south_open := HEIGHT
	if escape_kind == EscapeKind.DOOR and not entry.is_empty():
		south_gap = entry.get("gap_w", DOOR_W)
		south_center = _plan_x_to_world(entry.get("gap_start", pw * 0.5 - 2) + south_gap * 0.5)
		south_open = DOOR_H
	elif escape_kind == EscapeKind.DOOR:
		south_gap = DOOR_W
		south_center = 0.0
		south_open = DOOR_H
	_build_wall(true, _plan_z_to_world(0), pw, south_gap, south_center, material, HEIGHT, south_open)
	_build_wall(true, _plan_z_to_world(pd), pw, 0.0, 0.0, material, HEIGHT)
	_build_wall(false, _plan_x_to_world(0), pd, 0.0, 0.0, material, HEIGHT)
	_build_wall(false, _plan_x_to_world(pw), pd, 0.0, 0.0, material, HEIGHT)


func _wall_mount(local_pos: Vector3, wall_normal: Vector3, mount_height: float, prop_depth: float = 0.06) -> Vector3:
	var n := wall_normal.normalized()
	if n.length_squared() < 0.01:
		n = Vector3(0, 0, -1)
	var flush := local_pos
	flush.y = mount_height
	flush -= n * (WALL_THICK * 0.5 + prop_depth * 0.5)
	return flush


func _nearest_wall_normal(world_hint: Vector3) -> Vector3:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var px := world_hint.x
	var pz := world_hint.z
	var dx := minf(absf(px + half_w), absf(half_w - px))
	var dz := minf(absf(pz + half_d), absf(half_d - pz))
	if dx < dz:
		return Vector3(signf(px), 0, 0) if absf(px) > 0.01 else Vector3(-1, 0, 0)
	return Vector3(0, 0, signf(pz)) if absf(pz) > 0.01 else Vector3(0, 0, 1)


func _build_loft_stairs(theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var wall_mat := _wall_material(theme["wall_color"])
	var floor_mat := _wall_material(theme["floor_color"])
	var living := _zone_center("living")
	var sx := living.x - 0.45
	var sz := living.z + depth * 0.12
	var sw := 0.9
	var sd := 1.1
	var loft_h := HEIGHT * 0.42
	var steps := maxi(int(ceil(loft_h / STAIR_RISER)), 3)
	var step_h := loft_h / float(steps)
	var x0 := sx
	var x1 := sx + sw
	var z0 := sz
	for i in range(steps):
		add_child(_make_box_body(
			Vector3(x1 - x0, step_h, STAIR_TREAD + SEAM_OVERLAP),
			Vector3((x0 + x1) * 0.5, i * step_h + step_h * 0.5, z0 + STAIR_TREAD * (i + 0.5)),
			floor_mat, 1
		))
	add_child(_make_box_body(Vector3(sw + 0.25, WALL_THICK, sd + 0.25), Vector3((x0 + x1) * 0.5, loft_h, z0 + sd * 0.5), floor_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, loft_h, sd), Vector3(x0 - WALL_THICK * 0.5, loft_h * 0.5, z0 + sd * 0.5), wall_mat, 1))


# ---------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------

func _build_interactables(rng: RandomNumberGenerator, theme: Dictionary, escape_kind: EscapeKind, has_valve: bool, has_electrical_box: bool, wire_targets: Array, has_fireplace: bool, has_drain: bool, has_exhaust: bool, has_binary_puzzle: bool, binary_target: int, binary_peek_room: int) -> void:
	var accent := _accent_material(theme["accent_color"])
	var living := _zone_center("living")
	var bedroom := _zone_center("bedroom") if _zone_centers.has("bedroom") else living + Vector3(2, 0, -2)
	var bath := _zone_center("bath") if _zone_centers.has("bath") else living + Vector3(-2, 0, -2)

	var control_id := "room_%d_light_switch" % room_index
	var effect_id := "room_%d_room_light" % room_index

	var switch_wall := _nearest_wall_normal(living + Vector3(-width * 0.4, 0, 0))
	var switch_pos: Vector3 = _socket_pos("Mount_Switch", _wall_mount(living + Vector3(-width * 0.4, 0, 0), switch_wall, 1.25))
	var switch := _make_interactable(LIGHT_SWITCH_SCRIPT, Vector3(0.08, 0.12, 0.04), switch_pos, accent, "Flip switch")
	var switch_script: LightSwitch = switch
	switch_script.control_id = control_id
	switch_script.room_index = room_index
	switch.name = "LightSwitch"
	add_child(switch)
	light_switch = switch

	if escape_kind != EscapeKind.NONE:
		var escape_pos: Vector3
		var escape_size: Vector3
		var escape_prompt: String
		if escape_kind == EscapeKind.DOOR:
			escape_pos = _corridor_out + Vector3(0, 0, 0.06)
			escape_size = Vector3(DOOR_W, DOOR_H, 0.08)
			escape_prompt = "Open the door"
		else:
			var vent_zone := bath if _zone_centers.has("bath") else living
			if _kit_sockets.has("Vent_Ceiling"):
				escape_pos = _kit_sockets["Vent_Ceiling"] + Vector3(0, -0.5, 0)
			else:
				escape_pos = vent_zone + Vector3(0, 1.0, -depth * 0.35)
			escape_size = Vector3(0.55, 0.45, 0.08)
			escape_prompt = "Squeeze through the vent"
		var escape_point := _make_door(escape_size, escape_pos, accent, escape_prompt, escape_kind == EscapeKind.VENT)
		escape_point.name = "EscapePoint"
		add_child(escape_point)

	if has_fireplace:
		var fp_pos: Vector3 = _socket_pos("Mount_Fireplace", living + Vector3(-width * 0.25, 0, -depth * 0.15))
		_build_fireplace_nook(fp_pos, accent)
		_fireplace = _FIREPLACE_SCRIPT.build(self, fp_pos, accent, room_index)

	if has_drain:
		var drain_zone := bath if _zone_centers.has("bath") else living
		var drain := _make_interactable(DRAIN_SCRIPT, Vector3(0.35, 0.05, 0.35), drain_zone + Vector3(0, 0.02, 0), accent, "Floor drain")
		var drain_script: Node = drain
		drain_script.configure(room_index)
		drain.name = "Drain"
		add_child(drain)

	if has_exhaust:
		var vent_hint := living + Vector3(-width * 0.42, 0, depth * 0.3)
		var vent_wall := _nearest_wall_normal(vent_hint)
		var vent_pos := _wall_mount(vent_hint, vent_wall, HEIGHT * 0.55, 0.12)
		var exhaust := _make_interactable(EXHAUST_VENT_SCRIPT, Vector3(0.5, 0.35, 0.12), vent_pos, accent, "Exhaust vent")
		var exhaust_script: Node = exhaust
		exhaust_script.configure(room_index)
		exhaust.name = "ExhaustVent"
		add_child(exhaust)

	var phone_wall := _nearest_wall_normal(living + Vector3(width * 0.35, 0, 0))
	var phone_pos: Vector3 = _socket_pos("Mount_Phone", _wall_mount(living + Vector3(width * 0.35, 0, 0), phone_wall, 1.15))
	var phone := _make_interactable(PHONE_SCRIPT, Vector3(0.12, 0.18, 0.06), phone_pos, accent, "Pick up phone")
	var phone_script: Phone = phone
	phone_script.owner_peer_id = owner_peer_id
	phone.name = "Phone"
	add_child(phone)

	var camera_mount_y := 2.35
	var cam_hint := living + Vector3(width * 0.3, 0, -depth * 0.35)
	var cam_wall := _nearest_wall_normal(cam_hint)
	var camera_pos: Vector3 = _socket_pos("Mount_Camera", _wall_mount(cam_hint, cam_wall, camera_mount_y, 0.08))
	var camera := _make_interactable(SECURITY_CAMERA_SCRIPT, Vector3(0.14, 0.1, 0.12), camera_pos, accent, "Camera")
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
		var valve := _make_interactable(WATER_VALVE_SCRIPT, Vector3(0.1, 0.1, 0.08), valve_zone + Vector3(-0.5, 1.0, 0), accent, "Turn valve")
		var valve_script: WaterValve = valve
		valve_script.control_id = valve_control_id
		valve_script.room_index = room_index
		valve.name = "WaterValve"
		add_child(valve)

	if theme_id == "utility" and rng.randf() < 0.5:
		var gas_control_id := "room_%d_gas_valve" % room_index
		var gas_valve := _make_interactable(GAS_VALVE_SCRIPT, Vector3(0.09, 0.09, 0.06), living + Vector3(-width * 0.4, 1.15, -0.5), accent, "Turn gas valve")
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

	if has_binary_puzzle and binary_target > 0 and binary_peek_room >= 0:
		_build_binary_puzzle(theme, accent, living, binary_target, binary_peek_room)


func _build_binary_puzzle(theme: Dictionary, accent: Material, living: Vector3, target: int, peek_room: int) -> void:
	var wall := _nearest_wall_normal(living + Vector3(0, 0, -depth * 0.2))
	var term_pos := _wall_mount(living + Vector3(0.8, 0, -depth * 0.2), wall, 1.0, 0.08)
	var terminal := _make_interactable(BINARY_TERMINAL_SCRIPT, Vector3(0.35, 0.28, 0.1), term_pos, accent, "Binary terminal")
	terminal.name = "BinaryTerminal"
	var term_script: Node = terminal
	term_script.configure(room_index, target, 8)
	add_child(terminal)

	var bookcase := _make_interactable(MOVABLE_PROP_SCRIPT, Vector3(0.55, 1.1, 0.35), living + Vector3(-0.5, 0.55, -depth * 0.18), accent, "Move bookcase")
	bookcase.name = "BinaryBookcase"
	var bc_script: MovableProp = bookcase
	bc_script.move_offset = Vector3(0.95, 0, 0)
	bc_script.unmoved_prompt = "Blocked by bookcase"
	bc_script.moved_prompt = "Bookcase moved"
	add_child(bookcase)

	var mon_pos := _wall_mount(living + Vector3(-1.2, 0, -depth * 0.22), wall, 1.35, 0.1)
	var monitor := StaticBody3D.new()
	monitor.set_script(ROOM_PEEK_MONITOR_SCRIPT)
	monitor.name = "RoomPeekMonitor"
	monitor.position = mon_pos
	monitor.collision_layer = 2
	monitor.prompt_text = "Security monitor (locked)"
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.38, 0.08)
	mesh_instance.mesh = box
	mesh_instance.set_surface_override_material(0, accent)
	monitor.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 0.38, 0.08)
	collision.shape = shape
	monitor.add_child(collision)
	var mon_script: Node = monitor
	mon_script.configure(room_index, peek_room)
	monitor.visible = false
	for c in monitor.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	add_child(monitor)

	term_script.set("bookcase", bc_script)
	term_script.set("peek_monitor", mon_script)


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
	var scatter_w := minf(width * 0.6, 4.2)
	var scatter_d := minf(depth * 0.5, 3.0)
	var marker_count: int = clampi(int(width * depth / 4.5), 4, 14)
	var margin := 0.45

	for i in range(marker_count):
		if rng.randf() < 0.15:
			continue
		var x := living.x + rng.randf_range(-scatter_w * 0.5 + margin, scatter_w * 0.5 - margin)
		var z := living.z + rng.randf_range(-scatter_d * 0.5 + margin, scatter_d * 0.5 - margin)
		if rng.randf() < 0.25:
			var loose_book := _make_physics_book(Vector3(x, 0.45, z), "")
			add_child(loose_book)
			continue
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


func _build_plan_doors(theme: Dictionary, escape_kind: EscapeKind, floor_y: float, door_list: Array = []) -> void:
	var doors: Array = door_list if not door_list.is_empty() else _plan.get("doors", [])
	if doors.is_empty():
		return
	var accent := _accent_material(theme["accent_color"])
	var pw: float = _plan["w"]
	var pd: float = _plan["d"] if door_list.is_empty() else float(_plan.get("floor2", {}).get("d", _plan["d"]))
	var deck_z := 0.0 if door_list.is_empty() else depth * 0.5 - pd * 0.5

	for door in doors:
		if door.get("exterior", false) and escape_kind == EscapeKind.DOOR:
			continue
		var gap_w: float = door.get("gap_w", DOOR_W)
		var kind: String = door.get("kind", "")
		var gap_start: float = door.get("gap_start", 0.0)
		var pos := Vector3.ZERO
		var rot_y := 0.0
		match kind:
			"s":
				pos = Vector3(_plan_x_to_world(gap_start + gap_w * 0.5), DOOR_H * 0.5 + floor_y, _plan_z_to_world(0) - 0.06 + deck_z)
				rot_y = PI
			"n":
				pos = Vector3(_plan_x_to_world(gap_start + gap_w * 0.5), DOOR_H * 0.5 + floor_y, _plan_z_to_world(pd) + 0.06 + deck_z)
				rot_y = 0.0
			"w":
				pos = Vector3(_plan_x_to_world(0) - 0.06, DOOR_H * 0.5 + floor_y, _plan_z_to_world(gap_start + gap_w * 0.5) + deck_z)
				rot_y = -PI * 0.5
			"e":
				pos = Vector3(_plan_x_to_world(pw) + 0.06, DOOR_H * 0.5 + floor_y, _plan_z_to_world(gap_start + gap_w * 0.5) + deck_z)
				rot_y = PI * 0.5
			"v":
				pos = Vector3(_plan_x_to_world(door.get("pos", 0.0)), DOOR_H * 0.5 + floor_y, _plan_z_to_world(gap_start + gap_w * 0.5) + deck_z)
				rot_y = PI * 0.5
			"h":
				pos = Vector3(_plan_x_to_world(gap_start + gap_w * 0.5), DOOR_H * 0.5 + floor_y, _plan_z_to_world(door.get("pos", 0.0)) + deck_z)
				rot_y = 0.0
			_:
				continue
		var door_node := _make_door(Vector3(gap_w * 0.95, DOOR_H, 0.12), pos, accent, "Open door", false)
		door_node.rotation.y = rot_y
		door_node.name = "InteriorDoor"
		add_child(door_node)


func _build_escape_hall(_escape_kind: EscapeKind, theme: Dictionary) -> void:
	var grid_pos := Match.room_grid_position(room_index)
	var dist := Vector2(grid_pos.x, grid_pos.z).length()
	var horiz := clampf(dist - HUB_SHAFT_RADIUS - depth * 0.5, 18.0, 46.0)
	var hall_w := HUB_HALL_WIDTH
	var hall_h := HUB_HALL_HEIGHT
	var wall_mat := _wall_material(theme["wall_color"])
	var floor_mat := _wall_material(theme["floor_color"])
	var start_z := depth / 2.0

	_build_sealed_tunnel(start_z, horiz, hall_w, hall_h, wall_mat, floor_mat, true, true)

	var vert_base_z := start_z + horiz
	var up_h := HUB_SHAFT_HEIGHT
	_build_sealed_tunnel_vertical(vert_base_z, up_h, hall_w, hall_h, wall_mat, floor_mat)


func _build_sealed_tunnel(start_z: float, length: float, inner_w: float, inner_h: float, wall_mat: Material, floor_mat: Material, open_near: bool, open_far: bool) -> void:
	if length < 0.5:
		return
	var cz := start_z + length * 0.5
	add_child(_make_box_body(Vector3(inner_w, WALL_THICK, length), Vector3(0, -WALL_THICK / 2.0, cz), floor_mat, 1))
	add_child(_make_box_body(Vector3(inner_w + WALL_THICK * 2.0, WALL_THICK, length + WALL_THICK * 2.0), Vector3(0, inner_h + WALL_THICK / 2.0, cz), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, inner_h, length), Vector3(-inner_w / 2.0 - WALL_THICK / 2.0, inner_h / 2.0, cz), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, inner_h, length), Vector3(inner_w / 2.0 + WALL_THICK / 2.0, inner_h / 2.0, cz), wall_mat, 1))
	if not open_near:
		add_child(_make_box_body(Vector3(inner_w, inner_h, WALL_THICK), Vector3(0, inner_h / 2.0, start_z - WALL_THICK / 2.0), wall_mat, 1))
	if not open_far:
		add_child(_make_box_body(Vector3(inner_w, inner_h, WALL_THICK), Vector3(0, inner_h / 2.0, start_z + length + WALL_THICK / 2.0), wall_mat, 1))


func _build_sealed_tunnel_vertical(base_z: float, rise_h: float, inner_w: float, inner_h: float, wall_mat: Material, floor_mat: Material) -> void:
	var cz := base_z
	add_child(_make_box_body(Vector3(inner_w, WALL_THICK, inner_w), Vector3(0, -WALL_THICK / 2.0, cz), floor_mat, 1))
	add_child(_make_box_body(Vector3(inner_w + WALL_THICK * 2.0, WALL_THICK, inner_w + WALL_THICK * 2.0), Vector3(0, rise_h + WALL_THICK / 2.0, cz), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, rise_h, inner_w), Vector3(-inner_w / 2.0 - WALL_THICK / 2.0, rise_h / 2.0, cz), wall_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, rise_h, inner_w), Vector3(inner_w / 2.0 + WALL_THICK / 2.0, rise_h / 2.0, cz), wall_mat, 1))
	add_child(_make_box_body(Vector3(inner_w, rise_h, WALL_THICK), Vector3(0, rise_h / 2.0, cz - inner_w / 2.0 - WALL_THICK / 2.0), wall_mat, 1))
	add_child(_make_box_body(Vector3(inner_w, rise_h, WALL_THICK), Vector3(0, rise_h / 2.0, cz + inner_w / 2.0 + WALL_THICK / 2.0), wall_mat, 1))


func _make_door(size: Vector3, local_pos: Vector3, material: Material, prompt: String, is_vent: bool) -> Door:
	var body := StaticBody3D.new()
	body.set_script(DOOR_SCRIPT)
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = local_pos
	body.prompt_text = prompt

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	if is_vent:
		pivot.position = Vector3(0, -size.y * 0.5, 0)
	else:
		pivot.position = Vector3(-size.x * 0.5, -size.y * 0.5, 0)
	body.add_child(pivot)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(size.x * 0.5, size.y * 0.5, 0) if not is_vent else Vector3(0, size.y * 0.5, 0)
	mesh_instance.set_surface_override_material(0, material)
	pivot.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = mesh_instance.position
	pivot.add_child(collision)

	var door_script: Door = body
	door_script.is_vent = is_vent
	return door_script


func _make_physics_book(local_pos: Vector3, _code: String) -> RigidBody3D:
	var book := RigidBody3D.new()
	book.set_script(PHYSICS_BOOK_SCRIPT)
	book.position = local_pos
	book.mass = 0.8
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.03, 0.16)
	mesh_instance.mesh = box
	var mat := _accent_material(Color(0.5, 0.35, 0.22))
	mesh_instance.set_surface_override_material(0, mat)
	book.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.03, 0.16)
	collision.shape = shape
	book.add_child(collision)
	return book


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
