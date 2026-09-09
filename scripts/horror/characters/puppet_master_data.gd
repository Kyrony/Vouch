extends RefCounted
class_name PuppetMasterData
## Constants for Puppet Master horror chase abilities.

# ── TUNABLES — tweak these to balance gameplay ──
const BODY_SWAP_RANGE: float = 6.0  # max swap distance (m)
const BODY_SWAP_DURATION: float = 4.0  # swap active seconds
const POSSESSION_RANGE: float = 5.0  # max possess distance (m)
const POSSESSION_DURATION: float = 5.0  # possess active seconds
const FLOAT_LIFT: float = 5.5  # levitation height (m)

const LIFE_STEAL_EFFECT: String = "life_steal_aura"
const LIFE_STEAL_KEY: String = "interact"

## Radius falloff handled by PlayerEffects.server_apply_life_steal.
const LIFE_STEAL_MAX_RANGE: float = 8.0  # life-steal aura reach (m)
