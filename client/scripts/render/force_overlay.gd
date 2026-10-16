class_name ForceOverlay
extends Node2D
## Makes invisible forces readable (PHYSICS_SPEC.md §4 conveyors, §6 gravity fields), drawn in
## the ink style (docs/INK_ART_SPEC.md §9):
## - gravity fields: a tinted region with a dashed hand-drawn border, a hand-lettered label and
##   ink chevrons streaming in the gravity direction (speed and density follow its strength;
##   zero-G shows slow floating motes);
## - conveyor belts: a rubber band with chevrons running the way the belt moves.
## Fields are built once: the chevron grid is static geometry clipped to the field shape and only
## its offset moves each frame. Purely visual; never touches physics.

const INK := InkCanvas.INK
const SPACING := 90.0

var terrain: SimTerrain
var base_gravity := 1500.0
var _belts: Array[Dictionary] = []   ## {a, b, n, speed}
var _flows: Array[Dictionary] = []   ## {node, dir, speed, zero_g}
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
	for f in terrain.fields:
		_build_field(f)
	visible = not terrain.fields.is_empty() or not _belts.is_empty()
	set_process(visible)


func _field_style(f: Dictionary) -> Array:
	var g: Vector2 = f.vector if f.has_vector else Vector2(0, base_gravity) * float(f.scale)
	var strength := g.length() / base_gravity
	if strength < 0.05:
		return [Color("8a6be8"), "0 G", g, strength]
	if f.has_vector and g.y < -1.0:
		return [Color("e85aa8"), "LIFT", g, strength]
	if f.has_vector and absf(g.x) > 1.0:
		return [Color("f28c38"), "PULL", g, strength]
	if strength > 1.2:
		return [Color("e8543a"), "HEAVY", g, strength]
	return [Color("3dbf9f"), "LOW G", g, strength]


func _build_field(f: Dictionary) -> void:
	var style := _field_style(f)
	var col: Color = style[0]
	var g: Vector2 = style[2]
	var strength: float = style[3]
	var pts: PackedVector2Array = f.points
	var r: Rect2 = f.rect
	# Mask: the tinted field shape; the flow grid is clipped to it.
	var tint := _Mask.new()
	tint.poly = pts
	tint.color = Color(col, 0.1)
	add_child(tint)
	# Opaque mask used only for clipping (clip strength follows the mask's alpha).
	var mask := _Mask.new()
	mask.poly = pts
	mask.color = Color.WHITE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(mask)
	var flow_cv := InkCanvas.new()
	var zero_g := strength < 0.05
	var dirg := Vector2.DOWN if zero_g else g / g.length()
	var side := Vector2(-dirg.y, dirg.x)
	var c0 := r.get_center()
	var span := r.size.length() * 0.5 + SPACING * 2.0
	var u := -span
	var row := 0
	while u <= span:
		var v := -span
		while v <= span:
			var p := c0 + side * u + dirg * v
			if zero_g:
				var q := p + side * (float(row % 2) * 45.0)
				flow_cv.ellipse(q, Vector2(4, 4), Color(col, 0.35))
				flow_cv.ink_circle(q, Vector2(4, 4), 1.4, Color(col.darkened(0.3), 0.7), q.x)
			else:
				var size := 9.0
				flow_cv.stroke(PackedVector2Array([p - dirg * size * 0.6 + side * size, p + dirg * size * 0.4, p - dirg * size * 0.6 - side * size]), 2.6, Color(col.darkened(0.2), 0.65), 0.15, 0.15, p.x)
			v += SPACING * (0.7 if strength > 1.2 else 1.0)
		u += SPACING
		row += 1
	var flow := InkStatic.new()
	flow.canvas = flow_cv
	mask.add_child(flow)
	_flows.append({"node": flow, "dir": dirg, "speed": clampf(strength, 0.25, 2.5) * 70.0, "zero_g": zero_g,
		"step": SPACING * (0.7 if strength > 1.2 else 1.0)})
	# Static dashed border and label.
	var deco := InkCanvas.new()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := a.distance_to(b)
		var dir := (b - a) / maxf(d, 0.001)
		var s := 0.0
		while s < d:
			deco.stroke(PackedVector2Array([a + dir * s, a + dir * minf(s + 16.0, d)]), 2.6, Color(col.darkened(0.25), 0.7), 0.2, 0.2, s)
			s += 28.0
	var st := InkStatic.new()
	st.canvas = deco
	add_child(st)
	var label := _Label.new()
	label.text = str(style[1])
	label.color = col
	label.position = r.position + Vector2(14, 30)
	add_child(label)


func _process(delta: float) -> void:
	_t += delta
	for fl in _flows:
		var node: Node2D = fl.node
		if bool(fl.zero_g):
			node.position = Vector2(sin(_t * 0.9) * 6.0, cos(_t * 0.7) * 6.0)
		else:
			node.position = (fl.dir as Vector2) * fmod(_t * float(fl.speed), float(fl.step))
	if not _belts.is_empty():
		queue_redraw()


func _chevron(p: Vector2, dir: Vector2, size: float, c: Color, w: float = 2.6) -> void:
	var side := Vector2(-dir.y, dir.x)
	_cv.stroke(PackedVector2Array([p - dir * size * 0.6 + side * size, p + dir * size * 0.4, p - dir * size * 0.6 - side * size]), w, c, 0.15, 0.15)


func _draw() -> void:
	for b in _belts:
		_draw_belt(b)
	_cv.flush(get_canvas_item())


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
	_cv.fill(PackedVector2Array([a, e, e - n * 14.0, a - n * 14.0]), Color("3b3340"))
	_cv.stroke(PackedVector2Array([a - n * 14.0, e - n * 14.0]), 2.2, INK, 0.0001, 0.0001)
	var spacing := 34.0
	var s := fmod(_t * absf(float(b.speed)) * 0.4 * signf(tan.dot(seg)), spacing)
	if s < 0.0:
		s += spacing
	while s < d:
		_chevron(a + seg * s - n * 7.0, tan, 5.0, Color("f2b630"), 2.4)
		s += spacing


class _Mask extends Node2D:
	var poly := PackedVector2Array()
	var color := Color.WHITE

	func _draw() -> void:
		draw_colored_polygon(poly, color)


class _Label extends Node2D:
	var text := ""
	var color := Color.WHITE

	func _draw() -> void:
		var font := UITheme.heading_font()
		draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, InkCanvas.PAPER)
		draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color.darkened(0.45))
