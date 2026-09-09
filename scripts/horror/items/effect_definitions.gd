extends RefCounted
class_name EffectDefinitions
## Data-driven effect ids for horror player stacks.

enum Meter { HEALTH, STAMINA, FEAR }

# ── TUNABLES — tweak these to balance gameplay ──
const EFFECTS: Dictionary = {
	"life_steal_aura": {
		"meter": Meter.HEALTH,
		"apply_rate": 0.0,
		"duration": 6.0,  # active seconds
		"cooldown": 10.0,  # seconds before recast
		"radius": 8.0,  # aura reach (m)
		# Close-range TTK ~7s (100 / 14); edge of 8m is a trickle (~50s).
		"max_drain_per_sec": 14.0,  # HP/sec at center
		"min_drain_per_sec": 2.0,  # HP/sec at edge
	},
	"fear_pulse": {
		"meter": Meter.FEAR,
		"apply_rate": 8.0,  # fear/sec while active
		"duration": 3.0,
		"cooldown": 0.0,
	},
	"stamina_drain": {
		"meter": Meter.STAMINA,
		"apply_rate": 12.0,  # stamina/sec drained
		"duration": 5.0,
		"cooldown": 0.0,
	},
	"medkit_heal": {
		"meter": Meter.HEALTH,
		"apply_rate": -40.0,  # negative = heal amount
		"duration": 0.1,
		"cooldown": 0.0,
		"instant": true,
	},
}


static func get_def(effect_id: String) -> Dictionary:
	return EFFECTS.get(effect_id, {})


static func meter_name(m: int) -> String:
	match m:
		Meter.HEALTH:
			return "health"
		Meter.STAMINA:
			return "stamina"
		Meter.FEAR:
			return "fear"
		_:
			return "unknown"
