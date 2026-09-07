extends RefCounted
class_name KitMaterials
## Palette presets for modular room kit (floor / wall / ceiling / trim).


static func bunker(theme: Dictionary) -> Dictionary:
	return {
		"floor": _mat(theme.get("floor_color", Color(0.22, 0.21, 0.2)), 0.92, 0.02),
		"wall": _mat(theme.get("wall_color", Color(0.38, 0.36, 0.34)), 0.88, 0.04),
		"ceiling": _mat(theme.get("wall_color", Color(0.32, 0.31, 0.3)).lerp(Color.WHITE, 0.08), 0.95, 0.0),
		"trim": _mat(theme.get("accent_color", Color(0.45, 0.42, 0.38)), 0.7, 0.08),
		"frame": _mat(Color(0.28, 0.26, 0.24), 0.75, 0.1),
		"light": theme.get("light_color", Color(1.0, 0.9, 0.75)),
	}


static func wood_room(theme: Dictionary) -> Dictionary:
	return {
		"floor": _mat(Color(0.34, 0.24, 0.16), 0.82, 0.05),
		"wall": _mat(theme.get("wall_color", Color(0.52, 0.4, 0.34)), 0.86, 0.04),
		"ceiling": _mat(Color(0.88, 0.85, 0.78), 0.94, 0.0),
		"trim": _mat(Color(0.42, 0.32, 0.22), 0.72, 0.06),
		"frame": _mat(Color(0.35, 0.28, 0.2), 0.75, 0.08),
		"light": theme.get("light_color", Color(1.0, 0.88, 0.68)),
	}


static func tile_bath(theme: Dictionary) -> Dictionary:
	return {
		"floor": _mat(Color(0.55, 0.58, 0.6), 0.35, 0.15),
		"wall": _mat(Color(0.72, 0.76, 0.78), 0.4, 0.12),
		"ceiling": _mat(Color(0.9, 0.91, 0.92), 0.6, 0.0),
		"trim": _mat(Color(0.62, 0.64, 0.66), 0.5, 0.1),
		"frame": _mat(Color(0.45, 0.47, 0.48), 0.55, 0.12),
		"light": Color(0.95, 0.98, 1.0),
	}


static func utility(theme: Dictionary) -> Dictionary:
	return bunker(theme)


static func for_module(module_type: String, theme: Dictionary) -> Dictionary:
	match module_type:
		"bath":
			return tile_bath(theme)
		"bedroom", "closet":
			return wood_room(theme)
		"utility":
			return utility(theme)
		_:
			return wood_room(theme)


static func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
