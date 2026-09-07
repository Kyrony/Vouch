extends Node3D
class_name KitModule
## One authored kit room piece with named socket markers.


@export var module_type: String = "living"


func get_socket(name: String) -> Marker3D:
	var n := get_node_or_null("Sockets/%s" % name)
	return n as Marker3D if n is Marker3D else null


func socket_global(name: String) -> Transform3D:
	var s := get_socket(name)
	if s:
		return s.global_transform
	return global_transform


func all_sockets() -> Dictionary:
	var out := {}
	var root := get_node_or_null("Sockets")
	if not root:
		return out
	for c in root.get_children():
		if c is Marker3D:
			out[c.name] = c
	return out
