extends Node
## MatchSettings
##
## Host-authoritative "spawn odds" for optional room features, adjustable
## from the Play screen before starting a match. Only ever read by the
## HOST during `Match._server_build_match()` - never synced to clients,
## since clients never need to know the exact odds, just the resulting
## rooms (consistent with everything else host-authoritative in this
## project).
##
## Values are 0.0-1.0 probabilities. Defaults match the hand-tuned values
## the base room generator originally shipped with.

var hidden_hallway_chance: float = 0.6
var code_lock_chance: float = 0.6
var flame_paper_chance: float = 0.5
var flood_valve_chance: float = 0.3


func reset_to_defaults() -> void:
	hidden_hallway_chance = 0.6
	code_lock_chance = 0.6
	flame_paper_chance = 0.5
	flood_valve_chance = 0.3
