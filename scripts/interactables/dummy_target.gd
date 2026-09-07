extends StaticBody3D
class_name DummyTarget
## DummyTarget
##
## *** TEST-ONLY PROP - REMOVE BEFORE FULL RELEASE ***
## A simple hit-reactive target for testing `Gun.gd`. Flashes red and
## wobbles when shot, host-authoritative, purely cosmetic feedback - no
## gameplay purpose. See docs/MVP_GDD.md.

@onready var mesh: MeshInstance3D = $MeshInstance3D

var hit_count: int = 0


## Client entry point for a hit registered on a non-host peer.
@rpc("any_peer", "call_remote", "reliable")
func request_hit() -> void:
	if not multiplayer.is_server():
		return
	server_register_hit()


func server_register_hit() -> void:
	if not multiplayer.is_server():
		return
	hit_count += 1
	_client_apply_hit.rpc(hit_count)
	_apply_hit_visual()


@rpc("authority", "call_remote", "reliable")
func _client_apply_hit(count: int) -> void:
	hit_count = count
	_apply_hit_visual()


func _apply_hit_visual() -> void:
	var mat := mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0.85, 0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", 0.35, 0.06)
	tween.tween_property(self, "rotation:z", 0.0, 0.3)
