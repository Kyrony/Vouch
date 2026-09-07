extends Interactable
## RoomPeekMonitor
##
## Wall monitor that shows a live camera into another player's room once
## activated (usually via binary terminal puzzle).

var room_index: int = -1
var peek_room_index: int = -1
var active: bool = false

var _viewport: SubViewport
var _feed_camera: Camera3D


func configure(p_room_index: int, p_peek_room: int) -> void:
	room_index = p_room_index
	peek_room_index = p_peek_room
	prompt_text = "Security monitor (locked)"


func server_activate() -> void:
	if not multiplayer.is_server() or active:
		return
	active = true
	_client_activate.rpc()


@rpc("authority", "call_remote", "reliable")
func _client_activate() -> void:
	active = true
	visible = true
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	prompt_text = "Live feed"
	_setup_feed()


func _setup_feed() -> void:
	if _viewport:
		return
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.34)
	screen.mesh = quad
	screen.position = Vector3(0, 0, 0.05)
	add_child(screen)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 216)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_feed_camera = Camera3D.new()
	_feed_camera.fov = 70.0
	_viewport.add_child(_feed_camera)
	add_child(_viewport)

	var target_pos := Match.room_grid_position(peek_room_index)
	_feed_camera.global_position = target_pos + Vector3(0, 10.0, 0)
	_feed_camera.look_at(target_pos + Vector3(0, 1.0, 0), Vector3.UP)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.55, 0.45)
	mat.emission_energy_multiplier = 0.6
	screen.set_surface_override_material(0, mat)
