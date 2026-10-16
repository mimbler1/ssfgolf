class_name ToonCanvas
extends RefCounted
## Collects one character's parts for a frame, then draws them in the house style
## (docs/CHARACTER_ART_SPEC.md):
##   1. silhouette pass: every part grown by the outer width, in ink (one merged outline);
##   2. part pass in layer order: inner-width ink rim, fill, one shadow crescent, optional
##      highlight, then the part's detail callback.
## Shapes are tubes (chains of circles joined by convex tangent hulls), ellipses, and local-space
## polygons whose grown/shrunk versions are cached. Nothing is clipped at runtime.
##
## With `ci == null` the canvas only measures: `bounds` gets the inked extent of every part.

const LIGHT := Vector2(-0.55, -0.835)      ## light comes from the top-left (screen space)
const SHADE_SHIFT := 0.17                   ## crescent thickness as a fraction of the radius
const CIRCLE_SEG := 24

var ci: CanvasItem
var xf := Transform2D.IDENTITY             ## rig space -> canvas
var facing := 1.0
var out_w := 2.4                           ## silhouette ink width (rig units)
var in_w := 1.3                            ## inner rim width (rig units)
var ink := Color("191a33")
var bounds := Rect2()
var measure_min_z := -INF                  ## measure mode: ignore parts below this layer

var _parts: Array[Dictionary] = []
var _seq := 0
var _light := LIGHT                        ## light direction in rig space (mirrors with facing)

static var _cache: Dictionary = {}         ## "key|grow" -> Array[PackedVector2Array]
static var _warned: Dictionary = {}


func begin(p_ci: CanvasItem, p_xf: Transform2D, p_facing: float, p_out: float) -> void:
	ci = p_ci
	xf = p_xf
	facing = p_facing
	out_w = p_out
	in_w = maxf(0.55, p_out * 0.55)
	_light = Vector2(LIGHT.x * facing, LIGHT.y)
	_parts.clear()
	_seq = 0
	bounds = Rect2()


## Shadow tone: darker and nudged slightly cool so shading never looks muddy.
static func shadow_of(c: Color, k: float) -> Color:
	return c.darkened(k).lerp(Color(0.16, 0.15, 0.42), k * 0.22)


# ---------------------------------------------------------------------------
# Part emitters. Common options (o):
#   sil (true)   include in the merged silhouette
#   rim (true)   inner ink line around this part
#   shade (0.2)  shadow crescent strength (0 = flat)
#   hl (0.0)     highlight strength (ellipses / circles only)
#   alpha (1.0)  fill alpha (effects)
# ---------------------------------------------------------------------------

func tube(pts: PackedVector2Array, radii: PackedFloat32Array, fill: Color, z: float, o: Dictionary = {}) -> void:
	_add({"kind": 0, "pts": pts, "radii": radii}, fill, z, o)


func capsule(a: Vector2, b: Vector2, ra: float, rb: float, fill: Color, z: float, o: Dictionary = {}) -> void:
	tube(PackedVector2Array([a, b]), PackedFloat32Array([ra, rb]), fill, z, o)


func circle(c: Vector2, r: float, fill: Color, z: float, o: Dictionary = {}) -> void:
	ellipse(c, Vector2(r, r), 0.0, fill, z, o)


func ellipse(c: Vector2, r: Vector2, rot: float, fill: Color, z: float, o: Dictionary = {}) -> void:
	_add({"kind": 1, "c": c, "r": r, "rot": rot}, fill, z, o)


## A polygon defined in its own local space, placed with `at`. `key` must uniquely identify the
## point list (grown/shrunk copies are cached under it).
func poly(key: String, pts: PackedVector2Array, at: Transform2D, fill: Color, z: float, o: Dictionary = {}) -> void:
	_add({"kind": 2, "key": key, "pts": pts, "at": at}, fill, z, o)


## A polygon that changes every frame (robe hems, capes). Grown along vertex normals instead of
## through the cached offsetter, so it costs nothing to animate. Keep it smooth and mostly convex.
func blob(pts: PackedVector2Array, fill: Color, z: float, o: Dictionary = {}) -> void:
	_add({"kind": 4, "pts": pts}, fill, z, o)


## Free drawing at layer z, in rig space: fn(cv: ToonCanvas). Not part of the silhouette.
func detail(z: float, fn: Callable) -> void:
	_parts.append({"kind": 3, "z": z, "seq": _seq, "fn": fn})
	_seq += 1


func _add(part: Dictionary, fill: Color, z: float, o: Dictionary) -> void:
	part.z = z
	part.seq = _seq
	_seq += 1
	part.fill = fill
	part.sil = bool(o.get("sil", true))
	part.rim = bool(o.get("rim", true))
	part.shade = float(o.get("shade", 0.2))
	part.hl = float(o.get("hl", 0.0))
	part.alpha = float(o.get("alpha", 1.0))
	_parts.append(part)


# ---------------------------------------------------------------------------
# Flush
# ---------------------------------------------------------------------------

func flush() -> void:
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.z < b.z or (a.z == b.z and a.seq < b.seq))
	if ci == null:
		_measure()
		return
	ci.draw_set_transform_matrix(xf)
	for p in _parts:
		if p.kind != 3 and p.sil:
			_shape(p, out_w, ink)
	for p in _parts:
		if p.kind == 3:
			ci.draw_set_transform_matrix(xf)
			(p.fn as Callable).call(self)
			continue
		var fill: Color = p.fill
		fill.a *= p.alpha
		if p.rim:
			_shape(p, in_w, Color(ink, p.alpha))
		if p.shade > 0.0:
			_shape(p, 0.0, Color(shadow_of(p.fill, p.shade), fill.a))
			_lit(p, fill)
		else:
			_shape(p, 0.0, fill)
		if p.hl > 0.0:
			_highlight(p)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_parts.clear()


func _measure() -> void:
	var r := Rect2()
	var first := true
	for p in _parts:
		if p.kind == 3 or not p.sil or float(p.z) < measure_min_z:
			continue
		var pr := _part_rect(p).grow(out_w)
		r = pr if first else r.merge(pr)
		first = false
	bounds = r
	_parts.clear()


func _part_rect(p: Dictionary) -> Rect2:
	match int(p.kind):
		0:
			var pts: PackedVector2Array = p.pts
			var radii: PackedFloat32Array = p.radii
			var r := Rect2(pts[0], Vector2.ZERO).grow(radii[0])
			for i in pts.size():
				r = r.merge(Rect2(pts[i], Vector2.ZERO).grow(radii[i]))
			return r
		1:
			var m := maxf(p.r.x, p.r.y)
			return Rect2(p.c, Vector2.ZERO).grow(m)
		4:
			var pts4: PackedVector2Array = p.pts
			var r4 := Rect2(pts4[0], Vector2.ZERO)
			for v in pts4:
				r4 = r4.expand(v)
			return r4
		_:
			var at: Transform2D = p.at
			var pts2: PackedVector2Array = p.pts
			var r2 := Rect2(at * pts2[0], Vector2.ZERO)
			for v in pts2:
				r2 = r2.expand(at * v)
			return r2


# ---------------------------------------------------------------------------
# Shape drawing
# ---------------------------------------------------------------------------

func _shape(p: Dictionary, grow: float, col: Color) -> void:
	match int(p.kind):
		0:
			_tube(p.pts, p.radii, grow, col, Vector2.ZERO, 1.0)
		1:
			_ellipse(p.c, p.r + Vector2(grow, grow), p.rot, col)
		2:
			ci.draw_set_transform_matrix(xf * (p.at as Transform2D))
			for g: PackedVector2Array in _grown(p.key, p.pts, grow):
				ci.draw_colored_polygon(g, col)
			ci.draw_set_transform_matrix(xf)
		4:
			_fill_safe(offset_normals(p.pts, grow), col)


func _fill_safe(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, col)


## Moves every vertex along its averaged outward normal (cheap offset for smooth shapes).
static func offset_normals(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	if is_zero_approx(d):
		return pts
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].x * pts[(i + 1) % n].y - pts[(i + 1) % n].x * pts[i].y
	var sgn := -1.0 if area > 0.0 else 1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var e1 := (b - a).normalized()
		var e2 := (c - b).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var n2 := Vector2(e2.y, -e2.x)
		var nm := (n1 + n2)
		var l := nm.length()
		nm = nm / l if l > 0.001 else n1
		var miter := 1.0 / maxf(0.5, nm.dot(n1))
		out[i] = b + nm * d * sgn * miter
	return out


## The lit part of a shaded shape: the same shape, shrunk and shifted toward the light, drawn
## over the shadow-coloured base so a crescent of shadow remains on the far side.
func _lit(p: Dictionary, col: Color) -> void:
	match int(p.kind):
		0:
			_tube(p.pts, p.radii, 0.0, col, _light, 1.0 - SHADE_SHIFT)
		1:
			var r: Vector2 = p.r
			var m := minf(r.x, r.y) * SHADE_SHIFT
			_ellipse(p.c + _light * m, r - Vector2(m, m), p.rot, col)
		2:
			var at: Transform2D = p.at
			var local_light := at.basis_xform_inv(_light).normalized()
			var shrink := 1.1
			ci.draw_set_transform_matrix(xf * at * Transform2D(0.0, local_light * shrink))
			for g: PackedVector2Array in _grown(p.key, p.pts, -shrink):
				ci.draw_colored_polygon(g, col)
			ci.draw_set_transform_matrix(xf)
		4:
			var sh := offset_normals(p.pts, -1.1)
			for i in sh.size():
				sh[i] += _light * 1.1
			_fill_safe(sh, col)


func _highlight(p: Dictionary) -> void:
	if int(p.kind) != 1:
		return
	var r: Vector2 = p.r
	var c: Vector2 = p.c
	var m := minf(r.x, r.y)
	var at := c + Vector2(_light.x * r.x, _light.y * r.y) * 0.52
	var col: Color = (p.fill as Color).lightened(p.hl)
	col.a *= p.alpha
	_ellipse(at, Vector2(m * 0.24, m * 0.13), _light.angle() + PI * 0.5, col)


func _tube(pts: PackedVector2Array, radii: PackedFloat32Array, grow: float, col: Color, shift: Vector2, k: float) -> void:
	var n := pts.size()
	var cs := PackedVector2Array()
	var rs := PackedFloat32Array()
	cs.resize(n)
	rs.resize(n)
	for i in n:
		var r := radii[i]
		cs[i] = pts[i] + shift * r * (1.0 - k)
		rs[i] = r * k + grow
	for i in n:
		ci.draw_circle(cs[i], rs[i], col, true, -1.0, false)
	for i in n - 1:
		var q := hull(cs[i], rs[i], cs[i + 1], rs[i + 1])
		if q.size() == 4:
			ci.draw_colored_polygon(q, col)


## Convex quad joining two circles along their outer tangents (empty if one contains the other).
static func hull(c1: Vector2, r1: float, c2: Vector2, r2: float) -> PackedVector2Array:
	var d := c2 - c1
	var dist := d.length()
	if dist < 0.001 or dist <= absf(r1 - r2):
		return PackedVector2Array()
	var u := d / dist
	var k := (r1 - r2) / dist
	var s := sqrt(maxf(0.0, 1.0 - k * k))
	var perp := Vector2(-u.y, u.x)
	var n1 := u * k + perp * s
	var n2 := u * k - perp * s
	return PackedVector2Array([c1 + n1 * r1, c2 + n1 * r2, c2 + n2 * r2, c1 + n2 * r1])


func _ellipse(c: Vector2, r: Vector2, rot: float, col: Color) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, r, rot, CIRCLE_SEG + 8), col)


static func ellipse_pts(c: Vector2, r: Vector2, rot: float = 0.0, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * float(i) / float(n)
		var v := Vector2(cos(a) * r.x, sin(a) * r.y)
		pts[i] = c + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr)
	return pts


## Cached offset of a local polygon (grow < 0 shrinks). Quantised to 0.05 units.
static func _grown(key: String, pts: PackedVector2Array, grow: float) -> Array:
	var q := snappedf(grow, 0.05)
	var ck := "%s|%.2f" % [key, q]
	if _cache.has(ck):
		return _cache[ck]
	var out: Array = []
	if is_zero_approx(q):
		if not Geometry2D.triangulate_polygon(pts).is_empty():
			out = [pts]
			_cache[ck] = out
			return out
		# Self-touching outline (tight scallops): clean it with a hair-thin offset.
		if OS.is_debug_build() and not _warned.has(key):
			_warned[key] = true
			push_warning("ToonCanvas: polygon '%s' needed cleaning" % key)
		q = 0.01
	var cw := Geometry2D.is_polygon_clockwise(pts)
	for g: PackedVector2Array in Geometry2D.offset_polygon(pts, q, Geometry2D.JOIN_ROUND):
		# Skip holes (opposite winding); keep only drawable outer rings.
		if Geometry2D.is_polygon_clockwise(g) == cw and g.size() >= 3 and not Geometry2D.triangulate_polygon(g).is_empty():
			out.append(g)
	if _cache.size() > 4000:
		_cache.clear()
	_cache[ck] = out
	return out


# ---------------------------------------------------------------------------
# Helpers for builders
# ---------------------------------------------------------------------------

## Light direction in rig space (already mirrored for facing).
func light() -> Vector2:
	return _light


## Line in rig space (call from detail callbacks).
func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, false)
	ci.draw_circle(a, w * 0.5, col, true, -1.0, false)
	ci.draw_circle(b, w * 0.5, col, true, -1.0, false)


func polyline(pts: PackedVector2Array, col: Color, w: float) -> void:
	if pts.size() < 2:
		return
	for i in pts.size() - 1:
		ci.draw_line(pts[i], pts[i + 1], col, w, false)
	for v in pts:
		ci.draw_circle(v, w * 0.5, col, true, -1.0, false)


func arc(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, seg: int = 12) -> void:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	polyline(pts, col, w)


func dot(c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1.0, false)


func fill_ellipse(c: Vector2, r: Vector2, rot: float, col: Color) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, r, rot), col)


func fill_poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, col)


## Sets a local transform (relative to rig space) for subsequent detail drawing.
func push(at: Transform2D) -> void:
	ci.draw_set_transform_matrix(xf * at)


func pop() -> void:
	ci.draw_set_transform_matrix(xf)


## Quadratic Bezier sampled at n points.
static func bezier(a: Vector2, c: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var t := float(i) / float(n - 1)
		var u := 1.0 - t
		pts[i] = a * u * u + c * 2.0 * u * t + b * t * t
	return pts
