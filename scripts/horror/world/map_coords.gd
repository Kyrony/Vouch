extends RefCounted
class_name MapCoords
## Configurable mask UV → world XZ. Image u left→right is +X east;
## image v top→bottom is +Z south. Defaults come from extract_semantic_masks.py
## (fitted onto Kyle pad centroids). Override via map_transform.txt or setters.

const TRANSFORM_PATH := "res://assets/horror/farm/masks/map_transform.txt"

const TERRAIN_ORIGIN_X: float = -72.0
const TERRAIN_ORIGIN_Z: float = -60.0
const TERRAIN_SPAN_X: float = 144.0
const TERRAIN_SPAN_Z: float = 120.0
const CELL_M: float = 1.5
const MAP_WIDTH: int = 97
const MAP_DEPTH: int = 81

var origin_x: float = -53.80
var origin_z: float = -40.92
var span_x: float = 112.65
var span_z: float = 91.66


func _init() -> void:
	_load_file()


func _load_file() -> void:
	if not FileAccess.file_exists(TRANSFORM_PATH):
		return
	var txt := FileAccess.get_file_as_string(TRANSFORM_PATH)
	for line in txt.split("\n"):
		var parts := line.strip_edges().split("=")
		if parts.size() != 2:
			continue
		var key := parts[0]
		var val := float(parts[1])
		match key:
			"origin_x":
				origin_x = val
			"origin_z":
				origin_z = val
			"span_x":
				span_x = val
			"span_z":
				span_z = val


func configure(ox: float, oz: float, sx: float, sz: float) -> void:
	origin_x = ox
	origin_z = oz
	span_x = sx
	span_z = sz


func uv_to_world(u: float, v: float) -> Vector2:
	return Vector2(origin_x + u * span_x, origin_z + v * span_z)


func world_to_uv(x: float, z: float) -> Vector2:
	return Vector2((x - origin_x) / span_x, (z - origin_z) / span_z)


func world_to_terrain_uv(x: float, z: float) -> Vector2:
	return Vector2((x - TERRAIN_ORIGIN_X) / TERRAIN_SPAN_X, (z - TERRAIN_ORIGIN_Z) / TERRAIN_SPAN_Z)


func in_terrain(x: float, z: float) -> bool:
	return x >= TERRAIN_ORIGIN_X and x <= TERRAIN_ORIGIN_X + TERRAIN_SPAN_X \
		and z >= TERRAIN_ORIGIN_Z and z <= TERRAIN_ORIGIN_Z + TERRAIN_SPAN_Z
