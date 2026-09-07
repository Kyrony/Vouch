extends RefCounted
class_name RoomLayouts
## Friends-MVP room routing — hand-sealed graybox scenes only (procedural room_geometry frozen).

const _GRAYBOX: GDScript = preload("res://scripts/rooms/graybox_layouts.gd")


static func get_layout(room_id: int) -> Dictionary:
	if room_id <= 0:
		return _GRAYBOX.call("pm_layout").duplicate(true)
	return _GRAYBOX.call("get_layout", room_id).duplicate(true)


static func scene_path(room_id: int) -> String:
	return _GRAYBOX.call("scene_path", room_id)


static func pick_id(rng: RandomNumberGenerator) -> int:
	return _GRAYBOX.call("pick_id", rng)
