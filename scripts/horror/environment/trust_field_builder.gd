extends RefCounted
class_name TrustFieldBuilder
## v0.5 radio masts + handsets. Many candidates; 1 sits on the PM gate.

const _TOWER_SCRIPT: Script = preload("res://scripts/horror/environment/radio_tower.gd")
const _PHONE_SCRIPT: Script = preload("res://scripts/horror/environment/signal_phone.gd")
const _TERRAIN: GDScript = preload("res://scripts/horror/environment/outdoor_terrain.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(parent: Node3D) -> Dictionary:
	var towers_root := Node3D.new()
	towers_root.name = "RadioTowers"
	parent.add_child(towers_root)
	var towers: Array[Node] = []
	for spec in _V05.TOWER_CANDIDATES:
		var tower := StaticBody3D.new()
		tower.name = "Tower_%s" % spec["id"]
		tower.set_script(_TOWER_SCRIPT)
		tower.set("tower_id", spec["id"])
		towers_root.add_child(tower)
		var tp: Vector3 = spec["pos"]
		var ty: float = float(_TERRAIN.call("height_at", tp.x, tp.z))
		tower.global_position = Vector3(tp.x, maxf(ty, 0.0), tp.z)
		towers.append(tower)

	var phones_root := Node3D.new()
	phones_root.name = "SignalPhones"
	parent.add_child(phones_root)
	var phones: Array[Node] = []
	for spec in _V05.PHONE_SPOTS:
		var phone := StaticBody3D.new()
		phone.name = "Phone_%s" % spec["id"]
		phone.set_script(_PHONE_SCRIPT)
		phone.set("phone_id", spec["id"])
		phones_root.add_child(phone)
		var pp: Vector3 = spec["pos"]
		var py: float = float(_TERRAIN.call("height_at", pp.x, pp.z))
		phone.global_position = Vector3(pp.x, maxf(py, 0.0) + 0.2, pp.z)
		phones.append(phone)

	return {
		"towers": towers,
		"phones": phones,
		"candidate_count": towers.size(),
	}
