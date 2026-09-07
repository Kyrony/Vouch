extends RefCounted
class_name ItemSpawnSystem
## Assigns interactables to typed ItemSpawnSlot markers (wall / floor / wall_floor).

const SLOT_COUNT: int = 16
const WALL_EMBED: float = 0.04

const LIGHT_SWITCH_SCRIPT: Script = preload("res://scripts/interactables/light_switch.gd")
const DOOR_SCRIPT: Script = preload("res://scripts/interactables/door.gd")
const PHONE_SCRIPT: Script = preload("res://scripts/interactables/phone.gd")
const SECURITY_CAMERA_SCRIPT: Script = preload("res://scripts/interactables/security_camera.gd")
const WATER_VALVE_SCRIPT: Script = preload("res://scripts/interactables/water_valve.gd")
const ELECTRICAL_BOX_SCRIPT: Script = preload("res://scripts/interactables/electrical_box.gd")
const GAS_VALVE_SCRIPT: Script = preload("res://scripts/interactables/gas_valve.gd")
const DRAIN_SCRIPT: Script = preload("res://scripts/interactables/drain.gd")
const EXHAUST_VENT_SCRIPT: Script = preload("res://scripts/interactables/exhaust_vent.gd")
const _FIREPLACE_SCRIPT: GDScript = preload("res://scripts/interactables/fireplace.gd")
const BINARY_TERMINAL_SCRIPT: Script = preload("res://scripts/interactables/binary_terminal.gd")
const MOVABLE_PROP_SCRIPT: Script = preload("res://scripts/interactables/movable_prop.gd")
const ROOM_PEEK_MONITOR_SCRIPT: Script = preload("res://scripts/interactables/room_peek_monitor.gd")
const LADDER_SCENE: PackedScene = preload("res://scenes/Match/Interactables/Ladder.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/Match/Props/Crate.tscn")
const SHELF_SCENE: PackedScene = preload("res://scenes/Match/Props/Shelf.tscn")
const BARREL_SCENE: PackedScene = preload("res://scenes/Match/Props/Barrel.tscn")
const _SLOT_SCRIPT: GDScript = preload("res://scripts/rooms/item_spawn_slot.gd")


static func populate(room: Node3D, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var slots := _collect_slots(room)
	if slots.size() != SLOT_COUNT:
		push_warning("ItemSpawnSystem: expected %d slots, found %d in %s" % [SLOT_COUNT, slots.size(), room.name])

	var pools := _group_slots_by_surface(slots)
	var requests := _build_requests(ctx, rng)
	var result := {"light_switch": null, "fireplace": null, "bookcase": null, "peek_monitor": null}
	var accent: Material = ctx["accent_material"]

	for req in requests:
		var surface_key: String = _surface_for_kind(req["kind"])
		var pool: Array = pools.get(surface_key, [])
		if pool.is_empty():
			push_warning("ItemSpawnSystem: no %s slot for %s in %s" % [surface_key, req["kind"], room.name])
			continue
		var pick := rng.randi() % pool.size()
		var slot: Marker3D = pool[pick]
		pool.remove_at(pick)

		var node := _spawn_request(room, req, slot, accent, ctx)
		if node == null:
			continue
		match req["kind"]:
			"light_switch":
				result["light_switch"] = node
			"fireplace":
				result["fireplace"] = node
			"bookcase":
				result["bookcase"] = node
			"peek_monitor":
				result["peek_monitor"] = node

	var floor_pool: Array = pools.get("floor", [])
	while not floor_pool.is_empty():
		var slot: Marker3D = floor_pool.pop_back()
		var prop_scene: PackedScene = [CRATE_SCENE, SHELF_SCENE, BARREL_SCENE][rng.randi() % 3]
		var req := {"kind": "prop", "scene": prop_scene}
		_spawn_request(room, req, slot, accent, ctx)

	if ctx.get("has_binary_puzzle", false) and result["bookcase"] and result["peek_monitor"]:
		var term := room.get_node_or_null("BinaryTerminal")
		if term:
			term.set("bookcase", result["bookcase"])
			term.set("peek_monitor", result["peek_monitor"])

	return result


static func _surface_for_kind(kind: String) -> String:
	match kind:
		"fireplace":
			return "wall_floor"
		"drain", "ladder", "bookcase", "prop":
			return "floor"
		_:
			return "wall"


static func _group_slots_by_surface(slots: Array) -> Dictionary:
	var pools := {"wall": [], "floor": [], "wall_floor": []}
	for slot in slots:
		if slot is Marker3D and slot.get("surface_kind"):
			var kind: String = slot.surface_kind
			if pools.has(kind):
				pools[kind].append(slot)
	return pools


static func spawn_escape(room: Node3D, ctx: Dictionary, escape_pos: Vector3, is_vent: bool) -> void:
	var accent: Material = ctx["accent_material"]
	var prompt := "Squeeze through the vent" if is_vent else "Open the door"
	var size := Vector3(0.55, 0.45, 0.08) if is_vent else Vector3(0.85, 2.05, 0.08)
	var door := _make_door(size, escape_pos, accent, prompt, is_vent)
	door.name = "EscapePoint"
	room.add_child(door)


static func spawn_room_effects(room: Node3D, ctx: Dictionary) -> void:
	var layout: Dictionary = ctx["layout"]
	var w: float = layout["width"]
	var d: float = layout["depth"]
	var h: float = layout["height"]
	var room_index: int = ctx["room_index"]
	var owner_peer_id: int = ctx["owner_peer_id"]

	var room_light := Node3D.new()
	room_light.set_script(preload("res://scripts/interactables/room_light.gd"))
	room_light.name = "RoomLight"
	room_light.position = Vector3(0, h - 0.3, 0)
	var bulb_light := OmniLight3D.new()
	bulb_light.name = "OmniLight3D"
	bulb_light.light_color = ctx["theme"]["light_color"]
	bulb_light.light_energy = 1.6
	bulb_light.omni_range = maxf(w, d) + 2.0
	room_light.add_child(bulb_light)
	var bulb_mesh := MeshInstance3D.new()
	bulb_mesh.name = "BulbMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	bulb_mesh.mesh = sphere
	bulb_mesh.set_surface_override_material(0, preload("res://assets/materials/bulb_emissive.tres"))
	room_light.add_child(bulb_mesh)
	room_light.set("effect_id", "room_%d_room_light" % room_index)
	room_light.set("owner_peer_id", owner_peer_id)
	room_light.set("room_index", room_index)
	room.add_child(room_light)

	var pipe := Node3D.new()
	pipe.set_script(preload("res://scripts/interactables/broken_pipe.gd"))
	pipe.name = "BrokenPipe"
	var water_mesh := MeshInstance3D.new()
	water_mesh.name = "WaterMesh"
	var water_box := BoxMesh.new()
	water_box.size = Vector3(w - 0.24, 1.0, d - 0.24)
	water_mesh.mesh = water_box
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.4, 0.55, 0.55)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh.set_surface_override_material(0, water_mat)
	water_mesh.visible = false
	pipe.add_child(water_mesh)
	pipe.set("effect_id", "room_%d_broken_pipe" % room_index)
	pipe.set("owner_peer_id", owner_peer_id)
	pipe.set("room_index", room_index)
	pipe.set("room_height", h)
	room.add_child(pipe)

	var gas_leak := Node3D.new()
	gas_leak.set_script(preload("res://scripts/interactables/gas_leak.gd"))
	gas_leak.name = "GasLeak"
	gas_leak.position = Vector3(-1.5, h - 0.5, 1.0)
	gas_leak.set("effect_id", "room_%d_gas_leak" % room_index)
	gas_leak.set("owner_peer_id", owner_peer_id)
	gas_leak.set("room_index", room_index)
	room.add_child(gas_leak)


static func _collect_slots(room: Node3D) -> Array:
	var slots: Array = []
	var root := room.get_node_or_null("ItemSpawns")
	if not root:
		return slots
	for c in root.get_children():
		if c is Marker3D and c.get("slot_index"):
			slots.append(c)
	slots.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return int(a.slot_index) < int(b.slot_index))
	return slots


static func _build_requests(ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var requests: Array = []
	var room_index: int = ctx["room_index"]
	var theme_id: String = ctx.get("theme_id", "bedroom")

	requests.append({"kind": "light_switch", "control_id": "room_%d_light_switch" % room_index})
	requests.append({"kind": "phone"})
	requests.append({"kind": "camera"})
	requests.append({"kind": "ladder"})

	if ctx.get("has_valve", false):
		requests.append({"kind": "water_valve", "control_id": "room_%d_water_valve" % room_index})
	if ctx.get("has_electrical_box", false):
		requests.append({"kind": "electrical_box", "targets": ctx.get("wire_targets", [])})
	if ctx.get("has_drain", false):
		requests.append({"kind": "drain"})
	if ctx.get("has_exhaust", false):
		requests.append({"kind": "exhaust"})
	if ctx.get("has_fireplace", false):
		requests.append({"kind": "fireplace"})
	if theme_id == "utility" and rng.randf() < 0.5:
		requests.append({"kind": "gas_valve", "control_id": "room_%d_gas_valve" % room_index})
	if ctx.get("has_binary_puzzle", false):
		requests.append({"kind": "binary_terminal", "target": ctx.get("binary_target", 0), "peek_room": ctx.get("binary_peek_room", -1)})
		requests.append({"kind": "bookcase"})
		requests.append({"kind": "peek_monitor", "peek_room": ctx.get("binary_peek_room", -1)})

	return requests


static func _spawn_request(room: Node3D, req: Dictionary, slot: Marker3D, accent: Material, ctx: Dictionary) -> Node:
	var room_index: int = ctx["room_index"]
	var owner_peer_id: int = ctx["owner_peer_id"]
	var pos := _anchor_position(slot, req["kind"])
	var rot_y := slot.rotation.y

	match req["kind"]:
		"light_switch":
			var sw := _make_interactable(LIGHT_SWITCH_SCRIPT, Vector3(0.08, 0.12, 0.04), pos, accent, "Flip switch")
			sw.rotation.y = rot_y
			sw.set("control_id", req["control_id"])
			sw.set("room_index", room_index)
			sw.name = "LightSwitch"
			room.add_child(sw)
			return sw
		"phone":
			var phone := _make_interactable(PHONE_SCRIPT, Vector3(0.12, 0.18, 0.06), pos, accent, "Pick up phone")
			phone.rotation.y = rot_y
			phone.set("owner_peer_id", owner_peer_id)
			phone.name = "Phone"
			room.add_child(phone)
			return phone
		"camera":
			var cam := _make_interactable(SECURITY_CAMERA_SCRIPT, Vector3(0.14, 0.1, 0.12), pos, accent, "Camera")
			cam.rotation.y = rot_y
			cam.set("min_elevation_y", pos.y - 1.2)
			cam.name = "SecurityCamera"
			room.add_child(cam)
			return cam
		"ladder":
			var ladder := LADDER_SCENE.instantiate()
			ladder.position = pos
			ladder.rotation.y = rot_y + PI
			if ladder.has_method("configure"):
				ladder.configure(pos.y + 0.95, room_index)
			ladder.prompt_text = "Pick up ladder"
			room.add_child(ladder)
			return ladder
		"water_valve":
			var valve := _make_interactable(WATER_VALVE_SCRIPT, Vector3(0.1, 0.1, 0.08), pos, accent, "Turn valve")
			valve.rotation.y = rot_y
			valve.set("control_id", req["control_id"])
			valve.set("room_index", room_index)
			valve.name = "WaterValve"
			room.add_child(valve)
			return valve
		"electrical_box":
			var box := _make_interactable(ELECTRICAL_BOX_SCRIPT, Vector3(0.35, 0.45, 0.12), pos, accent, "Electrical box")
			box.rotation.y = rot_y
			box.call("configure", room_index, req.get("targets", []))
			box.name = "ElectricalBox"
			room.add_child(box)
			return box
		"drain":
			var drain_pos := pos + Vector3(0, 0.025, 0)
			var drain := _make_interactable(DRAIN_SCRIPT, Vector3(0.35, 0.05, 0.35), drain_pos, accent, "Floor drain")
			drain.rotation.y = rot_y
			drain.call("configure", room_index)
			drain.name = "Drain"
			room.add_child(drain)
			return drain
		"exhaust":
			var exhaust := _make_interactable(EXHAUST_VENT_SCRIPT, Vector3(0.5, 0.35, 0.12), pos, accent, "Exhaust vent")
			exhaust.rotation.y = rot_y
			exhaust.call("configure", room_index)
			exhaust.name = "ExhaustVent"
			room.add_child(exhaust)
			return exhaust
		"fireplace":
			var fp: Node3D = _FIREPLACE_SCRIPT.build(room, pos, accent, room_index)
			fp.rotation.y = rot_y
			return fp
		"gas_valve":
			var gv := _make_interactable(GAS_VALVE_SCRIPT, Vector3(0.09, 0.09, 0.06), pos, accent, "Turn gas valve")
			gv.rotation.y = rot_y
			gv.set("control_id", req["control_id"])
			gv.set("room_index", room_index)
			gv.name = "GasValve"
			room.add_child(gv)
			return gv
		"binary_terminal":
			var term := _make_interactable(BINARY_TERMINAL_SCRIPT, Vector3(0.35, 0.28, 0.1), pos, accent, "Binary terminal")
			term.rotation.y = rot_y
			term.name = "BinaryTerminal"
			term.call("configure", room_index, req.get("target", 0), 8)
			room.add_child(term)
			return term
		"bookcase":
			var bc_pos := pos + Vector3(0, 0.55, 0)
			var bc := _make_interactable(MOVABLE_PROP_SCRIPT, Vector3(0.55, 1.1, 0.35), bc_pos, accent, "Move bookcase")
			bc.rotation.y = rot_y
			bc.name = "BinaryBookcase"
			bc.set("move_offset", Vector3(0.95, 0, 0))
			bc.set("unmoved_prompt", "Blocked by bookcase")
			bc.set("moved_prompt", "Bookcase moved")
			room.add_child(bc)
			return bc
		"peek_monitor":
			var mon := StaticBody3D.new()
			mon.set_script(ROOM_PEEK_MONITOR_SCRIPT)
			mon.name = "RoomPeekMonitor"
			mon.position = pos
			mon.rotation.y = rot_y
			mon.collision_layer = 2
			mon.prompt_text = "Security monitor (locked)"
			var mesh_instance := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.55, 0.38, 0.08)
			mesh_instance.mesh = box
			mesh_instance.set_surface_override_material(0, accent)
			mon.add_child(mesh_instance)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.55, 0.38, 0.08)
			collision.shape = shape
			mon.add_child(collision)
			mon.call("configure", room_index, req.get("peek_room", -1))
			mon.visible = false
			for c in mon.get_children():
				if c is CollisionShape3D:
					c.disabled = true
			room.add_child(mon)
			return mon
		"prop":
			var scene: PackedScene = req["scene"]
			var prop: Node3D = scene.instantiate() as Node3D
			prop.position = pos
			prop.rotation.y = rot_y
			room.add_child(prop)
			return prop
	return null


static func _anchor_position(slot: Marker3D, kind: String) -> Vector3:
	var surface_kind: String = slot.surface_kind if slot.get("surface_kind") else "wall"
	var n: Vector3 = slot.wall_normal if slot.get("wall_normal") else Vector3(0, 0, -1)
	n = n.normalized()
	match surface_kind:
		"floor":
			var half_y := 0.0
			if kind == "bookcase":
				half_y = 0.55
			elif kind == "drain":
				half_y = 0.025
			return slot.position + Vector3(0, half_y, 0)
		"wall_floor":
			return slot.position
		_:
			return slot.position - n * WALL_EMBED


static func _make_interactable(script: Script, size: Vector3, local_pos: Vector3, material: Material, prompt: String) -> StaticBody3D:
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


static func _make_door(size: Vector3, local_pos: Vector3, material: Material, prompt: String, is_vent: bool) -> Node:
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
	body.set("is_vent", is_vent)
	return body
