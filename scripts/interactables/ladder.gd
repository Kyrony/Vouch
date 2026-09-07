extends Area3D
class_name Ladder
## Ladder
##
## A climbable zone (not an `Interactable` - climbing is a continuous
## physical state, not a discrete E-press). While a player's body is
## inside this Area3D, Player.gd switches to ladder-climbing physics:
## forward/back input moves vertically instead of horizontally, gravity
## is suspended, and normal movement resumes the moment they leave the
## zone. See `Player.gd`'s `enter_ladder()`/`exit_ladder()`/`_on_ladder`.
##
## Placed next to a `SecurityCamera` mounted near the ceiling so reaching
## (and destroying) it requires actually climbing up - see
## `SecurityCamera.min_elevation_y`.

## Purely informational for room-builders; Player.gd owns the actual climb
## speed constant so all ladders behave consistently.
var top_y: float = 3.0


func configure(p_top_y: float) -> void:
	top_y = p_top_y


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # "players" physics layer
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_ladder"):
		body.enter_ladder(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder(self)
