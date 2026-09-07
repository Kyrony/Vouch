extends Marker3D
class_name ItemSpawnSlot
## Fixed item spawn location in a room map (1 of 16 per room).

const SURFACE_WALL := "wall"
const SURFACE_FLOOR := "floor"
const SURFACE_WALL_FLOOR := "wall_floor"
const SURFACE_CEILING := "ceiling"

@export var slot_index: int = 1
@export var surface_kind: String = SURFACE_WALL
@export var wall_normal: Vector3 = Vector3(0, 0, -1)


static func from_dict(index: int, data: Dictionary) -> Marker3D:
	var slot: Marker3D = load("res://scripts/rooms/item_spawn_slot.gd").new()
	slot.slot_index = index
	slot.name = "Slot_%02d" % index
	slot.surface_kind = str(data.get("surface_type", SURFACE_WALL))
	slot.wall_normal = data.get("wall_normal", Vector3(0, 0, -1))
	slot.position = data.get("position", Vector3.ZERO)
	if slot.surface_kind != SURFACE_FLOOR:
		slot.rotation.y = rotation_y_from_normal(slot.wall_normal)
	if slot.surface_kind == SURFACE_CEILING:
		slot.rotation.x = PI
	return slot


static func rotation_y_from_normal(n: Vector3) -> float:
	return atan2(n.x, n.z)
