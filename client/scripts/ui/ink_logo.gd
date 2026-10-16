class_name InkLogo
extends Control
## The game's hand-lettered logo: "Fairway Frenzy" in inked paper letters, a looping ball
## swoosh and a little flag, with a gentle bob. Original artwork (no reference branding).

var _t := 0.0
var _cv := InkCanvas.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(760, 300)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := UITheme.heading_font()
	var bob := sin(_t * 1.6) * 3.0
	var swoosh := InkCanvas.cubic_bez(Vector2(40, 230), Vector2(160, 300), Vector2(560, 300), Vector2(700, 150), 26)
	_cv.stroke(swoosh, 14.0, Color(UITheme.SUN, 0.9), 0.6, 0.05, 1.0, 0.1, 0.0, 0.05)
	_cv.stroke(InkCanvas.offset_line(swoosh, 7.5), 2.4, Color(InkCanvas.INK, 0.8), 0.6, 0.1, 2.0, 0.1, 0.0, 0.05)
	# Flag on the right end of the swoosh.
	var base := Vector2(712, 150 + bob)
	_cv.stroke(PackedVector2Array([base, base + Vector2(2, -96)]), 6.0, InkCanvas.INK, 0.05, 0.05)
	_cv.stroke(PackedVector2Array([base, base + Vector2(2, -96)]), 2.6, UITheme.PAPER, 0.05, 0.05)
	var top := base + Vector2(2, -96)
	var flag := PackedVector2Array()
	for i in 8:
		var u := i / 7.0
		flag.append(top + Vector2(u * 52.0, sin(_t * 4.0 - u * 4.0) * 3.0 * u + u * 6.0))
	for i in 8:
		var u := 1.0 - i / 7.0
		flag.append(top + Vector2(u * 50.0, 32.0 - u * 12.0 + sin(_t * 4.0 - u * 4.0) * 3.0 * u))
	_cv.fill(flag, UITheme.CORAL)
	_cv.outline(flag, 3.0, InkCanvas.INK, 3.0)
	# Ball riding the swoosh.
	var k := fposmod(_t * 0.25, 1.0)
	var bp := swoosh[int(k * (swoosh.size() - 1))] + Vector2(0, -10)
	_cv.ellipse(bp, Vector2(11, 11), Color.WHITE)
	_cv.crescent(bp, 10.6, Vector2(-3, -3), Color("e3ddd2"))
	_cv.ink_circle(bp, Vector2(11, 11), 3.0, InkCanvas.INK, 2.0)
	_cv.flush(get_canvas_item())
	_word(font, "Fairway", Vector2(20, 112 + bob * 0.6), 118, UITheme.PAPER, -0.035)
	_word(font, "Frenzy", Vector2(150, 222 - bob * 0.4), 118, UITheme.SUN, -0.02)


func _word(font: Font, text: String, pos: Vector2, size_px: int, col: Color, rot: float) -> void:
	draw_set_transform(pos, rot, Vector2.ONE)
	draw_string_outline(font, Vector2(6, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 26, Color(0, 0, 0, 0.18))
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 24, InkCanvas.INK)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
