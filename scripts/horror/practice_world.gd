extends Node3D
## Practice bay root. Same pickup API as HorrorWorld so dig sites and
## dropped items resolve in the training room.

const PICKUP_SCENE: String = "res://scenes/Horror/WorldPickup.tscn"


func spawn_pickup(item_id: String, at: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_spawn_pickup_local.rpc(item_id, at)


func spawn_flare(at: Vector3, light_range: float, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_flare_local.rpc(at, light_range, seconds)


@rpc("authority", "call_local", "reliable")
func _spawn_pickup_local(item_id: String, at: Vector3) -> void:
	if not ResourceLoader.exists(PICKUP_SCENE):
		return
	var packed: PackedScene = load(PICKUP_SCENE) as PackedScene
	if packed == null:
		return
	var pickup: Node3D = packed.instantiate() as Node3D
	if pickup == null:
		return
	pickup.set("item_id", item_id)
	pickup.position = at
	pickup.name = "Pickup_%s_%d" % [item_id, get_child_count()]
	add_child(pickup)


@rpc("authority", "call_local", "reliable")
func _spawn_flare_local(at: Vector3, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Flare"
	light.position = at + Vector3(0.0, 0.35, 0.0)
	light.light_color = Color(1.0, 0.45, 0.2)
	light.light_energy = 3.2
	light.omni_range = light_range
	add_child(light)
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(light):
			light.queue_free())
