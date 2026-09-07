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


func _init() -> void:
	wall = _mat(Color(0.32, 0.31, 0.3))
	floor = _mat(Color(0.26, 0.25, 0.24))
	ceiling = _mat(Color(0.22, 0.22, 0.23))
	field = _mat(Color(0.38, 0.36, 0.32))
	dirt = _mat(Color(0.28, 0.24, 0.2))
	blood = _mat(Color(0.35, 0.12, 0.1))
	duct = _mat(Color(0.2, 0.2, 0.22))
	wood = _mat(Color(0.4, 0.28, 0.18))


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m
