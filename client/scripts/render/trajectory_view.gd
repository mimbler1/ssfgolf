class_name TrajectoryView
extends Node2D
## Dotted aim preview computed from the same physics the server runs.
## It previews terrain only: opponents, abilities triggered later, and latency can change the outcome.

var points: PackedVector2Array = PackedVector2Array()
var contact_index: int = -1
var power: float = 0.0
var color: Color = Color.WHITE
var hazard: bool = false
var _t: float = 0.0


func set_path(p_points: PackedVector2Array, p_contact: int, p_power: float, p_color: Color, p_hazard: bool = false) -> void:
	points = p_points
	hazard = p_hazard
	contact_index = p_contact
	power = p_power
	color = p_color
	queue_redraw()


func clear() -> void:
	points = PackedVector2Array()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if points.size() > 0:
		queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var total := 0.0
	var spacing := 18.0
	var phase := fmod(_t * 40.0, spacing)
	var acc := spacing - phase
	var drawn := 0
	var end_index := points.size() - 1
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
			var c := color
			c.a = (1.0 - k * 0.75) * (0.45 if after else 0.95)
			var r := lerpf(5.0, 2.5, k)
			draw_circle(p, r + 1.6, Color(0.1, 0.1, 0.2, c.a * 0.55), true, -1.0, true)
			draw_circle(p, r, c, true, -1.0, true)
			drawn += 1
		acc -= seg - d
		total += seg
	if contact_index > 0 and contact_index < points.size():
		var land := points[contact_index]
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(land, 12.0 + pulse * 3.0, 0, TAU, 32, Color(color, 0.9), 3.0, true)
		draw_arc(land, 5.0, 0, TAU, 16, Color(color, 0.9), 2.0, true)
	if hazard:
		# Warn when the previewed path ends in water/lava or out of bounds.
		var end := points[points.size() - 1]
		var r := 10.0
		var warn := Color("ff4d6d")
		draw_line(end + Vector2(-r, -r), end + Vector2(r, r), Color("1b2040"), 7.0, true)
		draw_line(end + Vector2(-r, r), end + Vector2(r, -r), Color("1b2040"), 7.0, true)
		draw_line(end + Vector2(-r, -r), end + Vector2(r, r), warn, 4.0, true)
		draw_line(end + Vector2(-r, r), end + Vector2(r, -r), warn, 4.0, true)
