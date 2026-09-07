extends RefCounted
## Path-based interactable type checks — safe without global_script_class_cache.

const INTERACTABLE_BASE := "res://scripts/interactables/interactable.gd"
const LADDER := "res://scripts/interactables/ladder.gd"
const CLUE_FLAME_PAPER := "res://scripts/interactables/clue_flame_paper.gd"
const GUN := "res://scripts/interactables/gun.gd"
const PHONE := "res://scripts/interactables/phone.gd"
const RADIO_TOWER := "res://scripts/horror/environment/radio_tower.gd"
const SIGNAL_PHONE := "res://scripts/horror/environment/signal_phone.gd"
const CODE_KEYPAD := "res://scripts/interactables/code_keypad.gd"
const SECURITY_CAMERA := "res://scripts/interactables/security_camera.gd"
const TEST_PROJECTILE := "res://scripts/interactables/test_projectile.gd"
const DUMMY_TARGET := "res://scripts/interactables/dummy_target.gd"
const PLAYER := "res://scripts/player.gd"


static func script_path(node: Object) -> String:
	if not is_instance_valid(node):
		return ""
	var s: Script = node.get_script()
	return s.resource_path if s else ""


static func is_script(node: Object, path: String) -> bool:
	return script_path(node) == path


static func extends_script(node: Object, base_path: String) -> bool:
	var s: Script = node.get_script() if is_instance_valid(node) else null
	while s:
		if s.resource_path == base_path:
			return true
		s = s.get_base_script()
	return false


static func is_interactable(node: Object) -> bool:
	return extends_script(node, INTERACTABLE_BASE)


static func is_ladder(node: Object) -> bool:
	return is_script(node, LADDER)


static func is_clue_flame_paper(node: Object) -> bool:
	return is_script(node, CLUE_FLAME_PAPER)


static func is_gun(node: Object) -> bool:
	return is_script(node, GUN)


static func is_phone(node: Object) -> bool:
	return is_script(node, PHONE)


static func is_radio_tower(node: Object) -> bool:
	return is_script(node, RADIO_TOWER)


static func is_signal_phone(node: Object) -> bool:
	return is_script(node, SIGNAL_PHONE)


static func is_code_keypad(node: Object) -> bool:
	return is_script(node, CODE_KEYPAD)


static func is_security_camera(node: Object) -> bool:
	return is_script(node, SECURITY_CAMERA)


static func is_dummy_target(node: Object) -> bool:
	return is_script(node, DUMMY_TARGET)
