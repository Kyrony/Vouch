extends RefCounted
class_name SpawnPointMarkers
## Visible L2 child-pin markers on the open farm. No building shells.

const _TERRAIN: GDScript = preload("res://scripts/horror/environment/outdoor_terrain.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")

const BOX_SIZE := Vector3(0.95, 1.55, 0.95)
const LABEL_TEXT := "Spawn Point"


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "L2SpawnMarkers"
	parent.add_child(root)

	var markers: Array[Marker3D] = []
	for spawn_id in _V05.SPAWN_IDS:
		var xz: Vector3 = _V05.call("l2_world_pos", spawn_id)
		var y: float = float(_TERRAIN.call("height_at", xz.x, xz.z))
		var pos := Vector3(xz.x, maxf(y, 0.0) + 0.12, xz.z)
		markers.append(_add_marker(root, pos, spawn_id))

	return {
		"root": root,
		"markers": markers,
	}


static func _add_marker(parent: Node3D, pos: Vector3, spawn_id: String) -> Marker3D:
	var site := Node3D.new()
	site.name = "SpawnPoint_%s" % spawn_id
	site.position = pos
	parent.add_child(site)

	var marker := Marker3D.new()
	marker.position = Vector3.ZERO
	site.add_child(marker)
	_V05.call("stamp_child_pin", marker, spawn_id)
	marker.set_meta("visible_label", LABEL_TEXT)

	var mesh := MeshInstance3D.new()
	mesh.name = "Box"
	var box := BoxMesh.new()
	box.size = BOX_SIZE
	mesh.mesh = box
	mesh.position = Vector3(0, BOX_SIZE.y * 0.5, 0)
	mesh.material_override = _box_mat(spawn_id)
	site.add_child(mesh)

	var label := Label3D.new()
	label.name = "Label"
	label.text = LABEL_TEXT
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0.05, 0.05, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, BOX_SIZE.y + 0.55, 0)
	site.add_child(label)

	var id_label := Label3D.new()
	id_label.name = "SpawnId"
	id_label.text = spawn_id
	id_label.font_size = 22
	id_label.outline_size = 8
	id_label.modulate = Color(0.85, 0.92, 1.0)
	id_label.outline_modulate = Color(0.05, 0.05, 0.08)
	id_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	id_label.no_depth_test = true
	id_label.position = Vector3(0, BOX_SIZE.y + 0.22, 0)
	site.add_child(id_label)

	return marker


static func _box_mat(spawn_id: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	## Pin 4 vs pin 9 stay visually distinct so they cannot be collapsed by eye.
	if spawn_id == "basement":
		m.albedo_color = Color(0.95, 0.35, 0.18)
	elif spawn_id == "under_porch_crawl":
		m.albedo_color = Color(0.25, 0.85, 0.95)
	else:
		m.albedo_color = Color(0.92, 0.82, 0.18)
	m.roughness = 0.45
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.55
	return m
