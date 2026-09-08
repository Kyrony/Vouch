extends RefCounted
class_name ItemCatalog
## Central metadata for survivor items: pickup color, label, and the tunable
## numbers each item uses when consumed/used. One place to add or rebalance
## an item. Behaviour lives in PlayerInventory._apply_use_item().

# ── TUNABLES — item effects (tweak to rebalance) ──
const ITEMS: Dictionary = {
	# Floor pickups a survivor can grab (E) and use (R).
	"medkit": {
		"label": "Medkit",
		"color": Color(0.85, 0.18, 0.18),
		"heal": 60.0,  # HP restored
		"consumable": true,
	},
	"bandage": {
		"label": "Bandage",
		"color": Color(0.90, 0.55, 0.55),
		"heal": 25.0,  # small HP restore
		"consumable": true,
	},
	"energy_drink": {
		"label": "Energy Drink",
		"color": Color(0.55, 0.85, 0.25),
		"stamina": 100.0,  # stamina refilled
		"consumable": true,
	},
	"painkillers": {
		"label": "Painkillers",
		"color": Color(0.92, 0.92, 0.88),
		"heal": 15.0,  # HP restore
		"fear_relief": 100.0,  # fear removed
		"consumable": true,
	},
	"adrenaline": {
		"label": "Adrenaline Shot",
		"color": Color(0.95, 0.55, 0.10),
		"stamina": 100.0,  # stamina refilled
		"fear_relief": 100.0,  # fear removed
		"cuts_own_strings": true,  # breaks a puppet tether on yourself
		"consumable": true,
	},
	"scissors": {
		"label": "Scissors",
		"color": Color(0.70, 0.72, 0.78),
		"cut_range": 4.0,  # reach to cut a teammate's strings (m)
		"consumable": true,  # consumed only when a cut succeeds
	},
	"fuse": {
		"label": "Fuse",
		"color": Color(0.85, 0.68, 0.20),
		"restores_power": true,  # relights + restores comms in your room
		"consumable": true,  # consumed only when a room actually needed power
	},
	"flare": {
		"label": "Flare",
		"color": Color(0.98, 0.35, 0.15),
		"light_range": 9.0,  # dropped light reach (m)
		"light_seconds": 30.0,  # burn time
		"consumable": true,
	},
	"crowbar": {
		"label": "Crowbar",
		"color": Color(0.55, 0.58, 0.62),
		"stun_range": 3.0,  # reach to strike the Puppet Master (m)
		"stun_seconds": 3.0,  # PM ability lockout
		"consumable": false,  # reusable tool
	},
	"light_switch": {
		"label": "Light Switch",
		"color": Color(0.70, 0.85, 0.95),
		"consumable": false,  # reusable — flips your room's lights on/off
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


## The item ids introduced in this pass (used to scatter pickups at match start).
static func survival_item_ids() -> Array:
	return ITEMS.keys()
