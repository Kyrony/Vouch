extends RefCounted
class_name NeighborhoodLayout
## Host Match world: L1b farm terrain + roads + labeled L2 spawn markers.
## No house / bunker / mast meshes — Kyle farm redirect.

const _OUTDOOR: GDScript = preload("res://scripts/horror/environment/outdoor_builder.gd")
const _MARKERS: GDScript = preload("res://scripts/horror/environment/spawn_point_markers.gd")
const _MATS: GDScript = preload("res://scripts/horror/environment/graybox_materials.gd")
const _V05: GDScript = preload("res://scripts/horror/world/neighborhood_v05.gd")


static func build(parent: Node3D, max_families: int = 4) -> Dictionary:
	var mats = _MATS.new()
	var outdoor_result: Dictionary = _OUTDOOR.call("build", parent, mats)
	var marker_result: Dictionary = _MARKERS.call("build", parent)

	var outdoor_spawns: Array = outdoor_result.get("player_spawns", [])
	var live_spawns: Array[Marker3D] = []
	for m in outdoor_spawns:
		if m is Marker3D:
			live_spawns.append(m)

	var pm_spawn: Marker3D = outdoor_result.get("pm_spawn")
	var family_count: int = clampi(max_families, 1, _V05.FAMILY_HOUSES.size())

	return {
		"family_spawns": live_spawns,
		"bedroom_spawns": [],
		"porch_spawns": [],
		"pm_spawn": pm_spawn,
		"uncle_root": null,
		"garage_root": null,
		"mansion_root": null,
		"outdoor_root": outdoor_result["root"],
		"l2_markers": marker_result.get("markers", []),
		"family_count": family_count,
		"tower_candidates": 0,
	}
