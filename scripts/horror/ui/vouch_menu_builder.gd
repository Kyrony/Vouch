extends RefCounted
class_name VouchMenuBuilder
## Builds Kyle's React VouchMenu as Godot Controls over menu_title_bg.
## Fiery VOUCH MenuLogo sits top-left. Nav/sidebox sit lower so they miss it.
## Blank mode thumbs only — no mansion-bg.png or modes/*.png. No SIGNAL.

const _T: GDScript = preload("res://scripts/horror/ui/vouch_menu_theme.gd")
const TITLE_BG := "res://assets/horror/ui/menu_title_bg.png"
const LOGO := "res://assets/horror/ui/vouch_fiery_logo.png"
# Left nav sits a little above the vertical center of the 720-tall viewport.
const NAV_TOP := 196.0
## Previous plate was 880×260. Keep the same aspect at one-third scale.
const LOGO_SIZE := Vector2(880.0 / 3.0, 260.0 / 3.0)
## Draw order for the interactive menu so it always sits in front of the
## decorative logo and background plate ("most forward" when the menu opens).
const MENU_FRONT_Z := 5
## Centered side-box size (opens in the middle of the page on nav click).
## Sized so the mode banner image fills the width and every mode row + START
## fits; width stays wide enough for the Settings tab content.
const SIDE_SIZE := Vector2(496, 560)
## Mode banner aspect (cropped art is 1280x304).
const THUMB_ASPECT := 1280.0 / 304.0

const NAV := [
	{"id": "play", "name": "PlayButton", "label": "PLAY"},
	{"id": "friends", "name": "JoinFriendsButton", "label": "JOIN FRIENDS"},
	{"id": "settings", "name": "SettingsButton", "label": "SETTINGS"},
	{"id": "quit", "name": "QuitButton", "label": "QUIT"},
]

# Scary preview art shown in the mode thumbnail when a mode is selected.
# Add a mode here to give it a thumbnail; modes left out show a blank box.
const MODE_THUMBS := {
	"classic": "res://assets/horror/ui/mode_classic.png",
	"hardcore": "res://assets/horror/ui/mode_hardcore.png",
	"custom": "res://assets/horror/ui/mode_custom.png",
}

const MODE_ORDER := ["classic", "hardcore", "custom", "practice", "friends-lobby"]
const MODE_NODE := {
	"classic": "ClassicButton",
	"hardcore": "HardcoreButton",
	"custom": "CustomButton",
	"practice": "PracticeButton",
	"friends-lobby": "FriendsLobbyButton",
}


static func ensure(lobby: Control) -> void:
	_strip_plate(lobby)
	_ensure_background(lobby)
	_ensure_atmosphere(lobby)
	_ensure_vignette(lobby)
	_ensure_mansion(lobby)
	_ensure_home(lobby)
	_ensure_host(lobby)
	_drop_legacy_panels(lobby)


static func _strip_plate(lobby: Control) -> void:
	for path in ["HomePanel/HitboxRoot", "HomePanel/ModesCover"]:
		var n := lobby.get_node_or_null(path)
		if n:
			n.queue_free()


static func _ensure_background(lobby: Control) -> void:
	var bg := lobby.get_node_or_null("Background")
	if bg is TextureRect or bg == null:
		var rect := ColorRect.new()
		rect.name = "Background"
		if bg:
			bg.replace_by(rect)
			bg.free()
		else:
			lobby.add_child(rect)
			lobby.move_child(rect, 0)
		bg = rect
	var color_bg := bg as ColorRect
	color_bg.color = _T.BASE
	color_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_bg.offset_left = 0
	color_bg.offset_top = 0
	color_bg.offset_right = 0
	color_bg.offset_bottom = 0
	color_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	color_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	color_bg.grow_vertical = Control.GROW_DIRECTION_BOTH


static func _ensure_atmosphere(lobby: Control) -> void:
	var atmo := lobby.get_node_or_null("MenuAtmosphere") as Control
	if atmo == null:
		atmo = TextureRect.new()
		atmo.name = "MenuAtmosphere"
		lobby.add_child(atmo)
	if not (atmo is TextureRect):
		var tex_rect := TextureRect.new()
		tex_rect.name = "MenuAtmosphere"
		atmo.replace_by(tex_rect)
		atmo.free()
		atmo = tex_rect
	var tex := atmo as TextureRect
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 0
	tex.offset_top = 0
	tex.offset_right = 0
	tex.offset_bottom = 0
	tex.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tex.grow_vertical = Control.GROW_DIRECTION_BOTH
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.visible = true
	tex.modulate = Color.WHITE
	tex.self_modulate = Color.WHITE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture = load_png_texture(TITLE_BG)
	var bg := lobby.get_node_or_null("Background")
	if bg:
		lobby.move_child(tex, bg.get_index() + 1)


static func _ensure_vignette(lobby: Control) -> void:
	var dim := lobby.get_node_or_null("MenuVignette") as ColorRect
	if dim == null:
		dim = ColorRect.new()
		dim.name = "MenuVignette"
		lobby.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deeper, red-tinted vignette for a darker mood (kept well under the 38%
	# black that used to swallow Kyle's village plate).
	dim.color = Color(0.02, 0.004, 0.008, 0.22)
	var atmo := lobby.get_node_or_null("MenuAtmosphere")
	if atmo:
		lobby.move_child(dim, atmo.get_index() + 1)
	var shade := lobby.get_node_or_null("MenuNavShade") as ColorRect
	if shade == null:
		shade = ColorRect.new()
		shade.name = "MenuNavShade"
		lobby.add_child(shade)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.anchor_right = 0.36
	shade.offset_left = 0
	shade.offset_top = 0
	shade.offset_right = 0
	shade.offset_bottom = 0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.012, 0.004, 0.01, 0.10)
	lobby.move_child(shade, dim.get_index() + 1)


static func _hide_wordmark_and_signal(home: Control) -> void:
	for node_name in ["Banner", "SignalCluster"]:
		var n := home.get_node_or_null(node_name) as Control
		if n:
			n.visible = false
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _ensure_mansion(lobby: Control) -> void:
	var mansion := lobby.get_node_or_null("MansionPlaceholder") as Control
	if mansion == null:
		mansion = ColorRect.new()
		mansion.name = "MansionPlaceholder"
		lobby.add_child(mansion)
	if mansion is ColorRect:
		(mansion as ColorRect).color = Color(0, 0, 0, 0)
	mansion.visible = false
	mansion.set_anchors_preset(Control.PRESET_FULL_RECT)
	mansion.anchor_left = 0.42
	mansion.offset_left = 0
	mansion.offset_top = 0
	mansion.offset_right = 0
	mansion.offset_bottom = 0
	mansion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := mansion.get_node_or_null("Texture") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "Texture"
		mansion.add_child(tex)
	tex.texture = null
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 0
	tex.offset_top = 0
	tex.offset_right = 0
	tex.offset_bottom = 0
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


static func _ensure_home(lobby: Control) -> void:
	var home := lobby.get_node_or_null("HomePanel") as Control
	if home == null:
		home = Control.new()
		home.name = "HomePanel"
		lobby.add_child(home)
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.offset_left = 0
	home.offset_top = 0
	home.offset_right = 0
	home.offset_bottom = 0
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_wordmark_and_signal(home)
	_ensure_logo(home)
	_ensure_nav(home)
	_ensure_side(home)
	_ensure_toast(home)


static func _ensure_logo(home: Control) -> void:
	var logo := home.get_node_or_null("MenuLogo") as TextureRect
	if logo == null:
		logo = TextureRect.new()
		logo.name = "MenuLogo"
		home.add_child(logo)
		home.move_child(logo, 0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2(16, 10)
	logo.size = LOGO_SIZE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.visible = true
	logo.modulate = Color.WHITE
	logo.self_modulate = Color.WHITE
	logo.texture = load_png_texture(LOGO)


static func _ensure_nav(home: Control) -> void:
	var nav := home.get_node_or_null("NavColumn") as VBoxContainer
	if nav == null:
		nav = VBoxContainer.new()
		nav.name = "NavColumn"
		home.add_child(nav)
	nav.position = Vector2(28, NAV_TOP)
	nav.size = Vector2(300, 280)
	nav.add_theme_constant_override("separation", 10)
	nav.mouse_filter = Control.MOUSE_FILTER_STOP
	nav.z_index = MENU_FRONT_Z
	for spec in NAV:
		var btn := nav.get_node_or_null(spec["name"]) as Button
		if btn == null:
			btn = _make_nav_button(spec)
			nav.add_child(btn)
		_strip_nav_glyph(btn)
		_T.apply_nav_button(btn, spec["id"] == "play")


static func _make_nav_button(spec: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = spec["name"]
	btn.text = ""
	btn.custom_minimum_size = Vector2(280, 54)
	btn.focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	btn.add_child(row)
	var diamond := Label.new()
	diamond.name = "Diamond"
	diamond.text = "◆"
	diamond.custom_minimum_size = Vector2(18, 0)
	diamond.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(diamond)
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = spec["label"]
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	return btn


static func _strip_nav_glyph(button: Button) -> void:
	if button == null:
		return
	var glyph := button.get_node_or_null("Row/Glyph")
	if glyph:
		glyph.free()


static func _ensure_side(home: Control) -> void:
	var side := home.get_node_or_null("SidePanel") as Panel
	if side == null:
		side = Panel.new()
		side.name = "SidePanel"
		home.add_child(side)
	# Opens centered in the page (modal-style) when a nav item is clicked.
	side.set_anchors_preset(Control.PRESET_CENTER)
	side.offset_left = -SIDE_SIZE.x * 0.5
	side.offset_top = -SIDE_SIZE.y * 0.5
	side.offset_right = SIDE_SIZE.x * 0.5
	side.offset_bottom = SIDE_SIZE.y * 0.5
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	side.z_index = MENU_FRONT_Z
	side.add_theme_stylebox_override("panel", _T.box(_T.GOLD, _T.PANEL, 1, 2, true))
	_ensure_play_content(side)
	_ensure_friends_content(side)
	_ensure_settings_content(side)
	# Close via Esc or clicking outside the box — no ✕ button.
	var old_close := side.get_node_or_null("CloseButton")
	if old_close:
		old_close.free()


static func _ensure_play_content(side: Control) -> void:
	var play := side.get_node_or_null("PlayContent") as Control
	if play == null:
		play = Control.new()
		play.name = "PlayContent"
		side.add_child(play)
	play.set_anchors_preset(Control.PRESET_FULL_RECT)
	play.offset_left = 14
	play.offset_top = 14
	play.offset_right = -14
	play.offset_bottom = -14
	# No "PLAY" heading — the banner art speaks for itself. Drop any old one.
	var old_heading := play.get_node_or_null("Heading")
	if old_heading:
		old_heading.free()
	var content_w := SIDE_SIZE.x - 28.0  # PlayContent inner width
	var thumb_h := roundf(content_w / THUMB_ASPECT)
	var thumb := play.get_node_or_null("ModeThumb") as Panel
	if thumb == null:
		thumb = Panel.new()
		thumb.name = "ModeThumb"
		play.add_child(thumb)
	thumb.add_theme_stylebox_override("panel", _T.box(_T.GOLD_DIM, Color(0.05, 0.010, 0.014, 1), 1))
	thumb.position = Vector2(0, 0)
	thumb.size = Vector2(content_w, thumb_h)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := thumb.get_node_or_null("Texture") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "Texture"
		thumb.add_child(tex)
	# Size the fill explicitly: full-rect anchors resolve to 0 inside a plain
	# Panel (not a container), which left the preview invisible.
	tex.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tex.position = Vector2.ZERO
	tex.size = thumb.size
	tex.custom_minimum_size = thumb.size
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Art is pre-cropped to the box aspect, so a plain stretch fills it cleanly.
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture = mode_thumb_texture("classic")
	var modes := play.get_node_or_null("ModeList") as VBoxContainer
	if modes == null:
		modes = VBoxContainer.new()
		modes.name = "ModeList"
		play.add_child(modes)
	modes.position = Vector2(0, thumb_h + 12.0)
	modes.size = Vector2(content_w, 360)
	modes.add_theme_constant_override("separation", 6)
	for mode_id in MODE_ORDER:
		var node_name: String = MODE_NODE[mode_id]
		var btn := modes.get_node_or_null(node_name) as Button
		if btn == null:
			btn = _make_mode_button(mode_id, node_name)
			modes.add_child(btn)
		_T.apply_mode_button(btn, mode_id == "classic")
	var start := play.get_node_or_null("StartButton") as Button
	if start == null:
		start = Button.new()
		start.name = "StartButton"
		play.add_child(start)
	start.text = "START"
	start.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	start.offset_left = 0
	start.offset_top = -44
	start.offset_right = 0
	start.offset_bottom = 0
	_T.apply_action_button(start, "gold")


static func _make_mode_button(mode_id: String, node_name: String) -> Button:
	var spec: Dictionary = _T.MODES[mode_id]
	var btn := Button.new()
	btn.name = node_name
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 48)
	btn.tooltip_text = spec["desc"]
	var col := VBoxContainer.new()
	col.name = "Col"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 4
	col.offset_bottom = -4
	col.add_theme_constant_override("separation", 0)
	btn.add_child(col)
	var title := Label.new()
	title.name = "Title"
	title.text = spec["title"]
	col.add_child(title)
	var desc := Label.new()
	desc.name = "Desc"
	desc.text = spec["desc"]
	col.add_child(desc)
	return btn


static func _ensure_friends_content(side: Control) -> void:
	var friends := side.get_node_or_null("FriendsContent") as Control
	if friends == null:
		friends = Control.new()
		friends.name = "FriendsContent"
		side.add_child(friends)
	friends.visible = false
	friends.set_anchors_preset(Control.PRESET_FULL_RECT)
	friends.offset_left = 18
	friends.offset_top = 18
	friends.offset_right = -18
	friends.offset_bottom = -18
	var heading := friends.get_node_or_null("Heading") as Label
	if heading == null:
		heading = Label.new()
		heading.name = "Heading"
		friends.add_child(heading)
	heading.text = "JOIN FRIENDS"
	heading.position = Vector2(0, 0)
	heading.size = Vector2(380, 28)
	_T.apply_label(heading, "ui")
	var hint := friends.get_node_or_null("Hint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "Hint"
		friends.add_child(hint)
	hint.text = "Enter a lobby code."
	hint.position = Vector2(0, 40)
	hint.size = Vector2(380, 24)
	_T.apply_label(hint, "stone")
	var code := friends.get_node_or_null("LobbyCodeInput") as LineEdit
	if code == null:
		code = LineEdit.new()
		code.name = "LobbyCodeInput"
		friends.add_child(code)
	code.placeholder_text = "CODE"
	code.max_length = 8
	code.position = Vector2(0, 78)
	code.size = Vector2(380, 40)
	_T.apply_line_edit(code)
	var join := friends.get_node_or_null("FriendsJoinButton") as Button
	if join == null:
		join = Button.new()
		join.name = "FriendsJoinButton"
		friends.add_child(join)
	join.text = "JOIN"
	join.position = Vector2(0, 132)
	join.size = Vector2(380, 44)
	_T.apply_action_button(join, "gold")


static func _ensure_settings_content(side: Control) -> void:
	var settings := side.get_node_or_null("SettingsContent") as Control
	if settings == null:
		settings = Control.new()
		settings.name = "SettingsContent"
		side.add_child(settings)
	settings.visible = false
	var box: GDScript = load("res://scripts/horror/ui/settings_sidebox.gd")
	if box:
		box.call("ensure", settings)


static func _ensure_toast(home: Control) -> void:
	var toast := home.get_node_or_null("ToastLabel") as Label
	if toast == null:
		toast = Label.new()
		toast.name = "ToastLabel"
		home.add_child(toast)
	toast.visible = false
	toast.z_index = MENU_FRONT_Z + 5
	toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 24
	toast.offset_top = -40
	toast.offset_right = -24
	toast.offset_bottom = -12
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_T.apply_label(toast, "stone")
	toast.add_theme_color_override("font_color", _T.GOLD)


static func _ensure_host(lobby: Control) -> void:
	var play := lobby.get_node_or_null("PlayPanel") as Control
	if play == null:
		play = Control.new()
		play.name = "PlayPanel"
		lobby.add_child(play)
	play.visible = false
	play.set_anchors_preset(Control.PRESET_FULL_RECT)
	play.offset_left = 0
	play.offset_top = 0
	play.offset_right = 0
	play.offset_bottom = 0
	var dim := play.get_node_or_null("Dim") as ColorRect
	if dim == null:
		dim = ColorRect.new()
		dim.name = "Dim"
		play.add_child(dim)
		play.move_child(dim, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(_T.BASE.r, _T.BASE.g, _T.BASE.b, 1)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := play.get_node_or_null("VBoxContainer") as VBoxContainer
	if box == null:
		box = VBoxContainer.new()
		box.name = "VBoxContainer"
		play.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_top = -180
	box.offset_right = 200
	box.offset_bottom = 180
	box.add_theme_constant_override("separation", 10)
	_ensure_label(box, "TitleLabel", "CLASSIC — HOST MATCH")
	_T.apply_label(box.get_node("TitleLabel"), "ui")
	box.get_node("TitleLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var host := _ensure_button(box, "HostButton", "Host Match")
	_T.apply_action_button(host, "gold")
	var join_row := box.get_node_or_null("JoinRow") as HBoxContainer
	if join_row == null:
		join_row = HBoxContainer.new()
		join_row.name = "JoinRow"
		box.add_child(join_row)
	join_row.add_theme_constant_override("separation", 8)
	var ip := join_row.get_node_or_null("IPInput") as LineEdit
	if ip == null:
		ip = LineEdit.new()
		ip.name = "IPInput"
		join_row.add_child(ip)
	ip.placeholder_text = "Host IP (blank = 127.0.0.1)"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_T.apply_line_edit(ip)
	var join := join_row.get_node_or_null("JoinButton") as Button
	if join == null:
		join = Button.new()
		join.name = "JoinButton"
		join_row.add_child(join)
	join.text = "Join"
	_T.apply_action_button(join, "gold")
	var start := _ensure_button(box, "StartMatchButton", "Start Match")
	_T.apply_action_button(start, "gold")
	var status := _ensure_label(box, "StatusLabel", "Host a match or join a friend's IP.")
	_T.apply_label(status, "stone")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var count := _ensure_label(box, "PlayerCountLabel", "Players: 0")
	_T.apply_label(count, "stone")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back := play.get_node_or_null("BackButton") as Button
	if back == null:
		back = Button.new()
		back.name = "BackButton"
		play.add_child(back)
	back.text = "Back"
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(160, 44)
	_T.apply_action_button(back, "gold")
	for junk_name in ["MatchSettingsPanel", "MatchSettingsClientLabel", "PlayerListPanel"]:
		var junk := play.get_node_or_null(junk_name)
		if junk:
			junk.queue_free()
	var list := box.get_node_or_null("PlayerListBox")
	if list:
		list.queue_free()


static func _ensure_label(parent: Node, node_name: String, text: String) -> Label:
	var label := parent.get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		parent.add_child(label)
	label.text = text
	return label


static func _ensure_button(parent: Node, node_name: String, text: String) -> Button:
	var btn := parent.get_node_or_null(node_name) as Button
	if btn == null:
		btn = Button.new()
		btn.name = node_name
		parent.add_child(btn)
	btn.text = text
	return btn


## Scary preview art for a mode, or null when the mode has no thumbnail.
## Decode straight to an uncompressed ImageTexture: the software GL path used
## in headless/CI VMs does not reliably sample the imported VRAM .ctex.
static func mode_thumb_texture(mode_id: String) -> Texture2D:
	var path: String = MODE_THUMBS.get(mode_id, "")
	if path.is_empty():
		return null
	var tex := _png_from_bytes(path)
	if tex != null:
		return tex
	return load_png_texture(path)


## Prefer the imported CompressedTexture2D. If the .ctex cache is stale or
## blank after a PNG byte-swap, decode Kyle's exact file bytes so the plate
## and fiery wordmark still show.
static func load_png_texture(path: String) -> Texture2D:
	var imported: Texture2D = null
	if ResourceLoader.exists(path):
		imported = load(path) as Texture2D
	if imported != null and imported.get_width() > 8 and imported.get_height() > 8:
		return imported
	return _png_from_bytes(path)


static func _png_from_bytes(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return null
	var buf := fa.get_buffer(int(fa.get_length()))
	fa.close()
	if buf.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(buf) != OK:
		return null
	if img.get_width() < 1 or img.get_height() < 1:
		return null
	return ImageTexture.create_from_image(img)


static func _drop_legacy_panels(lobby: Control) -> void:
	for path in ["SettingsPanel", "CharacterPanel"]:
		var n := lobby.get_node_or_null(path)
		if n:
			n.queue_free()
