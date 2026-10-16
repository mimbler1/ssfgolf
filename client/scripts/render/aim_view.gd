class_name AimView
extends Node2D
## The aim indicator around the local ball: a chunky pixel arrow (direction + power), the launch
## spin, the classic power meter and the putting tag. It never shows where the ball will go; only
## the Laser Ball guide (TrajectoryView) does that.
##
const PX := 2.0
const INK := Color("141428")

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


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _block(p: Vector2, c: Color, s: float = PX) -> void:
	draw_rect(Rect2((p / PX).floor() * PX - Vector2(s, s) * 0.5 + Vector2(PX, PX) * 0.5, Vector2(s, s)), c)


func _draw() -> void:
	var dir := Vector2.from_angle(angle)
	var nrm := Vector2(-dir.y, dir.x)
	var a := 0.55 if blocked else 1.0
	var start := ball_pos + dir * (ball_radius + 10.0)
	var length := 30.0 + 120.0 * power
	var fill := _power_color(shot_power).lerp(color, 0.25)
	# One solid arrow polygon with a thick ink outline (a solid shape, never dots, so it cannot be
	# mistaken for a flight path).
	var hw := 5.0
	var head_w := 15.0
	var head_l := 24.0
	var tip := start + dir * (length + head_l)
	var neck := start + dir * length
	var arrow := PackedVector2Array([
		start + nrm * hw, neck + nrm * hw, neck + nrm * head_w, tip,
		neck - nrm * head_w, neck - nrm * hw, start - nrm * hw])
	var outline := Geometry2D.offset_polygon(arrow, 3.5, Geometry2D.JOIN_MITER)
	if not outline.is_empty():
		draw_colored_polygon(outline[0], Color(INK, a))
	draw_colored_polygon(arrow, Color(fill, a))
	# Lit upper edge.
	draw_colored_polygon(PackedVector2Array([start + nrm * -hw, neck + nrm * -hw, neck + nrm * -(hw - 2.0), start + nrm * -(hw - 2.0)]), Color(1, 1, 1, 0.45 * a))
	_draw_label(tip + dir * 22.0, "%d%%" % roundi(shot_power * 100.0), Color(fill, a), 22)
	if putting:
		_draw_label(ball_pos + Vector2(0, -44), "PUTT", Color("9be36b"), 20)
	var below := 40.0
	if classic:
		_draw_meter(ball_pos + Vector2(0, 34))
		below = 70.0
	if absf(spin) > 0.01:
		var top := spin > 0.0
		var txt := "%s %d%%" % ["TOPSPIN" if top else "BACKSPIN", roundi(absf(spin) * 100.0)]
		_draw_label(ball_pos + Vector2(0, below), txt, Color("ffb347") if top else Color("6fd6ff"), 17)
		_draw_spin_glyph(ball_pos, top, absf(spin))


func _draw_spin_glyph(c: Vector2, top: bool, amount: float) -> void:
	# A ring of blocks around the ball, rotating in the spin direction.
	var r := ball_radius + 5.0
	var n := 10
	var dirn := 1.0 if top else -1.0
	for i in n:
		var t := float(i) / float(n)
		if t > 0.35 + 0.6 * amount:
			continue
		var ang := _t * 6.0 * dirn + t * TAU * dirn
		_block(c + Vector2.from_angle(ang) * r, Color(Color("ffb347") if top else Color("6fd6ff"), 1.0 - t * 0.8))


## Classic power meter: a horizontal segmented bar under the ball (clear of the golfer).
func _draw_meter(c: Vector2) -> void:
	var w := 132.0
	var h := 14.0
	var x0 := c.x - w * 0.5
	var y := c.y
	draw_rect(Rect2(x0 - 3, y - 3, w + 6, h + 6), INK)
	draw_rect(Rect2(x0, y, w, h), Color(1, 1, 1, 0.08))
	var cells := 12
	var gap := 2.0
	var cw := (w - gap * (cells - 1)) / cells
	for i in cells:
		var k := float(i + 1) / float(cells)
		var lit := power >= k - 0.5 / cells
		var col := _power_color(k * (ShotController.PUTT_POWER if putting else 1.0))
		draw_rect(Rect2(x0 + i * (cw + gap), y, cw, h), col if lit else Color(col, 0.16))
	if meter:
		var mx := x0 + w * power
		draw_rect(Rect2(mx - 2, y - 6, 4, h + 12), Color.WHITE)
		draw_rect(Rect2(mx - 3, y - 6, 1, h + 12), INK)
		draw_rect(Rect2(mx + 2, y - 6, 1, h + 12), INK)


func _draw_label(p: Vector2, text: String, col: Color, size: int) -> void:
	var f := UITheme.heading_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := (p + Vector2(-w * 0.5, size * 0.35)).floor()
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, INK)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _power_color(p: float) -> Color:
	if p < 0.5:
		return Color("f4f4f8").lerp(Color("ffd166"), p / 0.5)
	return Color("ffd166").lerp(Color("ff5a3c"), (p - 0.5) / 0.5)
