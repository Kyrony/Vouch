extends Node
## HorrorModeSettings
##
## Default play path: shared horror bunker escape (house + bunker + field).
## Legacy modes remain behind env flags:
##   VOUCH_BUNKER_ONLY=1  — sealed single-room bunker (friends-MVP)
##   VOUCH_ESCAPE_PATH=1  — multi-room tunnel escape loop

const BUNKER_ENV: String = "VOUCH_BUNKER_ONLY"
const ESCAPE_ENV: String = "VOUCH_ESCAPE_PATH"


static func is_horror_mode() -> bool:
	if OS.get_environment(BUNKER_ENV) == "1":
		return false
	if OS.get_environment(ESCAPE_ENV) == "1":
		return false
	return true


static func mode_label() -> String:
	if is_horror_mode():
		return "horror"
	if OS.get_environment(ESCAPE_ENV) == "1":
		return "escape_path"
	return "bunker_only"


func _ready() -> void:
	print("[HorrorModeSettings] active mode=%s" % mode_label())
