extends Node3D
class_name Outside
## Outside
##
## The shared courtyard escapees land in. All escaped players roam the
## same space regardless of faction - MVP explicitly does not implement
## any post-escape sabotage/interaction (see docs/MVP_GDD.md), it's just a
## safe holding area until the match ends.
##
## Also hosts `TestRange_RemoveBeforeRelease` - a pickup gun + a few dummy
## targets used ONLY to manually verify hit-registration during
## development. *** REMOVE BEFORE FULL RELEASE. *** See Gun.gd/
## DummyTarget.gd and docs/MVP_GDD.md.

@onready var roam_spawn_points: Node3D = $RoamSpawnPoints


func _ready() -> void:
	if multiplayer.is_server():
		EscapeSystem.server_register_outside(self)


func get_roam_spawn_transform() -> Transform3D:
	var points := roam_spawn_points.get_children()
	if points.is_empty():
		return global_transform
	var marker: Marker3D = points[randi() % points.size()]
	return marker.global_transform
