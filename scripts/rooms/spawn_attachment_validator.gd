extends RefCounted
class_name SpawnAttachmentValidator
## Headless validation — assert spawned items sit on the correct surface.

const WALL_TOLERANCE: float = 0.14
const FLOOR_Y_TOLERANCE: float = 0.08
const CEILING_TOLERANCE: float = 0.18
const FIREPLACE_WALL_Z_TOLERANCE: float = 0.35

const WALL_KINDS: Array[String] = [
	"LightSwitch", "Phone", "ExhaustVent", "WaterValve", "ElectricalBox",
	"GasValve", "BinaryTerminal", "RoomPeekMonitor", "SecurityCamera",
]

const FLOOR_KINDS: Array[String] = [
	"Drain", "Ladder", "BinaryBookcase", "WalkieTalkie", "PipeBandage",
]

const FLOOR_PROP_NAMES: Array[String] = ["Crate", "Shelf", "Barrel"]
const INSET: float = 0.5


static func validate(room: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if room == null:
		return ["room is null"]

	var w: float = room.get("width") if room.get("width") else 6.0
	var d: float = room.get("depth") if room.get("depth") else 6.0
	var h: float = 2.4
	if room.get("_layout"):
		h = room._layout.get("height", 2.4)
	var hw := w * 0.5
	var hd := d * 0.5

	for child in room.get_children():
		_check_node(child, hw, hd, h, errors)

	return errors


static func _check_node(node: Node, hw: float, hd: float, h: float, errors: Array[String]) -> void:
	if node.name == "Fireplace":
		_check_fireplace(node, hd, errors)
		return

	if node.name in WALL_KINDS:
		var surface: String = str(node.get_meta("attachment_surface", "wall"))
		if surface == "ceiling":
			_check_ceiling(node, h, errors)
		else:
			_check_wall(node, hw, hd, h, errors)
		return

	if node.name in FLOOR_KINDS or _is_floor_prop(node):
		_check_floor(node, errors)


static func _is_floor_prop(node: Node) -> bool:
	for prefix in FLOOR_PROP_NAMES:
		if node.name.begins_with(prefix):
			return true
	return false


static func _check_wall(node: Node3D, hw: float, hd: float, h: float, errors: Array[String]) -> void:
	var p: Vector3 = node.position
	var dist := _nearest_wall_distance(p, hw, hd)
	if dist > WALL_TOLERANCE:
		errors.append("%s not flush to wall (dist=%.3f pos=%s)" % [node.name, dist, p])
	if p.y < 0.05 or p.y > h + 0.05:
		if p.y < -0.05 or p.y > h + 0.2:
			errors.append("%s floating off wall height (y=%.3f)" % [node.name, p.y])


static func _check_ceiling(node: Node3D, h: float, errors: Array[String]) -> void:
	var p: Vector3 = node.position
	if absf(p.y - (h - 0.12)) > CEILING_TOLERANCE and absf(p.y - h) > CEILING_TOLERANCE:
		errors.append("%s not on ceiling (y=%.3f expected~%.2f)" % [node.name, p.y, h - 0.12])


static func _check_floor(node: Node3D, errors: Array[String]) -> void:
	var bottom_y := _node_bottom_y(node)
	if bottom_y > FLOOR_Y_TOLERANCE:
		errors.append("%s not on floor (bottom_y=%.3f)" % [node.name, bottom_y])
	if bottom_y < -0.05:
		errors.append("%s below floor (bottom_y=%.3f)" % [node.name, bottom_y])


static func _check_fireplace(node: Node3D, hd: float, errors: Array[String]) -> void:
	var bottom_y := _node_bottom_y(node)
	if bottom_y > FLOOR_Y_TOLERANCE:
		errors.append("Fireplace not on floor (bottom_y=%.3f)" % bottom_y)
	var p: Vector3 = node.position
	var inner_hd := hd - INSET
	if absf(p.z - (inner_hd - 0.08)) > FIREPLACE_WALL_Z_TOLERANCE:
		errors.append("Fireplace not against south wall (z=%.3f expected~%.2f)" % [p.z, inner_hd - 0.08])


static func _nearest_wall_distance(p: Vector3, hw: float, hd: float) -> float:
	var inner_hw := hw - INSET
	var inner_hd := hd - INSET
	return minf(
		minf(absf(p.x - inner_hw), absf(p.x + inner_hw)),
		minf(absf(p.z - inner_hd), absf(p.z + inner_hd))
	)


static func _node_bottom_y(node: Node3D) -> float:
	var lowest := node.position.y
	for c in node.get_children():
		if c is MeshInstance3D:
			var mesh: Mesh = c.mesh
			if mesh is BoxMesh:
				var half: float = mesh.size.y * 0.5
				lowest = minf(lowest, node.position.y + c.position.y - half)
			elif mesh is CylinderMesh:
				lowest = minf(lowest, node.position.y + c.position.y - mesh.height * 0.5)
	return lowest
