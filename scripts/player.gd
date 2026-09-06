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
## TODO(post-MVP): server-side movement validation/anti-cheat, footstep
## audio, ragdoll/animation, proper first-person arms model.

const SPEED: float = 4.5
const JUMP_VELOCITY: float = 4.0
const MOUSE_SENSITIVITY: float = 0.0025
const INTERACT_RANGE: float = 2.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hud: CanvasLayer = $HUD
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var faction_label: Label = $HUD/FactionLabel
@onready var phone_panel: Control = $HUD/PhonePanel
@onready var phone_input: LineEdit = $HUD/PhonePanel/VBoxContainer/PhoneInput
@onready var phone_log: RichTextLabel = $HUD/PhonePanel/VBoxContainer/PhoneLog

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _phone_open: bool = false

## Set by NetworkManager/Match director's spawn_function before this node
## is added to the tree. Purely informational in MVP - see the note in
## docs/MVP_GDD.md about why we deliberately do NOT tint remote players by
## faction color (that would leak the mystery/social-deduction info).
var faction_id: String = ""


func _ready() -> void:
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
		if not GameState.local_faction_id.is_empty():
			_on_faction_assigned(GameState.local_faction_id)
	else:
		camera.current = false
		hud.visible = false
		set_process_unhandled_input(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.3, 1.3)

	if event.is_action_pressed("ui_release_mouse"):
		if _phone_open:
			_close_phone_panel()
		else:
			var capture := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if capture else Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("interact") and not _phone_open:
		_try_interact()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if _phone_open:
		direction = Vector3.ZERO

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_update_interact_prompt()


func _update_interact_prompt() -> void:
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider() as Interactable
		if target:
			prompt_label.text = "[E] %s" % target.prompt_text
			prompt_label.visible = true
			return
	prompt_label.visible = false


func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var target := interact_ray.get_collider() as Interactable
	if target:
		target.interact(multiplayer.get_unique_id())
		if target is Phone:
			_open_phone_panel()


func _on_faction_assigned(faction_id_in: String) -> void:
	var faction_name: String = FactionData.get_faction_name(faction_id_in)
	var color: Color = FactionData.get_faction_color(faction_id_in)
	faction_label.text = "Faction: %s" % faction_name
	faction_label.add_theme_color_override("font_color", color)


func _open_phone_panel() -> void:
	_phone_open = true
	phone_panel.visible = true
	phone_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_phone_panel() -> void:
	_phone_open = false
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
	phone_log.append_text("[b]%s:[/b] %s\n" % [from_label, message])


func _on_text_sent_confirmation() -> void:
	phone_log.append_text("[i]-- sent into the unknown --[/i]\n")
