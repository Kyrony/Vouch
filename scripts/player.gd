extends CharacterBody3D
class_name Player
## Player
##
## Multiplayer player pawn. Movement is only ever processed on the peer
## that owns this instance (`is_multiplayer_authority()`); the resulting
## transform is replicated to everyone else via the MultiplayerSynchronizer
## child. This is the standard Godot 4 "input on authority, sync the
## result" pattern for a host-authoritative game.
##
## Also owns all of the local player's HUD: phone (+ local contact
## rename), physical code keypad, Puppet Master camera/sabotage panel,
## and the eliminated overlay. Any modal panel (phone/keypad) sets
## `_active_modal` which fully locks movement/look/jump - see
## `_is_input_locked()`. Ladder climbing, hold-to-destroy, held-clue-paper
## flame proximity, and the test-only gun are all handled here too.
##
## TODO(post-MVP): server-side movement validation/anti-cheat, footstep
## audio, ragdoll/animation, proper first-person arms model.

enum Modal { NONE, PHONE, KEYPAD, BINARY, WALKIE, PAUSE }

# ── TUNABLES — tweak these to balance gameplay ──
const SPEED: float = 4.5  # base walk speed (m/s)
const SPRINT_MULTIPLIER: float = 1.4  # sprint = SPEED * this
const STAMINA_EMPTY: float = 0.5
const STAMINA_RESUME: float = 12.0
const JUMP_VELOCITY: float = 3.2  # initial jump impulse
const MOUSE_SENSITIVITY: float = 0.0025  # radians per pixel
const TOAST_DURATION: float = 4.5
const CLIMB_SPEED: float = 3.0  # ladder climb speed (m/s)
const DESTROY_HOLD_DURATION: float = 1.2  # hold-to-destroy seconds
const PAPER_REVEAL_RADIUS: float = 2.0
const PAPER_BURN_RADIUS: float = 0.7
const PAPER_REVEAL_TIME: float = 1.5
const PAPER_BURN_TIME: float = 1.2

const _PATHS: GDScript = preload("res://scripts/interactable_script_paths.gd")
const _TEST_PROJECTILE_SCRIPT: Script = preload("res://scripts/interactables/test_projectile.gd")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hud: CanvasLayer = $HUD
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var faction_label: Label = $HUD/FactionLabel
@onready var holding_label: Label = $HUD/HoldingLabel
@onready var destroy_progress_bar: ProgressBar = $HUD/DestroyProgressBar

@onready var phone_panel: Control = $HUD/PhonePanel
@onready var phone_input: LineEdit = $HUD/PhonePanel/VBoxContainer/ComposeRow/PhoneInput
@onready var phone_log: RichTextLabel = $HUD/PhonePanel/VBoxContainer/PhoneLog
@onready var contacts_box: VBoxContainer = $HUD/PhonePanel/VBoxContainer/ContactsScroll/ContactsBox
@onready var rename_row: HBoxContainer = $HUD/PhonePanel/VBoxContainer/RenameRow
@onready var rename_input: LineEdit = $HUD/PhonePanel/VBoxContainer/RenameRow/RenameInput

@onready var keypad_panel: Control = $HUD/KeypadPanel
@onready var keypad_display: Label = $HUD/KeypadPanel/VBoxContainer/KeypadDisplay
@onready var keypad_feedback: Label = $HUD/KeypadPanel/VBoxContainer/KeypadFeedback

@onready var camera_panel: Control = $HUD/CameraPanel
@onready var camera_feed_box: HBoxContainer = $HUD/CameraPanel/FeedBox

@onready var toast_label: Label = $HUD/ToastLabel
@onready var toast_timer: Timer = $HUD/ToastLabel/ToastTimer

@onready var eliminated_overlay: Control = $HUD/EliminatedOverlay

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _active_modal: Modal = Modal.NONE
var _eliminated: bool = false
var _spectating: bool = false
var _keypad_room_index: int = -1
var _keypad_digits: String = ""
var _renaming_line_id: String = ""

var _on_ladder: bool = false
var _current_ladder: Node = null

var _destroy_target: Node = null
var _destroy_hold_time: float = 0.0

var _held_paper: Node = null
var _paper_reveal_progress: float = 0.0
var _paper_burn_progress: float = 0.0
var _paper_revealed: bool = false

## *** TEST-ONLY - REMOVE BEFORE FULL RELEASE. *** See Gun.gd.
var has_gun: bool = false

var _binary_terminal: Node = null
var _binary_panel: Panel
var _binary_target_label: Label
var _binary_bits_label: Label
var _binary_feedback_label: Label
var _pause_menu: Node

var _crouching: bool = false
var _highlight_target: Node = null
var _walkie_panel: Panel
var _walkie_log: RichTextLabel
var _walkie_input: LineEdit
var _walkie_partner_label: Label

## Set by NetworkManager/Match director's spawn_function before this node
## is added to the tree. Purely informational in MVP - see the note in
## docs/MVP_GDD.md about why we deliberately do NOT tint remote players by
## faction color (that would leak the mystery/social-deduction info).
var faction_id: String = ""

var horror_mode: bool = false
var is_horror_puppet_master: bool = false

var _pm_controller: Node = null
var _health_bar: ProgressBar = null
var _stamina_bar: ProgressBar = null
var _fear_bar: ProgressBar = null
var _hotbar_labels: Array[Label] = []
var _neon_hud: Control = null

# Puppet Master string tether / possession state (replicated to this survivor).
var _tether_slow: float = 0.0
var _tether_immobilized: bool = false
var _possessed: bool = false
var _trap_check_accum: float = 0.0
var _has_puppet: bool = false  # PM: currently wearing the puppet
var _grab_check_accum: float = 0.0
var _local_health: float = 100.0
var _local_stamina: float = 100.0
var _local_max_health: float = 100.0
var _is_sprinting: bool = false
var _stamina_exhausted: bool = false
var _stamina_sync_accum: float = 0.0
var _last_synced_stamina: float = 100.0
var _last_synced_sprinting: bool = false
var _inventory_slots: Array = []
var _inventory_selected: int = 0
var _phone_rig: Node3D = null
var _held_phone: Node3D = null
var _phone_led_spot: SpotLight3D = null
var _phone_led_omni: OmniLight3D = null
var _local_fear: float = 0.0


func _ready() -> void:
	add_to_group("players")

	# Authority is set by Match._spawn_player() before this node is added
	# to the tree (required so the MultiplayerSynchronizer child spawns
	# correctly) - by the time _ready() runs here it's already correct.
	if is_multiplayer_authority():
		camera.current = true
		hud.visible = true
		if horror_mode or HorrorModeSettings.is_horror_mode():
			horror_mode = true
		if is_horror_puppet_master:
			GameState.local_is_puppet_master = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameState.local_player_node = self

		NetworkManager.faction_assigned.connect(_on_faction_assigned)
		PhoneSystem.text_received.connect(_on_text_received)
		PhoneSystem.text_sent_confirmation.connect(_on_text_sent_confirmation)
		EscapeSystem.escape_locked.connect(_on_escape_locked)
		PuzzleSystem.unlock_result.connect(_on_unlock_result)
		PuppetMasterSystem.you_are_puppet_master.connect(_on_you_are_puppet_master)
		PuppetMasterSystem.sabotage_result.connect(_on_sabotage_result)
		PuppetMasterSystem.you_were_eliminated.connect(_on_you_were_eliminated)
		ContactBook.contacts_changed.connect(_refresh_contacts_list)
		WalkieSystem.message_received.connect(_on_walkie_received)
		WalkieSystem.message_sent_confirmation.connect(_on_walkie_sent)

		if not GameState.local_faction_id.is_empty():
			_on_faction_assigned(GameState.local_faction_id)
		if GameState.local_is_puppet_master or is_horror_puppet_master:
			faction_label.text = "PUPPET MASTER"
			faction_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.85))
		_build_binary_panel()
		if not horror_mode:
			_build_walkie_panel()
		_build_horror_hud()
		if horror_mode:
			PlayerHealth.local_health_changed.connect(_on_local_health_changed)
			PlayerInventory.local_inventory_changed.connect(_on_local_inventory_changed)
			PlayerEffects.local_meters_changed.connect(_on_local_meters_changed)
			PhoneDevice.local_phone_state.connect(_on_local_phone_state)
			PuppetStringSystem.local_tether_changed.connect(_on_local_tether)
			PuppetControlSystem.local_possessed_changed.connect(_on_local_possessed)
			PuppetControlSystem.local_puppet_state_changed.connect(_on_puppet_state)
		_pause_menu = get_node_or_null("/root/Main/PauseMenu")
		_wire_lose_overlay()
	else:
		camera.current = false
		hud.visible = false
		set_process_unhandled_input(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if _eliminated:
		_handle_eliminated_input(event)
		return

	if event.is_action_pressed("ui_cancel"):
		if _active_modal == Modal.BINARY:
			_close_binary_panel()
		elif _active_modal == Modal.WALKIE:
			_close_walkie_panel()
		elif _active_modal != Modal.NONE:
			_close_active_modal()
		elif is_instance_valid(_pause_menu) and _pause_menu.visible:
			_pause_menu.hide_menu()
		elif GameState.phase == GameState.Phase.IN_MATCH:
			if is_instance_valid(_pause_menu):
				_pause_menu.show_menu()
		return

	if event.is_action_pressed("ui_release_mouse"):
		if _active_modal != Modal.NONE:
			_close_active_modal()
		else:
			var capture := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if capture else Input.MOUSE_MODE_CAPTURED
		return

	if _is_input_locked():
		# Any active modal panel captures ALL other input - no look, no
		# jump/destroy/fire (handled in _physics_process), no interact.
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := MOUSE_SENSITIVITY * SettingsManager.mouse_sensitivity
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -1.3, 1.3)

	if event.is_action_pressed("interact"):
		_try_interact()
	elif horror_mode and is_horror_puppet_master:
		# Strings are the PM's innate weapon: fire shoots a string into whoever
		# you're aiming at, or pins a trap to a surface. R ghosts their strings.
		if event.is_action_pressed("fire"):
			_pm_fire_string()
		elif event.is_action_pressed("use_item"):
			_pm_ghost_string()
	elif horror_mode and not is_horror_puppet_master:
		if event.is_action_pressed("use_item"):
			_request_use_item()
		if event.is_action_pressed("drop_item"):
			_request_drop_item()
		for i in range(8):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_request_select_slot(i)
	elif event.is_action_pressed("fire") and has_gun and DebugBuild.enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire_gun()


func _is_input_locked() -> bool:
	return _active_modal != Modal.NONE


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var locked := _is_input_locked() or _eliminated

	if not _eliminated:
		_update_crouch_state()
		if _on_ladder and not locked:
			_is_sprinting = false
			_apply_ladder_velocity()
		else:
			_apply_ground_velocity(delta, locked)

		_tick_authority_stamina(delta)

		if horror_mode and is_horror_puppet_master:
			_pm_controller = get_node_or_null("PuppetMasterController")
			if _pm_controller:
				_pm_controller.call("process_movement", delta, locked)
			if _has_puppet:
				_pm_puppet_grab_tick(delta)

		move_and_slide()

		_update_interact_prompt()
		_process_destroy_hold(delta)
		_process_held_paper(delta)
		if horror_mode:
			_sync_horror_hud_signal()
			_update_phone_led_visuals()


func _apply_ground_velocity(delta: float, locked: bool) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var can_jump := is_on_floor()
	var cheats := get_node_or_null("/root/DebugCheats")
	if cheats and cheats.has_method("infinite_jump_enabled") and bool(cheats.call("infinite_jump_enabled")):
		can_jump = true
	if not locked and Input.is_action_just_pressed("jump") and can_jump:
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if not locked:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_room: int = WorldScale.world_position_to_room_index(global_position)
	var water_level: float = GameState.room_water_levels.get(current_room, 0.0)
	var want_sprint := (not locked) and (not _crouching) and Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	if horror_mode and not sprint_allowed(_local_stamina, _stamina_exhausted):
		want_sprint = false
	# Puppet strings drag you down; being possessed locks you in place.
	if _possessed or _tether_immobilized:
		want_sprint = false
	_is_sprinting = want_sprint
	var effective_speed := move_speed_for(want_sprint, _crouching, water_level)
	if _possessed:
		effective_speed = 0.0
	elif _tether_slow > 0.0:
		effective_speed *= (1.0 - _tether_slow)
	# Walk into a surface-pinned string trap and it snaps onto you.
	if horror_mode and not is_horror_puppet_master:
		_trap_check_accum += delta
		if _trap_check_accum >= 0.3:
			_trap_check_accum = 0.0
			if multiplayer.is_server():
				PuppetStringSystem.server_check_traps(multiplayer.get_unique_id(), global_position)
			else:
				PuppetStringSystem.request_check_traps.rpc_id(1, global_position)

	if direction:
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed
	else:
		velocity.x = move_toward(velocity.x, 0, effective_speed)
		velocity.z = move_toward(velocity.z, 0, effective_speed)


static func move_speed_for(sprinting: bool, crouching: bool = false, water_level: float = 0.0) -> float:
	var speed := SPEED * (1.0 - water_level * 0.6)
	if crouching:
		return speed * 0.55
	if sprinting:
		return speed * SPRINT_MULTIPLIER
	return speed


static func sprint_allowed(stamina: float, exhausted: bool = false) -> bool:
	if exhausted:
		return stamina >= STAMINA_RESUME
	return stamina > STAMINA_EMPTY


func _tick_authority_stamina(delta: float) -> void:
	if not is_multiplayer_authority() or _eliminated or not horror_mode:
		return
	var was_sprinting := _is_sprinting
	_local_stamina = PlayerEffects.tick_stamina(_local_stamina, _is_sprinting, delta)
	if _is_sprinting and _local_stamina <= STAMINA_EMPTY:
		_stamina_exhausted = true
		_is_sprinting = false
	elif _local_stamina >= STAMINA_RESUME:
		_stamina_exhausted = false
	if was_sprinting and not sprint_allowed(_local_stamina, _stamina_exhausted):
		# Empty bar cannot keep the 1.4× bonus for the rest of this frame.
		var water_level: float = GameState.room_water_levels.get(WorldScale.world_position_to_room_index(global_position), 0.0)
		var walk := move_speed_for(false, _crouching, water_level)
		if Vector2(velocity.x, velocity.z).length() > walk + 0.01:
			var planar := Vector3(velocity.x, 0.0, velocity.z)
			if planar.length() > 0.001:
				planar = planar.normalized() * walk
				velocity.x = planar.x
				velocity.z = planar.z
	_refresh_vital_meters()
	_replicate_stamina(delta)


func _refresh_vital_meters() -> void:
	if _neon_hud:
		_neon_hud.set_meters(_local_health, _local_max_health, _local_stamina, _local_fear)


func _replicate_stamina(delta: float) -> void:
	if not horror_mode:
		return
	if multiplayer.is_server():
		PlayerEffects.server_set_sprinting(multiplayer.get_unique_id(), _is_sprinting)
		PlayerEffects.server_set_stamina(multiplayer.get_unique_id(), _local_stamina, false)
		return
	_stamina_sync_accum += delta
	var changed := absf(_local_stamina - _last_synced_stamina) >= 1.0 or _is_sprinting != _last_synced_sprinting
	if _stamina_sync_accum < 0.1 and not changed:
		return
	_stamina_sync_accum = 0.0
	_last_synced_stamina = _local_stamina
	_last_synced_sprinting = _is_sprinting
	PlayerEffects.request_set_stamina.rpc_id(1, _local_stamina, _is_sprinting)


func _apply_ladder_velocity() -> void:
	var climb_dir := Vector3.UP
	if is_instance_valid(_current_ladder):
		climb_dir = _current_ladder.get_climb_up()
	var climb_input := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	velocity = climb_dir * climb_input * CLIMB_SPEED

	if climb_dir.is_equal_approx(Vector3.UP):
		var strafe := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var strafe_dir: Vector3 = transform.basis * Vector3(strafe, 0, 0)
		velocity.x += strafe_dir.x * SPEED * 0.4
		velocity.z += strafe_dir.z * SPEED * 0.4


## Called by Ladder.gd's Area3D when this player's body enters/exits it.
func enter_ladder(ladder: Node) -> void:
	if is_multiplayer_authority():
		_on_ladder = true
		_current_ladder = ladder


func exit_ladder(ladder: Node) -> void:
	if _current_ladder == ladder:
		_on_ladder = false
		_current_ladder = null
		velocity.y = 0.0


func _set_interact_prompt(shown: bool, hint: String = "") -> void:
	if _neon_hud and _neon_hud.has_method("set_interact_prompt"):
		var action := hint if not hint.is_empty() else "INTERACT"
		_neon_hud.call("set_interact_prompt", shown, action, "Look / Talk" if shown else "")
		prompt_label.visible = false
		return
	prompt_label.visible = shown
	if shown:
		prompt_label.text = "[E] %s" % hint


func _update_interact_prompt() -> void:
	if _is_input_locked() or _eliminated:
		_set_highlight(null)
		_set_interact_prompt(false)
		return
	var pickup := _find_world_pickup()
	if pickup:
		var hint: String = pickup.call("get_prompt") if pickup.has_method("get_prompt") else "Pick up item"
		_set_interact_prompt(true, hint)
		return
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if _PATHS.is_ladder(collider) and not collider.is_carried:
			var hint: String = collider.prompt_text
			if collider.is_placed and not collider.is_leaning and not collider.is_leaning_anim:
				hint = "Pick up ladder (place to lean on wall)"
			elif collider.is_leaning:
				hint = collider.prompt_text
			_set_interact_prompt(true, hint)
			_set_highlight(null)
			return
		if _PATHS.is_ladder(collider) and collider.is_carried and collider.carrier_peer_id == multiplayer.get_unique_id():
			_set_interact_prompt(true, "Place ladder")
			return
		if collider.is_in_group("flammable_props") and not collider.get("is_charred"):
			var hint: String = str(collider.get("prompt_text"))
			if collider.has_method("get_display_text") and not collider.get("is_carried"):
				hint = "Read book / pick up"
			_set_interact_prompt(true, hint)
			_set_highlight(null)
			return
		var target: Node = collider if _PATHS.is_interactable(collider) else null
		if target:
			var hint: String = str(target.get("prompt_text"))
			if target.get("destroyable") and not target.get("is_destroyed"):
				hint += "  [hold F: destroy]"
			_set_interact_prompt(true, hint)
			_set_highlight(target)
			return
	_set_highlight(null)
	_set_interact_prompt(false)


func _pickup_is_live(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if bool(node.get("_taken")):
		return false
	if node is Node3D and not (node as Node3D).visible:
		return false
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer == 0:
		return false
	return true


func _find_world_pickup() -> Node:
	if interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		if hit is Node and _pickup_is_live(hit as Node) and (hit as Node).is_in_group("world_pickups"):
			return hit as Node
	if not horror_mode:
		return null
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var best: Node = null
	var best_dist := 2.8
	for node in get_tree().get_nodes_in_group("world_pickups"):
		if not (node is Node3D) or not _pickup_is_live(node):
			continue
		var to: Vector3 = (node as Node3D).global_position - origin
		var dist := to.length()
		if dist > best_dist or dist < 0.05:
			continue
		if forward.dot(to / dist) < 0.15:
			continue
		best_dist = dist
		best = node
	return best


func _try_interact() -> void:
	# Possessed? E is the escape-the-mind struggle, nothing else works.
	if _possessed:
		if multiplayer.is_server():
			PuppetControlSystem.server_struggle(multiplayer.get_unique_id())
		else:
			PuppetControlSystem.request_struggle.rpc_id(1)
		return
	# PM can grab the puppet prop off the ground.
	if horror_mode and is_horror_puppet_master:
		var pm_hit := _find_world_pickup()
		if pm_hit and str(pm_hit.get("item_id")) == "puppet":
			if multiplayer.is_server():
				pm_hit.call("server_try_pickup", multiplayer.get_unique_id())
			else:
				pm_hit.rpc_id(1, "rpc_pm_take")
			return
	if horror_mode and not is_horror_puppet_master:
		var child_pos := ChildSpawnRNG.get_spawn_position()
		if child_pos != Vector3.ZERO and global_position.distance_to(child_pos) < 3.5:
			if multiplayer.is_server():
				if ChildSpawnRNG.server_try_pickup_child(multiplayer.get_unique_id(), global_position):
					_show_objective("Reach the escape zone with the child.")
			else:
				_rpc_try_child_pickup.rpc_id(1, global_position)
			return
		if interact_ray.is_colliding():
			var hit: Object = interact_ray.get_collider()
			if hit and (_PATHS.is_radio_tower(hit) or _PATHS.is_signal_phone(hit)):
				_try_open_signal_slate(hit)
				return

	var ground_item := _find_world_pickup()
	if horror_mode and not is_horror_puppet_master and ground_item and _pickup_is_live(ground_item):
		if multiplayer.is_server():
			ground_item.call("server_try_pickup", multiplayer.get_unique_id())
		else:
			PlayerInventory.request_pickup.rpc_id(1, ground_item.get_path())
		_set_interact_prompt(false)
		return

	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()

	var ladder_target: Node = collider if _PATHS.is_ladder(collider) else null
	if ladder_target:
		ladder_target.interact(multiplayer.get_unique_id())
		return

	if collider.is_in_group("flammable_props") and not collider.get("is_charred"):
		if collider.has_method("get_display_text") and not collider.get("is_carried"):
			_show_toast(collider.call("get_display_text"))
		if collider.has_method("interact"):
			collider.interact(multiplayer.get_unique_id())
		return

	var target: Node = collider if _PATHS.is_interactable(collider) else null
	if not target:
		return

	if _PATHS.is_clue_flame_paper(target) and not target.get("is_picked_up") and not target.get("is_destroyed"):
		target.interact(multiplayer.get_unique_id())
		_held_paper = target
		_paper_reveal_progress = 0.0
		_paper_burn_progress = 0.0
		_paper_revealed = false
		_show_toast("Picked up the paper. Find a flame to read it - but don't get too close.")
		return

	if _PATHS.is_gun(target) and not target.get("is_picked_up"):
		if not DebugBuild.enabled:
			_show_toast("Nothing useful here.")
			return
		target.interact(multiplayer.get_unique_id())
		has_gun = true
		_show_toast("Picked up a gun. (TEST ONLY)")
		return

	if _PATHS.is_gun(target):
		return

	target.interact(multiplayer.get_unique_id())

	if _PATHS.is_phone(target):
		_open_phone_panel()
	elif _PATHS.is_code_keypad(target):
		_open_keypad_panel(int(target.get("room_index")))
	elif target.has_method("get_display_text"):
		_show_toast(target.call("get_display_text"))


# --- Hold-to-destroy ------------------------------------------------------

func _process_destroy_hold(delta: float) -> void:
	if _is_input_locked() or not interact_ray.is_colliding():
		_cancel_destroy_hold()
		return

	var target: Node = interact_ray.get_collider() if _PATHS.is_interactable(interact_ray.get_collider()) else null
	if not target or not target.get("destroyable") or target.get("is_destroyed"):
		_cancel_destroy_hold()
		return

	if _PATHS.is_security_camera(target) and global_position.y < float(target.get("min_elevation_y")):
		_cancel_destroy_hold()
		return

	if not Input.is_action_pressed("destroy"):
		_cancel_destroy_hold()
		return

	if _destroy_target != target:
		_destroy_target = target
		_destroy_hold_time = 0.0

	_destroy_hold_time += delta
	destroy_progress_bar.visible = true
	destroy_progress_bar.value = clampf(_destroy_hold_time / DESTROY_HOLD_DURATION, 0.0, 1.0) * 100.0

	if _destroy_hold_time >= DESTROY_HOLD_DURATION:
		target.call("request_destroy", multiplayer.get_unique_id())
		_cancel_destroy_hold()


func _cancel_destroy_hold() -> void:
	_destroy_target = null
	_destroy_hold_time = 0.0
	destroy_progress_bar.visible = false


# --- Held clue paper: flame reveal / burn ---------------------------------

func _process_held_paper(delta: float) -> void:
	if not is_instance_valid(_held_paper) or _held_paper.get("is_destroyed"):
		_held_paper = null
		holding_label.visible = false
		return

	holding_label.visible = true
	holding_label.text = "Holding: Paper" + (" (code revealed)" if _paper_revealed else "")

	var nearest_dist := INF
	for flame in get_tree().get_nodes_in_group("flames"):
		var d: float = flame.global_position.distance_to(global_position)
		if d < nearest_dist:
			nearest_dist = d

	if nearest_dist <= PAPER_BURN_RADIUS:
		_paper_reveal_progress = 0.0
		_paper_burn_progress += delta
		if _paper_burn_progress >= PAPER_BURN_TIME:
			var burnt := _held_paper
			_held_paper = null
			holding_label.visible = false
			burnt.call("request_destroy", multiplayer.get_unique_id())
			_show_toast("The paper caught fire! You lost the clue.")
		else:
			_show_toast("Too close to the flame! (%d%%)" % roundi(_paper_burn_progress / PAPER_BURN_TIME * 100.0))
	elif nearest_dist <= PAPER_REVEAL_RADIUS:
		_paper_burn_progress = 0.0
		if not _paper_revealed:
			_paper_reveal_progress += delta
			if _paper_reveal_progress >= PAPER_REVEAL_TIME:
				_paper_revealed = true
				_show_toast("The code appears on the paper: %s" % str(_held_paper.get("revealed_code")))
	else:
		_paper_reveal_progress = 0.0
		_paper_burn_progress = 0.0


# --- Test-only gun (REMOVE BEFORE FULL RELEASE) ---------------------------

## --- Puppet Master: strings + puppet ---

func _on_puppet_state(active: bool) -> void:
	_has_puppet = active
	if active:
		_show_toast("You are wearing the puppet — walk into a survivor to seize them.")


## Raycast from the PM camera; returns {"hit": bool, "collider": Node, "pos": Vector3}.
func _pm_camera_hit(max_dist: float = 40.0) -> Dictionary:
	var cam := camera
	if cam == null:
		return {"hit": false}
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * max_dist
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return {"hit": false}
	return {"hit": true, "collider": hit.get("collider"), "pos": hit.get("position", to)}


func _pm_fire_string() -> void:
	var aim := _pm_camera_hit()
	if not aim.get("hit", false):
		return
	var col: Object = aim.get("collider")
	var victim := _peer_from_node(col)
	if victim > 0 and victim != multiplayer.get_unique_id():
		if multiplayer.is_server():
			PuppetStringSystem.server_shoot_string(multiplayer.get_unique_id(), victim)
		else:
			PuppetStringSystem.request_shoot.rpc_id(1, victim)
	else:
		# Aimed at the world — pin a trap there.
		if multiplayer.is_server():
			PuppetStringSystem.server_place_trap(multiplayer.get_unique_id(), aim.get("pos"))
		else:
			PuppetStringSystem.request_trap.rpc_id(1, aim.get("pos"))


func _pm_ghost_string() -> void:
	var aim := _pm_camera_hit()
	var victim := _peer_from_node(aim.get("collider")) if aim.get("hit", false) else -1
	if victim <= 0:
		return
	if multiplayer.is_server():
		PuppetStringSystem.server_make_ghost(multiplayer.get_unique_id(), victim)
	else:
		PuppetStringSystem.request_ghost.rpc_id(1, victim)


func _pm_puppet_grab_tick(delta: float) -> void:
	_grab_check_accum += delta
	if _grab_check_accum < 0.25:
		return
	_grab_check_accum = 0.0
	var nearest := -1
	var nearest_d := PuppetControlSystem.GRAB_RANGE
	for node in get_tree().get_nodes_in_group("players"):
		var pid := _peer_from_node(node)
		if pid <= 0 or pid == multiplayer.get_unique_id():
			continue
		var d := global_position.distance_to((node as Node3D).global_position)
		if d <= nearest_d:
			nearest_d = d
			nearest = pid
	if nearest > 0:
		if multiplayer.is_server():
			PuppetControlSystem.server_puppet_grab(multiplayer.get_unique_id(), nearest, nearest_d)
		else:
			PuppetControlSystem.request_grab.rpc_id(1, nearest, nearest_d)


func _peer_from_node(node: Object) -> int:
	if node == null or not (node is Node):
		return -1
	if not (node as Node).is_in_group("players"):
		return -1
	return str((node as Node).name).to_int()


func _fire_gun() -> void:
	if multiplayer.is_server():
		_spawn_test_projectile()
	else:
		_rpc_fire_projectile.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_fire_projectile() -> void:
	if not multiplayer.is_server():
		return
	_spawn_test_projectile()


func _spawn_test_projectile() -> void:
	var proj: Node = _TEST_PROJECTILE_SCRIPT.new()
	var world := get_node_or_null("/root/Main/World")
	if world:
		world.add_child(proj)
	else:
		get_tree().root.add_child(proj)
	var dir := -camera.global_transform.basis.z.normalized()
	proj.call("launch", camera.global_position + dir * 0.3, dir)


func _on_faction_assigned(faction_id_in: String) -> void:
	var faction_name: String = FactionData.get_faction_name(faction_id_in)
	var color: Color = FactionData.get_faction_color(faction_id_in)
	faction_label.text = "Faction: %s" % faction_name
	faction_label.add_theme_color_override("font_color", color)


# --- Modal panel management -------------------------------------------

func _close_active_modal() -> void:
	match _active_modal:
		Modal.PHONE:
			_close_phone_panel()
		Modal.KEYPAD:
			_close_keypad_panel()
		Modal.BINARY:
			_close_binary_panel()
		Modal.WALKIE:
			_close_walkie_panel()


func _open_phone_panel() -> void:
	if horror_mode and not TowerRules.can_use_signal(global_position, _holding_phone(), false):
		_show_toast("The line is dead here. Find a live mast.")
		return
	_active_modal = Modal.PHONE
	phone_panel.visible = true
	rename_row.visible = false
	phone_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_contacts_list()


func _try_open_signal_slate(target: Node) -> void:
	var at_tower: bool = _PATHS.is_radio_tower(target)
	if at_tower and not bool(target.get("is_tower_active")):
		_show_toast("The mast is silent.")
		return
	if not TowerRules.can_use_signal(global_position, _holding_phone(), at_tower):
		_show_toast("The scratch won't carry. Stay near a live mast.")
		return
	if target.has_method("interact"):
		target.interact(multiplayer.get_unique_id())
	_active_modal = Modal.PHONE
	phone_panel.visible = true
	rename_row.visible = false
	phone_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_contacts_list()


func _holding_phone() -> bool:
	for slot in _inventory_slots:
		if str(slot) == "phone":
			return true
	return false


func _close_phone_panel() -> void:
	_active_modal = Modal.NONE
	phone_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_highlight(target: Node) -> void:
	if _highlight_target == target:
		return
	if _highlight_target and _PATHS.is_interactable(_highlight_target):
		_highlight_target.call("set_highlighted", false)
	_highlight_target = target
	if target and _PATHS.is_interactable(target):
		target.call("set_highlighted", true)


func _update_crouch_state() -> void:
	if not is_multiplayer_authority() or _on_ladder:
		return
	var want := Input.is_action_pressed("crouch") and is_on_floor()
	if want == _crouching:
		return
	_crouching = want
	var shape := $CollisionShape3D.shape as CapsuleShape3D
	shape.height = WorldScale.PLAYER_CROUCH_HEIGHT if _crouching else WorldScale.PLAYER_HEIGHT
	$CollisionShape3D.position.y = shape.height * 0.5
	head.position.y = WorldScale.PLAYER_EYE_CROUCH if _crouching else WorldScale.PLAYER_EYE_STAND


func open_walkie_panel() -> void:
	if horror_mode or _walkie_panel == null:
		_show_toast("The old masts carry the scratch now.")
		return
	_active_modal = Modal.WALKIE
	_walkie_panel.visible = true
	if multiplayer.is_server():
		_walkie_partner_label.text = "Partner: %s" % WalkieSystem.server_get_partner_label(multiplayer.get_unique_id())
	else:
		_walkie_partner_label.text = "Partner: faction channel"
	_walkie_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_walkie_panel() -> void:
	_active_modal = Modal.NONE
	if _walkie_panel:
		_walkie_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_walkie_panel() -> void:
	_walkie_panel = Panel.new()
	_walkie_panel.name = "WalkiePanel"
	_walkie_panel.visible = false
	_walkie_panel.set_anchors_preset(Control.PRESET_CENTER)
	_walkie_panel.custom_minimum_size = Vector2(340, 260)
	_walkie_panel.position = Vector2(-170, -130)
	hud.add_child(_walkie_panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_walkie_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Walkie-talkie (faction pair)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_walkie_partner_label = Label.new()
	_walkie_partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_walkie_partner_label)
	_walkie_log = RichTextLabel.new()
	_walkie_log.custom_minimum_size = Vector2(0, 120)
	_walkie_log.bbcode_enabled = true
	vbox.add_child(_walkie_log)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	_walkie_input = LineEdit.new()
	_walkie_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_walkie_input.placeholder_text = "Push message to partner..."
	_walkie_input.max_length = 140
	row.add_child(_walkie_input)
	var send := Button.new()
	send.text = "Send"
	send.pressed.connect(_on_walkie_send_pressed)
	row.add_child(send)
	var close_btn := Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.pressed.connect(_close_walkie_panel)
	vbox.add_child(close_btn)


func _on_walkie_send_pressed() -> void:
	var message := _walkie_input.text.strip_edges()
	if message.is_empty():
		return
	if multiplayer.is_server():
		WalkieSystem.server_handle_send_text(multiplayer.get_unique_id(), message)
	else:
		WalkieSystem.request_send_text.rpc_id(1, message)
	_walkie_input.text = ""


func _on_walkie_received(from_label: String, message: String) -> void:
	if _walkie_log:
		_walkie_log.append_text("[b]%s:[/b] %s\n" % [from_label, message])
	if not horror_mode:
		_show_toast("Walkie: %s" % message)


func _on_walkie_sent() -> void:
	if _walkie_log:
		_walkie_log.append_text("[i]-- sent to partner --[/i]\n")


func _on_phone_send_pressed() -> void:
	var message := phone_input.text.strip_edges()
	if message.is_empty():
		return
	if horror_mode and not TowerRules.can_use_signal(global_position, _holding_phone(), _near_active_tower()):
		_show_toast("The scratch faded. Stay near a live mast.")
		return
	if multiplayer.is_server():
		PhoneSystem.server_handle_send_text(multiplayer.get_unique_id(), message)
	else:
		PhoneSystem.request_send_text.rpc_id(1, message)
	phone_input.text = ""


func _near_active_tower() -> bool:
	for node in get_tree().get_nodes_in_group("active_towers"):
		if node is Node3D and global_position.distance_to((node as Node3D).global_position) < 4.0:
			return true
	return false


func _on_text_received(from_label: String, message: String) -> void:
	ContactBook.note_line_seen(from_label)
	var display_name := ContactBook.get_display_name(from_label)
	phone_log.append_text("[b]%s:[/b] %s\n" % [display_name, message])


func _on_text_sent_confirmation() -> void:
	if horror_mode:
		phone_log.append_text("[i]-- mark left on the slate --[/i]\n")
	else:
		phone_log.append_text("[i]-- sent into the unknown --[/i]\n")


## Rebuilds the clickable contacts list. Each contact is a focusable
## Button (mouse click OR keyboard/gamepad focus+confirm both work) -
## pressing one opens the rename row for that line.
func _refresh_contacts_list() -> void:
	for child in contacts_box.get_children():
		child.queue_free()

	for line_id in ContactBook.get_known_line_ids():
		var button := Button.new()
		button.text = "%s  (%s)" % [ContactBook.get_display_name(line_id), line_id]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func(): _start_rename(line_id))
		contacts_box.add_child(button)


func _start_rename(line_id: String) -> void:
	_renaming_line_id = line_id
	rename_row.visible = true
	rename_input.text = ContactBook.get_display_name(line_id)
	rename_input.grab_focus()
	rename_input.select_all()


func _on_rename_confirm_pressed() -> void:
	if _renaming_line_id.is_empty():
		return
	ContactBook.set_nickname(_renaming_line_id, rename_input.text)
	rename_row.visible = false
	_renaming_line_id = ""
	_refresh_contacts_list()


func _on_rename_cancel_pressed() -> void:
	rename_row.visible = false
	_renaming_line_id = ""


# --- Code keypad (physical digit buttons) --------------------------------

func _open_keypad_panel(room_index: int) -> void:
	_keypad_room_index = room_index
	_active_modal = Modal.KEYPAD
	keypad_panel.visible = true
	keypad_feedback.text = ""
	_keypad_digits = ""
	keypad_display.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_keypad_panel() -> void:
	_active_modal = Modal.NONE
	keypad_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_binary_panel() -> void:
	_binary_panel = Panel.new()
	_binary_panel.name = "BinaryPanel"
	_binary_panel.visible = false
	_binary_panel.set_anchors_preset(Control.PRESET_CENTER)
	_binary_panel.custom_minimum_size = Vector2(320, 280)
	_binary_panel.position = Vector2(-160, -140)
	hud.add_child(_binary_panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_binary_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Binary terminal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_binary_target_label = Label.new()
	_binary_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_binary_target_label)
	_binary_bits_label = Label.new()
	_binary_bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_binary_bits_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_binary_bits_label)
	var grid := GridContainer.new()
	grid.columns = 4
	vbox.add_child(grid)
	for i in range(8):
		var btn := Button.new()
		btn.text = "Bit %d" % i
		btn.pressed.connect(func(): _on_binary_bit_pressed(i))
		grid.add_child(btn)
	_binary_feedback_label = Label.new()
	_binary_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_binary_feedback_label)
	var close_btn := Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.pressed.connect(_close_binary_panel)
	vbox.add_child(close_btn)


func open_binary_terminal(terminal: Node) -> void:
	_binary_terminal = terminal
	_active_modal = Modal.BINARY
	_binary_panel.visible = true
	_update_binary_display(int(terminal.get("target_value")), str(terminal.get("bit_string")))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func apply_binary_flip_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_binary_feedback_label.text = str(result.get("error", "Error"))
		return
	if is_instance_valid(_binary_terminal):
		_binary_terminal.set("bit_string", result.get("bits", _binary_terminal.get("bit_string")))
	_update_binary_display(int(_binary_terminal.get("target_value")), str(_binary_terminal.get("bit_string")))
	if result.get("solved", false):
		_binary_feedback_label.text = "Access granted!"
		_show_toast("Terminal unlocked — bookcase moved, monitor online.")
	else:
		var val := int(result.get("value", 0))
		_binary_feedback_label.text = "= %d (need %d)" % [val, int(_binary_terminal.get("target_value"))]


func _update_binary_display(target: int, bits: String) -> void:
	_binary_target_label.text = "Target decimal: %d" % target
	_binary_bits_label.text = bits
	_binary_feedback_label.text = ""


func _on_binary_bit_pressed(bit_index: int) -> void:
	if not is_instance_valid(_binary_terminal):
		return
	if multiplayer.is_server():
		var result: Dictionary = _binary_terminal.call("server_flip_bit", bit_index)
		apply_binary_flip_result(result)
	else:
		_binary_terminal.request_flip_bit.rpc_id(1, bit_index)


func _close_binary_panel() -> void:
	_active_modal = Modal.NONE
	_binary_terminal = null
	if _binary_panel:
		_binary_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_keypad_digit_pressed(digit: String) -> void:
	if _keypad_digits.length() < 8:
		_keypad_digits += digit
		keypad_display.text = _keypad_digits


func _on_keypad_backspace_pressed() -> void:
	if _keypad_digits.length() > 0:
		_keypad_digits = _keypad_digits.substr(0, _keypad_digits.length() - 1)
		keypad_display.text = _keypad_digits


func _on_keypad_clear_pressed() -> void:
	_keypad_digits = ""
	keypad_display.text = ""


func _on_keypad_submit_pressed() -> void:
	if _keypad_digits.is_empty() or _keypad_room_index == -1:
		return
	if multiplayer.is_server():
		PuzzleSystem.server_handle_attempt(multiplayer.get_unique_id(), _keypad_room_index, _keypad_digits)
	else:
		PuzzleSystem.request_attempt_unlock.rpc_id(1, _keypad_room_index, _keypad_digits)


func _on_unlock_result(room_index: int, success: bool) -> void:
	if room_index != _keypad_room_index:
		return
	keypad_feedback.text = "Unlocked!" if success else "Wrong code."
	if success:
		keypad_feedback.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		keypad_feedback.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func _on_escape_locked(feedback: String) -> void:
	_show_toast(feedback)


# --- Puppet Master camera / sabotage panel ------------------------------

func _on_you_are_puppet_master(camera_targets: Array, eliminable_targets: Array) -> void:
	camera_panel.visible = true
	for child in camera_feed_box.get_children():
		child.queue_free()

	for i in range(camera_targets.size()):
		var room_index: int = camera_targets[i]
		camera_feed_box.add_child(_build_camera_feed(room_index, i))

	# Elimination isn't limited to the camera-equipped rooms (see
	# PuppetMasterSystem) - list every other target with just a kill
	# button so "eliminate everyone" is actually achievable.
	var other_targets: Array = eliminable_targets.filter(func(r): return not camera_targets.has(r))
	if not other_targets.is_empty():
		camera_feed_box.add_child(_build_other_targets_panel(other_targets))


func _build_camera_feed(room_index: int, slot_index: int) -> Control:
	var box := VBoxContainer.new()

	var label := Label.new()
	label.text = "Feed %s" % char(65 + slot_index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(200, 130)
	viewport_container.stretch = true
	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(200, 130)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var feed_camera := Camera3D.new()
	feed_camera.position = WorldScale.room_grid_position(room_index) + Vector3(0, 5.5, 0)
	feed_camera.rotation_degrees = Vector3(-75, 0, 0)
	feed_camera.current = true
	sub_viewport.add_child(feed_camera)
	viewport_container.add_child(sub_viewport)
	box.add_child(viewport_container)

	var button_row := HBoxContainer.new()
	var sabotage_button := Button.new()
	sabotage_button.text = "Sabotage"
	sabotage_button.pressed.connect(func(): _request_sabotage(room_index))
	var eliminate_button := Button.new()
	eliminate_button.text = "Eliminate"
	eliminate_button.pressed.connect(func(): _request_eliminate(room_index))
	button_row.add_child(sabotage_button)
	button_row.add_child(eliminate_button)
	box.add_child(button_row)

	return box


func _build_other_targets_panel(room_indices: Array) -> Control:
	var box := VBoxContainer.new()

	var label := Label.new()
	label.text = "No feed"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	for room_index in room_indices:
		var eliminate_button := Button.new()
		eliminate_button.text = "Eliminate room %d" % room_index
		eliminate_button.pressed.connect(func(): _request_eliminate(room_index))
		box.add_child(eliminate_button)

	return box


func _request_sabotage(room_index: int) -> void:
	if multiplayer.is_server():
		PuppetMasterSystem.server_handle_sabotage(multiplayer.get_unique_id(), room_index)
	else:
		PuppetMasterSystem.request_sabotage.rpc_id(1, room_index)


func _request_eliminate(room_index: int) -> void:
	if multiplayer.is_server():
		PuppetMasterSystem.server_handle_eliminate(multiplayer.get_unique_id(), room_index)
	else:
		PuppetMasterSystem.request_eliminate.rpc_id(1, room_index)


func _on_sabotage_result(_room_index: int, success: bool) -> void:
	_show_toast("Sabotage sent." if success else "Sabotage failed.")


func _on_you_were_eliminated() -> void:
	apply_eliminated_visual()


## Called on the LOCAL client when this player is eliminated, and on
## EVERY client (including remote ones) via PuppetMasterSystem's public
## broadcast, so the model visibly goes down for everyone.
func apply_eliminated_visual() -> void:
	if _eliminated:
		return
	_eliminated = true
	_spectating = false
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		phone_panel.visible = false
		keypad_panel.visible = false
		_set_interact_prompt(false)
		destroy_progress_bar.visible = false
		if is_instance_valid(_pause_menu) and _pause_menu.visible:
			if _pause_menu.has_method("dismiss_for_exit"):
				_pause_menu.dismiss_for_exit()
			else:
				_pause_menu.visible = false
				get_tree().paused = false
		_show_lose_overlay()


func _wire_lose_overlay() -> void:
	if eliminated_overlay == null:
		return
	_ensure_lose_buttons()
	var exit_btn := eliminated_overlay.get_node_or_null("ButtonRow/ExitButton") as Button
	var spec_btn := eliminated_overlay.get_node_or_null("ButtonRow/SpectateButton") as Button
	if exit_btn and not exit_btn.pressed.is_connected(_on_lose_exit_pressed):
		exit_btn.pressed.connect(_on_lose_exit_pressed)
	if spec_btn and not spec_btn.pressed.is_connected(_on_lose_spectate_pressed):
		spec_btn.pressed.connect(_on_lose_spectate_pressed)


func _ensure_lose_buttons() -> void:
	if eliminated_overlay == null:
		return
	var title := eliminated_overlay.get_node_or_null("Label") as Label
	if title:
		title.text = "YOU LOST"
		title.offset_top = -90
		title.offset_bottom = -30
	var sub := eliminated_overlay.get_node_or_null("SubLabel") as Label
	if sub == null:
		sub = Label.new()
		sub.name = "SubLabel"
		eliminated_overlay.add_child(sub)
		sub.set_anchors_preset(Control.PRESET_CENTER)
		sub.offset_left = -240
		sub.offset_top = -24
		sub.offset_right = 240
		sub.offset_bottom = 16
	sub.text = "The neighborhood keeps moving without you."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.78, 0.74, 0.68, 1))
	var row := eliminated_overlay.get_node_or_null("ButtonRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "ButtonRow"
		eliminated_overlay.add_child(row)
		row.set_anchors_preset(Control.PRESET_CENTER)
		row.offset_left = -200
		row.offset_top = 36
		row.offset_right = 200
		row.offset_bottom = 88
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var exit_btn := row.get_node_or_null("ExitButton") as Button
	if exit_btn == null:
		exit_btn = Button.new()
		exit_btn.name = "ExitButton"
		row.add_child(exit_btn)
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(180, 46)
	var spec_btn := row.get_node_or_null("SpectateButton") as Button
	if spec_btn == null:
		spec_btn = Button.new()
		spec_btn.name = "SpectateButton"
		row.add_child(spec_btn)
	spec_btn.text = "SPECTATE"
	spec_btn.custom_minimum_size = Vector2(180, 46)
	var theme: GDScript = load("res://scripts/horror/ui/vouch_menu_theme.gd")
	if theme:
		theme.call("apply_action_button", exit_btn, "blood")
		theme.call("apply_action_button", spec_btn, "gold")


func _show_lose_overlay() -> void:
	_ensure_lose_buttons()
	eliminated_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _handle_eliminated_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _spectating:
			_spectating = false
			_show_lose_overlay()
		return
	if not _spectating:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := MOUSE_SENSITIVITY * SettingsManager.mouse_sensitivity
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -1.3, 1.3)


func _on_lose_exit_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.request_return_to_lobby()


func _on_lose_spectate_pressed() -> void:
	_spectating = true
	eliminated_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_toast("Spectating — Esc returns to the end screen.")


# --- Toast (brief on-screen text for clue reveals, lock feedback, ...) --

func _show_objective(text: String) -> void:
	if _neon_hud and _neon_hud.has_method("show_objective"):
		_neon_hud.call("show_objective", text, 5.0)
		return
	_show_toast(text)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start(TOAST_DURATION)


func _on_toast_timer_timeout() -> void:
	toast_label.visible = false


# --- Horror mode: neon HUD + phone signal --------------------------------

func _build_horror_hud() -> void:
	if not horror_mode:
		_health_bar = ProgressBar.new()
		_health_bar.name = "HealthBar"
		_health_bar.visible = false
		hud.add_child(_health_bar)
		return
	_style_horror_phone_panel()
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	_neon_hud = hud_script.new()
	hud.add_child(_neon_hud)
	_neon_hud.set_meters(100.0, 100.0, 100.0, 0.0)
	_attach_phone_rig()
	if is_horror_puppet_master:
		_neon_hud.call("set_steal", false, 0.0, 1.0)
	_show_objective(
		"Hunt the survivors before they escape." if is_horror_puppet_master
		else "Find the missing child — bring her home."
	)
	faction_label.visible = false
	prompt_label.visible = false
	var cross := hud.get_node_or_null("CrosshairLabel") as Label
	if cross:
		cross.visible = false


func _style_horror_phone_panel() -> void:
	var title := phone_panel.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title:
		title.text = "Unknown line"
		title.add_theme_color_override("font_color", Color(0.2, 0.92, 1.0))
	var sub := phone_panel.get_node_or_null("VBoxContainer/SubLabel") as Label
	if sub:
		sub.text = "You'll never know who hears the scratch — or who leaves one for you."
	phone_input.placeholder_text = "Scratch a short note..."
	var send := phone_panel.get_node_or_null("VBoxContainer/ComposeRow/SendButton") as Button
	if send:
		send.text = "Leave mark"
	var contacts := phone_panel.get_node_or_null("VBoxContainer/ContactsLabel") as Label
	if contacts:
		contacts.text = "Lines you remember — rename one for yourself only"


func _on_local_health_changed(hp: float, cap: float) -> void:
	_local_health = hp
	_local_max_health = cap
	_refresh_vital_meters()


func _on_local_meters_changed(hp: float, stamina: float, fear: float) -> void:
	_local_health = hp
	_local_fear = fear
	# Owning peer already ticks sprint drain/regen; don't let the 10 Hz
	# PlayerEffects broadcast rewind the live yellow bar.
	if not is_multiplayer_authority():
		_local_stamina = stamina
	_refresh_vital_meters()
	if _neon_hud:
		_sync_horror_hud_signal()


func _on_local_phone_state(_battery: float, _led_on: bool, _has_phone: bool) -> void:
	_sync_horror_hud_signal()
	_update_phone_led_visuals()


func _on_local_tether(strings: int, _ghost: bool, immobilized: bool) -> void:
	_tether_immobilized = immobilized
	if immobilized:
		_tether_slow = PuppetStringSystem.IMMOBILIZE_SLOW
	elif strings > 0:
		_tether_slow = minf(float(strings) * PuppetStringSystem.SLOW_PER_STRING, PuppetStringSystem.MAX_SLOW)
	else:
		_tether_slow = 0.0
	if _neon_hud and _neon_hud.has_method("set_tether"):
		_neon_hud.call("set_tether", strings, immobilized)


func _on_local_possessed(possessed: bool, struggle: float, needed: float) -> void:
	_possessed = possessed
	if possessed:
		_show_toast("The puppet has you! Mash E to escape your mind (%d/%d)." % [int(struggle), int(needed)])
	if _neon_hud and _neon_hud.has_method("set_possessed"):
		_neon_hud.call("set_possessed", possessed, struggle, needed)


func _sync_horror_hud_signal() -> void:
	if _neon_hud == null:
		return
	var band := TowerRules.signal_band(global_position)
	_neon_hud.set_tower_strength(TowerRules.nearest_tower_strength(global_position))
	_neon_hud.set_signal_band(band)
	_neon_hud.set_phone_device(_holding_phone(), PhoneDevice.local_battery, PhoneDevice.local_led_on)
	_neon_hud.set_utility_flags(_crouching, _local_fear >= 70.0)


func _attach_phone_rig() -> void:
	if camera == null or camera.get_node_or_null("PhoneRig") != null:
		return
	var vis_script: GDScript = load("res://scripts/horror/items/smartphone_visual.gd")
	_phone_rig = Node3D.new()
	_phone_rig.name = "PhoneRig"
	camera.add_child(_phone_rig)
	_phone_rig.position = Vector3(0.16, -0.14, -0.28)
	_phone_rig.rotation_degrees = Vector3(12, -22, 8)
	_held_phone = vis_script.attach(_phone_rig, true)
	_phone_rig.visible = false

	_phone_led_spot = SpotLight3D.new()
	_phone_led_spot.name = "PhoneLED"
	_phone_led_spot.light_color = Color(1.0, 0.96, 0.88)
	_phone_led_spot.light_energy = 0.0
	_phone_led_spot.spot_range = 14.0
	_phone_led_spot.spot_angle = 26.0
	_phone_led_spot.shadow_enabled = false
	camera.add_child(_phone_led_spot)

	_phone_led_omni = OmniLight3D.new()
	_phone_led_omni.name = "PhoneLEDGlow"
	_phone_led_omni.light_color = Color(1.0, 0.94, 0.8)
	_phone_led_omni.light_energy = 0.0
	_phone_led_omni.omni_range = 1.4
	camera.add_child(_phone_led_omni)
	_phone_led_omni.position = Vector3(0.06, -0.05, -0.1)


func _update_phone_led_visuals() -> void:
	var holding := _holding_phone()
	var selected := _selected_item_id() == "phone"
	var led := holding and PhoneDevice.local_led_on and PhoneDevice.local_battery >= 1.0
	if _phone_rig:
		_phone_rig.visible = selected
	if _held_phone:
		var vis_script: GDScript = load("res://scripts/horror/items/smartphone_visual.gd")
		vis_script.update_screen(_held_phone, PhoneDevice.local_battery, TowerRules.signal_band(global_position), led)
	if _phone_led_spot:
		_phone_led_spot.light_energy = 3.2 if led else 0.0
		_phone_led_spot.visible = led
	if _phone_led_omni:
		_phone_led_omni.light_energy = 0.85 if led else 0.0
		_phone_led_omni.visible = led


func _selected_item_id() -> String:
	if _inventory_selected < 0 or _inventory_selected >= _inventory_slots.size():
		return ""
	return str(_inventory_slots[_inventory_selected])


@rpc("any_peer", "call_remote", "reliable")
func _rpc_try_child_pickup(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if ChildSpawnRNG.server_try_pickup_child(sender, pos):
		pass


func _on_local_inventory_changed(slots: Array, selected: int) -> void:
	_inventory_slots = slots
	_inventory_selected = selected
	_refresh_hotbar()
	_sync_horror_hud_signal()
	_update_phone_led_visuals()


func _refresh_hotbar() -> void:
	if _neon_hud:
		_neon_hud.set_hotbar(_inventory_slots, _inventory_selected)
		return
	for i in range(mini(_hotbar_labels.size(), 8)):
		var item := ""
		if i < _inventory_slots.size():
			item = str(_inventory_slots[i])
		var prefix := ">" if i == _inventory_selected else ""
		_hotbar_labels[i].text = "%s[%d] %s" % [prefix, i + 1, item if not item.is_empty() else "-"]


func _request_use_item() -> void:
	if multiplayer.is_server():
		PlayerInventory.request_use_selected()
	else:
		PlayerInventory.request_use_selected.rpc_id(1)


func _request_drop_item() -> void:
	if multiplayer.is_server():
		PlayerInventory.request_drop_selected()
	else:
		PlayerInventory.request_drop_selected.rpc_id(1)


func _request_select_slot(index: int) -> void:
	if multiplayer.is_server():
		PlayerInventory.server_set_selected(multiplayer.get_unique_id(), index)
	else:
		PlayerInventory.request_select_slot.rpc_id(1, index)
