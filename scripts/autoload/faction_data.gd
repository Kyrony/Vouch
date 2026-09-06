extends Node
## FactionData
##
## Static definitions for the rival factions players are split into.
## MVP ships with exactly 4 factions (8 players, 4v4), but every system in
## this project reads from `ACTIVE_FACTIONS`/`get_active_factions()` rather
## than hardcoding "4" or "2 teams", so a host can later configure 3v3v3 or
## 4v4v4v4 without touching gameplay code.
##
## TODO(post-MVP): expose faction count / roster size as a lobby setting
## instead of the ALL_FACTIONS -> first N slice used today.

## Every faction Vouch ships with. MVP only ever activates 4 of these, but
## keeping the master list larger than the MVP requirement makes it trivial
## to add a 5th/6th faction later without restructuring data.
const ALL_FACTIONS: Array[Dictionary] = [
	{
		"id": "red_vipers",
		"name": "Red Vipers",
		"color": Color(0.82, 0.16, 0.16),
	},
	{
		"id": "blue_ash",
		"name": "Blue Ash",
		"color": Color(0.16, 0.42, 0.82),
	},
	{
		"id": "green_hollow",
		"name": "Green Hollow",
		"color": Color(0.24, 0.62, 0.30),
	},
	{
		"id": "yellow_sparks",
		"name": "Yellow Sparks",
		"color": Color(0.90, 0.75, 0.15),
	},
]

## How many factions the current match uses. Defaults to MVP's 4 (4v4 with
## 8 players). Change this (or wire it to a lobby setting) to test 2, 3, or
## more factions; every faction-aware system already loops over
## `get_active_factions()` instead of assuming a fixed count.
var active_faction_count: int = 4


func get_active_factions() -> Array[Dictionary]:
	var count := clampi(active_faction_count, 1, ALL_FACTIONS.size())
	return ALL_FACTIONS.slice(0, count)


func get_faction_by_id(faction_id: String) -> Dictionary:
	for faction in ALL_FACTIONS:
		if faction["id"] == faction_id:
			return faction
	return {}


func get_faction_color(faction_id: String) -> Color:
	var faction := get_faction_by_id(faction_id)
	if faction.is_empty():
		return Color.WHITE
	return faction["color"]


func get_faction_name(faction_id: String) -> String:
	var faction := get_faction_by_id(faction_id)
	if faction.is_empty():
		return "Unknown"
	return faction["name"]
