extends RefCounted
class_name EffectDefinitions
## Data-driven effect ids for horror player stacks.

enum Meter { HEALTH, STAMINA, FEAR }

const EFFECTS: Dictionary = {
	"life_steal_aura": {
		"meter": Meter.HEALTH,
		"apply_rate": 0.0,
		"duration": 6.0,
		"cooldown": 10.0,
		"radius": 8.0,
		"max_drain_per_sec": 22.0,
		"min_drain_per_sec": 4.0,
	},
	"fear_pulse": {
		"meter": Meter.FEAR,
		"apply_rate": 8.0,
		"duration": 3.0,
		"cooldown": 0.0,
	},
	"stamina_drain": {
		"meter": Meter.STAMINA,
		"apply_rate": 12.0,
		"duration": 5.0,
		"cooldown": 0.0,
	},
	"medkit_heal": {
		"meter": Meter.HEALTH,
		"apply_rate": -40.0,
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
