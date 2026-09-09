extends Node
## PhoneDevice — diegetic smartphone (ITEM_DEVICE_SMARTPHONE_01).
##
## Inventory id stays `phone` so TowerRules / holding checks stay intact.
## Light is the camera LED only — no handheld flashlight item.
##
## Battery drain constants are ENG-TUNABLE. Leonardo's item sheet listed
## ~15%/min (LED) and ~2%/min (passive) as CONCEPT numbers, not balance truth.

signal local_phone_state(battery: float, led_on: bool, has_phone: bool)

const ITEM_ID: String = "phone"
const ITEM_PRODUCTION_ID: String = "ITEM_DEVICE_SMARTPHONE_01"

# ── TUNABLES — tweak these to balance gameplay ──
const BATTERY_MAX: float = 100.0  # full battery cap
const BATTERY_START: float = 100.0
const LED_MIN_BATTERY: float = 1.0
## Eng-owned. Sheet concept was ~15%/min LED — do not treat as locked TTK.
const LED_DRAIN_PER_SEC: float = 0.16  # drain while LED on
## Eng-owned. Sheet concept was ~2%/min passive.
const PASSIVE_DRAIN_PER_SEC: float = 0.03  # idle drain
const RECHARGE_AMOUNT: float = 55.0  # per recharge pickup

var local_battery: float = BATTERY_START
var local_led_on: bool = false
var local_has_phone: bool = false

var _battery: Dictionary = {}
var _led_on: Dictionary = {}


func reset() -> void:
	_battery.clear()
	_led_on.clear()
	local_battery = BATTERY_START
	local_led_on = false
	local_has_phone = false


func server_init_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_battery[peer_id] = BATTERY_START
	_led_on[peer_id] = false
	_broadcast(peer_id)


func server_has_phone(peer_id: int) -> bool:
	return PlayerInventory.server_has_item(peer_id, ITEM_ID)


func server_get_battery(peer_id: int) -> float:
	return float(_battery.get(peer_id, BATTERY_START))


func server_is_led_on(peer_id: int) -> bool:
	return bool(_led_on.get(peer_id, false))


func server_toggle_led(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	_ensure(peer_id)
	if not server_has_phone(peer_id):
		_led_on[peer_id] = false
		_broadcast(peer_id)
		return false
	if bool(_led_on.get(peer_id, false)):
		_led_on[peer_id] = false
		_broadcast(peer_id)
		return false
	if float(_battery.get(peer_id, 0.0)) < LED_MIN_BATTERY:
		_led_on[peer_id] = false
		_broadcast(peer_id)
		return false
	_led_on[peer_id] = true
	_broadcast(peer_id)
	return true


func server_force_led(peer_id: int, on: bool) -> void:
	if not multiplayer.is_server():
		return
	_ensure(peer_id)
	if on and (not server_has_phone(peer_id) or float(_battery.get(peer_id, 0.0)) < LED_MIN_BATTERY):
		on = false
	_led_on[peer_id] = on
	_broadcast(peer_id)


func server_recharge(peer_id: int, amount: float = RECHARGE_AMOUNT) -> bool:
	if not multiplayer.is_server():
		return false
	if not server_has_phone(peer_id):
		return false
	_ensure(peer_id)
	_battery[peer_id] = minf(BATTERY_MAX, float(_battery.get(peer_id, 0.0)) + amount)
	_broadcast(peer_id)
	return true


func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for peer_id in _battery.keys():
		var has_phone := server_has_phone(int(peer_id))
		var bat: float = float(_battery[peer_id])
		var led: bool = bool(_led_on.get(peer_id, false))
		if not has_phone:
			if led:
				_led_on[peer_id] = false
				_broadcast(int(peer_id))
			continue
		bat -= PASSIVE_DRAIN_PER_SEC * delta
		if led:
			bat -= LED_DRAIN_PER_SEC * delta
		if bat <= 0.0:
			bat = 0.0
			led = false
		_battery[peer_id] = bat
		_led_on[peer_id] = led
		_broadcast(int(peer_id))


static func led_drain_per_minute() -> float:
	return LED_DRAIN_PER_SEC * 60.0


static func passive_drain_per_minute() -> float:
	return PASSIVE_DRAIN_PER_SEC * 60.0


func _ensure(peer_id: int) -> void:
	if not _battery.has(peer_id):
		_battery[peer_id] = BATTERY_START
	if not _led_on.has(peer_id):
		_led_on[peer_id] = false


func _broadcast(peer_id: int) -> void:
	var bat := float(_battery.get(peer_id, BATTERY_START))
	var led := bool(_led_on.get(peer_id, false))
	var has_phone := server_has_phone(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_apply_local(bat, led, has_phone)
	else:
		_client_phone_state.rpc_id(peer_id, bat, led, has_phone)


func _apply_local(battery: float, led_on: bool, has_phone: bool) -> void:
	local_battery = battery
	local_led_on = led_on
	local_has_phone = has_phone
	local_phone_state.emit(battery, led_on, has_phone)


@rpc("authority", "call_remote", "reliable")
func _client_phone_state(battery: float, led_on: bool, has_phone: bool) -> void:
	_apply_local(battery, led_on, has_phone)
