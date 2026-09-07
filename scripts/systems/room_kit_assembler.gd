extends RefCounted
class_name RoomKitAssembler
## Instances kit modules from James plan recipes and wires zone / socket metadata.

const _KB: GDScript = preload("res://scripts/kit/kit_builder.gd")
const _KM: GDScript = preload("res://scripts/kit/kit_module.gd")
const _MATS: GDScript = preload("res://scripts/kit/kit_materials.gd")
const _RECIPES: GDScript = preload("res://scripts/systems/room_kit_recipes.gd")


static func assemble(parent: Node3D, plan_id: String, theme: Dictionary, _escape_kind: int, _rng: RandomNumberGenerator) -> Dictionary:
	var recipe: Dictionary = _RECIPES.call("recipe_for_plan", plan_id)
	var kit_root := Node3D.new()
	kit_root.name = "KitAssembly"
	parent.add_child(kit_root)

	var placed: Array = []
	var zone_centers: Dictionary = {}
	var mount_sockets: Dictionary = {}
	var corridor_out := Vector3(0, _KB.DOOR_H, 3.0)
	var spawn_local := Vector3(0, 0.1, 1.0)

	for entry in recipe.get("modules", []):
		var opts: Dictionary = entry.get("opts", {}).duplicate(true)
		var role: String = entry.get("role", entry["type"])
		opts["role"] = role
		var mod: Node3D = _KB.call("build", entry["type"], theme, opts)
		mod.set("module_type", entry["type"])
		mod.position = entry["pos"]
		mod.rotation.y = entry.get("rot_y", 0.0)
		kit_root.add_child(mod)
		placed.append({"node": mod, "role": role})

		if not zone_centers.has(role):
			zone_centers[role] = mod.position
		else:
			zone_centers[role] = (zone_centers[role] + mod.position) * 0.5

		if role == "living" or opts.get("spawn_here", false):
			var sp: Marker3D = mod.call("get_socket", "SpawnPoint")
			if sp:
				spawn_local = sp.position + mod.position

		if opts.get("corridor_out", false):
			var co: Marker3D = mod.call("get_socket", "CorridorOut")
			if co:
				corridor_out = co.position + mod.position

		for mount_name in ["Mount_Switch", "Mount_Phone", "Mount_Camera", "Mount_Fireplace", "Vent_Ceiling"]:
			var sock: Marker3D = mod.call("get_socket", mount_name)
			if sock:
				mount_sockets[mount_name] = sock.position + mod.position

	var fp: Vector2 = _KB.call("footprint", placed)
	var bounds: Dictionary = _bounds(placed)

	var spawn_marker := Marker3D.new()
	spawn_marker.name = "SpawnPoint"
	spawn_marker.position = spawn_local
	parent.add_child(spawn_marker)

	_add_perimeter_trim(kit_root, bounds, theme)
	_add_ambient(parent, theme)

	return {
		"footprint": fp,
		"width": fp.x,
		"depth": fp.y,
		"zone_centers": zone_centers,
		"mount_sockets": mount_sockets,
		"corridor_out": corridor_out,
		"spawn_point": spawn_marker,
		"recipe_id": recipe.get("id", ""),
	}


static func _bounds(placed: Array) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for entry in placed:
		var mod: Node3D = entry["node"]
		var module_type: String = mod.get("module_type")
		var size: Vector2 = _KB.SIZES.get(module_type, _KB.SIZES["living"])
		var hw := size.x * 0.5
		var hd := size.y * 0.5
		var p: Vector3 = mod.position
		min_x = minf(min_x, p.x - hw)
		max_x = maxf(max_x, p.x + hw)
		min_z = minf(min_z, p.z - hd)
		max_z = maxf(max_z, p.z + hd)
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


static func _add_perimeter_trim(kit_root: Node3D, bounds: Dictionary, theme: Dictionary) -> void:
	var trim_mat: StandardMaterial3D = _MATS.call("for_module", "living", theme)["trim"]
	var w: float = bounds["max_x"] - bounds["min_x"]
	var d: float = bounds["max_z"] - bounds["min_z"]
	var cx: float = (bounds["min_x"] + bounds["max_x"]) * 0.5
	var cz: float = (bounds["min_z"] + bounds["max_z"]) * 0.5
	var y: float = _KB.TRIM_H * 0.5
	var trim := Node3D.new()
	trim.name = "PerimeterTrim"
	kit_root.add_child(trim)
	var south := StaticBody3D.new()
	south.position = Vector3(cx, y, bounds["max_z"] - 0.02)
	var sm := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(w + 0.1, _KB.TRIM_H, _KB.TRIM_D)
	sm.mesh = sb
	sm.set_surface_override_material(0, trim_mat)
	south.add_child(sm)
	trim.add_child(south)


static func _add_ambient(parent: Node3D, theme: Dictionary) -> void:
	if parent.get_node_or_null("KitAmbient"):
		return
	var amb := Node3D.new()
	amb.name = "KitAmbient"
	var fill := OmniLight3D.new()
	fill.light_color = theme.get("light_color", Color(0.85, 0.8, 0.72))
	fill.light_energy = 0.25
	fill.omni_range = 18.0
	fill.position = Vector3(0, _KB.HEIGHT, 0)
	amb.add_child(fill)
	parent.add_child(amb)
