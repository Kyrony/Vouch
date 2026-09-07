extends Area3D
## Blocks players from re-entering a one-way slide tunnel from the far chamber.
## Allows travel from the main room into the chamber, not back through the slide.

@export var block_direction: Vector3 = Vector3(0, 0, 1)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		var vel: Vector3 = body.velocity
		if vel.dot(block_direction.normalized()) > 0.3:
			body.global_position += block_direction.normalized() * 0.6
			body.velocity = Vector3.ZERO
