extends RefCounted
class_name NeonTheme
## Retro bunker neon accents — softened saturation, restrained emissive energy.


static func _soften(c: Color, sat_scale: float = 0.62) -> Color:
	return Color.from_hsv(c.h, c.s * sat_scale, c.v)


static func accent_material(base: Color, neon: Color) -> StandardMaterial3D:
	var soft_neon := _soften(neon)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.58
	mat.emission_enabled = true
	mat.emission = soft_neon
	mat.emission_energy_multiplier = 0.22
	return mat


static func trim_material(neon: Color) -> StandardMaterial3D:
	var soft_neon := _soften(neon)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = soft_neon.darkened(0.62)
	mat.roughness = 0.48
	mat.emission_enabled = true
	mat.emission = soft_neon
	mat.emission_energy_multiplier = 0.32
	return mat


static func neon_for_theme(theme_id: String) -> Color:
	match theme_id:
		"utility":
			return Color(0.28, 0.72, 0.48)
		"basement":
			return Color(0.78, 0.38, 0.42)
		_:
			return Color(0.38, 0.68, 0.78)
