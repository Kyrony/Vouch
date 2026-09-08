extends RefCounted
class_name LeonardoUiValidate
## Headless checks for the hybrid Leonardo plate + hitbox home.


static func validate_menu(lobby: Control) -> String:
	if lobby == null:
		return "Lobby missing"
	var scene_err := _validate_boot_scene_file()
	if not scene_err.is_empty():
		return scene_err
	var bg_node := lobby.get_node_or_null("Background")
	if bg_node is ColorRect:
		return "boot background must be TextureRect plate, not ColorRect"
	var bg := bg_node as TextureRect
	if bg == null:
		return "menu plate TextureRect missing"
	if bg.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		return "menu plate must use Keep Aspect Covered"
	if bg.texture == null:
		return "Leonardo menu plate texture not assigned"
	if lobby.get_node_or_null("HomePanel/NavColumn") != null:
		return "NavColumn must not exist on the boot home"
	if lobby.get_node_or_null("HomePanel/Banner") != null and lobby.get_node("HomePanel/Banner").visible:
		return "do not rebuild a separate banner over the plate"
	for path in [
		"HomePanel/HitboxRoot/MenuButtons/PlayButton",
		"HomePanel/HitboxRoot/MenuButtons/JoinFriendsButton",
		"HomePanel/HitboxRoot/MenuButtons/SettingsButton",
		"HomePanel/HitboxRoot/MenuButtons/QuitButton",
		"HomePanel/HitboxRoot/GameModes/ClassicButton",
		"PlayPanel/VBoxContainer/HostButton",
		"PlayPanel/BackButton",
	]:
		if lobby.get_node_or_null(path) == null:
			return "menu node missing: %s" % path
	for path in [
		"HomePanel/HitboxRoot/MenuButtons/PlayButton",
		"HomePanel/HitboxRoot/MenuButtons/JoinFriendsButton",
		"HomePanel/HitboxRoot/MenuButtons/SettingsButton",
		"HomePanel/HitboxRoot/MenuButtons/QuitButton",
		"HomePanel/HitboxRoot/GameModes/ClassicButton",
		"HomePanel/HitboxRoot/GameModes/HardcoreButton",
		"HomePanel/HitboxRoot/GameModes/CustomButton",
		"HomePanel/HitboxRoot/GameModes/PracticeButton",
		"HomePanel/HitboxRoot/GameModes/FriendsLobbyButton",
	]:
		var hit := lobby.get_node(path) as Button
		if not hit.text.is_empty():
			return "hitbox %s still has visible text" % path
		var hover := hit.get_theme_stylebox("hover")
		if not (hover is StyleBoxFlat):
			return "hitbox %s needs a neon glow hover box" % path
	var modes := lobby.get_node_or_null("HomePanel/HitboxRoot/GameModes") as Control
	if modes == null:
		return "GameModes panel missing"
	if modes.visible:
		return "game-modes panel must stay hidden until Play"
	if lobby.get_node_or_null("HomePanel/HitboxRoot/ModesCover") == null:
		return "ModesCover missing"
	if lobby.get_node_or_null("PlayPanel/MatchSettingsPanel") != null:
		return "Host Lobby still has spawn-odds sliders"
	var classic := lobby.get_node("HomePanel/HitboxRoot/GameModes/ClassicButton") as Button
	if classic.disabled:
		return "Classic must stay the live Host Match path"
	for gated_name in ["HardcoreButton", "CustomButton", "PracticeButton", "FriendsLobbyButton"]:
		var gated := lobby.get_node_or_null("HomePanel/HitboxRoot/GameModes/%s" % gated_name) as Button
		if gated == null:
			return "mode hitbox missing: %s" % gated_name
		if gated.disabled:
			return "%s should stay clickable (soft stub)" % gated_name
		var tip := gated.tooltip_text.to_lower()
		if tip.contains("coming soon"):
			return "%s overclaims Coming Soon" % gated_name
	var host := lobby.get_node("PlayPanel/VBoxContainer/HostButton") as Button
	if host.text.to_lower().find("host") < 0:
		return "Classic path lost Host Match"
	var menu_src := FileAccess.get_file_as_string("res://scripts/horror/ui/neon_menu.gd")
	if menu_src.contains("Coming Soon"):
		return "neon_menu overclaims Coming Soon"
	if menu_src.contains("voice") or menu_src.contains("SMS"):
		return "menu must not claim voice/SMS"
	if not ResourceLoader.exists("res://assets/horror/ui/menu_leonardo_locked.png"):
		return "locked menu plate missing"
	var plate := load("res://assets/horror/ui/menu_leonardo_locked.png") as Texture2D
	if plate == null:
		return "menu_leonardo_locked.png failed to load as a texture"
	if plate.get_width() != 1280 or plate.get_height() != 720:
		return "menu plate must be 1280x720"
	var png := FileAccess.open("res://assets/horror/ui/menu_leonardo_locked.png", FileAccess.READ)
	if png == null:
		return "menu_leonardo_locked.png unreadable"
	var magic := png.get_buffer(8)
	if magic != PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return "menu_leonardo_locked.png is not a PNG"
	var banner_src := FileAccess.get_file_as_string("res://scripts/horror/ui/vouch_banner.gd")
	if not banner_src.contains("BANNER_HAS_CROSSBAR := false"):
		return "VouchBanner must keep BANNER_HAS_CROSSBAR false"
	return ""


static func _validate_boot_scene_file() -> String:
	var tscn := FileAccess.get_file_as_string("res://scenes/Lobby/Lobby.tscn")
	if tscn.is_empty():
		return "Lobby.tscn unreadable"
	if tscn.contains('[node name="Background" type="ColorRect"'):
		return "Lobby.tscn boot background is still ColorRect"
	if not tscn.contains('[node name="Background" type="TextureRect"'):
		return "Lobby.tscn must ship a TextureRect plate named Background"
	if not tscn.contains("stretch_mode = 6"):
		return "Lobby.tscn plate must use Keep Aspect Covered (stretch_mode 6)"
	if not tscn.contains("res://assets/horror/ui/menu_leonardo_locked.png"):
		return "Lobby.tscn must reference menu_leonardo_locked.png"
	if tscn.contains("NavColumn"):
		return "Lobby.tscn still has NavColumn"
	if tscn.contains("MatchSettingsPanel") or tscn.contains("HiddenHallwayRow"):
		return "Lobby.tscn Host Lobby still has spawn-odds sliders"
	var play_chunk := tscn.get_slice('[node name="PlayPanel"', 1)
	play_chunk = play_chunk.get_slice('[node name="SettingsPanel"', 0)
	if play_chunk.contains("type=\"HSlider\""):
		return "PlayPanel still has sliders"
	var home := tscn.get_slice('[node name="PlayPanel"', 0)
	for line in home.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("text = \"") and trimmed != "text = \"\"":
			return "Lobby.tscn home hitboxes still show Godot button text"
	var project := FileAccess.get_file_as_string("res://project.godot")
	if not project.contains('run/main_scene="res://scenes/Main.tscn"'):
		return "F5 main scene is not scenes/Main.tscn"
	return ""


static func validate_hud() -> String:
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	if hud_script == null:
		return "neon_hud.gd failed to load"
	var hud: Object = hud_script.new()
	for method_name in ["set_meters", "set_signal_band", "set_phone_device", "set_interact_prompt", "set_steal"]:
		if not hud.has_method(method_name):
			hud.free()
			return "NeonHud missing %s" % method_name
	if str(hud.get("OBJECTIVE_TITLE")) != "MISSING CHILD":
		hud.free()
		return "objective banner title mismatch"
	if str(hud.get("OBJECTIVE_TAG")) != "ALIVE ONLY":
		hud.free()
		return "ALIVE ONLY tag missing"
	hud.call("set_signal_band", "service")
	if str(hud.get("signal_band")) != "full":
		hud.free()
		return "NeonHud did not map service -> full"
	hud.call("set_interact_prompt", true, "Open door", "Look / Talk")
	if not bool(hud.get("interact_visible")):
		hud.free()
		return "interact prompt did not show"
	hud.free()
	var pack: GDScript = load("res://scripts/horror/ui/hud_icon_pack.gd")
	if pack == null:
		return "hud_icon_pack.gd failed to load"
	if str(pack.TEX_PHONE_LED) != "phone_led":
		return "phone LED texture stem changed"
	if ResourceLoader.exists("res://assets/horror/hud/torch.png") or ResourceLoader.exists("res://assets/horror/hud/flashlight.png"):
		return "HUD pack must not ship a classic torch glyph"
	if str(pack.TEX_PHONE_LED).contains("torch") or str(pack.TEX_PHONE_LED).contains("flashlight"):
		return "phone LED stem must not be a torch glyph"
	if not ResourceLoader.exists("res://assets/horror/hud/phone_led.png"):
		return "phone_led.png missing"
	if not FileAccess.file_exists("res://assets/horror/ui/README.md"):
		return "UI pack README missing"
	for stem in ["health_bar_empty", "stamina_bar_empty", "phone_led", "signal_full", "signal_weak", "signal_dead"]:
		if not ResourceLoader.exists("res://assets/horror/hud/%s.png" % stem):
			return "%s.png missing" % stem
	var dir := DirAccess.open("res://assets/horror/hud")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.contains("fill_example") or fname.ends_with("_fill.png") or fname.contains("_fill_mid") or fname.contains("_fill_low"):
				return "HUD must not ship fill-state PNGs: %s" % fname
			fname = dir.get_next()
	var hud_src := FileAccess.get_file_as_string("res://scripts/horror/ui/neon_hud.gd")
	if hud_src.contains("_health_hearts") or hud_src.contains("health_heart"):
		return "NeonHud still uses ornate heart health"
	if hud_src.contains("_fear_bar") or hud_src.contains("TEX_FEAR") or hud_src.contains("FearRow"):
		return "NeonHud must not show a fear bar"
	if hud_src.contains("TEX_HEALTH_CHIP") or hud_src.contains("HealthChip"):
		return "NeonHud must not show meter chips"
	if not hud_src.contains("TextureProgressBar"):
		return "NeonHud must fill empty tracks with TextureProgressBar"
	if str(pack.TEX_HEALTH) != "health_bar_empty":
		return "health track stem must be health_bar_empty"
	if str(pack.TEX_STAMINA) != "stamina_bar_empty":
		return "stamina track stem must be stamina_bar_empty"
	if not pack.has_method("make_fill_texture"):
		return "HudIconPack must generate fill textures in-engine"
	return ""
