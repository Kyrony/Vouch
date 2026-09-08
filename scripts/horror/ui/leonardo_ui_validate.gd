extends RefCounted
class_name LeonardoUiValidate
## Headless checks for the React-port VouchMenu Control home + HUD pack.


static func validate_menu(lobby: Control) -> String:
	if lobby == null:
		return "Lobby missing"
	var scene_err := _validate_boot_scene_file()
	if not scene_err.is_empty():
		return scene_err
	var bg_node := lobby.get_node_or_null("Background")
	if bg_node is TextureRect:
		return "boot background must be ColorRect #050203, not the Leonardo plate"
	var bg := bg_node as ColorRect
	if bg == null:
		return "menu Background ColorRect missing"
	var base := Color(0.0196078, 0.0078431, 0.0117647, 1.0)
	if bg.color.r > 0.05 or bg.color.g > 0.04 or bg.color.b > 0.04:
		return "Background is not the dark #050203 base"
	var mansion := lobby.get_node_or_null("MansionPlaceholder")
	if mansion:
		if mansion.visible:
			return "MansionPlaceholder must stay hidden now that title art is the background"
		if mansion is TextureRect and (mansion as TextureRect).texture != null:
			return "MansionPlaceholder must stay a blank placeholder"
		var mansion_tex := lobby.get_node_or_null("MansionPlaceholder/Texture") as TextureRect
		if mansion_tex and mansion_tex.texture != null:
			return "mansion TextureRect must not require art"
	if lobby.get_node_or_null("HomePanel/HitboxRoot") != null:
		return "hybrid plate HitboxRoot must not remain on the boot home"
	if lobby.get_node_or_null("HomePanel/NavColumn") == null:
		return "NavColumn missing on the Control home"
	var banner := lobby.get_node_or_null("HomePanel/Banner") as Control
	if banner and banner.visible:
		return "legacy Banner wordmark must stay off the home (use MenuLogo)"
	var signal_cluster := lobby.get_node_or_null("HomePanel/SignalCluster") as Control
	if signal_cluster and signal_cluster.visible:
		return "SIGNAL cluster must stay off the home"
	var logo := lobby.get_node_or_null("HomePanel/MenuLogo") as TextureRect
	if logo == null:
		return "MenuLogo missing on the Control home"
	if not logo.visible:
		return "MenuLogo must stay visible on the home"
	if logo.texture == null:
		return "MenuLogo has no texture"
	if logo.position.x > 48.0 or logo.position.y > 48.0:
		return "MenuLogo must sit in the top-left"
	if not FileAccess.file_exists("res://assets/horror/ui/vouch_fiery_logo.png"):
		return "vouch_fiery_logo.png missing"
	var nav := lobby.get_node_or_null("HomePanel/NavColumn") as Control
	if nav and nav.position.y < logo.position.y + logo.size.y - 4.0:
		return "NavColumn overlaps the fiery VOUCH logo"
	var atmo := lobby.get_node_or_null("MenuAtmosphere")
	if atmo == null:
		return "MenuAtmosphere title background missing"
	if not (atmo is TextureRect):
		return "MenuAtmosphere must be a TextureRect"
	var atmo_tex := atmo as TextureRect
	if atmo_tex.texture == null:
		return "MenuAtmosphere has no texture"
	if atmo_tex.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		return "title background must use Keep Aspect Covered"
	if not FileAccess.file_exists("res://assets/horror/ui/menu_title_bg.png"):
		return "menu_title_bg.png missing"
	if lobby.get_node_or_null("MenuVignette") == null:
		return "MenuVignette missing over the title plate"
	if lobby.get_node_or_null("MenuNavShade") == null:
		return "MenuNavShade missing over the title plate"
	for path in [
		"HomePanel/NavColumn/PlayButton",
		"HomePanel/NavColumn/JoinFriendsButton",
		"HomePanel/NavColumn/SettingsButton",
		"HomePanel/NavColumn/QuitButton",
		"HomePanel/SidePanel/PlayContent/ModeList/ClassicButton",
		"HomePanel/SidePanel/PlayContent/StartButton",
		"HomePanel/SidePanel/FriendsContent/LobbyCodeInput",
		"HomePanel/SidePanel/FriendsContent/FriendsJoinButton",
		"HomePanel/SidePanel/SettingsContent/TabNav/KeybindsButton",
		"HomePanel/SidePanel/SettingsContent/TabNav/AudioButton",
		"HomePanel/SidePanel/SettingsContent/TabNav/VisualButton",
		"HomePanel/SidePanel/SettingsContent/TabNav/ControlsButton",
		"HomePanel/SidePanel/SettingsContent/KeybindsPanel",
		"HomePanel/SidePanel/SettingsContent/MasterVolumeRow/Slider",
		"HomePanel/SidePanel/SettingsContent/SfxVolumeRow/Slider",
		"HomePanel/SidePanel/SettingsContent/FullscreenRow/FullscreenToggle",
		"HomePanel/SidePanel/SettingsContent/SaveButton",
		"PlayPanel/VBoxContainer/HostButton",
		"PlayPanel/BackButton",
	]:
		if lobby.get_node_or_null(path) == null:
			return "menu node missing: %s" % path
	var play := lobby.get_node("HomePanel/NavColumn/PlayButton") as Button
	var caption := play.get_node_or_null("Row/Caption") as Label
	if caption == null or caption.text.strip_edges().is_empty():
		return "Play nav must show visible text"
	var play_content := lobby.get_node_or_null("HomePanel/SidePanel/PlayContent") as Control
	if play_content == null or not play_content.visible:
		return "Play modes panel must be open on boot"
	var thumb := lobby.get_node_or_null("HomePanel/SidePanel/PlayContent/ModeThumb")
	if thumb == null:
		return "ModeThumb placeholder missing"
	if thumb is TextureRect and (thumb as TextureRect).texture != null:
		return "ModeThumb must stay blank"
	if not (thumb is ColorRect or thumb is TextureRect or thumb is Panel):
		return "ModeThumb must be a blank ColorRect, TextureRect, or Panel"
	var thumb_tex := lobby.get_node_or_null("HomePanel/SidePanel/PlayContent/ModeThumb/Texture") as TextureRect
	if thumb_tex and thumb_tex.texture != null:
		return "mode thumbnail must not require modes/*.png"
	if lobby.get_node_or_null("PlayPanel/MatchSettingsPanel") != null:
		return "Host Lobby still has spawn-odds sliders"
	var classic := lobby.get_node("HomePanel/SidePanel/PlayContent/ModeList/ClassicButton") as Button
	if classic.disabled:
		return "Classic must stay the live Host Match path"
	for gated_name in ["HardcoreButton", "CustomButton", "PracticeButton", "FriendsLobbyButton"]:
		var gated := lobby.get_node_or_null("HomePanel/SidePanel/PlayContent/ModeList/%s" % gated_name) as Button
		if gated == null:
			return "mode button missing: %s" % gated_name
		if gated.disabled:
			return "%s should stay clickable (soft stub)" % gated_name
		var tip := gated.tooltip_text.to_lower()
		if tip.contains("coming soon"):
			return "%s overclaims Coming Soon" % gated_name
	var host := lobby.get_node("PlayPanel/VBoxContainer/HostButton") as Button
	if host.text.to_lower().find("host") < 0:
		return "Classic path lost Host Match"
	var code := lobby.get_node("HomePanel/SidePanel/FriendsContent/LobbyCodeInput") as LineEdit
	if code.max_length != 8:
		return "friends lobby code must be max 8"
	var menu_src := FileAccess.get_file_as_string("res://scripts/lobby.gd")
	if not menu_src.contains("get_tree().quit()"):
		return "Quit must call get_tree().quit()"
	if menu_src.contains("CreoTek") or menu_src.contains("shell_open"):
		return "Quit must not redirect to a web page"
	if menu_src.contains("Coming Soon"):
		return "lobby overclaims Coming Soon"
	var neon_src := FileAccess.get_file_as_string("res://scripts/horror/ui/neon_menu.gd")
	if neon_src.contains("Coming Soon"):
		return "neon_menu overclaims Coming Soon"
	if neon_src.contains("voice") or neon_src.contains("SMS"):
		return "menu must not claim voice/SMS"
	var builder_src := FileAccess.get_file_as_string("res://scripts/horror/ui/vouch_menu_builder.gd")
	if builder_src.contains("\"mansion-bg.png\"") or builder_src.contains("\"modes/") or builder_src.contains("res://assets/modes"):
		return "menu must not require mansion-bg.png or modes/*.png"
	if not builder_src.contains("vouch_fiery_logo.png"):
		return "menu builder lost the fiery VOUCH logo"
	if not builder_src.contains("NAV_TOP"):
		return "menu builder lost the lowered nav offset"
	if not builder_src.contains("load_png_from_buffer"):
		return "menu builder must decode Kyle PNGs from bytes if import cache is stale"
	var banner_src := FileAccess.get_file_as_string("res://scripts/horror/ui/vouch_banner.gd")
	if not banner_src.contains("BANNER_HAS_CROSSBAR := false"):
		return "VouchBanner must keep BANNER_HAS_CROSSBAR false"
	if not FileAccess.file_exists("res://assets/fonts/Cinzel-Bold.ttf"):
		return "Cinzel Bold missing"
	if not FileAccess.file_exists("res://assets/fonts/SpecialElite-Regular.ttf"):
		return "Special Elite missing"
	return ""


static func _validate_boot_scene_file() -> String:
	var tscn := FileAccess.get_file_as_string("res://scenes/Lobby/Lobby.tscn")
	if tscn.is_empty():
		return "Lobby.tscn unreadable"
	if tscn.contains("menu_leonardo_locked.png"):
		return "Lobby.tscn still references the Leonardo plate"
	if tscn.contains('[node name="Background" type="TextureRect"'):
		return "Lobby.tscn click-catcher Background must stay a ColorRect, not the plate"
	if not tscn.contains('[node name="Background" type="ColorRect"'):
		return "Lobby.tscn must ship a ColorRect named Background"
	if not tscn.contains("menu_title_bg.png"):
		return "Lobby.tscn must reference menu_title_bg.png as the title art"
	if not tscn.contains("vouch_fiery_logo.png"):
		return "Lobby.tscn must reference vouch_fiery_logo.png as MenuLogo"
	if not tscn.contains('[node name="MenuLogo" type="TextureRect"'):
		return "Lobby.tscn must ship MenuLogo as a TextureRect"
	if not tscn.contains('[node name="MenuAtmosphere" type="TextureRect"'):
		return "Lobby.tscn must ship MenuAtmosphere as a TextureRect"
	if tscn.contains("MatchSettingsPanel") or tscn.contains("HiddenHallwayRow"):
		return "Lobby.tscn Host Lobby still has spawn-odds sliders"
	if tscn.contains("mansion-bg.png") or tscn.contains("modes/"):
		return "Lobby.tscn must not require mansion/mode art"
	var play_chunk := tscn.get_slice('[node name="PlayPanel"', 1)
	if play_chunk.contains("type=\"HSlider\""):
		return "PlayPanel still has sliders"
	var project := FileAccess.get_file_as_string("res://project.godot")
	if not project.contains('run/main_scene="res://scenes/Main.tscn"'):
		return "F5 main scene is not scenes/Main.tscn"
	var lobby_src := FileAccess.get_file_as_string("res://scripts/lobby.gd")
	if not lobby_src.contains("get_tree().quit()"):
		return "lobby.gd Quit is not get_tree().quit()"
	return ""


static func validate_hud() -> String:
	var hud_script: GDScript = load("res://scripts/horror/ui/neon_hud.gd")
	if hud_script == null:
		return "neon_hud.gd failed to load"
	var hud: Object = hud_script.new()
	for method_name in ["set_meters", "set_signal_band", "set_phone_device", "set_interact_prompt", "set_steal", "set_hotbar", "apply_example_rail"]:
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
	for stem in [
		"health_bar_empty", "stamina_bar_empty", "phone_led",
		"signal_full", "signal_weak", "signal_dead", "signal_empty",
		"battery_empty", "slot_empty", "slot_selected",
		"icon_key", "icon_firearm", "icon_shovel", "icon_crowbar",
		"icon_bandage", "icon_battery_pack", "icon_lockpick", "icon_evidence",
		"icon_rope", "icon_fuse", "icon_medkit", "icon_flashlight",
	]:
		if not ResourceLoader.exists("res://assets/horror/hud/%s.png" % stem) and not FileAccess.file_exists("res://assets/horror/hud/%s.png" % stem):
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
	if not hud_src.contains("ItemRail"):
		return "NeonHud must build a right-edge ItemRail"
	if hud_src.contains('name = "Hotbar"'):
		return "NeonHud must not keep a bottom hotbar"
	if not hud_src.contains("BatteryBar") or not hud_src.contains("SignalWidget"):
		return "NeonHud missing top-right signal/battery widgets"
	if int(pack.RAIL_SLOTS) != 5:
		return "item rail must be 5 wells"
	if not pack.has_method("rail_texture"):
		return "HudIconPack missing rail_texture"
	if not hud_src.contains("MatchClockLabel") or not hud_src.contains("_on_match_clock"):
		return "NeonHud must keep MatchClockLabel wired to MatchClock"
	return ""
