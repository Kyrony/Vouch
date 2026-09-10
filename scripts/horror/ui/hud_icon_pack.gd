extends RefCounted
class_name HudIconPack
## Kyle-locked HUD meters: horror-vial health over yellow stamina.
## EMPTY tracks only. Eng owns fill % in Godot. Fill examples are color refs.
## Right rail: 5 octagon wells + multicolor item icons. Signal/battery stay widgets.
## Phone light = yellow smartphone + LED. Never a handheld torch.

const HEALTH := Color(0.55, 0.06, 0.10)
const STAMINA := Color(1.0, 0.70, 0.0)
const FEAR := Color(0.73, 0.32, 1.0)
const PHONE_LED := Color(1.0, 0.82, 0.19)
const SIGNAL_FULL := Color(0.25, 0.92, 0.38)
const SIGNAL_WEAK := Color(0.98, 0.82, 0.2)
const SIGNAL_DEAD := Color(1.0, 0.2, 0.22)
const SIGNAL_EMPTY := Color(0.42, 0.44, 0.48)
const BATTERY := Color(0.98, 0.72, 0.12)
const SELECTED := Color(0.31, 0.75, 1.0)
const GOLD := Color(1.0, 0.82, 0.22)
const PANEL := Color(0.04, 0.03, 0.07, 0.74)
const DIM := Color(0.16, 0.14, 0.2, 0.88)

const _K7: GDScript = preload("res://scripts/horror/ui/k7_overlays.gd")
const DIR := "res://assets/horror/hud"
const RAIL_SLOTS := 5
const EXAMPLE_RAIL: Array[String] = ["key", "firearm", "crowbar", "", ""]
const EXAMPLE_RAIL_SELECTED := 2

const TEX_HEALTH := "health_bar_empty"
const TEX_STAMINA := "stamina_bar_empty"
const TEX_FEAR := "fear_bar_empty"
const TEX_HEALTH_CHIP := "health_chip"
const TEX_STAMINA_CHIP := "stamina_chip"
const TEX_FEAR_CHIP := "fear_chip"
const TEX_PHONE_LED := "phone_led"
const TEX_SIGNAL_FULL := "signal_full"
const TEX_SIGNAL_WEAK := "signal_weak"
const TEX_SIGNAL_DEAD := "signal_dead"
const TEX_SIGNAL_EMPTY := "signal_empty"
const TEX_BATTERY_EMPTY := "battery_empty"
const TEX_SLOT_EMPTY := "slot_empty"
const TEX_SLOT_SELECTED := "slot_selected"
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
	if stem == TEX_SLOT_EMPTY:
		var k7: Texture2D = _K7.texture(_K7.SLOT_EMPTY)
		if k7:
			return k7
	if stem == TEX_SLOT_SELECTED:
		var k7s: Texture2D = _K7.texture(_K7.SLOT_SELECTED)
		if k7s:
			return k7s
	var path := "%s/%s.png" % [DIR, stem]
	var imported: Texture2D = null
	if ResourceLoader.exists(path):
		imported = load(path) as Texture2D
	if imported != null and imported.get_width() > 4 and imported.get_height() > 4:
		return imported
	if FileAccess.file_exists(path):
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa:
			var buf := fa.get_buffer(int(fa.get_length()))
			fa.close()
			var img := Image.new()
			if img.load_png_from_buffer(buf) == OK and img.get_width() > 0:
				return ImageTexture.create_from_image(img)
		var fallback := Image.load_from_file(path)
		if fallback:
			return ImageTexture.create_from_image(fallback)
	return null


static func signal_texture(band: String) -> Texture2D:
	match band:
		"full":
			return texture(TEX_SIGNAL_FULL)
		"weak":
			var weak := texture(TEX_SIGNAL_WEAK)
			return weak if weak else texture(TEX_SIGNAL_FULL)
		"empty":
			var empty := texture(TEX_SIGNAL_EMPTY)
			return empty if empty else texture(TEX_SIGNAL_DEAD)
		_:
			var dead := texture(TEX_SIGNAL_DEAD)
			return dead if dead else texture(TEX_SIGNAL_FULL)


static func signal_color(band: String) -> Color:
	match band:
		"full":
			return SIGNAL_FULL
		"weak":
			return SIGNAL_WEAK
		"empty":
			return SIGNAL_EMPTY
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
	return rail_texture(item_id)


static func rail_texture(item_id: String) -> Texture2D:
	## Multicolor rail icons. Phone is a device — only used if it lands in a well.
	## Never load flashlight.png / torch.png (classic torch glyph is forbidden).
	## Prefer K7 neon icons when the follow-up pack lands; else soft-go HUD icons.
	var k7_icon: Texture2D = _K7.icon_texture(item_id)
	if k7_icon:
		return k7_icon
	var stem := rail_icon_stem(item_id)
	if stem.is_empty():
		return null
	var tex := texture(stem)
	if tex:
		return tex
	match item_id:
		"phone":
			return texture(TEX_PHONE_LED)
		"medkit", "bandage":
			return texture(TEX_SUPPLY)
		_:
			return null


static func rail_icon_stem(item_id: String) -> String:
	match item_id:
		"key", "keycard":
			return "icon_key"
		"firearm", "gun":
			return "icon_firearm"
		"shovel":
			return "icon_shovel"
		"crowbar":
			return "icon_crowbar"
		"bandage":
			return "icon_bandage"
		"battery", "battery_pack":
			return "icon_battery_pack"
		"lockpick":
			return "icon_lockpick"
		"evidence":
			return "icon_evidence"
		"rope":
			return "icon_rope"
		"fuse":
			return "icon_fuse"
		"medkit":
			return "icon_medkit"
		"flashlight":
			return "icon_flashlight"
		"phone":
			return TEX_PHONE_LED
		_:
			return ""


static func is_rail_item(item_id: String) -> bool:
	## Signal / battery widgets stay off the rail. Phone is a device, not a well.
	if item_id.is_empty():
		return false
	if item_id == "phone" or item_id == "signal" or item_id.begins_with("signal_"):
		return false
	return true


static func make_fill_texture(color: Color, width: int, height: int, inset: int) -> ImageTexture:
	## Programmatic meter fill. No mid/low fill PNGs — eng owns %.
	var w := maxi(width, 8)
	var h := maxi(height, 8)
	var pad := clampi(inset, 2, int(h / 2) - 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inner_w := w - pad * 2
	var inner_h := h - pad * 2
	var rad := maxf(float(inner_h) * 0.5, 1.0)
	var hi := color.lightened(0.22)
	var lo := color.darkened(0.08)
	for y in range(pad, h - pad):
		var t := float(y - pad) / float(maxi(inner_h - 1, 1))
		var row_col := hi.lerp(lo, clampf(t, 0.0, 1.0))
		for x in range(pad, w - pad):
			if _in_round_rect(float(x - pad), float(y - pad), float(inner_w), float(inner_h), rad):
				img.set_pixel(x, y, row_col)
	return ImageTexture.create_from_image(img)


static func _in_round_rect(x: float, y: float, w: float, h: float, r: float) -> bool:
	var dx := maxf(absf(x - w * 0.5) - (w * 0.5 - r), 0.0)
	var dy := maxf(absf(y - h * 0.5) - (h * 0.5 - r), 0.0)
	return (dx * dx + dy * dy) <= (r * r + 0.35)
