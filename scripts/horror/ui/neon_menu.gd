extends RefCounted
class_name NeonMenu
## Styles the React-port VouchMenu + simplified Host Match panel.
## Classic is the live Host Match path. Other modes are soft stubs.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")
const _BUILD: GDScript = preload("res://scripts/horror/ui/vouch_menu_builder.gd")


static func apply(lobby: Control) -> void:
	if lobby == null:
		return
	_BUILD.call("ensure", lobby)
	var play := lobby.get_node_or_null("PlayPanel") as Control
	if play:
		_style_play(play)


static func set_play_selected(home: Control, selected: bool) -> void:
	if home == null:
		return
	var play := home.get_node_or_null("NavColumn/PlayButton") as Button
	if play:
		_T.apply_nav_button(play, selected)


static func _style_play(play: Control) -> void:
	var title := play.get_node_or_null("VBoxContainer/TitleLabel") as Label
	if title:
		title.text = "CLASSIC — HOST MATCH"
		_T.apply_label(title, "ui")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status := play.get_node_or_null("VBoxContainer/StatusLabel") as Label
	if status:
		_T.apply_label(status, "stone")
	var host := play.get_node_or_null("VBoxContainer/HostButton") as Button
	if host:
		_T.apply_action_button(host, "gold")
		host.text = "Host Match"
	var start := play.get_node_or_null("VBoxContainer/StartMatchButton") as Button
	if start:
		_T.apply_action_button(start, "gold")
		start.text = "Start Match"
	var back := play.get_node_or_null("BackButton") as Button
	if back:
		_T.apply_action_button(back, "gold")
	var join := play.get_node_or_null("VBoxContainer/JoinRow/JoinButton") as Button
	if join:
		_T.apply_action_button(join, "gold")
	var ip := play.get_node_or_null("VBoxContainer/JoinRow/IPInput") as LineEdit
	if ip:
		_T.apply_line_edit(ip)
