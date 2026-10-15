class_name Icon
extends Control
## Small vector UI icons (no emoji/font dependency). Size via custom_minimum_size.

var kind: String = "star":
	set(v):
		kind = v
		queue_redraw()
var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()


static func make(p_kind: String, px: float = 28.0, p_color: Color = Color.WHITE) -> Icon:
	var i := Icon.new()
	i.kind = p_kind
	i.color = p_color
	i.custom_minimum_size = Vector2(px, px)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var ink := Color("11142b")
	var lw := maxf(1.5, s * 0.08)
	match kind:
		"trophy":
			var gold := Color("ffb703")
			var cup := PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.38), c + Vector2(s * 0.32, -s * 0.38), c + Vector2(s * 0.24, -s * 0.02), c + Vector2(0, s * 0.12), c + Vector2(-s * 0.24, -s * 0.02)])
			draw_arc(c + Vector2(-s * 0.3, -s * 0.2), s * 0.14, PI * 0.5, PI * 1.5, 10, ink, lw * 2.2, true)
			draw_arc(c + Vector2(s * 0.3, -s * 0.2), s * 0.14, -PI * 0.5, PI * 0.5, 10, ink, lw * 2.2, true)
			draw_arc(c + Vector2(-s * 0.3, -s * 0.2), s * 0.14, PI * 0.5, PI * 1.5, 10, gold, lw, true)
			draw_arc(c + Vector2(s * 0.3, -s * 0.2), s * 0.14, -PI * 0.5, PI * 0.5, 10, gold, lw, true)
			_poly(cup, gold, ink, lw)
			_poly(PackedVector2Array([c + Vector2(-s * 0.07, s * 0.1), c + Vector2(s * 0.07, s * 0.1), c + Vector2(s * 0.09, s * 0.28), c + Vector2(-s * 0.09, s * 0.28)]), gold.darkened(0.15), ink, lw)
			_poly(PackedVector2Array([c + Vector2(-s * 0.24, s * 0.28), c + Vector2(s * 0.24, s * 0.28), c + Vector2(s * 0.24, s * 0.42), c + Vector2(-s * 0.24, s * 0.42)]), gold.darkened(0.3), ink, lw)
			draw_line(c + Vector2(-s * 0.16, -s * 0.3), c + Vector2(-s * 0.12, -s * 0.08), Color(1, 1, 1, 0.6), lw, true)
		"coin":
			draw_circle(c, s * 0.42 + lw, ink, true, -1.0, true)
			draw_circle(c, s * 0.42, Color("ffd166"), true, -1.0, true)
			draw_circle(c, s * 0.3, Color("f4a91e"), true, -1.0, true)
			draw_circle(c, s * 0.24, Color("ffd166"), true, -1.0, true)
			draw_rect(Rect2(c + Vector2(-s * 0.04, -s * 0.15), Vector2(s * 0.08, s * 0.3)), Color("f4a91e"))
			draw_arc(c, s * 0.36, PI * 1.1, PI * 1.45, 6, Color(1, 1, 1, 0.7), lw, true)
		"xp", "star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + PI * float(i) / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s * 0.46 if i % 2 == 0 else s * 0.2))
			_poly(pts, color if kind == "star" else Color("80ed99"), ink, lw)
		"crown":
			var pts2 := PackedVector2Array([c + Vector2(-s * 0.42, s * 0.3), c + Vector2(s * 0.42, s * 0.3), c + Vector2(s * 0.46, -s * 0.28),
				c + Vector2(s * 0.2, -s * 0.02), c + Vector2(0, -s * 0.38), c + Vector2(-s * 0.2, -s * 0.02), c + Vector2(-s * 0.46, -s * 0.28)])
			_poly(pts2, Color("ffd166"), ink, lw)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.32, 0), c + Vector2(-s * 0.08, s * 0.25), c + Vector2(s * 0.36, -s * 0.28)]), ink, lw * 3.2, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.32, 0), c + Vector2(-s * 0.08, s * 0.25), c + Vector2(s * 0.36, -s * 0.28)]), color, lw * 1.6, true)
		"flag":
			draw_line(c + Vector2(-s * 0.25, s * 0.42), c + Vector2(-s * 0.25, -s * 0.42), ink, lw * 1.6, true)
			_poly(PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.42), c + Vector2(s * 0.38, -s * 0.24), c + Vector2(-s * 0.22, -s * 0.04)]), Color("ff4d6d"), ink, lw)
		"gear":
			var pts3 := PackedVector2Array()
			for i in 32:
				var a := TAU * float(i) / 32.0
				var r := s * (0.44 if (i / 2) % 2 == 0 else 0.34)
				pts3.append(c + Vector2(cos(a), sin(a)) * r)
			_poly(pts3, color, ink, lw)
			draw_circle(c, s * 0.14, ink, true, -1.0, true)
		"user":
			draw_circle(c + Vector2(0, -s * 0.16), s * 0.2 + lw, ink, true, -1.0, true)
			draw_circle(c + Vector2(0, -s * 0.16), s * 0.2, color, true, -1.0, true)
			draw_arc(c + Vector2(0, s * 0.42), s * 0.34, PI, TAU, 16, ink, lw * 3.0, true)
			draw_arc(c + Vector2(0, s * 0.42), s * 0.34, PI, TAU, 16, color, lw * 1.5, true)
		"copy":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.38), Vector2(s * 0.5, s * 0.58)), color, false, lw, true)
			draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.2), Vector2(s * 0.5, s * 0.58)), color, false, lw, true)
		"wifi_off":
			for i in 3:
				draw_arc(c + Vector2(0, s * 0.3), s * (0.18 + i * 0.16), PI * 1.2, PI * 1.8, 10, color, lw, true)
			draw_line(c + Vector2(-s * 0.4, -s * 0.4), c + Vector2(s * 0.4, s * 0.4), Color("ef476f"), lw * 1.4, true)
		_:
			draw_circle(c, s * 0.3, color, true, -1.0, true)


func _poly(pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, width, true)
