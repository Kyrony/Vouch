extends SceneTree
## Headless behavior probe for the React-port VouchMenu.
## Run: godot4 --headless --path . -s res://scripts/vouch_menu_probe.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var lobby := main.get_node_or_null("Lobby") as Control
	var ui_check: GDScript = load("res://scripts/horror/world/horror_soft_go_validate.gd")
	var menu_err: String = ui_check.call("validate_leonardo_menu", lobby)
	if not menu_err.is_empty():
		push_error("VOUCH MENU PROBE FAILED: %s" % menu_err)
		quit(1)
		return
	lobby.call("_set_nav", "")
	if lobby.get_node("HomePanel/SidePanel").visible:
		push_error("VOUCH MENU PROBE FAILED: backdrop/nav-null did not close the side panel")
		quit(1)
		return
	lobby.call("_set_nav", "play")
	if not lobby.get_node("HomePanel/SidePanel/PlayContent").visible:
		push_error("VOUCH MENU PROBE FAILED: Play did not open modes")
		quit(1)
		return
	lobby.call("_set_mode", "hardcore")
	lobby.call("_on_start_mode")
	if lobby.get_node("PlayPanel").visible:
		push_error("VOUCH MENU PROBE FAILED: stub mode opened Host Match")
		quit(1)
		return
	lobby.call("_set_mode", "classic")
	lobby.call("_on_start_mode")
	if not lobby.get_node("PlayPanel").visible:
		push_error("VOUCH MENU PROBE FAILED: Classic START did not open Host Match")
		quit(1)
		return
	var host := lobby.get_node("PlayPanel/VBoxContainer/HostButton") as Button
	if host.text.to_lower().find("host") < 0:
		push_error("VOUCH MENU PROBE FAILED: Host Match button missing")
		quit(1)
		return
	lobby.call("_close_host")
	lobby.call("_set_nav", "friends")
	var code := lobby.get_node("HomePanel/SidePanel/FriendsContent/LobbyCodeInput") as LineEdit
	code.text = "ab12cd"
	lobby.call("_on_lobby_code_changed", code.text)
	if code.text != "AB12CD":
		push_error("VOUCH MENU PROBE FAILED: lobby code did not uppercase")
		quit(1)
		return
	lobby.call("_set_nav", "settings")
	if not lobby.get_node("HomePanel/SidePanel/SettingsContent").visible:
		push_error("VOUCH MENU PROBE FAILED: Settings panel hidden")
		quit(1)
		return
	print("VOUCH MENU PROBE OK")
	quit(0)
