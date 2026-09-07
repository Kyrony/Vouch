extends RefCounted
class_name GeometryUtil
## Shared StaticBody3D box primitive for room/tunnel/hub graybox geometry.


static func box(size: Vector3, pos: Vector3, mat: Material, collision_layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	if collision_layer != 0:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
	return body
