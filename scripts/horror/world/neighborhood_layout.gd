extends RefCounted
class_name NeighborhoodLayout
## Assembles v0.5 cul-de-sac families, east PM mansion, uncle, yard.

const _FAMILY: GDScript = preload("res://scripts/horror/environment/family_house_builder.gd")
const _UNCLE: GDScript = preload("res://scripts/horror/environment/uncle_house_builder.gd")
const _MANSION: GDScript = preload("res://scripts/horror/environment/pm_mansion_builder.gd")
const _OUTDOOR: GDScript = preload("res://scripts/horror/environment/outdoor_builder.gd")
const _TRUST: GDScript = preload("res://scripts/horror/environment/trust_field_builder.gd")
const _MATS: GDScript = preload("res://scripts/horror/environment/graybox_materials.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(parent: Node3D, max_families: int = 4) -> Dictionary:
	var mats = _MATS.new()
	var family_spawns: Array[Marker3D] = []
	var houses: Array = _V05.FAMILY_HOUSES
	var family_count: int = clampi(max_families, 1, houses.size())

	var families_root := Node3D.new()
	families_root.name = "FamilyHouses"
	parent.add_child(families_root)

	for i in family_count:
		var spec: Dictionary = houses[i]
		var result: Dictionary = _FAMILY.call(
			"build",
			families_root,
			spec["origin"],
			int(spec["index"]),
			mats,
			float(spec["yaw"]),
			str(spec["letter"]),
		)
		family_spawns.append(result["bedroom_spawn"])

	var uncle_result: Dictionary = _UNCLE.call("build", parent, _V05.UNCLE_ORIGIN, mats, _V05.UNCLE_YAW)
	var mansion_result: Dictionary = _MANSION.call("build", parent, _V05.MANSION_ORIGIN, mats, _V05.MANSION_YAW)
	var outdoor_result: Dictionary = _OUTDOOR.call("build", parent, mats)
	var trust_result: Dictionary = _TRUST.call("build", parent)

	return {
		"family_spawns": family_spawns,
		"pm_spawn": mansion_result["pm_spawn"],
		"uncle_root": uncle_result["root"],
		"mansion_root": mansion_result["root"],
		"outdoor_root": outdoor_result["root"],
		"family_count": family_count,
		"tower_candidates": trust_result["candidate_count"],
	}
