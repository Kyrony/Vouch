extends RefCounted
class_name HorrorGrayboxMaterials
## Shared graybox materials for horror neighborhood builders.

var wall: StandardMaterial3D
var floor: StandardMaterial3D
var ceiling: StandardMaterial3D
var field: StandardMaterial3D
var dirt: StandardMaterial3D
var blood: StandardMaterial3D
var duct: StandardMaterial3D
var wood: StandardMaterial3D
var asphalt: StandardMaterial3D
var curb: StandardMaterial3D
var grass: StandardMaterial3D
## Leonardo kit palettes (soft-go graybox — not Steam-final PBR).
var siding: StandardMaterial3D
var shingle: StandardMaterial3D
var concrete: StandardMaterial3D
var metal: StandardMaterial3D
var neon_magenta: StandardMaterial3D
var neon_red: StandardMaterial3D
var fluorescent: StandardMaterial3D
var glass: StandardMaterial3D


func _init() -> void:
	wall = _mat(Color(0.32, 0.31, 0.3))
	floor = _mat(Color(0.26, 0.25, 0.24))
	ceiling = _mat(Color(0.22, 0.22, 0.23))
	field = _mat(Color(0.32, 0.42, 0.24))
	dirt = _mat(Color(0.46, 0.33, 0.20))
	blood = _mat(Color(0.35, 0.12, 0.1))
	duct = _mat(Color(0.2, 0.2, 0.22))
	wood = _mat(Color(0.4, 0.28, 0.18))
	asphalt = _mat(Color(0.11, 0.11, 0.13))
	curb = _mat(Color(0.68, 0.66, 0.60))
	grass = _mat(Color(0.30, 0.46, 0.22))
	siding = _mat(Color(0.34, 0.33, 0.36))
	shingle = _mat(Color(0.14, 0.13, 0.15))
	concrete = _mat(Color(0.38, 0.36, 0.34))
	metal = _mat(Color(0.28, 0.27, 0.26), 0.42, 0.55)
	neon_magenta = _emit(Color(0.22, 0.08, 0.16), Color(0.95, 0.22, 0.72), 1.4)
	neon_red = _emit(Color(0.28, 0.08, 0.08), Color(0.95, 0.18, 0.16), 1.35)
	fluorescent = _emit(Color(0.55, 0.5, 0.28), Color(1.0, 0.88, 0.42), 1.1)
	glass = _mat(Color(0.12, 0.14, 0.16, 0.55), 0.08, 0.0)


func _mat(color: Color, roughness: float = 0.92, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _emit(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(albedo, 0.35, 0.05)
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m
