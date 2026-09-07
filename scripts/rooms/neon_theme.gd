extends RefCounted
class_name NeonTheme
## Retro bunker neon accents — vibrant but restrained.


static func accent_material(base: Color, neon: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = neon
	mat.emission_energy_multiplier = 0.35
	return mat


static func trim_material(neon: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = neon.darkened(0.55)
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = neon
	mat.emission_energy_multiplier = 0.5
	return mat


static func neon_for_theme(theme_id: String) -> Color:
	match theme_id:
		"utility":
			return Color(0.2, 1.0, 0.55)
		"basement":
			return Color(1.0, 0.35, 0.45)
		_:
			return Color(0.35, 0.85, 1.0)
