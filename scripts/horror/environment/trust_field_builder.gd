extends RefCounted
class_name TrustFieldBuilder
## Places many radio-mast candidates and a few handsets around the yard.

const _TOWER_SCRIPT: Script = preload("res://scripts/horror/environment/radio_tower.gd")
const _PHONE_SCRIPT: Script = preload("res://scripts/horror/environment/signal_phone.gd")

## Many candidates; host keeps 3 live, 1 forced near the mansion.
const TOWER_CANDIDATES: Array[Dictionary] = [
	{"id": "pm_yard", "pos": Vector3(0, 0, -44)},
	{"id": "pm_west", "pos": Vector3(-22, 0, -58)},
	{"id": "pm_east", "pos": Vector3(22, 0, -58)},
	{"id": "pm_rear", "pos": Vector3(0, 0, -78)},
	{"id": "street_center", "pos": Vector3(0, 0, 26)},
	{"id": "street_west", "pos": Vector3(-28, 0, 26)},
	{"id": "street_east", "pos": Vector3(28, 0, 26)},
	{"id": "uncle_yard", "pos": Vector3(10, 0, 48)},
	{"id": "family_gap", "pos": Vector3(0, 0, 8)},
	{"id": "shed_lane", "pos": Vector3(40, 0, -12)},
	{"id": "garden", "pos": Vector3(-16, 0, -28)},
	{"id": "field_south", "pos": Vector3(0, 0, 52)},
]

const PHONE_SPOTS: Array[Dictionary] = [
	{"id": "family_porch_phone", "pos": Vector3(-34, 0.2, 14)},
	{"id": "street_phone", "pos": Vector3(6, 0.2, 26)},
	{"id": "uncle_phone", "pos": Vector3(-4, 0.2, 40)},
	{"id": "mansion_gate_phone", "pos": Vector3(4, 0.2, -44)},
]


static func build(parent: Node3D) -> Dictionary:
	var towers_root := Node3D.new()
	towers_root.name = "RadioTowers"
	parent.add_child(towers_root)
	var towers: Array[Node] = []
	for spec in TOWER_CANDIDATES:
		var tower := StaticBody3D.new()
		tower.name = "Tower_%s" % spec["id"]
		tower.set_script(_TOWER_SCRIPT)
		tower.set("tower_id", spec["id"])
		towers_root.add_child(tower)
		tower.global_position = spec["pos"]
		towers.append(tower)

	var phones_root := Node3D.new()
	phones_root.name = "SignalPhones"
	parent.add_child(phones_root)
	var phones: Array[Node] = []
	for spec in PHONE_SPOTS:
		var phone := StaticBody3D.new()
		phone.name = "Phone_%s" % spec["id"]
		phone.set_script(_PHONE_SCRIPT)
		phone.set("phone_id", spec["id"])
		phones_root.add_child(phone)
		phone.global_position = spec["pos"]
		phones.append(phone)

	return {
		"towers": towers,
		"phones": phones,
		"candidate_count": towers.size(),
	}
