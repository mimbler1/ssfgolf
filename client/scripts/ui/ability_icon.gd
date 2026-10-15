class_name AbilityIcon
extends Control
## Vector icon for a ball ability. Draws centred in its rect.

var ability: String = "standard":
	set(v):
		ability = v
		queue_redraw()
var dimmed: bool = false:
	set(v):
		dimmed = v
		queue_redraw()
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if ability in ["nitro", "grenade"]:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	var ink := Color("1b2040")
	var mod := Color(1, 1, 1, 0.4) if dimmed else Color.WHITE
	match ability:
		"standard":
			_ball(c, r, Color("f4f4f8") * mod, ink)
			for a in [0.4, 2.0, 3.6, 5.0]:
				draw_circle(c + Vector2.from_angle(a) * r * 0.5, r * 0.09, Color("c5c9d6"), true, -1.0, true)
		"nitro":
			var flick := sin(_t * 14.0) * r * 0.06
			var flame := PackedVector2Array()
			for i in 25:
				var u := float(i) / 24.0
				var a := lerpf(-PI * 0.5, PI * 1.5, u)
				var rr := r * (0.65 + 0.35 * absf(sin(a * 1.5)))
				var p := Vector2(cos(a) * rr * 0.8, sin(a) * rr)
				if p.y < 0:
					p.y *= 1.5
					p.x *= 0.75
				flame.append(c + p + Vector2(0, r * 0.15 + flick * (1.0 if i % 2 == 0 else -1.0)))
			draw_colored_polygon(flame, Color("ff7b2e") * mod)
			draw_polyline(flame + PackedVector2Array([flame[0]]), ink, 2.5, true)
			_ball(c + Vector2(0, r * 0.3), r * 0.45, Color("ffd166") * mod, ink)
		"sticky":
			_ball(c, r, Color("b65cff") * mod, ink)
			for x in [-0.45, 0.1, 0.5]:
				var top := c + Vector2(r * x, r * 0.55)
				draw_line(top, top + Vector2(0, r * (0.35 + absf(x) * 0.3)), Color("7b2cbf") * mod, r * 0.22, true)
				draw_circle(top + Vector2(0, r * (0.35 + absf(x) * 0.3)), r * 0.14, Color("7b2cbf") * mod, true, -1.0, true)
			draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.2, Color(1, 1, 1, 0.6), true, -1.0, true)
		"grenade":
			_ball(c + Vector2(0, r * 0.12), r * 0.9, Color("56c271") * mod, ink)
			draw_line(c + Vector2(-r * 0.6, r * 0.12), c + Vector2(r * 0.6, r * 0.12), Color("2f7a45"), 2.0, true)
			draw_rect(Rect2(c + Vector2(-r * 0.22, -r * 0.95), Vector2(r * 0.44, r * 0.3)), Color("8d99ae") * mod)
			draw_arc(c + Vector2(r * 0.35, -r * 0.85), r * 0.22, 0, TAU, 12, ink, 2.0, true)
			var spark := 0.5 + 0.5 * sin(_t * 16.0)
			draw_circle(c + Vector2(-r * 0.15, -r * 1.1), r * (0.12 + spark * 0.1), Color("ffd166"), true, -1.0, true)
		"heavy":
			var w := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, -r * 0.55),
				c + Vector2(r * 0.95, r * 0.8), c + Vector2(-r * 0.95, r * 0.8)])
			draw_colored_polygon(w, Color("7d8597") * mod)
			draw_polyline(w + PackedVector2Array([w[0]]), ink, 2.5, true)
			draw_arc(c + Vector2(0, -r * 0.6), r * 0.35, PI, TAU, 12, ink, r * 0.16, true)
			var f := UITheme.heading_font()
			draw_string(f, c + Vector2(-r * 0.6, r * 0.55), "4x", HORIZONTAL_ALIGNMENT_CENTER, r * 1.2, int(r * 0.85), Color.WHITE * mod)
		"air_brake":
			var top := c + Vector2(0, -r * 0.15)
			var chute := PackedVector2Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				chute.append(top + Vector2(cos(a) * r, sin(a) * r * 0.7))
			draw_colored_polygon(chute, Color("4cc9f0") * mod)
			draw_polyline(chute + PackedVector2Array([chute[0]]), ink, 2.5, true)
			for x in [-1.0, 0.0, 1.0]:
				draw_line(top + Vector2(x * r * 0.95, 0), c + Vector2(0, r * 0.65), ink, 1.6, true)
			_ball(c + Vector2(0, r * 0.75), r * 0.3, Color("f4f4f8") * mod, ink)
		_:
			_ball(c, r, Color.WHITE * mod, ink)


func _ball(c: Vector2, r: float, fill: Color, ink: Color) -> void:
	draw_circle(c, r + 2.5, ink, true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)
	draw_circle(c + Vector2(-r * 0.32, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.65), true, -1.0, true)
