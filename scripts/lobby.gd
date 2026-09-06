extends Control
## Lobby
##
## Acts as the game's "home screen": Play / Settings / Character / Exit.
## Play swaps in the host/join sub-panel (IP-based direct connect only for
## MVP - lobby codes and relay/NAT traversal are explicitly future work,
## see docs/MVP_GDD.md). Settings/Character are stub panels for now. The
## Play panel shows a LIVE joined-player list (name + peer id) that
## updates as peers connect, broadcast to everyone via
## `NetworkManager.lobby_roster_updated` - this is pre-match "who's here"
## information only, never faction/role info.

@onready var home_panel: Control = $HomePanel
@onready var play_panel: Control = $PlayPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var character_panel: Control = $CharacterPanel

@onready var play_button: Button = $HomePanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $HomePanel/VBoxContainer/SettingsButton
@onready var character_button: Button = $HomePanel/VBoxContainer/CharacterButton
@onready var exit_button: Button = $HomePanel/VBoxContainer/ExitButton

@onready var host_button: Button = $PlayPanel/VBoxContainer/HostButton
@onready var ip_input: LineEdit = $PlayPanel/VBoxContainer/JoinRow/IPInput
@onready var join_button: Button = $PlayPanel/VBoxContainer/JoinRow/JoinButton
@onready var start_match_button: Button = $PlayPanel/VBoxContainer/StartMatchButton
@onready var status_label: Label = $PlayPanel/VBoxContainer/StatusLabel
@onready var play_back_button: Button = $PlayPanel/VBoxContainer/BackButton

@onready var player_count_label: Label = $PlayPanel/PlayerListPanel/VBoxContainer/PlayerCountLabel
@onready var player_list_box: VBoxContainer = $PlayPanel/PlayerListPanel/VBoxContainer/PlayerListScroll/PlayerListBox

@onready var settings_back_button: Button = $SettingsPanel/VBoxContainer/BackButton
@onready var character_back_button: Button = $CharacterPanel/VBoxContainer/BackButton


func _ready() -> void:
	play_button.pressed.connect(func(): _show_panel(play_panel))
	settings_button.pressed.connect(func(): _show_panel(settings_panel))
	character_button.pressed.connect(func(): _show_panel(character_panel))
	exit_button.pressed.connect(_on_exit_pressed)

	play_back_button.pressed.connect(func(): _show_panel(home_panel))
	settings_back_button.pressed.connect(func(): _show_panel(home_panel))
	character_back_button.pressed.connect(func(): _show_panel(home_panel))

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	start_match_button.visible = false

	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.lobby_roster_updated.connect(_on_roster_updated)

	_show_panel(home_panel)
	_on_roster_updated(NetworkManager.lobby_roster)


func _show_panel(panel: Control) -> void:
	home_panel.visible = false
	play_panel.visible = false
	settings_panel.visible = false
	character_panel.visible = false
	panel.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_host_pressed() -> void:
	var err := NetworkManager.host_game()
	if err == OK:
		status_label.text = "Hosting on port %d. Share your IP with friends." % NetworkManager.DEFAULT_PORT
		start_match_button.visible = true
	else:
		status_label.text = "Failed to host (error %s)." % err


func _on_join_pressed() -> void:
	var address := ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var err := NetworkManager.join_game(address)
	if err == OK:
		status_label.text = "Connecting to %s..." % address
	else:
		status_label.text = "Failed to connect (error %s)." % err


func _on_start_match_pressed() -> void:
	NetworkManager.start_match()


func _on_joined_server() -> void:
	status_label.text = "Connected. Waiting for the host to start the match."


func _on_join_failed(reason: String) -> void:
	status_label.text = "Join failed: %s" % reason


func _on_disconnected() -> void:
	status_label.text = "Disconnected from host."
	start_match_button.visible = false


func _on_roster_updated(roster: Array) -> void:
	for child in player_list_box.get_children():
		child.queue_free()

	for entry in roster:
		var label := Label.new()
		label.text = "\u2022 %s  (peer %d)" % [entry["name"], entry["peer_id"]]
		player_list_box.add_child(label)

	player_count_label.text = "Players connected: %d" % roster.size()
