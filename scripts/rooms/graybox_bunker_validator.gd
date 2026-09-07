extends RefCounted
class_name GrayboxBunkerValidator
## Headless: friends-MVP bunker-only rooms must be empty sealed boxes.


const ALLOWED_ROOT: Array[String] = [
	"Geometry", "PlayerSpawn", "EscapeDoor", "EscapeAttach", "ItemSpawns",
]

const ALLOWED_GEOMETRY: Array[String] = [
	"Floor", "Ceiling", "WallNegZ", "WallEast", "WallWest", "WallPosZ",
]

const FORBIDDEN_PROP_NAMES: Array[String] = [
	"Ladder", "LightSwitch", "Phone", "WalkieTalkie", "Fireplace",
	"SecurityCamera", "RoomLight", "EscapePoint", "Drain", "ExhaustVent",
	"WaterValve", "GasValve", "ElectricalBox", "BinaryTerminal",
	"BinaryBookcase", "RoomPeekMonitor", "PipeBandage", "BrokenPipe", "GasLeak",
	"CodeKeypad", "ClueBook", "ClueFlamePaper",
]


static func validate(room: Node3D) -> Array[String]:
	var errors: Array[String] = []
	if room == null:
		return ["room is null"]

	for child in room.get_children():
		if child.name in ALLOWED_ROOT:
			continue
		if _is_forbidden_prop(child):
			errors.append("bunker-only forbids spawned prop %s" % child.name)
		else:
			errors.append("unexpected root child %s in bunker-only room" % child.name)

	var geometry := room.get_node_or_null("Geometry") as Node3D
	if geometry == null:
		errors.append("Geometry missing")
	else:
		errors.append_array(_validate_geometry(geometry))

	return errors


static func _validate_geometry(geometry: Node3D) -> Array[String]:
	var errors: Array[String] = []
	for child in geometry.get_children():
		if not child is StaticBody3D:
			errors.append("Geometry/%s is not StaticBody3D" % child.name)
			continue
		if not _allowed_geometry_name(child.name):
			errors.append("Geometry/%s not allowed in bunker-only box" % child.name)
			continue
		if child.get_node_or_null("MeshInstance3D") == null:
			errors.append("Geometry/%s missing mesh" % child.name)
		if child.get_node_or_null("CollisionShape3D") == null:
			errors.append("Geometry/%s missing collision (mesh must match)" % child.name)
	return errors


static func _allowed_geometry_name(name: String) -> bool:
	if name in ALLOWED_GEOMETRY:
		return true
	if name.begins_with("WallPosZ"):
		return true
	return false


static func _is_forbidden_prop(node: Node) -> bool:
	if node.name in FORBIDDEN_PROP_NAMES:
		return true
	for prefix in ["Crate", "Shelf", "Barrel"]:
		if node.name.begins_with(prefix):
			return true
	return false
