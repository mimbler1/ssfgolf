class_name TrajectoryView
extends Node2D
## Predicted flight path, computed from the same physics the server runs. It is shown ONLY:
##  - as the Laser Ball's guide ("laser" style) while the Laser Ball is selected, or
##  - as a practice-mode debug overlay ("debug" style) that the player switches on explicitly.
## Regular shots never show it (docs/POWERUP_SPEC.md, Laser). It previews terrain only:
## opponents, abilities triggered later and network latency can still change the outcome.

var points: PackedVector2Array = PackedVector2Array()
var contact_index: int = -1
var power: float = 0.0
var color: Color = Color.WHITE
var hazard: bool = false
var style := "laser"
var _t: float = 0.0


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
	else:
		_draw_debug()
	if hazard:
		# Warn when the previewed path ends in a hazard or out of bounds.
		var end := points[points.size() - 1]
		var r := 10.0
		var warn := Color("ff4d6d")
		draw_line(end + Vector2(-r, -r), end + Vector2(r, r), Color("1b2040"), 7.0)
		draw_line(end + Vector2(-r, r), end + Vector2(r, -r), Color("1b2040"), 7.0)
		draw_line(end + Vector2(-r, -r), end + Vector2(r, r), warn, 4.0)
		draw_line(end + Vector2(-r, r), end + Vector2(r, -r), warn, 4.0)


## Laser guide: a solid pulsing beam up to the first bounce, then a fading short continuation.
func _draw_laser() -> void:
	var beam := Color("ff3d6e")
	var pulse := 0.75 + 0.25 * sin(_t * 9.0)
	var last := points.size() - 1
	var cut := contact_index if contact_index > 0 else last
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var after := i > cut
		var k := 0.0 if not after else float(i - cut) / maxf(1.0, float(last - cut))
		var alpha := (1.0 - k) * (0.35 if after else 1.0)
		draw_line(a, b, Color(beam, 0.22 * alpha * pulse), 10.0)
		draw_line(a, b, Color(beam, 0.95 * alpha), 3.0)
		draw_line(a, b, Color(1, 0.9, 0.92, 0.8 * alpha), 1.0)
	# Travelling sparks along the beam so it reads as a laser, not a drawn line.
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
					var p := points[i - 1].lerp(points[i], (target - acc) / maxf(seg, 0.001))
					draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.9))
					break
				acc += seg
	if contact_index > 0 and contact_index < points.size():
		var land := points[contact_index]
		var r := 13.0 + pulse * 3.0
		for side in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(land + side * (r - 7.0), land + side * (r + 5.0), Color("1b2040"), 5.0)
			draw_line(land + side * (r - 7.0), land + side * (r + 5.0), beam, 3.0)
		draw_arc(land, r, 0, TAU, 32, beam, 2.0)


## Practice debug overlay: the old dotted path, white, clearly not the laser.
func _draw_debug() -> void:
	var spacing := 18.0
	var phase := fmod(_t * 40.0, spacing)
	var acc := spacing - phase
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
			var c := Color(1, 1, 1, (1.0 - k * 0.75) * (0.4 if after else 0.8))
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.1, 0.2, c.a * 0.6))
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), c)
		acc -= seg - d
