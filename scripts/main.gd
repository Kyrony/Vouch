extends Node
## Main
##
## Root scene. Composes the Lobby UI and the persistent "World" (Match +
## Outside) as siblings and just toggles visibility between them, instead
## of using `change_scene_to_file()`. This sidesteps a lot of Godot 4
## multiplayer scene-change replication timing headaches for a project
## this size: Match/Outside/their MultiplayerSpawners are always present
## in the tree (on every peer) and ready to receive spawned nodes the
## moment the host starts the match.
##
## TODO(post-MVP): if the project grows multiple maps/rounds, revisit this
## in favor of proper scene streaming.

@onready var lobby: Control = $Lobby
@onready var world: Node3D = $World


func _ready() -> void:
	world.visible = false
	GameState.match_started.connect(_on_match_started)


func _on_match_started() -> void:
	lobby.visible = false
	world.visible = true
