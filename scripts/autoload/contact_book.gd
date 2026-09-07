extends Node
## ContactBook
##
## Client-local, UNSYNCED nickname map for the anonymous phone "lines"
## (see PhoneSystem). If a player thinks they've figured out who
## "Line 07" really is, they can rename it locally to whatever they want -
## purely a personal memory aid so their own texts don't get mixed up.
## This is never sent to the server or any other peer; two players can
## give the same line completely different (or wrong!) nicknames.
##
## Persisted to a small local config file so nicknames survive across
## sessions, but that's a convenience, not a gameplay requirement.

signal contacts_changed

const SAVE_PATH: String = "user://vouch_contacts.cfg"
const SECTION: String = "contacts"

## line_id (e.g. "Line 07") -> nickname (e.g. "probably Sam?")
var _nicknames: Dictionary = {}
## Every distinct line_id ever seen this session, in first-seen order -
## lets the phone UI list "known lines" even before they're renamed.
var _known_line_ids: Array[String] = []


func _ready() -> void:
	_load()


func note_line_seen(line_id: String) -> void:
	if line_id.is_empty() or _known_line_ids.has(line_id):
		return
	_known_line_ids.append(line_id)
	contacts_changed.emit()


func get_known_line_ids() -> Array[String]:
	return _known_line_ids.duplicate()


func get_display_name(line_id: String) -> String:
	return _nicknames.get(line_id, line_id)


func set_nickname(line_id: String, nickname: String) -> void:
	note_line_seen(line_id)
	var trimmed := nickname.strip_edges()
	if trimmed.is_empty():
		_nicknames.erase(line_id)
	else:
		_nicknames[line_id] = trimmed
	_save()
	contacts_changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	for line_id in _nicknames.keys():
		cfg.set_value(SECTION, line_id, _nicknames[line_id])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("ContactBook: failed to save contacts (err=%s)" % err)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for line_id in cfg.get_section_keys(SECTION):
		_nicknames[line_id] = cfg.get_value(SECTION, line_id)
		if not _known_line_ids.has(line_id):
			_known_line_ids.append(line_id)
