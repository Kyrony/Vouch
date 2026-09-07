extends Node3D
class_name RoomPod
## RoomPod
##
## One player's "randomly generated small room" - built entirely in code
## from a small "recipe" (size / theme / escape flavor / optional
## connector module / decoration) chosen deterministically from a
## per-room seed, so every peer builds an identical room from the same
## replicated spawn data.
##
## MODULE SYSTEM: a room is 1-2 chained "modules":
##   - The MAIN module is always one of the three room categories -
##     Bedroom / Utility Room / Creepy Basement (`THEMES`).
##   - An optional CONNECTOR module extends north from the main module:
##     Closet (small dead-end alcove), Hallway (corridor + a second
##     chamber), or Vent (a narrower, lower-ceilinged crawlspace + a
##     small end chamber - same shape as a hallway, distinct scale/
##     material so it reads as a cramped vent rather than a hallway).
## Every module boundary uses a STANDARDIZED opening size for its
## category (full-height for hallway/closet, a shorter "vent" opening for
## vent), and adjoining pieces (floor/ceiling/walls) OVERLAP by a small
## margin at every seam so there's never a hairline gap or a view into
## the void - see `SEAM_OVERLAP`. Pipes/wires are built longer than their
## span and embedded into the end walls so you never see a floating,
## flat-cut pipe end - see `_build_decor()`.
##
## TODO(post-MVP): more themes, hand-authored room shapes instead of
## box-and-gap construction, richer decoration variety, 3+ module chains.

const HEIGHT: float = 3.0
const WALL_THICK: float = 0.2
## Adjoining module pieces (floor/ceiling especially) are built slightly
## larger than their exact span and overlapped into the neighboring
## module by this much, so there's never a razor-thin seam that can
## z-fight or show a hairline gap - see the "seamless" requirement.
const SEAM_OVERLAP: float = 0.06

const SIZE_VARIANTS: Array[Dictionary] = [
	{"width": 5.0, "depth": 5.0},
	{"width": 6.0, "depth": 6.0},
	{"width": 7.5, "depth": 8.0},
	{"width": 6.5, "depth": 5.5},
]

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
## The optional second "module" chained onto the main room. VENT is a
## modular connector distinct from CLOSET/HALLWAY (see class doc) that
## can join any of the three main room categories, same as hallway/closet.
enum ConnectorKind { NONE, CLOSET, HALLWAY, VENT }

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

var room_index: int = 0
var owner_peer_id: int = -1
var rng_seed: int = 0
var is_puppet_master_room: bool = false
var theme_id: String = ""
var theme_name: String = ""
var width: float = 6.0
var depth: float = 6.0

var spawn_point: Marker3D
var light_switch: Node
var _theme: Dictionary = THEMES[0]


## Called by the Match director (server-only, e.g. from `_server_spawn_room`)
## BEFORE the room is spawned, to decide anything that depends on
## `MatchSettings` (host-configurable spawn odds). This must NEVER be
## called from `configure()` itself: `configure()` runs identically on
## EVERY peer (including clients) to build the replicated room, but
## `MatchSettings` is a per-peer local autoload - a client's own (default)
## odds could differ from the host's, and if `configure()` re-rolled
## these decisions locally, a client's room could visually/structurally
## desync from what the host (and everyone else) actually built. So
## anything gated by a host-configurable odd is decided ONCE here and
## baked into the replicated spawn `data` dict instead.
static func plan_recipe(is_pm: bool) -> Dictionary:
	var connector := ConnectorKind.NONE
	if not is_pm:
		var feature_roll := randf()
		if feature_roll < 0.28:
			connector = ConnectorKind.CLOSET
		elif feature_roll < 0.28 + MatchSettings.hidden_hallway_chance * 0.4:
			connector = ConnectorKind.HALLWAY
		elif feature_roll < 0.28 + MatchSettings.hidden_hallway_chance * 0.4 + 0.15:
			connector = ConnectorKind.VENT

	var hallway_hidden := connector == ConnectorKind.HALLWAY and randf() < MatchSettings.hidden_hallway_chance
	var has_valve := not is_pm and randf() < MatchSettings.flood_valve_chance

	return {
		"connector": connector,
		"hallway_hidden": hallway_hidden,
		"has_valve": has_valve,
	}


## Called by the Match director's spawn_function BEFORE this node is
## added to the tree, so every descendant's own `_ready()` sees a fully
## built room instead of racing a half-constructed one. `data` matches
## the dictionary Match.gd hands to `MultiplayerSpawner.spawn()`, so every
## peer builds an identical room from identical inputs - anything that
## depends on host-configurable odds (MatchSettings) MUST already be
## resolved into `data` by `plan_recipe()` above; nothing in here may read
## MatchSettings directly (see that function's doc for why).
func configure(data: Dictionary) -> void:
	room_index = data["room_index"]
	owner_peer_id = data["owner_peer_id"]
	rng_seed = data["rng_seed"]
	is_puppet_master_room = data.get("is_puppet_master", false)
	name = "RoomPod_%d" % room_index

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var size_variant: Dictionary = SIZE_VARIANTS[rng.randi() % SIZE_VARIANTS.size()]
	width = size_variant["width"]
	depth = size_variant["depth"]

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

	# Pre-resolved server-side by plan_recipe() - see its doc comment.
	var connector: ConnectorKind = data.get("connector", ConnectorKind.NONE)
	var hallway_hidden: bool = data.get("hallway_hidden", false)
	var has_valve: bool = data.get("has_valve", false)

	var has_pipes := rng.randf() < 0.5
	var has_wires := rng.randf() < 0.4

	_build_shell(rng, theme, escape_kind, connector, hallway_hidden)
	_build_decor(rng, theme, has_pipes, has_wires)
	_build_interactables(rng, theme, escape_kind, has_valve)
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


## Called by the Match director (post-spawn, still before the door prop
## has been interacted with) when this room's escape has been chosen to
## be code-locked. Purely cosmetic/informational on the room side - actual
## enforcement lives in EscapeSystem/PuzzleSystem, keyed by room_index.
func mark_escape_locked() -> void:
	if not has_node("EscapePoint"):
		return
	var escape_point: Door = get_node("EscapePoint")
	escape_point.prompt_text += " (locked - needs a code)"

	var keypad_pos := escape_point.position + Vector3(0.7, -0.3, 0.0)
	var keypad := _make_interactable(CODE_KEYPAD_SCRIPT, Vector3(0.24, 0.32, 0.06), keypad_pos, _accent_material(_theme["accent_color"]), "Enter code")
	var keypad_script: CodeKeypad = keypad
	keypad_script.room_index = room_index
	keypad.name = "CodeKeypad"
	add_child(keypad)


## Called by the Match director to place a discoverable clue (containing
## some OTHER room's unlock code) inside this room.
func add_clue_prop(kind: String, code: String) -> void:
	var nook := Vector3(-width / 2.0 + 0.5, 0.9, depth / 2.0 - 0.6)
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
# Shell construction (floor / ceiling / walls with optional gaps)
# ---------------------------------------------------------------------

func _build_shell(rng: RandomNumberGenerator, theme: Dictionary, escape_kind: EscapeKind, connector: ConnectorKind, hallway_hidden: bool) -> void:
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

	# South wall (positive Z) always hosts the escape point, unless this
	# is the Puppet Master's room (EscapeKind.NONE -> fully solid wall).
	var south_gap := 0.0 if escape_kind == EscapeKind.NONE else (1.2 if escape_kind == EscapeKind.DOOR else 0.9)
	_build_wall(true, depth / 2.0, width, south_gap, 0.0, wall_mat, HEIGHT)

	# North wall optionally hosts a closet, hallway, or vent opening.
	var north_gap := 0.0
	var north_gap_height := HEIGHT
	match connector:
		ConnectorKind.CLOSET:
			north_gap = 1.2
		ConnectorKind.HALLWAY:
			north_gap = 1.6
		ConnectorKind.VENT:
			north_gap = 0.9
			north_gap_height = 2.0
	_build_wall(true, -depth / 2.0, width, north_gap, 0.0, wall_mat, north_gap_height)

	# East/west walls are always solid - they host the light switch and
	# phone respectively.
	_build_wall(false, width / 2.0, depth, 0.0, 0.0, wall_mat, HEIGHT)
	_build_wall(false, -width / 2.0, depth, 0.0, 0.0, wall_mat, HEIGHT)

	match connector:
		ConnectorKind.CLOSET:
			_build_connector_wing(wall_mat, floor_mat, theme, 1.4, 1.3, 3.0, HEIGHT, false)
		ConnectorKind.HALLWAY:
			_build_connector_wing(wall_mat, floor_mat, theme, 1.6, 3.5, 3.2, HEIGHT, hallway_hidden)
		ConnectorKind.VENT:
			_build_connector_wing(wall_mat, floor_mat, theme, 0.9, 3.0, 2.2, 2.0, false, "vent")

	spawn_point = Marker3D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = Vector3(0, 0.1, depth / 2.0 - 1.2)
	add_child(spawn_point)


## `is_x_axis` true = wall runs along X (north/south); false = along Z
## (east/west). `wall_offset` is this wall's fixed coordinate along its
## perpendicular axis (e.g. +/-depth/2 for north/south). `gap_height`, if
## less than HEIGHT, adds a "header" segment above the gap so a shorter
## connector (e.g. a vent) still seals seamlessly into the full-height
## wall instead of leaving a tall slot open above it.
func _build_wall(is_x_axis: bool, wall_offset: float, span: float, gap_width: float, gap_center: float, material: Material, gap_height: float = HEIGHT) -> void:
	if gap_width <= 0.01:
		var size := Vector3(span, HEIGHT, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, HEIGHT, span)
		var pos := Vector3(0, HEIGHT / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, HEIGHT / 2.0, 0)
		add_child(_make_box_body(size, pos, material, 1))
		return

	var half_span := span / 2.0
	var seg1_len: float = (gap_center - gap_width / 2.0) - (-half_span)
	var seg2_len: float = half_span - (gap_center + gap_width / 2.0)

	if seg1_len > 0.05:
		var seg1_center := -half_span + seg1_len / 2.0
		var size1 := Vector3(seg1_len, HEIGHT, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, HEIGHT, seg1_len)
		var pos1 := Vector3(seg1_center, HEIGHT / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, HEIGHT / 2.0, seg1_center)
		add_child(_make_box_body(size1, pos1, material, 1))

	if seg2_len > 0.05:
		var seg2_center := gap_center + gap_width / 2.0 + seg2_len / 2.0
		var size2 := Vector3(seg2_len, HEIGHT, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, HEIGHT, seg2_len)
		var pos2 := Vector3(seg2_center, HEIGHT / 2.0, wall_offset) if is_x_axis else Vector3(wall_offset, HEIGHT / 2.0, seg2_center)
		add_child(_make_box_body(size2, pos2, material, 1))

	if gap_height < HEIGHT - 0.01:
		var header_thickness := HEIGHT - gap_height
		var header_center_y := gap_height + header_thickness / 2.0
		var size3 := Vector3(gap_width + SEAM_OVERLAP, header_thickness, WALL_THICK) if is_x_axis else Vector3(WALL_THICK, header_thickness, gap_width + SEAM_OVERLAP)
		var pos3 := Vector3(gap_center, header_center_y, wall_offset) if is_x_axis else Vector3(wall_offset, header_center_y, gap_center)
		add_child(_make_box_body(size3, pos3, material, 1))


## Builds ANY of the closet/hallway/vent connector modules - they're all
## the same shape (a corridor optionally ending in a small chamber),
## differing only in width/length/chamber size/ceiling height/material
## flavor. `kind_flavor` picks a distinct wall material for "vent" so it
## visually reads as a crawlspace rather than a normal-room hallway, even
## though (for simplicity/scope) it uses the same walkable collision as
## everywhere else - see class doc for why we don't implement crouching.
func _build_connector_wing(wall_mat: Material, floor_mat: Material, theme: Dictionary, corridor_width: float, corridor_length: float, chamber_size: float, ceiling_height: float, hidden: bool, kind_flavor: String = "") -> void:
	var corridor_mat := wall_mat
	var corridor_floor_mat := floor_mat
	if kind_flavor == "vent":
		corridor_mat = _vent_material()
		corridor_floor_mat = _vent_material()

	var z0 := -depth / 2.0
	var z1 := z0 - corridor_length
	var overlap := SEAM_OVERLAP

	# Floor/ceiling overlap slightly INTO the main room so there's never a
	# hairline seam at the doorway threshold.
	add_child(_make_box_body(Vector3(corridor_width, WALL_THICK, corridor_length + overlap), Vector3(0, -WALL_THICK / 2.0, z0 - corridor_length / 2.0 + overlap / 2.0), corridor_floor_mat, 1))
	if ceiling_height < HEIGHT - 0.01:
		add_child(_make_box_body(Vector3(corridor_width, WALL_THICK, corridor_length + overlap), Vector3(0, ceiling_height + WALL_THICK / 2.0, z0 - corridor_length / 2.0 + overlap / 2.0), corridor_mat, 0))
	add_child(_make_box_body(Vector3(WALL_THICK, ceiling_height, corridor_length), Vector3(-corridor_width / 2.0, ceiling_height / 2.0, z0 - corridor_length / 2.0), corridor_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, ceiling_height, corridor_length), Vector3(corridor_width / 2.0, ceiling_height / 2.0, z0 - corridor_length / 2.0), corridor_mat, 1))

	if not chamber_size > 0.0:
		return

	# End chamber, fully enclosing the far end of the corridor - no dead
	# opening to the void.
	var chamber_center_z := z1 - chamber_size / 2.0
	add_child(_make_box_body(Vector3(chamber_size, WALL_THICK, chamber_size + overlap), Vector3(0, -WALL_THICK / 2.0, chamber_center_z - overlap / 2.0), corridor_floor_mat, 1))
	add_child(_make_box_body(Vector3(chamber_size, ceiling_height, WALL_THICK), Vector3(0, ceiling_height / 2.0, z1 - chamber_size), corridor_mat, 1))
	if ceiling_height < HEIGHT - 0.01:
		add_child(_make_box_body(Vector3(chamber_size, WALL_THICK, chamber_size + overlap), Vector3(0, ceiling_height + WALL_THICK / 2.0, chamber_center_z - overlap / 2.0), corridor_mat, 0))
	else:
		var chamber_ceiling := MeshInstance3D.new()
		var cc_mesh := BoxMesh.new()
		cc_mesh.size = Vector3(chamber_size, WALL_THICK, chamber_size)
		chamber_ceiling.mesh = cc_mesh
		chamber_ceiling.set_surface_override_material(0, corridor_mat)
		chamber_ceiling.position = Vector3(0, HEIGHT + WALL_THICK / 2.0, chamber_center_z)
		add_child(chamber_ceiling)
	add_child(_make_box_body(Vector3(WALL_THICK, ceiling_height, chamber_size + overlap), Vector3(-chamber_size / 2.0, ceiling_height / 2.0, chamber_center_z - overlap / 2.0), corridor_mat, 1))
	add_child(_make_box_body(Vector3(WALL_THICK, ceiling_height, chamber_size + overlap), Vector3(chamber_size / 2.0, ceiling_height / 2.0, chamber_center_z - overlap / 2.0), corridor_mat, 1))

	if hidden:
		var bookcase := _make_interactable(MOVABLE_PROP_SCRIPT, Vector3(corridor_width - 0.1, ceiling_height * 0.85, 0.3), Vector3(0, ceiling_height * 0.85 / 2.0, z0), _accent_material(theme["accent_color"]), "Move bookcase")
		var bookcase_script: MovableProp = bookcase
		bookcase_script.move_offset = Vector3(corridor_width, 0.0, 0.0)
		bookcase.name = "SecretBookcase"
		add_child(bookcase)


func _vent_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.34)
	mat.metallic = 0.5
	mat.roughness = 0.5
	return mat


# ---------------------------------------------------------------------
# Interactables (light switch, escape point, phone, room light, camera)
# ---------------------------------------------------------------------

func _build_interactables(rng: RandomNumberGenerator, theme: Dictionary, escape_kind: EscapeKind, has_valve: bool) -> void:
	var accent := _accent_material(theme["accent_color"])
	var control_id := "room_%d_light_switch" % room_index
	var effect_id := "room_%d_room_light" % room_index

	var switch := _make_interactable(LIGHT_SWITCH_SCRIPT, Vector3(0.15, 0.2, 0.06), Vector3(-width / 2.0 + 0.1, 1.2, -depth * 0.2), accent, "Flip switch")
	var switch_script: LightSwitch = switch
	switch_script.control_id = control_id
	switch_script.room_index = room_index
	switch.name = "LightSwitch"
	add_child(switch)
	light_switch = switch

	if escape_kind != EscapeKind.NONE:
		var is_door := escape_kind == EscapeKind.DOOR
		var escape_size: Vector3
		var escape_pos: Vector3
		var escape_prompt: String
		if is_door:
			escape_size = Vector3(1.0, 2.0, 0.12)
			escape_pos = Vector3(0, 1.0, depth / 2.0 - 0.06)
			escape_prompt = "Open the door"
		else:
			escape_size = Vector3(0.7, 0.55, 0.1)
			escape_pos = Vector3(0, 0.45, depth / 2.0 - 0.06)
			escape_prompt = "Squeeze through the vent"
		var escape_point := _make_interactable(DOOR_SCRIPT, escape_size, escape_pos, accent, escape_prompt)
		escape_point.name = "EscapePoint"
		add_child(escape_point)

	var phone := _make_interactable(PHONE_SCRIPT, Vector3(0.16, 0.26, 0.1), Vector3(width / 2.0 - 0.1, 1.2, depth * 0.2), accent, "Pick up phone")
	var phone_script: Phone = phone
	phone_script.owner_peer_id = owner_peer_id
	phone.name = "Phone"
	add_child(phone)

	var camera_mount_y := HEIGHT - 0.3
	var camera := _make_interactable(SECURITY_CAMERA_SCRIPT, Vector3(0.18, 0.18, 0.28), Vector3(width / 2.0 - 0.3, camera_mount_y, -depth / 2.0 + 0.3), accent, "Camera")
	var camera_script: SecurityCamera = camera
	camera_script.min_elevation_y = camera_mount_y - 1.2
	camera.name = "SecurityCamera"
	add_child(camera)

	# A camera mounted near the ceiling needs a ladder to reach - see
	# SecurityCamera.min_elevation_y (checked by Player.gd's hold-to-
	# destroy flow) and Ladder.gd's climbing physics.
	var ladder := LADDER_SCENE.instantiate()
	ladder.position = Vector3(width / 2.0 - 0.15, 0, -depth / 2.0 + 0.9)
	ladder.rotation.y = PI
	if ladder.has_method("configure"):
		ladder.configure(camera_mount_y + 0.3)
	add_child(ladder)

	if has_valve:
		var valve_control_id := "room_%d_water_valve" % room_index
		var valve := _make_interactable(WATER_VALVE_SCRIPT, Vector3(0.16, 0.16, 0.12), Vector3(-width / 2.0 + 0.1, 0.9, depth * 0.2), accent, "Turn valve")
		var valve_script: WaterValve = valve
		valve_script.control_id = valve_control_id
		valve_script.room_index = room_index
		valve.name = "WaterValve"
		add_child(valve)

	var room_light := Node3D.new()
	room_light.set_script(ROOM_LIGHT_SCRIPT)
	room_light.name = "RoomLight"
	room_light.position = Vector3(0, HEIGHT - 0.3, 0)
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

	# Every room gets a broken-pipe EFFECT target (like every room gets a
	# room light) - most never get triggered since valves are sparse, but
	# the effect pool needs to exist everywhere for LinkGraph's pairing.
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


func _build_monitors(theme: Dictionary) -> void:
	# Decorative "a few monitors" for the Puppet Master's perfect box -
	# purely visual flavor. The FUNCTIONAL camera feeds are the PM-only
	# HUD panel (Player.gd), not these world-space screens, so nobody who
	# wanders into the PM's room (there's nothing stopping them) can peek
	# at the live feeds just by looking at the wall.
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


# ---------------------------------------------------------------------
# Decoration (pipes, wires, scattered props)
# ---------------------------------------------------------------------

func _build_decor(rng: RandomNumberGenerator, theme: Dictionary, has_pipes: bool, has_wires: bool) -> void:
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.45, 0.46, 0.48)
	pipe_mat.metallic = 0.6
	pipe_mat.roughness = 0.4

	if has_pipes:
		var pipe_count := 1 + (1 if depth > 6.5 else 0)
		for i in range(pipe_count):
			var pipe := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.08
			# Oversized on purpose: longer than the room span so both
			# ends bury into the north/south walls rather than floating
			# in open air with a visible flat cut end.
			cyl.height = depth + 0.3
			pipe.mesh = cyl
			pipe.rotation_degrees = Vector3(90, 0, 0)
			pipe.position = Vector3(-width / 2.0 + 0.3 + i * 0.3, HEIGHT - 0.15, 0)
			pipe.set_surface_override_material(0, pipe_mat)
			add_child(pipe)

	if has_wires:
		var wire_mat := StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.12, 0.12, 0.12)
		var segments := 5
		# Oversized on purpose (extends past the wall face on both ends)
		# so the wire run appears to continue into the wall rather than
		# stopping abruptly in mid-air.
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
	var marker_count: int = clampi(int(width * depth / 9.0), 2, 6)
	var margin := 1.0

	for i in range(marker_count):
		if rng.randf() < 0.3:
			continue
		var x := rng.randf_range(-width / 2.0 + margin, width / 2.0 - margin)
		var z := rng.randf_range(-depth / 2.0 + margin, depth / 2.0 - margin - 1.0)
		var scene: PackedScene = prop_scenes[rng.randi() % prop_scenes.size()]
		var prop := scene.instantiate()
		prop.position = Vector3(x, 0, z)
		prop.rotation.y = rng.randf_range(0.0, TAU)
		add_child(prop)


# ---------------------------------------------------------------------
# Small construction helpers
# ---------------------------------------------------------------------

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
