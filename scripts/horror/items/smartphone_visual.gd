extends RefCounted
class_name SmartphoneVisual
## Graphite / gold smartphone mesh (ITEM_DEVICE_SMARTPHONE_01).
## Camera-module LED is the only light source — no separate flashlight prop.

const PRODUCTION_ID := "ITEM_DEVICE_SMARTPHONE_01"


static func attach(parent: Node3D, held: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Smartphone"
	root.set_meta("production_id", PRODUCTION_ID)
	parent.add_child(root)

	var scale_mul := 1.15 if held else 1.0
	var body := _box(Vector3(0.072, 0.148, 0.012) * scale_mul, Vector3.ZERO, _mat(Color(0.16, 0.16, 0.17), 0.82, Color.BLACK, 0.0))
	body.name = "Body"
	root.add_child(body)

	var gold := _mat(Color(0.62, 0.48, 0.22), 0.35, Color(0.72, 0.52, 0.18), 0.18)
	var frame := _box(Vector3(0.078, 0.154, 0.006) * scale_mul, Vector3(0, 0, 0.004 * scale_mul), gold)
	frame.name = "GoldFrame"
	root.add_child(frame)

	var screen_col := Color(0.08, 0.02, 0.04)
	var screen_mat := _mat(screen_col, 0.2, Color(0.9, 0.12, 0.18), 0.45)
	var screen := _box(Vector3(0.062, 0.122, 0.002) * scale_mul, Vector3(0, 0.004, -0.006 * scale_mul), screen_mat)
	screen.name = "Screen"
	root.add_child(screen)

	var cam := _box(Vector3(0.028, 0.028, 0.006) * scale_mul, Vector3(-0.016 * scale_mul, 0.052 * scale_mul, 0.009 * scale_mul), _mat(Color(0.1, 0.1, 0.11), 0.25, Color.BLACK, 0.0))
	cam.name = "CameraModule"
	root.add_child(cam)

	var lens := _box(Vector3(0.01, 0.01, 0.004) * scale_mul, Vector3(-0.016 * scale_mul, 0.056 * scale_mul, 0.012 * scale_mul), _mat(Color(0.12, 0.16, 0.2), 0.08, Color(0.2, 0.3, 0.4), 0.2))
	lens.name = "Lens"
	root.add_child(lens)

	var led_mat := _mat(Color(0.95, 0.9, 0.7), 0.15, Color(1.0, 0.92, 0.55), 0.15)
	var led := _box(Vector3(0.006, 0.006, 0.004) * scale_mul, Vector3(-0.006 * scale_mul, 0.046 * scale_mul, 0.012 * scale_mul), led_mat)
	led.name = "CameraLED"
	root.add_child(led)

	var brand := Label3D.new()
	brand.name = "VouchMark"
	brand.text = "VOUCH"
	brand.font_size = 18 if held else 14
	brand.modulate = Color(1.0, 0.18, 0.22)
	brand.position = Vector3(0, 0.028 * scale_mul, -0.008 * scale_mul)
	brand.rotation_degrees = Vector3(0, 180, 0)
	brand.pixel_size = 0.0012
	root.add_child(brand)

	var status := Label3D.new()
	status.name = "StatusMark"
	status.text = "SIGNAL\nBATT"
	status.font_size = 12 if held else 10
	status.modulate = Color(0.75, 0.82, 0.88)
	status.position = Vector3(0, -0.018 * scale_mul, -0.008 * scale_mul)
	status.rotation_degrees = Vector3(0, 180, 0)
	status.pixel_size = 0.0011
	root.add_child(status)
	return root


static func update_screen(root: Node3D, battery: float, signal_band: String, led_on: bool) -> void:
	if root == null:
		return
	var status := root.get_node_or_null("StatusMark") as Label3D
	if status:
		var band := signal_band.to_upper()
		var led := "LED ON" if led_on else "LED OFF"
		status.text = "%s\n%d%%\n%s" % [band, int(round(battery)), led]
		match signal_band:
			"full":
				status.modulate = Color(0.3, 0.95, 0.4)
			"weak":
				status.modulate = Color(0.98, 0.82, 0.2)
			_:
				status.modulate = Color(1.0, 0.22, 0.22)
	var brand := root.get_node_or_null("VouchMark") as Label3D
	if brand:
		brand.modulate = Color(1.0, 0.18, 0.22) if battery > 1.0 else Color(0.35, 0.08, 0.1)
	var led_mesh := root.get_node_or_null("CameraLED") as MeshInstance3D
	if led_mesh:
		var mat := led_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.2 if led_on else 0.12


static func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	return mi


static func _mat(albedo: Color, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = 0.35
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m
