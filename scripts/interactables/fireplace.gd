extends Node3D
## Fireplace (use script path; avoid class_name self-ref in static factory)
## Fireplace
##
## Living-room hearth with a floor gas riser. Flame can ignite when gas
## utility is on; gas + flame = fire hazard (stub: hazard group + toast).

@export var room_index: int = -1

var _flame: Node3D
var _flame_light: OmniLight3D
var _gas_on: bool = true
var _lit: bool = false


func _ready() -> void:
	add_to_group("fire_hazards")
	RoomUtilities.utility_changed.connect(_on_utility_changed)
	_gas_on = RoomUtilities.is_enabled(room_index, RoomUtilities.UTILITY_GAS)
	_update_flame()
	set_process(true)


func _process(_delta: float) -> void:
	if _lit and _gas_on and multiplayer.is_server():
		var fire := get_node_or_null("/root/FireSystem")
		if not fire:
			return
		for node in get_tree().get_nodes_in_group("flammable_props"):
			if node is Node3D and node.global_position.distance_to(global_position) < 2.2:
				fire.server_try_ignite(node)


func configure(p_room_index: int) -> void:
	room_index = p_room_index


func is_fire_active() -> bool:
	return _lit and _gas_on


func get_flame() -> Node3D:
	return _flame


func _on_utility_changed(changed_room: int, utility: String, enabled: bool) -> void:
	if changed_room != room_index or utility != RoomUtilities.UTILITY_GAS:
		return
	_gas_on = enabled
	_update_flame()


func _update_flame() -> void:
	_lit = _gas_on
	if _flame_light:
		_flame_light.visible = _lit
	if _flame:
		_flame.visible = _lit


static func build(parent: Node3D, local_pos: Vector3, accent: Material, room_idx: int) -> Node3D:
	var fp: StaticBody3D = StaticBody3D.new()
	fp.set_script(load("res://scripts/interactables/fireplace.gd"))
	fp.name = "Fireplace"
	fp.collision_layer = 2
	fp.collision_mask = 0
	fp.position = local_pos + Vector3(0, 0.55, 0)
	fp.configure(room_idx)

	var size := Vector3(1.0, 1.1, 0.42)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.set_surface_override_material(0, accent)
	fp.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	fp.add_child(collision)

	fp._flame = Node3D.new()
	fp._flame.set_script(load("res://scripts/interactables/flame.gd"))
	fp._flame.position = Vector3(0, -0.15, 0.04)
	fp._flame.add_to_group("flames")
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.1
	cm.height = 0.25
	cone.mesh = cm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.45, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.35, 0.05)
	fm.emission_energy_multiplier = 2.0
	cone.set_surface_override_material(0, fm)
	fp._flame.add_child(cone)
	fp.add_child(fp._flame)

	fp._flame_light = OmniLight3D.new()
	fp._flame_light.light_color = Color(1.0, 0.55, 0.2)
	fp._flame_light.light_energy = 1.4
	fp._flame_light.omni_range = 4.0
	fp._flame_light.position = Vector3(0, 0.1, 0.1)
	fp.add_child(fp._flame_light)

	var slot := Marker3D.new()
	slot.name = "ClueSlot"
	slot.position = Vector3(0, -0.05, 0.15)
	fp.add_child(slot)

	fp._update_flame()
	parent.add_child(fp)
	return fp
