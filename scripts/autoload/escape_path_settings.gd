extends Node
## EscapePathSettings
##
## Friends-MVP gate: procedural escape tunnels + EscapeHub shaft/ramp are OFF
## by default so Start Match shows only the sealed graybox bunker.
##
## Enable with `VOUCH_ESCAPE_PATH=1` (env) or set `enabled = true` before
## match start when re-testing the full tunnel → hub → Outside flow.
##
## TODO(post-MVP): reattach a short **flat** hall from +Z door (no ramp stack).

const ENV_FLAG: String = "VOUCH_ESCAPE_PATH"

var enabled: bool = false


static func escape_path_enabled() -> bool:
	return OS.get_environment(ENV_FLAG) == "1"


func _ready() -> void:
	enabled = escape_path_enabled()


func is_enabled() -> bool:
	return enabled
