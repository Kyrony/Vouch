extends RefCounted
class_name PuppetMasterData
## Constants for Puppet Master horror chase abilities.

const BODY_SWAP_RANGE: float = 6.0
const BODY_SWAP_DURATION: float = 4.0
const POSSESSION_RANGE: float = 5.0
const POSSESSION_DURATION: float = 5.0
const FLOAT_LIFT: float = 5.5

const LIFE_STEAL_EFFECT: String = "life_steal_aura"
const LIFE_STEAL_KEY: String = "interact"

## Radius falloff handled by PlayerEffects.server_apply_life_steal.
const LIFE_STEAL_MAX_RANGE: float = 8.0
