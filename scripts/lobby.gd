extends Control
## Lobby
##
## Host/join UI stub. IP-based direct connect only for MVP - lobby codes
## and relay/NAT traversal are explicitly future work (see
## docs/MVP_GDD.md). The host is the only one who can start the match.

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var ip_input: LineEdit = $VBoxContainer/JoinRow/IPInput
@onready var join_button: Button = $VBoxContainer/JoinRow/JoinButton
@onready var start_match_button: Button = $VBoxContainer/StartMatchButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_count_label: Label = $VBoxContainer/PlayerCountLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	start_match_button.visible = false

	NetworkManager.player_connected.connect(_on_roster_changed)
	NetworkManager.player_disconnected.connect(_on_roster_changed)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)


func _on_host_pressed() -> void:
	var err := NetworkManager.host_game()
	if err == OK:
		status_label.text = "Hosting on port %d. Share your IP with friends." % NetworkManager.DEFAULT_PORT
		start_match_button.visible = true
		_on_roster_changed(0)
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


func _on_roster_changed(_peer_id: int) -> void:
	if NetworkManager.is_server():
		player_count_label.text = "Players connected: %d" % GameState.players.size()
