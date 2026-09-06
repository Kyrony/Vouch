extends Node3D
class_name Flame
## Flame
##
## Decorative always-lit flame prop. Purely a lighting/visual stub - its
## only functional role is `glow_radius`, which `ClueFlamePaper` uses to
## decide whether it's close enough to read by. Carries an Area3D so the
## "glow zone" is a real, inspectable volume (useful for later VFX/audio),
## even though the readability check itself is a simple distance test
## rather than an Area3D signal for simplicity.

@export var glow_radius: float = 2.5
