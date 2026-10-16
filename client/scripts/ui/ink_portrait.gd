class_name InkPortrait
extends Control
## Player portrait: the golfer's own head, hair, face, hat and eyewear (InkHead) in a paper
## disc with a slot-colour ring. Static: it only redraws when the look or expression changes.

var ring := UITheme.SUN
var look: Dictionary = InkLook.DEFAULT
## Face left (right-hand HUD panels look inward).
var mirror := false:
	set(v):
		mirror = v
		queue_redraw()
## Draw the paper disc and coloured ring (off for a bare head on a card).
var framed := true
var _expr := ""
var _cv := InkCanvas.new()
var _pose: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_look(appearance: Dictionary) -> void:
	look = Appearance.normalize(appearance).ink
	queue_redraw()


func set_expression(e: String) -> void:
	if e == _expr:
		return
	_expr = e
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.48
	_cv.xf = Transform2D.IDENTITY
	if framed:
		_cv.ellipse(c, Vector2(r, r), UITheme.PAPER)
		_cv.ellipse(c + Vector2(0, r * 0.62), Vector2(r * 0.75, r * 0.35), Color(ring, 0.35))
	# Head-and-shoulders pose, framed so the head sits slightly high in the disc.
	if _pose.is_empty():
		_pose = InkRig.solve({"club": "none", "lean": 0.0, "tilt": -0.06})
	var p := _pose.duplicate()
	if _expr == "joy":
		p.expr = {"eyes": "joy", "mouth": "open"}
	var k := s / 34.0
	var head: Vector2 = p.head
	var fx := -1.0 if mirror else 1.0
	_cv.xf = Transform2D(0.0, Vector2(k * fx, k), 0.0, c + Vector2(-head.x * k * fx + s * 0.04 * fx, -head.y * k + s * 0.06))
	var st := {"lw": 2.2 * 34.0 / maxf(s, 1.0) * maxf(1.0, s / 40.0), "t": 0.0, "seed": 3.0, "sway": 0.0, "blink": false}
	# Neck and shoulders hint.
	_cv.stroke(PackedVector2Array([p.neck, (p.neck as Vector2) + Vector2(0, 10)]), float(st.lw), InkCanvas.INK, 0.05, 0.3)
	InkHead.draw(_cv, p, look, st)
	_cv.xf = Transform2D.IDENTITY
	if framed:
		_cv.ink_circle(c, Vector2(r, r), maxf(2.4, s * 0.06), ring.darkened(0.15), 7.0, 0.0, 0.2, 0.015)
	_cv.flush(get_canvas_item())
