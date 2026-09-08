extends "res://scripts/interactables/props/lockable_barrier.gd"
class_name Hatch
## A floor/cellar hatch. Often bolted (locked) until forced or unlocked.


func _ready() -> void:
	kind = "hatch"
	super._ready()
