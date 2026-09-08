extends Node3D
class_name MaskDebugView
## F8 cycles interpreted semantic-mask layers over the farm.

const LAYERS: Array[String] = [
	"off",
	"building",
	"road",
	"no_spawn",
	"cliff",
	"building_type",
	"vegetation",
]

var maps: SemanticMaps
var layer_index: int = 0
var _plane: MeshInstance3D
var _label: Label3D


func bind_world(_world: Node3D) -> void:
	_build()
	_apply()


func _ready() -> void:
	if _plane == null:
		_build()
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	var cycle := false
	if InputMap.has_action("mask_debug_cycle"):
		cycle = event.is_action_pressed("mask_debug_cycle")
	if not cycle and event is InputEventKey and event.pressed and not event.echo:
		cycle = event.physical_keycode == KEY_F8
	if not cycle:
		return
	layer_index = (layer_index + 1) % LAYERS.size()
	_apply()
	get_viewport().set_input_as_handled()


func _build() -> void:
	if _plane:
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(MapCoords.TERRAIN_SPAN_X, MapCoords.TERRAIN_SPAN_Z)
	_plane = MeshInstance3D.new()
	_plane.name = "MaskPlane"
	_plane.mesh = mesh
	_plane.position = Vector3(0.0, 11.5, 0.0)
	_plane.visible = false
	add_child(_plane)
	_label = Label3D.new()
	_label.name = "MaskLayerLabel"
	_label.position = Vector3(0.0, 14.0, -50.0)
	_label.font_size = 48
	_label.modulate = Color(1, 0.92, 0.55)
	_label.text = ""
	add_child(_label)


func _apply() -> void:
	var layer := LAYERS[layer_index]
	if layer == "off" or maps == null:
		if _plane:
			_plane.visible = false
		if _label:
			_label.text = "MASK DEBUG off  (F8)"
		return
	var tex: Texture2D = maps.debug_texture(layer)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.72)
	_plane.material_override = mat
	_plane.visible = true
	_label.text = "MASK DEBUG: %s  (F8)" % layer
	print("[SemanticMaps] debug layer=%s" % layer)
