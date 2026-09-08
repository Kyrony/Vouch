extends "res://scripts/interactables/props/lockable_barrier.gd"
class_name LockedGate
## A locked perimeter gate. Force with a crowbar or open with a key/lockpick.


func _ready() -> void:
	kind = "gate"
	super._ready()
