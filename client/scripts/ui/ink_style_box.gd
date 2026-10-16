class_name InkStyleBox
extends StyleBox
## Hand-drawn panel/button frame (docs/INK_ART_SPEC.md §10): a slightly wobbly rounded shape with
## a paper or colour fill, an inked rim of varying weight, an optional darker bottom lip (button
## depth) and an offset drop shadow. The wobble is seeded by the rect size, so a box keeps one
## stable hand-drawn shape; geometry is cached per size.

var fill := Color("fbf6ec")
var ink := InkCanvas.INK
var ink_width := 3.0
var radius := 14.0
var wobble := 1.4
var lip := 0.0
var lip_color := Color(0, 0, 0, 0.18)
var shadow := 0.0
var shadow_color := Color(0.11, 0.09, 0.08, 0.22)
## Optional hatching inside the fill (pressed/selected cards).
var hatch := 0.0
var hatch_color := Color(0, 0, 0, 0.08)
var seed_value := 0

var _cache: Dictionary = {}


static func make(p_fill: Color, p_ink_width: float = 3.0, p_radius: float = 14.0, p_lip: float = 0.0, p_shadow: float = 0.0) -> InkStyleBox:
	var s := InkStyleBox.new()
	s.fill = p_fill
	s.ink_width = p_ink_width
	s.radius = p_radius
	s.lip = p_lip
	s.shadow = p_shadow
	s.lip_color = p_fill.darkened(0.25)
	s.set_content_margin_all(12.0)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_bottom = 12.0 + p_lip
	return s


func copy() -> InkStyleBox:
	var s := InkStyleBox.new()
	for prop in ["fill", "ink", "ink_width", "radius", "wobble", "lip", "lip_color", "shadow", "shadow_color", "hatch", "hatch_color", "seed_value"]:
		s.set(prop, get(prop))
	for side in 4:
		s.set_content_margin(side, get_content_margin(side))
	return s


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(ink_width + wobble + 1.0).expand(rect.end + Vector2(shadow, shadow))


static func outline_pts(rect: Rect2, r: float, wob: float, seed_v: float) -> PackedVector2Array:
	r = maxf(0.5, minf(r, minf(rect.size.x, rect.size.y) * 0.5 - 0.6))
	var c := [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r), rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	var start := [PI, PI * 1.5, 0.0, PI * 0.5]
	var pts := PackedVector2Array()
	for i in 4:
		var cc: Vector2 = c[i]
		var steps := 6
		for k in steps + 1:
			pts.append(cc + Vector2.from_angle(float(start[i]) + PI * 0.5 * k / steps) * r)
		# Straight side to the next corner, subdivided so the wobble can bend it.
		var nxt: Vector2 = c[(i + 1) % 4] + Vector2.from_angle(float(start[(i + 1) % 4])) * r
		var cur := pts[pts.size() - 1]
		var segs := maxi(1, int(cur.distance_to(nxt) / 24.0))
		for k in range(1, segs):
			pts.append(cur.lerp(nxt, float(k) / segs))
	var cen := rect.get_center()
	var out := PackedVector2Array()
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		var dir := (pts[i] - cen).normalized()
		out.append(pts[i] + dir * wob * InkCanvas.noise(acc * 0.045, seed_v))
	return out


func _build(rect: Rect2) -> InkCanvas:
	var cv := InkCanvas.new()
	var s := float(hash(Vector2i(rect.size)) % 997) + float(seed_value)
	var shape := outline_pts(rect, radius, wobble, s)
	if shadow > 0.0:
		var sh := PackedVector2Array()
		for v in shape:
			sh.append(v + Vector2(shadow * 0.6, shadow))
		cv.fill(sh, shadow_color)
	cv.fill(shape, fill)
	if lip > 0.0:
		var lip_rect := Rect2(rect.position + Vector2(0, rect.size.y - lip - radius * 0.6), Vector2(rect.size.x, lip + radius * 0.6))
		var band := Geometry2D.intersect_polygons(shape, outline_pts(lip_rect.grow_individual(4, 0, 4, 4), radius * 0.6, 0.0, s))
		for p in band:
			cv.fill(p, lip_color)
	if hatch > 0.0:
		var x := rect.position.x - rect.size.y
		while x < rect.end.x:
			var a := Vector2(x, rect.end.y)
			var b := Vector2(x + rect.size.y, rect.position.y)
			for seg in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), shape):
				cv.stroke(seg, 1.4, hatch_color, 0.2, 0.2)
			x += hatch
	if ink_width > 0.0 and ink.a > 0.0:
		cv.outline(shape, ink_width, ink, s, 0.18, 0.0)
	return cv


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var key := Vector2i(rect.size.round())
	var cv: InkCanvas = _cache.get(key)
	if cv == null:
		if _cache.size() > 48:
			_cache.clear()
		cv = _build(Rect2(Vector2.ZERO, rect.size))
		_cache[key] = cv
	if rect.position == Vector2.ZERO:
		cv.submit(to_canvas_item)
		return
	var moved := PackedVector2Array()
	moved.resize(cv.pts.size())
	for i in cv.pts.size():
		moved[i] = cv.pts[i] + rect.position
	if cv.idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(to_canvas_item, cv.idx, moved, cv.cols)
