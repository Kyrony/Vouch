extends "res://scripts/interactables/flammable_prop.gd"
## Loose physics book for room scatter (decorative, flammable).

func _ready() -> void:
	super._ready()
	prompt_text = "Pick up book"
	burn_time = 4.5
