extends Node
## Autoload: shared world layout, player scale, and tunnel dimensions (meters).

const HUB_SHAFT_RADIUS: float = 1.45
const HUB_HALL_W: float = 1.25
const HUB_HALL_H: float = 2.5

const UNDERGROUND_DEPTH: float = 12.0
const TUNNEL_LIGHT_SPACING: float = 8.0
const WALL_THICK: float = 0.12

const GRID_SPACING: float = 52.0
const CORRIDOR_MIN: float = 18.0
const CORRIDOR_MAX: float = 46.0

## Residential room scale
const CEILING_H: float = 2.4
const DOOR_W: float = 0.85
const DOOR_H: float = 2.05

## Player reference (matches Player.tscn capsule)
const PLAYER_HEIGHT: float = 1.7
const PLAYER_CROUCH_HEIGHT: float = 1.0
const PLAYER_EYE_STAND: float = 1.6
const PLAYER_EYE_CROUCH: float = 1.0

## Climbable stair spec (IBC-ish comfort range)
const STAIR_RISER: float = 0.18
const STAIR_TREAD: float = 0.28
