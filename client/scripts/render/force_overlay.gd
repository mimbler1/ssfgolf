class_name ForceOverlay
extends Node2D
## Makes invisible forces readable (PHYSICS_SPEC.md §4 conveyors, §6 gravity fields):
## - gravity fields: tinted region, a label and pixel chevrons streaming in the gravity direction
##   (speed and density follow its strength; zero-G shows slow floating motes);
## - conveyor belts: chevrons running along the belt surface in its direction of travel.
## Drawn in 2 px blocks to match the stage pixel density. Purely visual; never touches physics.

const PX := 2.0

var terrain: SimTerrain
var base_gravity := 1500.0
var _belts: Array[Dictionary] = []   ## {a, b, n, speed}
var _t := 0.0


func setup(p_terrain: SimTerrain, materials: Dictionary, gravity: float) -> void:
	terrain = p_terrain
	base_gravity = gravity
	_belts.clear()
	for i in terrain.seg_a.size():
		var mname := terrain.material_names[terrain.seg_mat[i]]
		var speed := float((materials.get(mname, {}) as Dictionary).get("surface_speed", 0.0))
		if speed != 0.0:
			_belts.append({"a": terrain.seg_a[i], "b": terrain.seg_b[i], "n": terrain.seg_n[i], "speed": speed})
	z_index = 2
	visible = not terrain.fields.is_empty() or not _belts.is_empty()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _block(p: Vector2, c: Color, s: float = PX) -> void:
	draw_rect(Rect2((p / PX).floor() * PX, Vector2(s, s)), c)


func _chevron(p: Vector2, dir: Vector2, size: float, c: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var k := -size
	while k <= size:
		_block(p - dir * absf(k) * 0.9 + side * k, c, PX * 1.5)
		k += PX
	return


func _draw() -> void:
	if terrain == null:
		return
	for f in terrain.fields:
		_draw_field(f)
	for b in _belts:
		_draw_belt(b)


func _draw_field(f: Dictionary) -> void:
	var r: Rect2 = f.rect
	var g: Vector2 = f.vector if f.has_vector else Vector2(0, base_gravity) * float(f.scale)
	var strength := g.length() / base_gravity
	var col := Color("7cf2c9")          # low gravity
	var label := "LOW G"
	if strength < 0.05:
		col = Color("b9a6ff")
		label = "0 G"
	elif f.has_vector and g.y < -1.0:
		col = Color("ff6ad5")
		label = "LIFT"
	elif f.has_vector and absf(g.x) > 1.0:
		col = Color("ffb347")
		label = "PULL"
	elif strength > 1.2:
		col = Color("ff7b2e")
		label = "HEAVY"
	draw_colored_polygon(f.points, Color(col, 0.11))
	# Dashed pixel border.
	var pts: PackedVector2Array = f.points
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := a.distance_to(b)
		var dir := (b - a) / maxf(d, 0.001)
		var s := fmod(_t * 30.0, 24.0)
		while s < d:
			draw_rect(Rect2((a + dir * s).floor(), Vector2(PX * 5 if absf(dir.x) > 0.5 else PX, PX if absf(dir.x) > 0.5 else PX * 5)), Color(col, 0.55))
			s += 24.0
	var f2 := UITheme.heading_font()
	var lp := (r.position + Vector2(12, 26)).floor()
	draw_string_outline(f2, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color("141428"))
	draw_string(f2, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	# Flow: chevrons on a grid, scrolling along gravity at a speed that follows its strength.
	var spacing := 90.0
	if strength < 0.05:
		# Zero-G: slow floating motes.
		var y := r.position.y + 30.0
		var i := 0
		while y < r.end.y:
			var x := r.position.x + 40.0 + float(i % 2) * 45.0
			while x < r.end.x:
				var bob := Vector2(sin(_t * 0.9 + x * 0.01) * 6.0, cos(_t * 0.7 + y * 0.013) * 6.0)
				_block(Vector2(x, y) + bob, Color(col, 0.6), PX * 2)
				x += spacing
			y += spacing
			i += 1
		return
	var dirg := g / g.length()
	var speed := clampf(strength, 0.25, 2.5) * 70.0
	var off := fmod(_t * speed, spacing)
	var side := Vector2(-dirg.y, dirg.x)
	var c0 := r.get_center()
	var span := r.size.length() * 0.5 + spacing
	var u := -span
	while u <= span:
		var v := -span
		while v <= span:
			var p := c0 + side * u + dirg * (v + off)
			if r.grow(-10.0).has_point(p) and SimTerrain.point_in_polygon(p, f.points):
				_chevron(p, dirg, 9.0, Color(col, 0.55))
			v += spacing * (0.7 if strength > 1.2 else 1.0)
		u += spacing
	return


func _draw_belt(b: Dictionary) -> void:
	var a: Vector2 = b.a
	var e: Vector2 = b.b
	var n: Vector2 = b.n
	var d := a.distance_to(e)
	if d < 4.0:
		return
	# Surface tangent (-n.y, n.x) is the direction a positive surface_speed moves the ball.
	var tan := Vector2(-n.y, n.x) * signf(float(b.speed))
	var seg := (e - a) / d
	# A dark belt band just under the surface, with big yellow chevrons that scroll the way it runs.
	var band := PackedVector2Array([a, e, e - n * 14.0, a - n * 14.0])
	draw_colored_polygon(band, Color("2b2533"))
	draw_line(a - n * 14.0, e - n * 14.0, Color("141428"), 2.0)
	var spacing := 34.0
	var s := fmod(_t * absf(float(b.speed)) * 0.4 * signf(tan.dot(seg)), spacing)
	if s < 0.0:
		s += spacing
	while s < d:
		_chevron(a + seg * s - n * 7.0, tan, 6.0, Color("ffd166"))
		s += spacing
