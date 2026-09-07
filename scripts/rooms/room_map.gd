extends Node3D
class_name RoomMap
## One complete authored room map — solid geometry + 16 fixed item spawn slots.

const _LAYOUTS: GDScript = preload("res://scripts/rooms/room_layouts.gd")
const _INTERACTABLE_BASE: GDScript = preload("res://scripts/interactables/interactable.gd")
const _GEOMETRY: GDScript = preload("res://scripts/rooms/room_geometry.gd")
const _ITEMS: GDScript = preload("res://scripts/rooms/item_spawn_system.gd")
const _PLAYABLE: GDScript = preload("res://scripts/rooms/playable_loop_spawns.gd")
const _SLOT_SCRIPT: GDScript = preload("res://scripts/rooms/item_spawn_slot.gd")
const _TUNNEL: GDScript = preload("res://scripts/rooms/tunnel_kit.gd")
const _NEON: GDScript = preload("res://scripts/rooms/neon_theme.gd")

const WALL: float = WorldScale.WALL_THICK

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

enum EscapeKind { DOOR, VENT }

@export var room_id: int = 1
@export var is_puppet_master: bool = false

var room_index: int = 0
var owner_peer_id: int = -1
var width: float = 6.0
var depth: float = 6.0
var theme_id: String = ""
var theme_name: String = ""
var light_switch: Node
var spawn_point: Marker3D
var _layout: Dictionary = {}
var _theme: Dictionary = {}
var _fireplace: Node3D = null
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	if is_puppet_master:
		_layout = _pm_layout()
	else:
		_layout = _LAYOUTS.call("get_layout", room_id)
	width = _layout.get("width", 6.0)
	depth = _layout.get("depth", 6.0)
	var theme := _theme_for_layout(_layout)
	_theme = theme
	theme_id = theme["id"]
	theme_name = theme["name"]
	_GEOMETRY.call("build", self, _layout, theme)
	_ensure_markers()


func configure(data: Dictionary) -> void:
	_ensure_built()
	room_index = data["room_index"]
	owner_peer_id = data["owner_peer_id"]
	var rng := RandomNumberGenerator.new()
	rng.seed = data["rng_seed"]

	if is_puppet_master:
		_configure_pm(data, rng)
		return

	if _theme.is_empty():
		_theme = _theme_for_layout(_layout)
		theme_id = _theme["id"]
		theme_name = _theme["name"]

	var escape_kind: EscapeKind
	if rng.randf() < 0.6:
		escape_kind = EscapeKind.DOOR
	else:
		escape_kind = EscapeKind.VENT

	var accent := _accent_material(_theme["accent_color"], theme_id)
	var ctx := {
		"room_index": room_index,
		"owner_peer_id": owner_peer_id,
		"theme": _theme,
		"theme_id": theme_id,
		"layout": _layout,
		"accent_material": accent,
		"spawn_hint": spawn_point.position if spawn_point else _layout.get("spawn", Vector3.ZERO),
		"has_valve": data.get("has_valve", false),
		"has_electrical_box": data.get("has_electrical_box", false),
		"wire_targets": data.get("wire_targets", []),
		"has_fireplace": data.get("has_fireplace", false),
		"has_drain": data.get("has_drain", false),
		"has_exhaust": data.get("has_exhaust", false),
		"has_binary_puzzle": data.get("has_binary_puzzle", false),
		"binary_target": data.get("binary_target", 0),
		"binary_peek_room": data.get("binary_peek_room", -1),
	}

	var spawned: Dictionary = _ITEMS.call("populate", self, ctx, rng)
	light_switch = spawned.get("light_switch")
	_fireplace = spawned.get("fireplace")

	var spawn_local: Vector3 = spawn_point.position if spawn_point else _layout.get("spawn", Vector3.ZERO)
	_PLAYABLE.call("spawn_near_player", self, spawn_local, accent, owner_peer_id)

	_ITEMS.call("spawn_room_effects", self, ctx)

	var escape_pos: Vector3 = _layout["escape"]
	if escape_kind == EscapeKind.VENT:
		escape_pos = _vent_escape_position()
	_ITEMS.call("spawn_escape", self, ctx, escape_pos, escape_kind == EscapeKind.VENT)
	_build_escape_corridor(_layout["corridor_out"], data["room_index"])

	if data.get("requires_code", false):
		mark_escape_locked()

	var clue_kind: String = data.get("clue_kind", "")
	if not clue_kind.is_empty():
		add_clue_prop(clue_kind, data.get("clue_code", ""), data.get("clue_in_fireplace", false) and data.get("has_fireplace", false))


func get_spawn_transform() -> Transform3D:
	if spawn_point:
		return spawn_point.global_transform
	return global_transform


func add_clue_prop(kind: String, code: String, in_fireplace: bool = false) -> void:
	var accent := _accent_material(_theme["accent_color"], theme_id)
	if kind == "flame_paper":
		var spawn_pos := Vector3(0, 0.9, 0)
		var flame: Node3D = null
		if in_fireplace and is_instance_valid(_fireplace):
			spawn_pos = _fireplace.position + Vector3(0, 0.5, 0.2)
			flame = _fireplace.get_flame()
		var paper: StaticBody3D = _ITEMS.call("_make_interactable",
			load("res://scripts/interactables/clue_flame_paper.gd") as Script,
			Vector3(0.3, 0.02, 0.4), spawn_pos, accent, "Pick up paper"
		)
		paper.set("revealed_code", code)
		paper.set("flame", flame)
		paper.name = "ClueFlamePaper"
		add_child(paper)
	else:
		var book_pos := Vector3(-1, 0.35, 1)
		if in_fireplace and is_instance_valid(_fireplace) and _fireplace.has_node("ClueSlot"):
			book_pos = _fireplace.get_node("ClueSlot").position + _fireplace.position
		var book: StaticBody3D = _ITEMS.call("_make_interactable",
			load("res://scripts/interactables/clue_book.gd") as Script,
			Vector3(0.3, 0.25, 0.35), book_pos, accent, "Read book"
		)
		book.set("revealed_text", "A page has a code scrawled in the corner: %s" % code)
		book.name = "ClueBook"
		add_child(book)


func _ensure_markers() -> void:
	spawn_point = get_node_or_null("PlayerSpawn") as Marker3D
	if spawn_point == null:
		spawn_point = Marker3D.new()
		spawn_point.name = "PlayerSpawn"
		spawn_point.position = _layout.get("spawn", Vector3(0, 0.1, depth * 0.35))
		add_child(spawn_point)

	var slots_root := get_node_or_null("ItemSpawns")
	if slots_root == null:
		slots_root = Node3D.new()
		slots_root.name = "ItemSpawns"
		add_child(slots_root)
		var slot_defs: Array = _layout.get("slots", [])
		for i in range(mini(16, slot_defs.size())):
			var data: Dictionary = slot_defs[i]
			var slot: Marker3D = _SLOT_SCRIPT.call("from_dict", i + 1, data)
			slots_root.add_child(slot)


func _vent_escape_position() -> Vector3:
	var best_y := 0.0
	var best_pos: Vector3 = _layout.get("escape", Vector3.ZERO)
	var root := get_node_or_null("ItemSpawns")
	if not root:
		return best_pos
	for c in root.get_children():
		if not c is Marker3D or not c.get("surface_kind"):
			continue
		if c.surface_kind != "wall":
			continue
		if c.position.y > best_y:
			best_y = c.position.y
			var n: Vector3 = c.wall_normal.normalized()
			best_pos = c.position - n * 0.04
	return best_pos


func _configure_pm(data: Dictionary, _rng: RandomNumberGenerator) -> void:
	_build_pm_monitors()


func _pm_layout() -> Dictionary:
	return {
		"width": 6.0,
		"depth": 6.0,
		"height": 2.6,
		"theme": "basement",
		"partitions": [],
		"props": [],
		"spawn": Vector3(0, 0.1, 1.5),
		"escape": Vector3.ZERO,
		"corridor_out": Vector3.ZERO,
		"slots": _LAYOUTS.call("slot_layout", 99, 6.0, 6.0),
	}


func _theme_for_layout(layout: Dictionary) -> Dictionary:
	var tid: String = layout.get("theme", "bedroom")
	for t in THEMES:
		if t["id"] == tid:
			return t
	return THEMES[0]


func mark_escape_locked() -> void:
	if not has_node("EscapePoint"):
		return
	var escape_point: Node = get_node("EscapePoint")
	escape_point.prompt_text += " (locked - needs a code)"
	var keypad: StaticBody3D = _ITEMS.call("_make_interactable",
		load("res://scripts/interactables/code_keypad.gd") as Script,
		Vector3(0.24, 0.32, 0.06), Vector3(0.7, 1.0, 0), _accent_material(_theme["accent_color"], theme_id), "Enter code"
	)
	keypad.set("room_index", room_index)
	keypad.name = "CodeKeypad"
	add_child(keypad)


func _build_pm_monitors() -> void:
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.08, 0.07)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.55, 0.35)
	for i in range(3):
		var screen := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(0.4, 0.28, 0.03)
		screen.mesh = quad
		screen.position = Vector3(-0.5 + i * 0.5, 1.6, -depth / 2.0 + 0.05)
		screen.set_surface_override_material(0, screen_mat)
		add_child(screen)


func _build_escape_corridor(corridor_out: Vector3, idx: int) -> void:
	var grid_pos: Vector3 = WorldScale.room_grid_position(idx)
	var dist := Vector2(grid_pos.x, grid_pos.z).length()
	var raw_horiz := dist - WorldScale.HUB_SHAFT_RADIUS - depth * 0.5
	var horiz: float
	if raw_horiz < 1.0:
		horiz = 3.0
	else:
		horiz = clampf(raw_horiz, WorldScale.CORRIDOR_MIN, WorldScale.CORRIDOR_MAX)
	var start_z := corridor_out.z + WALL
	# Escape tunnels ramp upward toward the central shaft / mountain surface.
	var rise := clampf(horiz * 0.045, 0.35, 2.2)
	_TUNNEL.call("build_horizontal", self, start_z, horiz, WorldScale.HUB_HALL_W, WorldScale.HUB_HALL_H, true, true, rise)
	_TUNNEL.call("build_hub_connector", self, start_z + horiz, WorldScale.HUB_HALL_W, WorldScale.HUB_HALL_H, rise)


static func _accent_material(color: Color, theme_id: String = "bedroom") -> StandardMaterial3D:
	var neon: Color = _NEON.call("neon_for_theme", theme_id)
	return _NEON.call("accent_material", color, neon)
