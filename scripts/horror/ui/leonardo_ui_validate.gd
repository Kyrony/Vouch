extends RefCounted
class_name LeonardoUiValidate
## Headless checks for the locked Leonardo UI pack wire.


static func validate_menu(lobby: Control) -> String:
	if lobby == null:
		return "Lobby missing"
	var banner := lobby.get_node_or_null("HomePanel/Banner")
	if banner == null:
		return "VOUCH banner missing"
	if banner.has_method("has_forbidden_stick") and bool(banner.call("has_forbidden_stick")):
		return "banner has a puppet X / crossbar / stick through the V"
	if banner.has_method("is_banner_form") and not bool(banner.call("is_banner_form")):
		return "banner must be banner-form only"
	for path in [
		"HomePanel/NavColumn/PlayButton",
		"HomePanel/NavColumn/JoinFriendsButton",
		"HomePanel/NavColumn/SettingsButton",
		"HomePanel/NavColumn/QuitButton",
		"HomePanel/ModePanel/ModeList/ClassicButton",
		"HomePanel/ModePanel/Preview",
		"HomePanel/SignalAccent",
		"HomePanel/VersionLabel",
		"PlayPanel/VBoxContainer/HostButton",
	]:
		if lobby.get_node_or_null(path) == null:
			return "menu node missing: %s" % path
	var classic := lobby.get_node("HomePanel/ModePanel/ModeList/ClassicButton") as Button
	if classic.disabled:
		return "Classic must stay the live Host Match path"
	for gated_name in ["HardcoreButton", "CustomButton", "PracticeButton", "FriendsLobbyButton"]:
		var gated := lobby.get_node_or_null("HomePanel/ModePanel/ModeList/%s" % gated_name) as Button
		if gated == null:
			return "mode row missing: %s" % gated_name
		if not gated.disabled:
			return "%s must be soft-gated" % gated_name
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
	var banner_src := FileAccess.get_file_as_string("res://scripts/horror/ui/vouch_banner.gd")
	if banner_src.contains("draw_line") and banner_src.contains("crossbar"):
		pass
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
	if not ResourceLoader.exists("res://assets/horror/ui/banner_vouch.png"):
		return "banner_vouch.png missing"
	if not FileAccess.file_exists("res://assets/horror/ui/README.md"):
		return "UI pack README missing"
	return ""
