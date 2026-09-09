extends RefCounted
class_name SemanticMaps
## Samples the extracted 512² semantic masks. These are placement inputs,
## not terrain textures.

const MASK_DIR := "res://assets/horror/farm/masks/"
const SIZE := 512

## Configurable type colors (RGB 0–1). Extra keys stay user-editable.
var type_colors := {
	"mansion": Color(0.86, 0.16, 0.20),
	"family": Color(0.94, 0.59, 0.20),
	"uncle": Color(0.12, 0.43, 0.94),
	"garage": Color(0.59, 0.16, 0.90),
	"utility": Color(0.04, 0.75, 0.86),
}

var coords: MapCoords
var building: Image
var road: Image
var no_spawn: Image
var cliff: Image
var building_type: Image
var vegetation: Image


func _init() -> void:
	coords = MapCoords.new()


func load_all() -> String:
	building = _load_img("building.png")
	road = _load_img("road.png")
	no_spawn = _load_img("no_spawn.png")
	cliff = _load_img("cliff.png")
	building_type = _load_img("building_type.png")
	vegetation = _load_img("vegetation.png")
	if building == null:
		return "building.png missing"
	if road == null:
		return "road.png missing"
	if no_spawn == null:
		return "no_spawn.png missing"
	if cliff == null:
		return "cliff.png missing"
	if building_type == null:
		return "building_type.png missing"
	if vegetation == null:
		return "vegetation.png missing"
	return ""


func _load_img(fname: String) -> Image:
	var path := MASK_DIR + fname
	if not FileAccess.file_exists(path):
		return null
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return null
	var buf := fa.get_buffer(int(fa.get_length()))
	fa.close()
	var img := Image.new()
	var loaded: Variant = img.load_png_from_buffer(buf)
	if loaded is Image:
		return loaded
	if loaded != OK:
		return null
	if img.get_width() < 2 or img.get_height() < 2:
		return null
	return img


func _px(img: Image, u: float, v: float) -> Color:
	if img == null:
		return Color.BLACK
	var x := clampi(int(round(u * float(img.get_width() - 1))), 0, img.get_width() - 1)
	var y := clampi(int(round(v * float(img.get_height() - 1))), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


func sample_uv(img: Image, u: float, v: float) -> Color:
	return _px(img, u, v)


func is_lit(img: Image, u: float, v: float, thresh: float = 0.45) -> bool:
	var c := _px(img, u, v)
	return maxf(c.r, maxf(c.g, c.b)) > thresh


func is_building_uv(u: float, v: float) -> bool:
	return is_lit(building, u, v)


func is_road_uv(u: float, v: float) -> bool:
	return is_lit(road, u, v, 0.55)


func is_no_spawn_uv(u: float, v: float) -> bool:
	return is_lit(no_spawn, u, v, 0.40)


func is_cliff_uv(u: float, v: float) -> bool:
	return is_lit(cliff, u, v, 0.40)


func vegetation_density_uv(u: float, v: float) -> int:
	## Red channel stores 0/85/170/255 → 0–3.
	var c := _px(vegetation, u, v)
	return clampi(int(round(c.r * 3.0)), 0, 3)


func building_kind_uv(u: float, v: float) -> String:
	var c := _px(building_type, u, v)
	if maxf(c.r, maxf(c.g, c.b)) < 0.12:
		return ""
	var best := ""
	var best_d := 1.0e9
	for kind in type_colors.keys():
		var other: Color = type_colors[kind]
		var d: float = Vector3(c.r, c.g, c.b).distance_to(Vector3(other.r, other.g, other.b))
		if d < best_d:
			best_d = d
			best = str(kind)
	return best if best_d < 0.55 else ""


func is_building_world(x: float, z: float) -> bool:
	var uv := coords.world_to_uv(x, z)
	return is_building_uv(uv.x, uv.y)


func is_road_world(x: float, z: float) -> bool:
	var uv := coords.world_to_uv(x, z)
	return is_road_uv(uv.x, uv.y)


func is_no_spawn_world(x: float, z: float) -> bool:
	var uv := coords.world_to_uv(x, z)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return true
	return is_no_spawn_uv(uv.x, uv.y)


func is_cliff_world(x: float, z: float) -> bool:
	var uv := coords.world_to_uv(x, z)
	return is_cliff_uv(uv.x, uv.y)


func vegetation_density_world(x: float, z: float) -> int:
	var uv := coords.world_to_uv(x, z)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return 0
	return vegetation_density_uv(uv.x, uv.y)


func debug_texture(layer: String) -> Texture2D:
	var img: Image
	match layer:
		"building":
			img = building
		"road":
			img = road
		"no_spawn":
			img = no_spawn
		"cliff":
			img = cliff
		"building_type":
			img = building_type
		"vegetation":
			img = vegetation
		_:
			img = building
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
