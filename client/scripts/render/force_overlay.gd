class_name ForceOverlay
extends Node2D
## Makes invisible forces readable (PHYSICS_SPEC.md §4 conveyors, §6 gravity fields), drawn in
## the ink style (docs/INK_ART_SPEC.md §9):
## - gravity fields: a tinted region with a dashed hand-drawn border, a hand-lettered label and
##   ink chevrons streaming in the gravity direction (speed and density follow its strength;
##   zero-G shows slow floating motes);
## - conveyor belts: a rubber band with chevrons running the way the belt moves.
## Purely visual; never touches physics.

const INK := InkCanvas.INK

var terrain: SimTerrain
var base_gravity := 1500.0
var _belts: Array[Dictionary] = []   ## {a, b, n, speed}
var _t := 0.0
var _cv := InkCanvas.new()


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
	set_process(visible)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _chevron(p: Vector2, dir: Vector2, size: float, c: Color, w: float = 2.6) -> void:
	var side := Vector2(-dir.y, dir.x)
	_cv.stroke(PackedVector2Array([p - dir * size * 0.6 + side * size, p + dir * size * 0.4, p - dir * size * 0.6 - side * size]), w, c, 0.15, 0.15)


func _draw() -> void:
	if terrain == null:
		return
	var labels: Array = []
	for f in terrain.fields:
		labels.append(_draw_field(f))
	for b in _belts:
		_draw_belt(b)
	_cv.flush(get_canvas_item())
	var font := UITheme.heading_font()
	for l: Array in labels:
		draw_string_outline(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, InkCanvas.PAPER)
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, (l[2] as Color).darkened(0.45))


func _draw_field(f: Dictionary) -> Array:
	var r: Rect2 = f.rect
	var g: Vector2 = f.vector if f.has_vector else Vector2(0, base_gravity) * float(f.scale)
	var strength := g.length() / base_gravity
	var col := Color("3dbf9f")
	var label := "LOW G"
	if strength < 0.05:
		col = Color("8a6be8")
		label = "0 G"
	elif f.has_vector and g.y < -1.0:
		col = Color("e85aa8")
		label = "LIFT"
	elif f.has_vector and absf(g.x) > 1.0:
		col = Color("f28c38")
		label = "PULL"
	elif strength > 1.2:
		col = Color("e8543a")
		label = "HEAVY"
	var pts: PackedVector2Array = f.points
	_cv.fill(pts, Color(col, 0.1))
	# Dashed hand-drawn border, marching slowly.
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := a.distance_to(b)
		var dir := (b - a) / maxf(d, 0.001)
		var s := fmod(_t * 30.0, 28.0)
		while s < d:
			var e := minf(s + 16.0, d)
			_cv.stroke(PackedVector2Array([a + dir * s, a + dir * e]), 2.6, Color(col.darkened(0.25), 0.7), 0.2, 0.2)
			s += 28.0
	var lp := r.position + Vector2(14, 30)
	var spacing := 90.0
	if strength < 0.05:
		var y := r.position.y + 30.0
		var row := 0
		while y < r.end.y:
			var x := r.position.x + 40.0 + float(row % 2) * 45.0
			while x < r.end.x:
				var bob := Vector2(sin(_t * 0.9 + x * 0.01) * 6.0, cos(_t * 0.7 + y * 0.013) * 6.0)
				_cv.ellipse(Vector2(x, y) + bob, Vector2(4, 4), Color(col, 0.35))
				_cv.ink_circle(Vector2(x, y) + bob, Vector2(4, 4), 1.4, Color(col.darkened(0.3), 0.7), x)
				x += spacing
			y += spacing
			row += 1
		return [lp, label, col]
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
				_chevron(p, dirg, 9.0, Color(col.darkened(0.2), 0.65))
			v += spacing * (0.7 if strength > 1.2 else 1.0)
		u += spacing
	return [lp, label, col]


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
	var band := PackedVector2Array([a, e, e - n * 14.0, a - n * 14.0])
	_cv.fill(band, Color("3b3340"))
	_cv.stroke(PackedVector2Array([a - n * 14.0, e - n * 14.0]), 2.2, INK, 0.0001, 0.0001)
	var spacing := 34.0
	var s := fmod(_t * absf(float(b.speed)) * 0.4 * signf(tan.dot(seg)), spacing)
	if s < 0.0:
		s += spacing
	while s < d:
		_chevron(a + seg * s - n * 7.0, tan, 5.0, Color("f2b630"), 2.4)
		s += spacing
