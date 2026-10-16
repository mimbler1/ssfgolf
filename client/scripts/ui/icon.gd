class_name Icon
extends Control
## Small hand-drawn UI icons (InkIcons; no emoji/font dependency). Size via custom_minimum_size.

var kind: String = "star":
	set(v):
		kind = v
		queue_redraw()
## Accent colour for icons that take one (Color.WHITE = the icon's own colours).
var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var _cv := InkCanvas.new()


static func make(p_kind: String, px: float = 28.0, p_color: Color = Color.WHITE) -> Icon:
	var i := Icon.new()
	i.kind = p_kind
	i.color = p_color
	i.custom_minimum_size = Vector2(px, px)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	InkIcons.draw(_cv, kind, size * 0.5, minf(size.x, size.y), 0.0, false, color if color != UITheme.PAPER else Color.WHITE)
	_cv.flush(get_canvas_item())
