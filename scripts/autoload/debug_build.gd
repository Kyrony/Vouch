extends Node
## DebugBuild
##
## Friends-ready gate for dev-only tooling (test gun, Outside test range,
## debug-menu spawn buttons). REMOVE test-gun paths entirely before retail
## launch — this flag is the interim strip for playtest builds.
##
## Enabled when Godot debug export is used OR `VOUCH_DEBUG_BUILD=1`.

const ENV_FLAG: String = "VOUCH_DEBUG_BUILD"

var enabled: bool = false


func _ready() -> void:
	enabled = OS.is_debug_build() or OS.get_environment(ENV_FLAG) == "1"
