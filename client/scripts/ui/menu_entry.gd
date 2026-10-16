class_name MenuEntry
extends GameButton
## Main-menu button with a hand-drawn icon on the left (and a lock when the feature is planned
## but not built yet).

var icon_kind := "star"
var locked := false:
	set(v):
		locked = v
		queue_redraw()
var _cv := InkCanvas.new()


static func entry(label: String, icon_name: String, variation: String = "", min_size: Vector2 = Vector2(0, 64)) -> MenuEntry:
	var b := MenuEntry.new()
	b.text = label
	b.icon_kind = icon_name
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	return b


func _ready() -> void:
	super._ready()
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("h_separation", 0)
	text = "         " + text.strip_edges()


func _draw() -> void:
	var s := minf(size.y * 0.62, 40.0)
	InkIcons.draw(_cv, icon_kind, Vector2(14 + s * 0.5 + 6, size.y * 0.5 - 1), s, 0.0, disabled)
	if locked:
		InkIcons.draw(_cv, "lock", Vector2(size.x - 13, 13), 20.0)
	_cv.flush(get_canvas_item())
