extends Control
class_name MenuHitboxLayout
## Maps 1280×720 design-space hitboxes onto a Keep Aspect Covered menu plate.
## Does not draw chrome — the Leonardo plate is the visual.

const DESIGN := Vector2(1280, 720)
const ART := "res://assets/horror/ui/menu_leonardo_locked.png"

const NAV := {
	"PlayButton": Rect2(40, 248, 276, 88),
	"JoinFriendsButton": Rect2(40, 344, 276, 72),
	"SettingsButton": Rect2(40, 424, 276, 72),
	"QuitButton": Rect2(40, 504, 276, 72),
}
const MODES := {
	"ClassicButton": Rect2(348, 336, 220, 64),
	"HardcoreButton": Rect2(348, 408, 220, 52),
	"CustomButton": Rect2(348, 464, 220, 52),
	"PracticeButton": Rect2(348, 516, 220, 52),
	"FriendsLobbyButton": Rect2(348, 572, 220, 52),
}
const MODE_COVER := Rect2(324, 214, 272, 454)


static func covered_rect(view: Vector2, design: Vector2 = DESIGN) -> Rect2:
	if view.x <= 1.0 or view.y <= 1.0:
		return Rect2(Vector2.ZERO, design)
	var view_aspect := view.x / view.y
	var design_aspect := design.x / design.y
	if view_aspect > design_aspect:
		var h := view.x / design_aspect
		return Rect2(0.0, (view.y - h) * 0.5, view.x, h)
	var w := view.y * design_aspect
	return Rect2((view.x - w) * 0.5, 0.0, w, view.y)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	resized.connect(_sync)
	call_deferred("_sync")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync()


func _sync() -> void:
	var root := get_node_or_null("HitboxRoot") as Control
	if root == null:
		return
	var dest := covered_rect(size)
	root.position = dest.position
	root.size = DESIGN
	var sx := dest.size.x / DESIGN.x
	root.scale = Vector2(sx, sx)
	var cover := root.get_node_or_null("ModesCover") as Control
	if cover:
		cover.position = MODE_COVER.position
		cover.size = MODE_COVER.size
