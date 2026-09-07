extends Node
## EscapePathSettings
##
## Friends-MVP gate: bunker-only match (sealed box, center spawn, no props).
##
## Default: bunker-only ON whenever escape path is OFF.
## Override: `VOUCH_BUNKER_ONLY=0` allows item populate without escape (dev only).
## Full loop: `VOUCH_ESCAPE_PATH=1` enables tunnels, hub, and item populate.
##
## TODO(post-MVP): reattach short flat hall + minimal interactables when re-enabled.

const ENV_FLAG: String = "VOUCH_ESCAPE_PATH"
const BUNKER_ENV: String = "VOUCH_BUNKER_ONLY"

var enabled: bool = false


static func escape_path_enabled() -> bool:
	return OS.get_environment(ENV_FLAG) == "1"


static func bunker_only() -> bool:
	if escape_path_enabled():
		return false
	if OS.get_environment(BUNKER_ENV) == "0":
		return false
	return true


func _ready() -> void:
	enabled = escape_path_enabled()


func is_enabled() -> bool:
	return enabled


func is_bunker_only() -> bool:
	return bunker_only()
