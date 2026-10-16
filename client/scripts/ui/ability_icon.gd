class_name AbilityIcon
extends Control
## Hand-drawn icon for a ball ability (InkIcons). Draws centred in its rect.

var ability: String = "standard":
	set(v):
		ability = v
		queue_redraw()
var dimmed: bool = false:
	set(v):
		dimmed = v
		queue_redraw()
var _t := 0.0
var _cv := InkCanvas.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if ability in ["nitro", "grenade"] and not dimmed:
		queue_redraw()


func _draw() -> void:
	InkIcons.draw(_cv, ability, size * 0.5, minf(size.x, size.y), _t, dimmed)
	_cv.flush(get_canvas_item())
