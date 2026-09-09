extends RefCounted
class_name K7Overlays
## Kyle-locked K7 diegetic phone HUD overlays.
## Exact Leonardo PNG bytes live under res://hud/k7_overlays/.
## Eng owns fills, inventory, and input. Overlay TextureRects stay IGNORE.

const ROOT := "res://hud/k7_overlays"
const PHONE := ROOT + "/01_phone_overlays"
const BARS := ROOT + "/02_bars_overlays"
const RAIL := ROOT + "/03_rail_overlays"
const ICONS64 := ROOT + "/04_icons/64"
const ICONS128 := ROOT + "/04_icons/128"
const INTERACT := ROOT + "/05_interact_overlays"

const PHONE_FRAME := PHONE + "/phone_frame.png"
const ISLAND_NOTCH := PHONE + "/island_notch.png"
const PHONE_NOTCH := PHONE + "/phone_notch.png"
const STATUS_BAR := PHONE + "/status_bar.png"
const BOTTOM_NAV := PHONE + "/bottom_nav.png"
const FLASHLIGHT_ON := PHONE + "/flashlight_on.png"
const FLASHLIGHT_OFF := PHONE + "/flashlight_off.png"

const ECG_CHROME := BARS + "/ecg_panel_chrome.png"
const STAMINA_TRACK := BARS + "/stamina_track_empty.png"
const STAMINA_SEGMENT := BARS + "/stamina_segment.png"
const SIGNAL_TRACK := BARS + "/signal_track_empty.png"
const SIGNAL_SEGMENT := BARS + "/signal_segment.png"

const SLOT_EMPTY := RAIL + "/slot_empty.png"
const SLOT_SELECTED := RAIL + "/slot_selected.png"
const SLOT_EMPTY_SELECTED := RAIL + "/slot_empty_selected.png"
const RAIL_ALL_EMPTY := RAIL + "/rail_all_empty.png"
const RAIL_EXAMPLE := RAIL + "/rail_example_filled.png"
const BEVEL_DETAIL := RAIL + "/bevel_detail.png"

const PROMPT := INTERACT + "/interact_prompt.png"
const PROMPT_HOLD := INTERACT + "/interact_prompt_hold.png"
const BLUEPRINT := ROOT + "/IMPORT_BLUEPRINT.png"

const ICON_STEMS: Array[String] = [
	"key", "firearm", "shovel", "crowbar", "bandage", "battery_pack",
	"lockpick", "evidence", "rope", "fuse", "medkit", "flashlight",
]

const REQUIRED_OVERLAYS: Array[String] = [
	BLUEPRINT,
	PHONE_FRAME, ISLAND_NOTCH, PHONE_NOTCH, STATUS_BAR, BOTTOM_NAV,
	FLASHLIGHT_ON, FLASHLIGHT_OFF,
	ECG_CHROME, STAMINA_TRACK, STAMINA_SEGMENT, SIGNAL_TRACK, SIGNAL_SEGMENT,
	SLOT_EMPTY, SLOT_SELECTED, SLOT_EMPTY_SELECTED, RAIL_ALL_EMPTY,
	RAIL_EXAMPLE, BEVEL_DETAIL,
	PROMPT, PROMPT_HOLD,
]


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var imported: Texture2D = null
	if ResourceLoader.exists(path):
		imported = load(path) as Texture2D
	if imported != null and imported.get_width() > 2 and imported.get_height() > 2:
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


static func icon_path(item_id: String, size: int = 64) -> String:
	var stem := icon_stem(item_id)
	if stem.is_empty():
		return ""
	var folder := ICONS128 if size >= 96 else ICONS64
	return "%s/%s.png" % [folder, stem]


static func icon_stem(item_id: String) -> String:
	match item_id:
		"key", "keycard":
			return "key"
		"firearm", "gun":
			return "firearm"
		"shovel":
			return "shovel"
		"crowbar":
			return "crowbar"
		"bandage":
			return "bandage"
		"battery", "battery_pack":
			return "battery_pack"
		"lockpick":
			return "lockpick"
		"evidence":
			return "evidence"
		"rope":
			return "rope"
		"fuse":
			return "fuse"
		"medkit":
			return "medkit"
		"flashlight":
			return "flashlight"
		_:
			return ""


static func icon_texture(item_id: String) -> Texture2D:
	var hi := texture(icon_path(item_id, 128))
	if hi:
		return hi
	return texture(icon_path(item_id, 64))


static func missing_overlays() -> Array[String]:
	var missing: Array[String] = []
	for path in REQUIRED_OVERLAYS:
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			missing.append(path)
	return missing


static func apply_overlay_rect(rect: TextureRect) -> void:
	if rect == null:
		return
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
