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
## rename), code keypad, Puppet Master camera/sabotage panel, and the
## eliminated overlay. Any modal panel (phone/keypad) sets `_active_modal`
## which fully locks movement/look/jump - see `_is_input_locked()`.
##
## TODO(post-MVP): server-side movement validation/anti-cheat, footstep
## audio, ragdoll/animation, proper first-person arms model.

enum Modal { NONE, PHONE, KEYPAD }

const SPEED: float = 4.5
const JUMP_VELOCITY: float = 4.0
const MOUSE_SENSITIVITY: float = 0.0025
const TOAST_DURATION: float = 4.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hud: CanvasLayer = $HUD
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var faction_label: Label = $HUD/FactionLabel

@onready var phone_panel: Control = $HUD/PhonePanel
@onready var phone_input: LineEdit = $HUD/PhonePanel/VBoxContainer/PhoneInput
@onready var phone_log: RichTextLabel = $HUD/PhonePanel/VBoxContainer/PhoneLog
@onready var known_lines_box: VBoxContainer = $HUD/PhonePanel/VBoxContainer/KnownLinesScroll/KnownLinesBox

@onready var keypad_panel: Control = $HUD/KeypadPanel
@onready var keypad_input: LineEdit = $HUD/KeypadPanel/VBoxContainer/KeypadInput
@onready var keypad_feedback: Label = $HUD/KeypadPanel/VBoxContainer/KeypadFeedback

@onready var camera_panel: Control = $HUD/CameraPanel
@onready var camera_feed_box: HBoxContainer = $HUD/CameraPanel/FeedBox

@onready var toast_label: Label = $HUD/ToastLabel
@onready var toast_timer: Timer = $HUD/ToastLabel/ToastTimer

@onready var eliminated_overlay: Control = $HUD/EliminatedOverlay

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _active_modal: Modal = Modal.NONE
var _eliminated: bool = false
var _keypad_room_index: int = -1

## Set by NetworkManager/Match director's spawn_function before this node
## is added to the tree. Purely informational in MVP - see the note in
## docs/MVP_GDD.md about why we deliberately do NOT tint remote players by
## faction color (that would leak the mystery/social-deduction info).
var faction_id: String = ""


func _ready() -> void:
	add_to_group("players")

	# Authority is set by Match._spawn_player() before this node is added
	# to the tree (required so the MultiplayerSynchronizer child spawns
	# correctly) - by the time _ready() runs here it's already correct.
	if is_multiplayer_authority():
		camera.current = true
		hud.visible = true
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

		if not GameState.local_faction_id.is_empty():
			_on_faction_assigned(GameState.local_faction_id)
		if GameState.local_is_puppet_master:
			faction_label.text = "PUPPET MASTER"
			faction_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.85))
	else:
		camera.current = false
		hud.visible = false
		set_process_unhandled_input(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or _eliminated:
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
		# jump (handled in _physics_process), no interact/destroy.
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.3, 1.3)

	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("destroy"):
		_try_destroy()


func _is_input_locked() -> bool:
	return _active_modal != Modal.NONE


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var locked := _is_input_locked() or _eliminated

	if not locked and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if not locked:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	if not _eliminated:
		_update_interact_prompt()


func _update_interact_prompt() -> void:
	if _is_input_locked():
		prompt_label.visible = false
		return
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider() as Interactable
		if target:
			var hint := target.prompt_text
			if target.destroyable and not target.is_destroyed:
				hint += "  [F: destroy]"
			prompt_label.text = "[E] %s" % hint
			prompt_label.visible = true
			return
	prompt_label.visible = false


func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var target := interact_ray.get_collider() as Interactable
	if not target:
		return

	target.interact(multiplayer.get_unique_id())

	if target is Phone:
		_open_phone_panel()
	elif target is CodeKeypad:
		_open_keypad_panel(target.room_index)
	elif target.has_method("get_display_text"):
		_show_toast(target.get_display_text())


func _try_destroy() -> void:
	if not interact_ray.is_colliding():
		return
	var target := interact_ray.get_collider() as Interactable
	if target and target.destroyable and not target.is_destroyed:
		target.request_destroy(multiplayer.get_unique_id())


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


func _open_phone_panel() -> void:
	_active_modal = Modal.PHONE
	phone_panel.visible = true
	phone_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_phone_panel() -> void:
	_active_modal = Modal.NONE
	phone_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_phone_send_pressed() -> void:
	var message := phone_input.text.strip_edges()
	if message.is_empty():
		return
	if multiplayer.is_server():
		PhoneSystem.server_handle_send_text(multiplayer.get_unique_id(), message)
	else:
		PhoneSystem.request_send_text.rpc_id(1, message)
	phone_input.text = ""


func _on_text_received(from_label: String, message: String) -> void:
	ContactBook.note_line_seen(from_label)
	_refresh_known_lines()
	var display_name := ContactBook.get_display_name(from_label)
	phone_log.append_text("[b]%s:[/b] %s\n" % [display_name, message])


func _on_text_sent_confirmation() -> void:
	phone_log.append_text("[i]-- sent into the unknown --[/i]\n")


## Rebuilds the "known lines" rename list in the phone panel. Small
## enough (a handful of lines per match) that a full rebuild is simpler
## and plenty fast, rather than diffing.
func _refresh_known_lines() -> void:
	for child in known_lines_box.get_children():
		child.queue_free()

	for line_id in ContactBook.get_known_line_ids():
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = ContactBook.get_display_name(line_id)
		name_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_label)

		var rename_input := LineEdit.new()
		rename_input.placeholder_text = "rename %s..." % line_id
		rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rename_input)

		var save_button := Button.new()
		save_button.text = "Save"
		save_button.pressed.connect(func():
			ContactBook.set_nickname(line_id, rename_input.text)
			_refresh_known_lines())
		row.add_child(save_button)

		known_lines_box.add_child(row)


# --- Code keypad --------------------------------------------------------

func _open_keypad_panel(room_index: int) -> void:
	_keypad_room_index = room_index
	_active_modal = Modal.KEYPAD
	keypad_panel.visible = true
	keypad_feedback.text = ""
	keypad_input.text = ""
	keypad_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_keypad_panel() -> void:
	_active_modal = Modal.NONE
	keypad_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_keypad_submit_pressed() -> void:
	var code := keypad_input.text.strip_edges()
	if code.is_empty() or _keypad_room_index == -1:
		return
	if multiplayer.is_server():
		PuzzleSystem.server_handle_attempt(multiplayer.get_unique_id(), _keypad_room_index, code)
	else:
		PuzzleSystem.request_attempt_unlock.rpc_id(1, _keypad_room_index, code)


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
	feed_camera.position = Match.room_grid_position(room_index) + Vector3(0, 5.5, 0)
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
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		phone_panel.visible = false
		keypad_panel.visible = false
		prompt_label.visible = false
		eliminated_overlay.visible = true


# --- Toast (brief on-screen text for clue reveals, lock feedback, ...) --

func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start(TOAST_DURATION)


func _on_toast_timer_timeout() -> void:
	toast_label.visible = false
