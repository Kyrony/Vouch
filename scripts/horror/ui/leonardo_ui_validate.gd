extends RefCounted
class_name LeonardoUiValidate
## Headless checks for the hybrid Leonardo plate + hitbox home.


static func validate_menu(lobby: Control) -> String:
	if lobby == null:
		return "Lobby missing"
	var bg := lobby.get_node_or_null("Background") as TextureRect
	if bg == null:
		return "menu plate TextureRect missing"
	if bg.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		return "menu plate must use Keep Aspect Covered"
	if bg.texture == null:
		return "Leonardo menu plate texture not assigned"
	if lobby.get_node_or_null("HomePanel/Banner") != null and lobby.get_node("HomePanel/Banner").visible:
		return "do not rebuild a separate banner over the plate"
	for path in [
		"HomePanel/HitboxRoot/MenuButtons/PlayButton",
		"HomePanel/HitboxRoot/MenuButtons/JoinFriendsButton",
		"HomePanel/HitboxRoot/MenuButtons/SettingsButton",
		"HomePanel/HitboxRoot/MenuButtons/QuitButton",
		"HomePanel/HitboxRoot/GameModes/ClassicButton",
		"PlayPanel/VBoxContainer/HostButton",
	]:
		if lobby.get_node_or_null(path) == null:
			return "menu node missing: %s" % path
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
	var banner_src := FileAccess.get_file_as_string("res://scripts/horror/ui/vouch_banner.gd")
	if not banner_src.contains("BANNER_HAS_CROSSBAR := false"):
		return "VouchBanner must keep BANNER_HAS_CROSSBAR false"
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
	return ""
