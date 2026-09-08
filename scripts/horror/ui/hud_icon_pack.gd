extends RefCounted
class_name HudIconPack
## Leonardo v2 neon-horror HUD language (soft-go wiring).
##
## Phone light = yellow smartphone + LED bloom. Never a handheld torch.

const HEALTH := Color(1.0, 0.18, 0.28)
const STAMINA := Color(0.22, 0.92, 1.0)
const FEAR := Color(0.73, 0.32, 1.0)
const PHONE_LED := Color(1.0, 0.82, 0.19)
const SIGNAL_FULL := Color(0.25, 0.92, 0.38)
const SIGNAL_WEAK := Color(0.98, 0.82, 0.2)
const SIGNAL_DEAD := Color(1.0, 0.2, 0.22)
const GOLD := Color(1.0, 0.82, 0.22)
const PANEL := Color(0.04, 0.03, 0.07, 0.74)
const DIM := Color(0.16, 0.14, 0.2, 0.88)

const DIR := "res://assets/horror/hud"

const TEX_HEALTH := "health_heart"
const TEX_STAMINA := "stamina_pulse"
const TEX_FEAR := "fear_eye"
const TEX_PHONE_LED := "phone_led"
const TEX_SIGNAL_FULL := "signal_full"
const TEX_SIGNAL_WEAK := "signal_weak"
const TEX_SIGNAL_DEAD := "signal_dead"
const TEX_ABILITY := "ability_skull"
const TEX_SUPPLY := "supply_kit"
const TEX_HIDE := "hide_stealth"
const TEX_PANIC := "panic_warning"
const TEX_KEY_E := "key_e"
const TEX_MISSING_CHILD := "missing_child"
const TEX_PICKUP := "pickup_use"
const TEX_DOOR := "door_open"
const TEX_HIDE_PORCH := "hide_porch"


static func texture(stem: String) -> Texture2D:
	var path := "%s/%s.png" % [DIR, stem]
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D


static func signal_texture(band: String) -> Texture2D:
	match band:
		"full":
			return texture(TEX_SIGNAL_FULL)
		"weak":
			return texture(TEX_SIGNAL_WEAK)
		_:
			return texture(TEX_SIGNAL_DEAD)


static func signal_color(band: String) -> Color:
	match band:
		"full":
			return SIGNAL_FULL
		"weak":
			return SIGNAL_WEAK
		_:
			return SIGNAL_DEAD


static func band_from_strength(strength: float) -> String:
	if strength >= 0.82:
		return "full"
	if strength > 0.08:
		return "weak"
	return "dead"


static func hotbar_label(item_id: String) -> String:
	match item_id:
		"phone":
			return "PHONE"
		"medkit", "bandage":
			return "HEAL"
		"battery":
			return "BATT"
		"keycard":
			return "KEY"
		"crowbar":
			return "BAR"
		_:
			return item_id.to_upper()


static func hotbar_texture(item_id: String) -> Texture2D:
	match item_id:
		"phone":
			return texture(TEX_PHONE_LED)
		"medkit", "bandage":
			return texture(TEX_SUPPLY)
		"battery":
			return texture(TEX_PHONE_LED)
		_:
			return null
