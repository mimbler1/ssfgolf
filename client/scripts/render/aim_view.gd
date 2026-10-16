class_name AimView
extends Node2D
## The aim indicator around the local ball, drawn in ink: a bold hand-drawn arrow (direction +
## power), the launch spin, the classic power meter and the putting tag. Where the ball will go
## is drawn separately by TrajectoryView (the dotted aim guide, or the Laser Ball's beam).

const INK := InkCanvas.INK

var ball_pos := Vector2.ZERO
var ball_radius := 9.0
var angle := 0.0
var power := 0.0           ## 0..1 within the current profile
var shot_power := 0.0      ## 0..1 of the full scale (shown as a percentage)
var spin := 0.0
var putting := false
var meter := false         ## classic meter running
var classic := false
var color := Color.WHITE
var blocked := false       ## e.g. cooldown: drawn dimmer
var _t := 0.0
var _cv := InkCanvas.new()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var dir := Vector2.from_angle(angle)
	var nrm := Vector2(-dir.y, dir.x)
	var a := 0.55 if blocked else 1.0
	var start := ball_pos + dir * (ball_radius + 10.0)
	var length := 30.0 + 120.0 * power
	var fill := _power_color(shot_power).lerp(color, 0.25)
	# One solid arrow with an ink rim: a shape, never dots, so it cannot be read as a flight path.
	var w0 := 4.0
	var w1 := lerpf(5.5, 8.0, power)
	var head_w := 15.0
	var head_l := 24.0
	var neck := start + dir * length
	var tip := neck + dir * head_l
	var arrow := PackedVector2Array([start + nrm * w0, neck + nrm * w1, neck + nrm * head_w, tip, neck - nrm * head_w, neck - nrm * w1, start - nrm * w0])
	_cv.fill(arrow, Color(fill, a))
	_cv.stroke(PackedVector2Array([start - nrm * (w0 - 1.5), neck - nrm * (w1 - 1.5)]), 1.8, Color(1, 1, 1, 0.55 * a), 0.2, 0.2)
	for k in 3:
		var u := float(k + 1) / 4.0
		var p := start + dir * length * u
		var hw := lerpf(w0, w1, u) - 1.5
		_cv.stroke(PackedVector2Array([p + nrm * hw, p - nrm * hw]), 1.4, Color(INK, 0.45 * a), 0.2, 0.2)
	_cv.outline(arrow, 3.0, Color(INK, a), 3.0, 0.15)
	if absf(spin) > 0.01:
		_spin_glyph(ball_pos, spin > 0.0, absf(spin))
	if classic:
		_meter(ball_pos + Vector2(0, 34))
	_cv.flush(get_canvas_item())
	_label(tip + dir * 22.0, "%d%%" % roundi(shot_power * 100.0), Color(fill, a), 24)
	if putting:
		_label(ball_pos + Vector2(0, -44), "PUTT", UITheme.GRASS, 22)
	var below := 70.0 if classic else 40.0
	if absf(spin) > 0.01:
		var top := spin > 0.0
		_label(ball_pos + Vector2(0, below), "%s %d%%" % ["TOPSPIN" if top else "BACKSPIN", roundi(absf(spin) * 100.0)], Color("f28c38") if top else Color("3fa3e8"), 19)


## A curling ink arrow around the ball, turning the way the spin turns.
func _spin_glyph(c: Vector2, top: bool, amount: float) -> void:
	var r := ball_radius + 6.0
	var dirn := 1.0 if top else -1.0
	var span := (0.35 + 0.6 * amount) * TAU
	var a0 := _t * 6.0 * dirn
	var arc := InkCanvas.arc_pts(c, r, a0, a0 + span * dirn, 18)
	var col := Color("f28c38") if top else Color("3fa3e8")
	_cv.stroke(arc, 3.0, col, 0.4, 0.05)
	var end := arc[arc.size() - 1]
	var tdir := (arc[arc.size() - 1] - arc[arc.size() - 2]).normalized()
	var tn := Vector2(-tdir.y, tdir.x)
	_cv.shape(PackedVector2Array([end + tdir * 5.0, end - tdir * 2.0 + tn * 4.5, end - tdir * 2.0 - tn * 4.5]), col, 1.4)


## Classic power meter: a hand-drawn segmented bar under the ball (clear of the golfer).
func _meter(c: Vector2) -> void:
	var w := 132.0
	var h := 14.0
	var r := Rect2(Vector2(c.x - w * 0.5, c.y), Vector2(w, h))
	var shape := InkStyleBox.outline_pts(r.grow(3.0), 8.0, 0.8, 1.0)
	_cv.fill(shape, Color(InkCanvas.PAPER, 0.95))
	var cells := 12
	var gap := 2.0
	var cw := (w - gap * (cells - 1)) / cells
	for i in cells:
		var k := float(i + 1) / float(cells)
		var lit := power >= k - 0.5 / cells
		var col := _power_color(k * (ShotController.PUTT_POWER if putting else 1.0))
		_cv.fill(InkStyleBox.outline_pts(Rect2(r.position.x + i * (cw + gap), r.position.y, cw, h), 3.0, 0.4, float(i)), col if lit else Color(col, 0.18))
	_cv.outline(shape, 2.4, INK, 1.0)
	if meter:
		var mx := r.position.x + w * power
		_cv.stroke(PackedVector2Array([Vector2(mx, r.position.y - 7), Vector2(mx, r.end.y + 7)]), 4.0, INK, 0.1, 0.1)
		_cv.stroke(PackedVector2Array([Vector2(mx, r.position.y - 5), Vector2(mx, r.end.y + 5)]), 1.6, Color.WHITE, 0.1, 0.1)


func _label(p: Vector2, text: String, col: Color, size: int) -> void:
	var f := UITheme.heading_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := p + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, INK)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _power_color(p: float) -> Color:
	if p < 0.5:
		return Color("fbf6ec").lerp(Color("f2b630"), p / 0.5)
	return Color("f2b630").lerp(Color("e8543a"), (p - 0.5) / 0.5)
