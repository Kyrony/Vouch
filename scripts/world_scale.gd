extends Node
## Autoload: human-scale metric constants for Vouch (meters).

const FT_TO_M: float = 0.3048

const CEILING_H: float = 2.6
const DOOR_W: float = 0.85
const DOOR_H: float = 2.05
const WALL_THICK: float = 0.12
const SEAM_OVERLAP: float = 0.02

const PLAYER_HEIGHT: float = 1.7
const INTERACT_HEIGHT: float = 1.15
const SWITCH_HEIGHT: float = 1.25
const VALVE_HEIGHT: float = 1.0
const CAMERA_HEIGHT: float = 2.35

const PM_BOX_SIZE: float = 6.0

const HUB_SHAFT_RADIUS: float = 1.45
const HUB_SHAFT_HEIGHT: float = 10.0
const HUB_HALL_W: float = 1.25
const HUB_HALL_H: float = 2.5

const GRID_SPACING: float = 52.0
const CORRIDOR_MIN: float = 18.0
const CORRIDOR_MAX: float = 46.0

const STAIR_RISER: float = 0.18
const STAIR_TREAD: float = 0.28

static func ft(v: float) -> float:
	return v * FT_TO_M
