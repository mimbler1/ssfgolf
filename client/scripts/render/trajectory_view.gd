class_name TrajectoryView
extends Node2D
## Predicted flight path, computed from the same physics the server runs, drawn in ink
## (docs/INK_ART_SPEC.md §11). Styles:
##  - "dots": the standard dotted aim guide for every shot (Settings > Gameplay, on by default),
##    showing the first arc and a short roll-out;
##  - "laser": the Laser Ball's longer beam guide while the Laser Ball is selected;
##  - "debug": a practice-mode overlay that follows the whole flight.
## It previews terrain only: opponents, abilities triggered later and network latency can still
## change the outcome.

const INK := InkCanvas.INK

var points: PackedVector2Array = PackedVector2Array()
var contact_index: int = -1
var power: float = 0.0
var color: Color = Color.WHITE
var hazard: bool = false
var style := "laser"
var _t: float = 0.0
var _cv := InkCanvas.new()


func set_path(p_points: PackedVector2Array, p_contact: int, p_power: float, p_color: Color, p_hazard: bool = false, p_style: String = "laser") -> void:
	points = p_points
	hazard = p_hazard
	contact_index = p_contact
	power = p_power
	color = p_color
	style = p_style
	queue_redraw()


func clear() -> void:
	if points.is_empty():
		return
	points = PackedVector2Array()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if points.size() > 0:
		queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	if style == "laser":
		_draw_laser()
	elif style == "dots":
		_draw_dots()
	else:
		_draw_debug()
	if hazard:
		var end := points[points.size() - 1]
		var r := 10.0
		_cv.stroke(PackedVector2Array([end + Vector2(-r, -r), end + Vector2(r, r)]), 5.0, Color("ef5a5a"), 0.15, 0.15)
		_cv.stroke(PackedVector2Array([end + Vector2(-r, r), end + Vector2(r, -r)]), 5.0, Color("ef5a5a"), 0.15, 0.15)
		_cv.ink_circle(end, Vector2(r + 5.0, r + 5.0), 1.6, Color(INK, 0.6), 3.0)
	_cv.flush(get_canvas_item())


## Laser guide: a pulsing beam to the first bounce, then a fading short continuation, with
## travelling sparks so it reads as a laser rather than a pen line.
func _draw_laser() -> void:
	var beam := Color("ef3b5e")
	var pulse := 0.75 + 0.25 * sin(_t * 9.0)
	var last := points.size() - 1
	var cut := contact_index if contact_index > 0 else last
	var main := points.slice(0, cut + 1)
	if main.size() >= 2:
		_cv.stroke(main, 11.0, Color(beam, 0.2 * pulse), 0.02, 0.05, 0.0, 0.0)
		_cv.stroke(main, 3.6, beam, 0.02, 0.05, 0.0, 0.0)
		_cv.stroke(main, 1.2, Color(1, 0.92, 0.94, 0.85), 0.02, 0.05, 0.0, 0.0)
	if cut < last:
		var tail := points.slice(cut, last + 1)
		_cv.stroke(tail, 2.4, Color(beam, 0.4), 0.02, 0.9, 0.0, 0.0)
	var total := 0.0
	for i in range(1, cut + 1):
		total += points[i - 1].distance_to(points[i])
	if total > 0.0:
		for s in 4:
			var target := fmod(_t * 520.0 + s * total / 4.0, total)
			var acc := 0.0
			for i in range(1, cut + 1):
				var seg := points[i - 1].distance_to(points[i])
				if acc + seg >= target:
					InkIcons._spark(_cv, points[i - 1].lerp(points[i], (target - acc) / maxf(seg, 0.001)), 5.0, Color(1, 1, 1, 0.95))
					break
				acc += seg
	if contact_index > 0 and contact_index < points.size():
		_land_marker(points[contact_index], beam, 13.0 + pulse * 3.0)


## Standard aim guide: round ink-ringed dots in the ball's colour that shrink and fade along the
## flight, dimmer after the first bounce, with a landing marker.
func _draw_dots() -> void:
	var spacing := 18.0
	var phase := fmod(_t * 40.0, spacing)
	var acc := spacing - phase
	var end_index := points.size() - 1
	var fill := color if color.get_luminance() < 0.92 else InkCanvas.PAPER
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var seg := a.distance_to(b)
		var d := 0.0
		while acc <= seg - d:
			d += acc
			acc = spacing
			var p := a.lerp(b, d / seg)
			var k := float(i) / float(end_index)
			var after := contact_index != -1 and i > contact_index
			var alpha := (1.0 - k * 0.7) * (0.45 if after else 0.95)
			var r := lerpf(4.6, 2.4, k)
			_cv.ellipse(p, Vector2(r, r), Color(fill, alpha))
			_cv.ink_circle(p, Vector2(r, r), 1.4, Color(INK, alpha * 0.85), float(i), 0.0, 0.15, 0.04)
		acc -= seg - d
	if contact_index > 0 and contact_index < points.size():
		_land_marker(points[contact_index], fill.darkened(0.15), 11.0 + (0.5 + 0.5 * sin(_t * 6.0)) * 3.0)


## Practice debug overlay: the whole flight as faint pencil dashes, clearly not the laser.
func _draw_debug() -> void:
	var dense := InkCanvas.resample(points, 9.0)
	var i := 0
	while i < dense.size() - 2:
		var k := float(i) / float(dense.size())
		var after := contact_index != -1 and float(i) / dense.size() > float(contact_index) / points.size()
		_cv.stroke(dense.slice(i, i + 2), 2.0, Color(INK, (1.0 - k * 0.7) * (0.25 if after else 0.5)), 0.2, 0.2)
		i += 3


func _land_marker(land: Vector2, col: Color, r: float) -> void:
	for side in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_cv.stroke(PackedVector2Array([land + side * (r - 6.0), land + side * (r + 5.0)]), 3.6, col, 0.15, 0.4)
	_cv.ink_circle(land, Vector2(r, r), 2.0, Color(INK, 0.75), 2.0)
