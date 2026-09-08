extends Node
## RoomUtilities
##
## Per-room Power/Water/Gas/Communication state, all ON at match start.
## Mystery controls, the electrical-box puzzle, and sabotage flip them OFF
## per room (light->power, flood->water, gas->gas, comms->communication).
## State is replicated to every peer without leaking who caused what.

signal utility_changed(room_index: int, utility: String, enabled: bool)

const UTILITY_POWER := "power"
const UTILITY_WATER := "water"
const UTILITY_GAS := "gas"
const UTILITY_COMMS := "comms"

const ALL_UTILITIES: Array[String] = [UTILITY_POWER, UTILITY_WATER, UTILITY_GAS, UTILITY_COMMS]

## room_index -> { power: bool, water: bool, gas: bool, comms: bool }
var room_states: Dictionary = {}


func reset() -> void:
	room_states.clear()


func server_init_room(room_index: int) -> void:
	if not multiplayer.is_server():
		return
	room_states[room_index] = {
		UTILITY_POWER: true,
		UTILITY_WATER: true,
		UTILITY_GAS: true,
		UTILITY_COMMS: true,
	}


func is_enabled(room_index: int, utility: String) -> bool:
	var state: Dictionary = room_states.get(room_index, {})
	if state.is_empty():
		return true
	return state.get(utility, true)


func server_set_utility(room_index: int, utility: String, enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	if not room_states.has(room_index):
		server_init_room(room_index)
	room_states[room_index][utility] = enabled
	_client_sync_utility.rpc(room_index, utility, enabled)
	utility_changed.emit(room_index, utility, enabled)


@rpc("authority", "call_remote", "reliable")
func _client_sync_utility(room_index: int, utility: String, enabled: bool) -> void:
	if not room_states.has(room_index):
		room_states[room_index] = {
			UTILITY_POWER: true,
			UTILITY_WATER: true,
			UTILITY_GAS: true,
			UTILITY_COMMS: true,
		}
	room_states[room_index][utility] = enabled
	utility_changed.emit(room_index, utility, enabled)
