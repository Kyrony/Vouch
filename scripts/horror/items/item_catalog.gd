extends RefCounted
class_name ItemCatalog
## Central metadata for items: pickup color, label, use time, and the tunable
## numbers each item uses. One place to add or rebalance an item. Behaviour
## lives in PlayerInventory._apply_use_item(); use time is enforced there too.
##
## `use_time` = seconds the survivor must hold to finish using it (animations
## come later). `pm_only` items belong to the Puppet Master.

# ── TUNABLES — item effects & use times (tweak to rebalance) ──
const ITEMS: Dictionary = {
	# --- Survivor items ---
	"medkit": {
		"label": "Medkit", "color": Color(0.85, 0.18, 0.18),
		"heal": 60.0, "use_time": 3.0, "consumable": true,
	},
	"bandage": {
		"label": "Bandage", "color": Color(0.90, 0.55, 0.55),
		"heal": 25.0, "use_time": 2.0, "consumable": true,
	},
	"painkillers": {
		"label": "Painkillers", "color": Color(0.92, 0.92, 0.88),
		"heal": 15.0, "fear_relief": 100.0, "use_time": 1.5, "consumable": true,
	},
	"energy_drink": {
		"label": "Energy Drink", "color": Color(0.55, 0.85, 0.25),
		"stamina": 100.0, "use_time": 1.0, "consumable": true,
	},
	"adrenaline": {
		"label": "Adrenaline Shot", "color": Color(0.95, 0.55, 0.10),
		"stamina": 100.0, "fear_relief": 100.0, "use_time": 1.0, "consumable": true,
	},
	"scissors": {
		"label": "Scissors", "color": Color(0.70, 0.72, 0.78),
		"cut_range": 4.0, "use_time": 1.2, "consumable": true,
	},
	"fuse": {
		"label": "Fuse", "color": Color(0.85, 0.68, 0.20),
		"insert_range": 3.0, "use_time": 2.0, "consumable": true,
	},
	"flare": {
		"label": "Flare", "color": Color(0.98, 0.35, 0.15),
		"light_range": 9.0, "light_seconds": 30.0, "use_time": 0.5, "consumable": true,
	},
	"crowbar": {
		"label": "Crowbar", "color": Color(0.55, 0.58, 0.62),
		"stun_range": 3.0, "stun_seconds": 3.0, "pry_range": 3.0,
		"use_time": 1.5, "consumable": false,
	},
	"key": {
		"label": "Key", "color": Color(0.85, 0.78, 0.30),
		"unlock_range": 3.0, "use_time": 0.6, "consumable": true,
	},
	"lockpick": {
		"label": "Lockpick", "color": Color(0.60, 0.62, 0.66),
		"unlock_range": 2.5, "use_time": 2.5, "consumable": false,
	},
	"phone": {
		"label": "Smartphone", "color": Color(0.18, 0.18, 0.20),
		"use_time": 0.0, "consumable": false,
	},
	"battery": {
		"label": "Battery", "color": Color(0.72, 0.58, 0.16),
		"recharge": 55.0, "use_time": 0.4, "consumable": true,
	},
	"keycard": {
		"label": "Keycard", "color": Color(0.2, 0.7, 0.9),
		"unlock_range": 3.0, "use_time": 0.6, "consumable": true,
	},

	# --- Puppet Master items ---
	"strings": {
		"label": "Strings", "color": Color(0.85, 0.85, 0.90),
		"pm_only": true, "use_time": 0.0, "consumable": false,
	},
	"puppet": {
		"label": "Puppet", "color": Color(0.60, 0.40, 0.25),
		"pm_only": true, "use_time": 1.0, "consumable": false,
	},
}


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func label(item_id: String) -> String:
	return str(get_item(item_id).get("label", item_id))


static func color(item_id: String) -> Color:
	return get_item(item_id).get("color", Color(0.55, 0.55, 0.6))


static func is_consumable(item_id: String) -> bool:
	return bool(get_item(item_id).get("consumable", true))


static func use_time(item_id: String) -> float:
	return float(get_item(item_id).get("use_time", 0.0))


static func is_pm_only(item_id: String) -> bool:
	return bool(get_item(item_id).get("pm_only", false))


## Survivor item ids (scattered on the ground for survivors to grab).
static func survivor_item_ids() -> Array:
	var out: Array = []
	for id in ITEMS.keys():
		if not is_pm_only(str(id)):
			out.append(id)
	return out


## Puppet Master item ids (strings, puppet).
static func pm_item_ids() -> Array:
	var out: Array = []
	for id in ITEMS.keys():
		if is_pm_only(str(id)):
			out.append(id)
	return out
