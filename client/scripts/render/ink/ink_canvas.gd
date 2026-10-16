class_name InkCanvas
extends RefCounted
## Hand-drawn vector renderer (docs/INK_ART_SPEC.md §1).
##
## Strokes become tapered, pressure-varied triangle strips with round joins and caps; fills are
## triangulated. Everything is appended, in painter's order and with per-vertex colour, to one
## triangle array that `flush()` submits as a single canvas command. All input coordinates go
## through `xf` (set it per body part); widths are in the same local units.

const INK := Color("1c1714")
const PAPER := Color("fbf6ec")

var pts := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
## Local -> canvas transform applied to every point.
var xf := Transform2D.IDENTITY
## Multiplies every stroke width (screen-aware line weight, set by the owner).
var line_scale := 1.0
## Global wobble multiplier (0 disables hand jitter, e.g. for tiny thumbnails).
var wobble := 1.0
## Round caps on stroke ends (off for bands that must stop exactly at their ends).
var caps := true
## Bounding box of everything emitted (canvas space), for framing previews (computed on demand).
var bounds: Rect2:
	get:
		if pts.is_empty():
			return Rect2()
		var lo := pts[0]
		var hi := pts[0]
		for q in pts:
			lo = lo.min(q)
			hi = hi.max(q)
		return Rect2(lo, hi - lo)

# Staging: shapes are built in local space into _lp / _li (indices already offset to their
# final position), then transformed by `xf` and appended in bulk by _commit (native ops).
var _lp := PackedVector2Array()
var _li := PackedInt32Array()
var _base := 0


func clear() -> void:
	pts.clear()
	cols.clear()
	idx.clear()


func vertex_count() -> int:
	return pts.size()


## Submits the accumulated geometry to `ci` as one triangle array, then clears.
func flush(ci: RID) -> void:
	if idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)
	clear()


## Submits without clearing (static art kept for redraws).
func submit(ci: RID) -> void:
	if idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## Bakes the geometry into a vertex-coloured mesh (shared by several canvas items, e.g. the
## repeated tiles of a backdrop layer).
func to_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	if idx.size() < 3:
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func append_canvas(other: InkCanvas) -> void:
	var base := pts.size()
	pts.append_array(other.pts)
	cols.append_array(other.cols)
	for i in other.idx:
		idx.append(i + base)


func _begin() -> void:
	_lp.clear()
	_li.clear()
	_base = pts.size()


## Stages a local-space vertex; returns its final index.
func _sv(p: Vector2) -> int:
	_lp.append(p)
	return _base + _lp.size() - 1


func _commit(color: Color) -> void:
	var n := _lp.size()
	if n == 0:
		return
	pts.append_array(xf * _lp)
	var c := PackedColorArray()
	c.resize(n)
	c.fill(color)
	cols.append_array(c)
	idx.append_array(_li)
	_lp.clear()
	_li.clear()


func _v(p: Vector2, c: Color) -> int:
	pts.append(xf * p)
	cols.append(c)
	return pts.size() - 1


## Cheap smooth 1D noise in roughly [-1, 1]; stable for a given seed.
static func noise(x: float, seed_value: float) -> float:
	return sin(x + seed_value * 1.37) * 0.62 + sin(x * 2.63 + seed_value * 2.71) * 0.38


# ---------------------------------------------------------------------------
# Strokes
# ---------------------------------------------------------------------------

## Draws a hand-inked stroke along `line` (an open polyline, ideally smooth and dense).
## width: full width at full pressure. taper_a / taper_b: fraction of the length over which the
## start / end thins to `tip` × width. pressure: ±fraction of slow width variation.
## jitter: max sideways hand wobble (local units). seed_value: makes each line unique but stable.
func stroke(line: PackedVector2Array, width: float, color: Color, taper_a: float = 0.15, taper_b: float = 0.15,
		seed_value: float = 0.0, pressure: float = 0.12, jitter: float = 0.0, tip: float = 0.35) -> void:
	var n := line.size()
	if n < 2:
		if n == 1:
			dot(line[0], width * 0.5, color)
		return
	var w0 := width * line_scale
	# Arc length.
	var acc := PackedFloat32Array()
	acc.resize(n)
	acc[0] = 0.0
	for i in range(1, n):
		acc[i] = acc[i - 1] + line[i].distance_to(line[i - 1])
	var total := acc[n - 1]
	if total < 0.0001:
		dot(line[0], w0 * 0.5, color)
		return
	var jit := jitter * wobble
	var freq := TAU / maxf(18.0, total * 0.6)
	# Per-point half widths and (jittered) positions.
	var hw := PackedFloat32Array()
	hw.resize(n)
	var p := PackedVector2Array()
	p.resize(n)
	var ta := maxf(taper_a, 0.0001)
	var tb := maxf(taper_b, 0.0001)
	for i in n:
		var t := acc[i] / total
		var f := 1.0
		if t < ta:
			f = lerpf(tip, 1.0, _smooth(t / ta))
		if t > 1.0 - tb:
			f = minf(f, lerpf(tip, 1.0, _smooth((1.0 - t) / tb)))
		f *= 1.0 + pressure * noise(acc[i] * freq * 3.0, seed_value)
		hw[i] = maxf(0.05, w0 * 0.5 * f)
		var q := line[i]
		if jit > 0.0:
			var d := (line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]).normalized()
			q += Vector2(-d.y, d.x) * jit * noise(acc[i] * 0.21, seed_value + 11.0)
		p[i] = q
	_strip(p, hw, color)


## Strip with round caps; sharp corners get round joins (strip is split there).
func _strip(p: PackedVector2Array, hw: PackedFloat32Array, color: Color) -> void:
	var n := p.size()
	_begin()
	var prev_l := -1
	var prev_r := -1
	var d_in := (p[1] - p[0]).normalized()
	if d_in == Vector2.ZERO:
		d_in = Vector2.RIGHT
	if caps:
		_scap(p[0], hw[0], -d_in)
	var d_prev := d_in
	for i in n:
		var d_next := (p[i + 1] - p[i]).normalized() if i < n - 1 else d_prev
		if d_next == Vector2.ZERO:
			d_next = d_prev
		var sharp := i > 0 and i < n - 1 and d_prev.dot(d_next) < 0.6
		var nrm: Vector2
		var miter := 1.0
		if sharp:
			nrm = Vector2(-d_prev.y, d_prev.x)
		else:
			var avg := d_prev + d_next
			if avg.length_squared() < 0.0001:
				avg = d_next
			avg = avg.normalized()
			nrm = Vector2(-avg.y, avg.x)
			miter = clampf(1.0 / maxf(0.2, nrm.x * -d_prev.y + nrm.y * d_prev.x), 1.0, 2.0)
		var o := nrm * (hw[i] * miter)
		var l := _sv(p[i] + o)
		var r := _sv(p[i] - o)
		if prev_l >= 0:
			_li.append(prev_l)
			_li.append(l)
			_li.append(r)
			_li.append(prev_l)
			_li.append(r)
			_li.append(prev_r)
		prev_l = l
		prev_r = r
		if sharp:
			# Round join, then restart the strip with the outgoing normal.
			_sdot(p[i], hw[i])
			var n2 := Vector2(-d_next.y, d_next.x) * hw[i]
			prev_l = _sv(p[i] + n2)
			prev_r = _sv(p[i] - n2)
		d_prev = d_next
	var d_out := (p[n - 1] - p[n - 2]).normalized()
	if d_out == Vector2.ZERO:
		d_out = d_in
	if caps:
		_scap(p[n - 1], hw[n - 1], d_out)
	_commit(color)


func _seg_for(r: float, k: float, lo: int, hi: int) -> int:
	return clampi(int(r * absf(xf.x.x + xf.y.y) * 0.5 * k) + lo, lo, hi)


## Staged semicircle cap at `c` bulging toward `dir`.
func _scap(c: Vector2, r: float, dir: Vector2) -> void:
	var seg := _seg_for(r, 0.9, 3, 10)
	var ci := _sv(c)
	var a0 := dir.angle() - PI * 0.5
	var prev := _sv(c + Vector2.from_angle(a0) * r)
	for k in range(1, seg + 1):
		var cur := _sv(c + Vector2.from_angle(a0 + PI * float(k) / float(seg)) * r)
		_li.append(ci)
		_li.append(prev)
		_li.append(cur)
		prev = cur


## Staged filled disc.
func _sdot(c: Vector2, r: float) -> void:
	var seg := _seg_for(r, 1.2, 6, 40)
	var ci := _sv(c)
	var first := _sv(c + Vector2(r, 0))
	var prev := first
	for k in range(1, seg):
		var cur := _sv(c + Vector2.from_angle(TAU * float(k) / float(seg)) * r)
		_li.append(ci)
		_li.append(prev)
		_li.append(cur)
		prev = cur
	_li.append(ci)
	_li.append(prev)
	_li.append(first)


## Filled disc.
func dot(c: Vector2, r: float, color: Color) -> void:
	_begin()
	_sdot(c, r)
	_commit(color)


## Closed outline (polygon contour) inked with the stroke rules.
func outline(poly: PackedVector2Array, width: float, color: Color, seed_value: float = 0.0, pressure: float = 0.1, jitter: float = 0.0) -> void:
	if poly.size() < 2:
		return
	var line := poly.duplicate()
	line.append(poly[0])
	if poly.size() > 2:
		line.append(poly[1])
	stroke(line, width, color, 0.0001, 0.0001, seed_value, pressure, jitter, 1.0)


## A hand-drawn ellipse/circle: a single pen loop that overshoots its start a little and tapers
## at both ends, with a slightly irregular radius.
func ink_circle(c: Vector2, r: Vector2, width: float, color: Color, seed_value: float = 0.0, rot: float = 0.0,
		overlap: float = 0.22, irregular: float = 0.035) -> void:
	var seg := clampi(int(maxf(r.x, r.y) * xf.get_scale().length() * 0.8) + 18, 18, 72)
	var line := PackedVector2Array()
	var a0 := -2.2 + noise(seed_value, 3.0) * 0.6
	var span := TAU + overlap
	for k in seg + 1:
		var a := a0 + span * float(k) / float(seg)
		var rr := 1.0 + irregular * wobble * noise(a * 1.3, seed_value)
		line.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) * rr)
	stroke(line, width, color, 0.12, 0.12, seed_value, 0.1, 0.0, 0.3)


# ---------------------------------------------------------------------------
# Fills
# ---------------------------------------------------------------------------

## Flat fill of a polygon. Self-intersecting outlines (fast-moving cloth, merged blobs) are
## resolved into simple pieces with a polygon union before triangulating.
func fill(poly: PackedVector2Array, color: Color) -> void:
	poly = _dedupe(poly)
	var n := poly.size()
	if n < 3:
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		var pieces := Geometry2D.merge_polygons(poly, PackedVector2Array())
		if pieces.is_empty():
			pieces = Geometry2D.offset_polygon(poly, 0.01)
		var drawn := false
		for piece in pieces:
			if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(poly) and pieces.size() > 1:
				continue
			var t2 := Geometry2D.triangulate_polygon(piece)
			if t2.is_empty():
				continue
			var b2 := pts.size()
			for v in piece:
				_v(v, color)
			for t in t2:
				idx.append(b2 + t)
			drawn = true
		if drawn:
			return
		if OS.is_debug_build() and n > 12:
			push_warning("InkCanvas.fill: triangulation failed (%d pts, first %s)" % [n, poly[0]])
		var c := Vector2.ZERO
		for v in poly:
			c += v
		var base0 := pts.size()
		for v in poly:
			_v(v, color)
		var ci := _v(c / n, color)
		for i in n:
			idx.append_array(PackedInt32Array([ci, base0 + i, base0 + (i + 1) % n]))
		return
	var base := pts.size()
	pts.append_array(xf * poly)
	var c2 := PackedColorArray()
	c2.resize(n)
	c2.fill(color)
	cols.append_array(c2)
	if base == 0:
		idx.append_array(tri)
	else:
		for t in tri:
			idx.append(base + t)


static func _dedupe(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	var out := PackedVector2Array()
	for v in poly:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(v) > 0.0004:
			out.append(v)
	while out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.0004:
		out.remove_at(out.size() - 1)
	return out


## Shaded crescent inside a disc (circle minus a shifted circle), e.g. ball shading.
func crescent(c: Vector2, r: float, shift: Vector2, color: Color) -> void:
	var seg := clampi(int(r * xf.get_scale().length()) + 14, 14, 48)
	var disc := ellipse_pts(c, Vector2(r, r), 0.0, seg)
	var cut := ellipse_pts(c + shift, Vector2(r, r) * 1.02, 0.0, seg)
	for piece in Geometry2D.clip_polygons(disc, cut):
		if not Geometry2D.is_polygon_clockwise(piece):
			fill(piece, color)


## Fill with one colour per vertex (atmospheric gradients, soil depth).
func fill_colored(poly: PackedVector2Array, colors: PackedColorArray) -> void:
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var base := pts.size()
	for i in poly.size():
		_v(poly[i], colors[i])
	for t in tri:
		idx.append(base + t)


## Filled ellipse.
func ellipse(c: Vector2, r: Vector2, color: Color, rot: float = 0.0, seg: int = 0) -> void:
	fill(ellipse_pts(c, r, rot, seg if seg > 0 else clampi(int(maxf(r.x, r.y) * xf.get_scale().length()) + 12, 12, 64)), color)


## Filled shape plus inked outline in one call.
func shape(poly: PackedVector2Array, fill_color: Color, width: float, ink: Color = INK, seed_value: float = 0.0) -> void:
	fill(poly, fill_color)
	outline(poly, width, ink, seed_value)


## Quad (any orientation).
func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var i := _v(a, color)
	_v(b, color)
	_v(c, color)
	_v(d, color)
	idx.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


func tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var i := _v(a, color)
	_v(b, color)
	_v(c, color)
	idx.append_array(PackedInt32Array([i, i + 1, i + 2]))


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func ellipse_pts(c: Vector2, r: Vector2, rot: float = 0.0, seg: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(seg)
	for k in seg:
		var a := TAU * float(k) / float(seg)
		out[k] = c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
	return out


static func arc_pts(c: Vector2, r: float, a0: float, a1: float, seg: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in seg + 1:
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / float(seg))) * r)
	return out


static func quad_bez(a: Vector2, c: Vector2, b: Vector2, seg: int = 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(seg + 1)
	for k in seg + 1:
		var t := float(k) / float(seg)
		var u := 1.0 - t
		out[k] = a * u * u + c * 2.0 * u * t + b * t * t
	return out


static func cubic_bez(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, seg: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(seg + 1)
	for k in seg + 1:
		var t := float(k) / float(seg)
		var u := 1.0 - t
		out[k] = a * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + b * (t * t * t)
	return out


## Centripetal-ish Catmull-Rom through `points` (open), `seg` samples per span.
static func spline(points: PackedVector2Array, seg: int = 6, closed: bool = false) -> PackedVector2Array:
	var n := points.size()
	if n < 3:
		return points
	var out := PackedVector2Array()
	var spans := n if closed else n - 1
	for i in spans:
		var p0 := points[(i - 1 + n) % n] if closed or i > 0 else points[0] * 2.0 - points[1]
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var p3 := points[(i + 2) % n] if closed or i + 2 < n else p2 * 2.0 - p1
		for k in seg:
			var t := float(k) / float(seg)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(points[n - 1])
	return out


## Resamples a polyline at roughly even `step` spacing (keeps both ends).
static func resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line.size() < 2:
		return line
	out.append(line[0])
	var carry := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var seg := a.distance_to(b)
		var d := step - carry
		while d <= seg:
			out.append(a.lerp(b, d / seg))
			d += step
		carry = seg - (d - step)
	if out[out.size() - 1].distance_to(line[line.size() - 1]) > step * 0.25:
		out.append(line[line.size() - 1])
	return out


## Polyline offset along per-point normals (open line, normals from neighbours).
static func offset_line(line: PackedVector2Array, dist: float) -> PackedVector2Array:
	var n := line.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var d := (line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]).normalized()
		out[i] = line[i] + Vector2(-d.y, d.x) * dist
	return out


static func shade(c: Color, k: float) -> Color:
	return c.darkened(k) if k >= 0.0 else c.lightened(-k)
