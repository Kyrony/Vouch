extends "res://scripts/interactables/props/lockable_barrier.gd"
class_name GarageDoor
## A motorised garage door — needs power (a live fuse box) to roll up.


func _ready() -> void:
	kind = "garage"
	needs_power = true
	super._ready()
