class_name TerrainView
extends Node2D
## Hand-drawn render of one hole (docs/INK_ART_SPEC.md §9): soil with depth strata and sketch
## marks, material strips, an ink outline on the exact collision edge, the cup and flag, water
## and decor. Everything static is built once into InkCanvas geometry; only the flag, water
## surface and tree canopies move. Physics never reads anything drawn here.

const SKIRT_LEN := 4000.0
## Materials that get their strip on any edge orientation (walls and ceilings included).
const ALWAYS_STRIP := ["sticky", "bouncy", "ice", "sand", "snow", "metal", "wood", "rock"]

var terrain: SimTerrain
var theme: Dictionary
var hole: Dictionary
var hole_number: int = 1
var pal: Dictionary = {}
## Visual-only ground that continues past the world's left/right edges so the camera never
## shows a cut-off cliff. Each entry: {poly, top, src, edge_x | edge_y}.
var skirts: Array[Dictionary] = []
var _water: _Water
var _rng := RandomNumberGenerator.new()


func build(p_terrain: SimTerrain, p_hole: Dictionary, p_theme: Dictionary, p_hole_number: int) -> void:
	terrain = p_terrain
	hole = p_hole
	theme = p_theme
	hole_number = p_hole_number
	pal = InkThemes.get_palette(theme)
	for c in get_children():
		c.queue_free()
	_rng.seed = hash(str(hole.get("id", ""))) + 17
	_build_skirts()
	var decor_back := Node2D.new()
	decor_back.name = "DecorBack"
	add_child(decor_back)
	var cup := _Cup.new()
	cup.view = self
	add_child(cup)
	var ground := InkStatic.new()
	ground.name = "Ground"
	ground.canvas = _build_ground()
	add_child(ground)
	_water = _Water.new()
	_water.view = self
	add_child(_water)
	_water.setup()
	if terrain.has_cup:
		var flag := _Flag.new()
		flag.position = terrain.cup_pos
		flag.number = hole_number
		add_child(flag)
	_build_decor(decor_back)
	var forces := ForceOverlay.new()
	forces.setup(terrain, GameData.materials, float(GameData.balance.physics.gravity))
	add_child(forces)


func c(key: String) -> Color:
	return InkThemes.col(pal, key)


# ---------------------------------------------------------------------------
# Skirts (visual continuation past the world edges)
# ---------------------------------------------------------------------------

## Extends the terrain's outermost left/right edges outward as flat plateaus at the same height,
## so the camera never sees past the end of the ground. The edge comes from the terrain itself
## (not the hole bounds), so ground that stops short of or overruns the bounds still continues.
func _build_skirts() -> void:
	skirts.clear()
	var bd := terrain.bounds
	var min_x := INF
	var max_x := -INF
	for poly in terrain.polygons:
		for v: Vector2 in poly.points:
			min_x = minf(min_x, v.x)
			max_x = maxf(max_x, v.x)
	for pi in terrain.polygons.size():
		var pts: PackedVector2Array = terrain.polygons[pi].points
		for side: float in [-1.0, 1.0]:
			var edge_x: float = min_x if side < 0.0 else max_x
			var top := INF
			var bottom := -INF
			for v in pts:
				if absf(v.x - edge_x) < 0.5:
					top = minf(top, v.y)
					bottom = maxf(bottom, v.y)
			if top == INF or bottom - top < 1.0:
				continue
			var far := edge_x + side * SKIRT_LEN
			var near := edge_x - side * 1.0
			skirts.append({
				"poly": PackedVector2Array([Vector2(near, top), Vector2(far, top), Vector2(far, bottom + 2000.0), Vector2(near, bottom + 2000.0)]),
				"top": PackedVector2Array([Vector2(edge_x, top), Vector2(far, top)]) if side > 0.0 else PackedVector2Array([Vector2(far, top), Vector2(edge_x, top)]),
				"edge_x": edge_x, "src": pi,
			})
		var bottom_pts := 0
		for v in pts:
			if absf(v.y - bd.end.y) < 0.5:
				bottom_pts += 1
		if bottom_pts >= 2:
			var y0 := bd.end.y - 1.0
			skirts.append({
				"poly": PackedVector2Array([Vector2(bd.position.x - SKIRT_LEN, y0), Vector2(bd.end.x + SKIRT_LEN, y0),
					Vector2(bd.end.x + SKIRT_LEN, y0 + 3000.0), Vector2(bd.position.x - SKIRT_LEN, y0 + 3000.0)]),
				"top": PackedVector2Array(), "edge_y": bd.end.y, "src": pi,
			})


## True for polygon edges that sit exactly on a skirted world boundary (hidden seams).
func is_seam(a: Vector2, b: Vector2) -> bool:
	for sk in skirts:
		if sk.has("edge_x"):
			var x: float = sk.edge_x
			if absf(a.x - x) < 0.5 and absf(b.x - x) < 0.5:
				return true
		elif absf(a.y - float(sk.edge_y)) < 0.5 and absf(b.y - float(sk.edge_y)) < 0.5:
			return true
	return false


## Terrain polygons merged with their skirts (for fills, strata and marks; seam-free).
func _visual_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for pi in terrain.polygons.size():
		var merged: PackedVector2Array = terrain.polygons[pi].points
		for sk in skirts:
			if int(sk.src) != pi:
				continue
			var res := Geometry2D.merge_polygons(merged, sk.poly)
			var best := merged
			var best_a := 0.0
			for r in res:
				var a := absf(_area(r))
				if a > best_a and not _is_hole(r, merged):
					best_a = a
					best = r
			merged = best
		out.append(merged)
	return out


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


static func _is_hole(r: PackedVector2Array, ref: PackedVector2Array) -> bool:
	return (_area(r) > 0.0) != (_area(ref) > 0.0)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

func _build_ground() -> InkCanvas:
	var cv := InkCanvas.new()
	var vis := _visual_polygons()
	var top_c := c("soil_top")
	var deep_c := c("soil_deep")
	for vp in vis:
		_soil_fill(cv, vp, top_c, deep_c, 0.0)
		# Strata: inset contours, each a little darker, with a sketchy line on the boundary.
		var depth := 0.0
		for band: Array in [[38.0, 0.07], [120.0, 0.15], [260.0, 0.22]]:
			depth = band[0]
			for inset in Geometry2D.offset_polygon(vp, -depth, Geometry2D.JOIN_ROUND):
				if _is_hole(inset, vp) or inset.size() < 3:
					continue
				_soil_fill(cv, inset, top_c.darkened(band[1]), deep_c.darkened(band[1]), depth)
				_strata_line(cv, inset, c("soil_line"), float(band[1]))
		_soil_marks(cv, vp)
	# Material strips along the surface, then the ink outline exactly on the collision edge.
	for pi in terrain.polygons.size():
		var poly: Dictionary = terrain.polygons[pi]
		for run in _runs(poly.points, poly.edge_mats):
			if run.mat == "cup":
				continue
			if run.top or run.mat in ALWAYS_STRIP:
				_strip(cv, run)
	for sk in skirts:
		var tp: PackedVector2Array = sk.top
		if tp.size() >= 2:
			var dense := InkCanvas.resample(tp, 24.0)
			var nrm := PackedVector2Array()
			for i in dense.size():
				nrm.append(Vector2.UP)
			_strip(cv, {"points": dense, "normals": nrm, "mat": "grass", "top": true})
	var ink := c("ink")
	for pi in terrain.polygons.size():
		var poly: Dictionary = terrain.polygons[pi]
		for run in _runs(poly.points, poly.edge_mats):
			for part in _split_seams(run.points):
				cv.stroke(part, 3.6 if run.top else 2.7, ink, 0.0001, 0.0001, float(pi) + part[0].x * 0.01, 0.14, 0.25, 1.0)
	for sk in skirts:
		var tp: PackedVector2Array = sk.top
		if tp.size() >= 2:
			cv.stroke(InkCanvas.resample(tp, 30.0), 3.6, ink, 0.0001, 0.0001, 5.0, 0.14, 0.25, 1.0)
	# Grass blades and flowers sit on top of the ink line.
	for pi in terrain.polygons.size():
		var poly: Dictionary = terrain.polygons[pi]
		for run in _runs(poly.points, poly.edge_mats):
			if run.top and run.mat in ["grass", "rough"]:
				_tufts(cv, run)
	for sk in skirts:
		var tp: PackedVector2Array = sk.top
		if tp.size() >= 2:
			var dense := InkCanvas.resample(tp, 24.0)
			var nrm := PackedVector2Array()
			for i in dense.size():
				nrm.append(Vector2.UP)
			_tufts(cv, {"points": dense, "normals": nrm, "mat": "grass", "top": true})
	return cv


## Soil fill: colour darkens with depth below the local surface.
func _soil_fill(cv: InkCanvas, poly: PackedVector2Array, top_c: Color, deep_c: Color, offset: float) -> void:
	var cols := PackedColorArray()
	cols.resize(poly.size())
	for i in poly.size():
		var v := poly[i]
		var surf := _surface_y(v.x, v.y)
		var k := clampf((v.y - surf - offset) / 700.0, 0.0, 1.0)
		cols[i] = top_c.lerp(deep_c, k)
	cv.fill_colored(poly, cols)


func _surface_y(x: float, below: float) -> float:
	var hit := terrain.raycast(Vector2(clampf(x, terrain.bounds.position.x + 1.0, terrain.bounds.end.x - 1.0), terrain.bounds.position.y - 50.0), Vector2.DOWN, terrain.bounds.size.y + 2000.0)
	return minf(float(hit.pos.y), below) if hit.hit else below


func _strata_line(cv: InkCanvas, poly: PackedVector2Array, col: Color, k: float) -> void:
	# Broken, hand-drawn dashes along the contour (not a continuous mechanical line).
	var ring := poly.duplicate()
	ring.append(poly[0])
	var dense := InkCanvas.resample(ring, 9.0)
	var line_c := Color(col.darkened(k), 0.55)
	var i := 0
	while i < dense.size() - 2:
		var run_len := _rng.randi_range(5, 16)
		var gap := _rng.randi_range(2, 6)
		var seg := dense.slice(i, mini(i + run_len, dense.size()))
		if seg.size() >= 2:
			cv.stroke(seg, _rng.randf_range(1.4, 2.2), line_c, 0.3, 0.3, float(i), 0.2, 0.6, 0.2)
		i += run_len + gap


func _soil_marks(cv: InkCanvas, vp: PackedVector2Array) -> void:
	var insets := Geometry2D.offset_polygon(vp, -30.0, Geometry2D.JOIN_ROUND)
	var r := Rect2(vp[0], Vector2.ZERO)
	for v in vp:
		r = r.expand(v)
	r = r.intersection(terrain.bounds.grow(900.0))
	var mark := c("soil_mark")
	var peb := c("pebble")
	var line := c("soil_line")
	var step := 44.0
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x + _rng.randf_range(0, step)
		while x < r.end.x:
			var p := Vector2(x + _rng.randf_range(-14, 14), y + _rng.randf_range(-14, 14))
			x += step
			if _rng.randf() < 0.42:
				continue
			var inside := false
			for ins in insets:
				if not _is_hole(ins, vp) and Geometry2D.is_point_in_polygon(p, ins):
					inside = true
					break
			if not inside:
				continue
			var depth := p.y - _surface_y(p.x, p.y)
			if depth > 900.0:
				continue
			var roll := _rng.randf()
			var fade := 1.0 - clampf(depth / 1100.0, 0.0, 0.6)
			if roll < 0.44:
				var a := _rng.randf_range(-0.5, 0.5)
				var l := _rng.randf_range(7.0, 15.0)
				var d := Vector2.from_angle(a)
				var bend := Vector2(-d.y, d.x) * _rng.randf_range(-2.5, 2.5)
				cv.stroke(InkCanvas.quad_bez(p - d * l * 0.5, p + bend, p + d * l * 0.5, 5), _rng.randf_range(1.3, 2.0), Color(mark, 0.7 * fade), 0.35, 0.35, x, 0.2, 0.0, 0.2)
			elif roll < 0.7:
				var rr := Vector2(_rng.randf_range(2.5, 5.0), _rng.randf_range(1.8, 3.6))
				var rot := _rng.randf_range(-0.6, 0.6)
				cv.ellipse(p, rr, Color(peb, 0.85 * fade), rot, 12)
				cv.ink_circle(p, rr, 1.1, Color(mark, 0.75 * fade), x, rot, 0.15, 0.08)
			elif roll < 0.85:
				var a2 := _rng.randf_range(-0.4, 0.4)
				var d2 := Vector2.from_angle(a2)
				for k in 2:
					var o := Vector2(-d2.y, d2.x) * (k * 3.2)
					cv.stroke(PackedVector2Array([p - d2 * 4.5 + o, p + d2 * 4.5 + o]), 1.4, Color(mark, 0.6 * fade), 0.4, 0.4)
			elif roll < 0.93 and depth > 60.0:
				# Buried stone.
				var n := 9
				var stone := PackedVector2Array()
				var sz := _rng.randf_range(7.0, 13.0)
				for k in n:
					var aa := TAU * k / n
					stone.append(p + Vector2(cos(aa) * sz * _rng.randf_range(0.8, 1.15), sin(aa) * sz * 0.7 * _rng.randf_range(0.8, 1.15)))
				stone = InkCanvas.spline(stone, 3, true)
				cv.fill(stone, Color(peb.darkened(0.12), fade))
				cv.outline(stone, 1.6, Color(line.darkened(0.2), 0.9 * fade), x)
				cv.stroke(PackedVector2Array([p + Vector2(-sz * 0.4, -sz * 0.2), p + Vector2(-sz * 0.1, -sz * 0.35)]), 1.2, Color(1, 1, 1, 0.35 * fade), 0.3, 0.3)
			elif depth < 140.0:
				# Root squiggle near the top.
				var sq := PackedVector2Array()
				var dir := _rng.randf_range(-1.0, 1.0)
				for k in 6:
					sq.append(p + Vector2(k * 4.0 * dir, sin(k * 1.4) * 2.4 + k * 1.5))
				cv.stroke(sq, 1.5, Color(mark.darkened(0.1), 0.65 * fade), 0.2, 0.5, x, 0.2, 0.0, 0.2)
		y += step


# ---------------------------------------------------------------------------
# Runs and strips
# ---------------------------------------------------------------------------

## Splits a polygon outline into runs of equal (top-facing, material) with per-point normals.
func _runs(pts: PackedVector2Array, mats: PackedInt32Array) -> Array[Dictionary]:
	var n := pts.size()
	var cls: Array[Dictionary] = []
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		var nrm := Vector2(d.y, -d.x).normalized()
		var mname := terrain.material_names[mats[i]]
		cls.append({"top": nrm.y < -0.42, "mat": mname, "n": nrm})
	var start := 0
	for i in n:
		var prev: Dictionary = cls[(i - 1 + n) % n]
		if prev.top != cls[i].top or prev.mat != cls[i].mat:
			start = i
			break
	var runs: Array[Dictionary] = []
	var cur: Dictionary = {}
	for k in n:
		var i := (start + k) % n
		var cl: Dictionary = cls[i]
		if cur.is_empty() or cur.top != cl.top or cur.mat != cl.mat:
			if not cur.is_empty():
				cur.points.append(pts[i])
				cur.normals.append(cur.last_n)
				runs.append(cur)
			cur = {"top": cl.top, "mat": cl.mat, "points": PackedVector2Array(), "normals": PackedVector2Array(), "last_n": cl.n}
		var prev_n: Vector2 = cls[(i - 1 + n) % n].n
		var vn: Vector2 = cl.n if cur.points.is_empty() else (prev_n + cl.n).normalized()
		cur.points.append(pts[i])
		cur.normals.append(vn)
		cur.last_n = cl.n
	if not cur.is_empty():
		cur.points.append(pts[start % n])
		cur.normals.append(cur.last_n)
		runs.append(cur)
	return runs


func _split_seams(line: PackedVector2Array) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	var cur := PackedVector2Array()
	for i in line.size():
		if i > 0 and is_seam(line[i - 1], line[i]):
			if cur.size() >= 2:
				parts.append(cur)
			cur = PackedVector2Array()
		cur.append(line[i])
	if cur.size() >= 2:
		parts.append(cur)
	return parts


static func _off(pts: PackedVector2Array, nrm: PackedVector2Array, dist: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + nrm[i] * dist
	return out


## Calls cb(point, normal, tangent) every ~spacing along a run.
func _walk(run: Dictionary, spacing: float, cb: Callable, jitter: float = 0.0) -> void:
	var pts: PackedVector2Array = run.points
	var nrm: PackedVector2Array = run.normals
	var acc := spacing * _rng.randf()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var d := 0.0
		while acc + (seg - d) >= spacing:
			d += spacing - acc
			acc = 0.0
			var t := d / seg
			var n := nrm[i].lerp(nrm[i + 1], t).normalized()
			cb.call(a.lerp(b, t), n, (b - a) / seg)
			if jitter > 0.0:
				acc = -_rng.randf_range(0.0, jitter)
		acc += seg - d


func _band(cv: InkCanvas, run: Dictionary, depth: float, width: float, col: Color) -> void:
	cv.caps = false
	cv.stroke(_off(run.points, run.normals, -depth - width * 0.5), width, col, 0.0001, 0.0001, 0.0, 0.0, 0.0, 1.0)
	cv.caps = true


func _strip(cv: InkCanvas, run: Dictionary) -> void:
	var mat: String = run.mat
	var pts: PackedVector2Array = InkCanvas.resample(run.points, 10.0)
	if pts.size() < 2:
		return
	# Re-derive normals for the resampled line (outward = left of travel, as in _runs).
	var nrm := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm.append(Vector2(d.y, -d.x))
	var r := {"points": pts, "normals": nrm, "mat": mat, "top": run.top}
	match mat:
		"grass", "rough":
			var g := c("grass")
			var gd := c("grass_dark")
			var gl := c("grass_light")
			if mat == "rough":
				g = g.darkened(0.16)
				gl = gl.darkened(0.16)
			_band(cv, r, 0.0, 17.0, gd)
			# Jagged hanging fringe under the grass band.
			_walk(r, 6.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				var l := _rng.randf_range(3.0, 8.0)
				var a := p - n * 16.0
				cv.stroke(PackedVector2Array([a, a - n * l + _t * _rng.randf_range(-1.5, 1.5)]), _rng.randf_range(2.6, 4.2), gd, 0.05, 0.9, p.x), 1.5)
			_band(cv, r, 0.0, 12.0, g)
			_band(cv, r, 0.4, 2.8, gl)
			# Highlight ticks along the lip.
			_walk(r, 26.0, func(p: Vector2, n: Vector2, t: Vector2) -> void:
				cv.stroke(PackedVector2Array([p - n * 6.0, p - n * 6.0 + t * _rng.randf_range(5.0, 9.0)]), 1.6, Color(gl, 0.8), 0.4, 0.4), 18.0)
		"sand":
			_band(cv, r, 0.0, 15.0, c("sand_dark"))
			_band(cv, r, 0.0, 11.0, c("sand"))
			_walk(r, 7.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				cv.dot(p - n * _rng.randf_range(3.0, 12.0) + _t * _rng.randf_range(-3, 3), _rng.randf_range(0.6, 1.3), c("sand_dark")), 2.0)
			_walk(r, 34.0, func(p: Vector2, n: Vector2, t: Vector2) -> void:
				var q := p - n * 6.5
				cv.stroke(InkCanvas.quad_bez(q - t * 5.0, q - n * 1.6, q + t * 5.0, 4), 1.3, c("sand_dark"), 0.3, 0.3), 14.0)
		"snow":
			_band(cv, r, 0.0, 19.0, c("snow_shadow"))
			_band(cv, r, 0.0, 15.0, c("snow"))
			_walk(r, 30.0, func(p: Vector2, n: Vector2, t: Vector2) -> void:
				var q := p - n * _rng.randf_range(8.0, 13.0)
				cv.stroke(PackedVector2Array([q, q + t * _rng.randf_range(6.0, 12.0)]), 1.5, Color(c("snow_shadow"), 0.9), 0.4, 0.4), 20.0)
		"ice":
			_band(cv, r, 0.0, 14.0, c("ice_dark"))
			_band(cv, r, 0.0, 11.0, c("ice"))
			_band(cv, r, 1.2, 2.2, c("ice_light"))
			_walk(r, 40.0, func(p: Vector2, n: Vector2, t: Vector2) -> void:
				var q := p - n * 7.0
				cv.stroke(PackedVector2Array([q - t * 6.0, q + t * 6.0]), 1.8, Color(1, 1, 1, 0.9), 0.4, 0.4)
				cv.stroke(PackedVector2Array([q + t * 9.0 - n * 1.0, q + t * 12.0 + n * -6.0]), 1.0, Color(c("ink"), 0.35), 0.2, 0.4), 25.0)
		"sticky":
			_band(cv, r, 0.0, 15.0, c("sticky_dark"))
			_band(cv, r, 0.0, 11.0, c("sticky"))
			_band(cv, r, 1.0, 2.4, c("sticky").lightened(0.35))
			# Goo drips always hang downward, so ceilings drip into the air.
			_walk(r, 20.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				var base := p - n * 13.0
				var l := _rng.randf_range(4.0, 15.0)
				var tip := base + Vector2(0, l)
				if Geometry2D.is_point_in_polygon(tip + Vector2(0, 4), _poly_for(p)) and n.y > 0.3:
					return
				cv.stroke(PackedVector2Array([base, tip]), _rng.randf_range(3.0, 5.0), c("sticky_dark"), 0.05, 0.3)
				cv.dot(tip, _rng.randf_range(2.0, 3.0), c("sticky_dark"))
				cv.dot(tip + Vector2(-0.6, -0.6), 0.8, Color(1, 1, 1, 0.6)), 14.0)
		"bouncy":
			_band(cv, r, 0.0, 14.0, c("bouncy").darkened(0.3))
			var prev := [pts[0]]
			var on := [false]
			_walk(r, 13.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				var col: Color = c("bouncy") if on[0] else c("bouncy_light")
				var a: Vector2 = prev[0]
				cv.quad(a - n * 1.5, p - n * 1.5, p - n * 11.0, a - n * 11.0, col)
				prev[0] = p
				on[0] = not on[0])
			cv.stroke(_off(pts, nrm, -12.0), 1.6, c("ink"), 0.0001, 0.0001)
		"rock":
			_band(cv, r, 0.0, 14.0, c("rock_dark"))
			_band(cv, r, 0.0, 11.0, c("rock"))
			_walk(r, 6.5, func(p: Vector2, n: Vector2, t: Vector2) -> void:
				var q := p - n * _rng.randf_range(3.0, 10.0)
				cv.stroke(PackedVector2Array([q, q + (t * 0.7 - n * 0.7) * _rng.randf_range(3.0, 6.0)]), 1.1, Color(c("rock_dark"), 0.9), 0.3, 0.3), 3.0)
		"wood":
			_band(cv, r, 0.0, 14.0, c("wood_dark"))
			_band(cv, r, 0.0, 11.0, c("wood"))
			cv.stroke(_off(pts, nrm, -5.5), 1.0, Color(c("wood_dark"), 0.8), 0.0001, 0.0001, 3.0, 0.3, 0.8, 0.5)
			_walk(r, 62.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				cv.stroke(PackedVector2Array([p - n * 1.0, p - n * 11.0]), 1.4, c("wood_dark"), 0.1, 0.1)
				cv.dot(p - n * 6.0 + _t * 8.0, 1.0, c("wood_dark")))
		"metal":
			_band(cv, r, 0.0, 14.0, c("metal_dark"))
			_band(cv, r, 0.0, 11.0, c("metal"))
			_band(cv, r, 1.4, 1.8, Color(1, 1, 1, 0.75))
			_walk(r, 28.0, func(p: Vector2, n: Vector2, _t: Vector2) -> void:
				cv.dot(p - n * 7.5, 1.4, c("metal_dark"))
				cv.dot(p - n * 7.5 + Vector2(-0.4, -0.4), 0.5, Color(1, 1, 1, 0.8)))
		_:
			pass


func _poly_for(p: Vector2) -> PackedVector2Array:
	for poly in terrain.polygons:
		var pts: PackedVector2Array = poly.points
		if Geometry2D.is_point_in_polygon(p + Vector2(0, -2), pts) or Geometry2D.is_point_in_polygon(p + Vector2(0, 2), pts):
			return pts
	return terrain.polygons[0].points if terrain.polygons.size() > 0 else PackedVector2Array()


## Grass blade clumps and the odd flower above the surface (decoration only).
func _tufts(cv: InkCanvas, run: Dictionary) -> void:
	var pts: PackedVector2Array = InkCanvas.resample(run.points, 10.0)
	if pts.size() < 2:
		return
	var nrm := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm.append(Vector2(d.y, -d.x))
	var r := {"points": pts, "normals": nrm}
	var rough: bool = run.mat == "rough"
	var gd := c("grass_dark")
	var g := c("grass")
	var flowers: Array = pal.flowers
	var cup_l := terrain.cup_left - 30.0
	var cup_r := terrain.cup_right + 30.0
	_walk(r, 34.0 if not rough else 18.0, func(p: Vector2, n: Vector2, t: Vector2) -> void:
		if terrain.has_cup and p.x > cup_l and p.x < cup_r:
			return
		if _rng.randf() < 0.3:
			return
		var blades := _rng.randi_range(2, 4)
		for k in blades:
			var off := float(k - blades * 0.5) * 2.6
			var h := _rng.randf_range(5.0, 10.0) * (1.6 if rough else 1.0)
			var lean := _rng.randf_range(-0.45, 0.45)
			var base := p + t * off - n * 1.5
			var tip := base + n * h + t * lean * h
			cv.stroke(InkCanvas.quad_bez(base, base + n * h * 0.6, tip, 4), _rng.randf_range(1.7, 2.4), gd if k % 2 == 0 else g.darkened(0.1), 0.05, 0.85, p.x + k)
		if _rng.randf() < 0.16 and not rough:
			var stem_top := p + n * _rng.randf_range(9.0, 15.0) + t * _rng.randf_range(-3, 3)
			cv.stroke(PackedVector2Array([p - n * 1.0, stem_top]), 1.4, gd, 0.05, 0.2)
			var fc := Color(str(flowers[_rng.randi() % flowers.size()]))
			for q in 5:
				cv.dot(stem_top + Vector2.from_angle(TAU * q / 5.0) * 2.4, 1.9, fc)
			cv.dot(stem_top, 1.3, Color("f2b630") if fc != Color("f7d24a") else Color("e8543a")), 22.0)


# ---------------------------------------------------------------------------
# Decor
# ---------------------------------------------------------------------------

## Decor never floats in the air: ground decor stands on the lowest walkable point under its
## footprint, "water" decor bobs at the waterline under x, "ceiling" decor hangs from the
## surface above. Anything without a surface to sit on is skipped.
func _build_decor(parent: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hole.get("id", ""))
	for d: Dictionary in hole.get("decor", []):
		var type := str(d.get("type", ""))
		var node := InkDecor.make(type, pal, rng.randi())
		if node == null:
			continue
		var pos := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		var sc := float(d.get("scale", 1.0))
		node.scale = Vector2(sc, sc)
		if rng.randf() < 0.5 and InkDecor.can_flip(type):
			node.scale.x = -sc
		match InkDecor.anchor(type):
			"water":
				var placed := false
				for z in terrain.zones:
					var zr: Rect2 = z["rect"]
					if z["type"] == "water" and pos.x >= zr.position.x and pos.x <= zr.end.x:
						node.position = Vector2(pos.x, zr.position.y + 4.0)
						placed = true
						break
				if not placed:
					node.free()
					continue
			"ceiling":
				var up := terrain.raycast(pos + Vector2(0, 40), Vector2.UP, 400.0)
				if not (up.hit and up.normal.y > 0.5):
					node.free()
					continue
				node.position = up.pos + Vector2(0, -3)
			"free":
				node.position = pos
			_:
				var base := _decor_ground(pos, InkDecor.footprint(type) * sc)
				if base.x == INF:
					node.free()
					continue
				node.position = base + Vector2(0, 5)
		parent.add_child(node)


## Where a ground decor `width` wide stands near `pos`: the lowest walkable surface point under
## its footprint (so it never overhangs a slope; the part below hides behind the soil). Searches
## down from just above the authored height so decor under an overhang lands on the floor.
func _decor_ground(pos: Vector2, width: float) -> Vector2:
	var centre := _walkable_below(pos)
	if centre.x == INF:
		return centre
	var lowest := centre.y
	for dx in [-width * 0.35, width * 0.35]:
		var side := _walkable_below(Vector2(pos.x + dx, centre.y))
		if side.x != INF and absf(side.y - centre.y) < 60.0:
			lowest = maxf(lowest, side.y)
	return Vector2(centre.x, lowest)


func _walkable_below(pos: Vector2) -> Vector2:
	for start in [80.0, 400.0]:
		var hit := terrain.raycast(pos + Vector2(0, -start), Vector2.DOWN, start + 1000.0)
		if hit.hit and hit.normal.y < -0.6 and not terrain.is_point_solid(pos + Vector2(0, -start)):
			return hit.pos
	return Vector2(INF, INF)


# ---------------------------------------------------------------------------
# Cup & flag
# ---------------------------------------------------------------------------

class _Cup extends Node2D:
	var view: TerrainView

	func _draw() -> void:
		var t := view.terrain
		if not t.has_cup:
			return
		var cv := InkCanvas.new()
		var l := t.cup_left
		var r := t.cup_right
		var top := t.cup_pos.y - 8.0
		var bottom := t.cup_floor_y
		cv.fill(PackedVector2Array([Vector2(l - 1, top), Vector2(r + 1, top), Vector2(r + 1, bottom + 2), Vector2(l - 1, bottom + 2)]), Color("221a16"))
		cv.fill(PackedVector2Array([Vector2(l, bottom - 5), Vector2(r, bottom - 5), Vector2(r, bottom + 2), Vector2(l, bottom + 2)]), Color("3a2c24"))
		# White cup liner on both walls.
		cv.stroke(PackedVector2Array([Vector2(l + 2.0, top + 9.0), Vector2(l + 2.0, bottom - 1.0)]), 3.0, Color("f2eee6"), 0.05, 0.05)
		cv.stroke(PackedVector2Array([Vector2(r - 2.0, top + 9.0), Vector2(r - 2.0, bottom - 1.0)]), 3.0, Color("d9d3c8"), 0.05, 0.05)
		cv.flush(get_canvas_item())


class _Flag extends Node2D:
	var number := 1
	var _t := 0.0
	var _cv := InkCanvas.new()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var h := 132.0
		var top := Vector2(1.0, -h)
		var pole := PackedVector2Array([Vector2(0, 24), Vector2(0.6, -h * 0.5), top])
		_cv.stroke(pole, 5.6, InkCanvas.INK, 0.0001, 0.0001, 1.0, 0.0)
		_cv.stroke(pole, 2.6, Color("f6f2ea"), 0.0001, 0.0001, 2.0, 0.0)
		var w := 60.0
		var hh := 38.0
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 11:
			var u := float(i) / 10.0
			var wave := sin(_t * 4.6 - u * 4.2) * 4.5 * u + sin(_t * 7.3 - u * 6.0) * 1.2 * u
			upper.append(top + Vector2(u * w, wave + u * 3.0))
			lower.append(top + Vector2(u * w * 0.97, hh - u * hh * 0.42 + wave))
		lower.reverse()
		var cloth := upper + lower
		_cv.fill(cloth, Color("e8543a"))
		# A darker fold where the cloth turns.
		var fold := PackedVector2Array()
		for i in range(4, 8):
			fold.append(upper[i].lerp(lower[10 - i], 0.5) + Vector2(0, -3))
		_cv.stroke(fold, 1.4, Color(0, 0, 0, 0.25), 0.4, 0.4)
		_cv.outline(cloth, 2.8, InkCanvas.INK, 4.0)
		_cv.ink_circle(top + Vector2(0, -2.0), Vector2(3.6, 3.6), 2.2, InkCanvas.INK, 2.0)
		_cv.flush(get_canvas_item())
		var font := UITheme.heading_font()
		var mid := top + Vector2(w * 0.4, hh * 0.52 + sin(_t * 4.6 - 1.8) * 2.0)
		draw_string_outline(font, mid + Vector2(-12, 11), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 30, 6, InkCanvas.INK)
		draw_string(font, mid + Vector2(-12, 11), str(number), HORIZONTAL_ALIGNMENT_CENTER, 24, 30, Color("fbf6ec"))


# ---------------------------------------------------------------------------
# Hazard zones (water / lava / acid)
# ---------------------------------------------------------------------------

## Water bodies are clipped to open air once; each frame only the wavy ink surface line, ripple
## ticks and glints are redrawn.
class _Water extends Node2D:
	var view: TerrainView
	var _bodies: Array[Dictionary] = []   ## {kind, parts: Array[PackedVector2Array], spans: Array[Vector2], rect}
	var _static: InkStatic
	var _t := 0.0
	var _cv := InkCanvas.new()

	func setup() -> void:
		var terrain := view.terrain
		var body_cv := InkCanvas.new()
		for z in terrain.zones:
			var rect: Rect2 = z.rect
			var kind: String = z.type
			var poly := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			var parts: Array[PackedVector2Array] = [poly]
			for tp in terrain.polygons:
				var next: Array[PackedVector2Array] = []
				for part in parts:
					for clipped in Geometry2D.clip_polygons(part, tp.points):
						if not Geometry2D.is_polygon_clockwise(clipped):
							next.append(clipped)
				parts = next
			var cols := _colors(kind)
			for part in parts:
				var pc := PackedColorArray()
				for v in part:
					var k := clampf((v.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
					pc.append(Color(cols[0].lerp(cols[1], k), 0.95))
				body_cv.fill_colored(part, pc)
			# Open-air spans along the water line (where the surface stroke is drawn).
			var spans: Array[Vector2] = []
			var x := rect.position.x
			var start := INF
			while x <= rect.end.x:
				var open := not terrain.is_point_solid(Vector2(x, rect.position.y + 3.0))
				if open and start == INF:
					start = x
				elif not open and start != INF:
					spans.append(Vector2(start, x - 4.0))
					start = INF
				x += 4.0
			if start != INF:
				spans.append(Vector2(start, rect.end.x))
			_bodies.append({"kind": kind, "parts": parts, "spans": spans, "rect": rect})
		if not _bodies.is_empty():
			_static = InkStatic.new()
			_static.canvas = body_cv
			_static.show_behind_parent = true
			add_child(_static)
		set_process(not _bodies.is_empty())

	func _colors(kind: String) -> Array[Color]:
		match kind:
			"lava":
				return [Color("ffb347"), Color("d62828")]
			"acid":
				return [Color("b8f35a"), Color("3f8f2a")]
		return [view.c("water"), view.c("water_deep")]

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var line_c := view.c("water_line")
		for b in _bodies:
			var rect: Rect2 = b.rect
			var kind: String = b.kind
			var lc := line_c if kind == "water" else Color(_colors(kind)[1], 1.0).darkened(0.4)
			for sp: Vector2 in b.spans:
				if sp.y - sp.x < 6.0:
					continue
				var surf := PackedVector2Array()
				var steps := maxi(3, int((sp.y - sp.x) / 12.0))
				for i in steps + 1:
					var x := lerpf(sp.x, sp.y, float(i) / steps)
					surf.append(Vector2(x, rect.position.y + sin(x * 0.034 + _t * 2.1) * 2.2 + sin(x * 0.011 - _t * 1.2) * 1.4))
				_cv.stroke(surf, 3.0, lc, 0.0001, 0.0001, 3.0, 0.12)
				_cv.stroke(InkCanvas.offset_line(surf, -2.6), 1.6, Color(1, 1, 1, 0.75), 0.0001, 0.0001)
				# Ripple ticks drifting under the surface.
				var n := int((sp.y - sp.x) / 64.0)
				for i in n:
					var x := sp.x + fposmod(float(i) * 64.0 + _t * 14.0, sp.y - sp.x)
					var y := rect.position.y + 14.0 + fmod(float(i) * 29.0, maxf(rect.size.y * 0.6, 1.0))
					if view.terrain.is_point_solid(Vector2(x, y)) or view.terrain.is_point_solid(Vector2(x + 14, y)):
						continue
					var a := 0.5 * (0.6 + 0.4 * sin(_t * 2.0 + i))
					_cv.stroke(InkCanvas.quad_bez(Vector2(x, y), Vector2(x + 7, y - 2.5), Vector2(x + 14, y), 4), 1.6, Color(1, 1, 1, a), 0.3, 0.3)
		_cv.flush(get_canvas_item())
