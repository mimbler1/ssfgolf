class_name SimTerrain
extends RefCounted
## Static collision geometry for one hole, built from hole data.
##
## Hole data polygons are lists of control points. Each point is [x, y] or
## [x, y, {"m": "<material>", "c": true}], where "m" sets the material of the
## edge that starts at that point and "c" marks a hard corner (no smoothing).
## Smooth polygons are subdivided with centripetal Catmull-Rom splines.
## The cup notch is cut automatically into the surface at the cup's x position.

const CELL := 96.0
const GRID_MARGIN := 28.0
const SMOOTH_STEP := 22.0
const CUP_WIDTH := 34.0
const CUP_DEPTH := 30.0

var hole_id: String = ""
var bounds: Rect2 = Rect2()
var material_names: PackedStringArray = PackedStringArray()

# Flattened segment arrays (index-aligned).
var seg_a: PackedVector2Array = PackedVector2Array()
var seg_b: PackedVector2Array = PackedVector2Array()
var seg_n: PackedVector2Array = PackedVector2Array()
var seg_mat: PackedInt32Array = PackedInt32Array()

## Render/solid data: Array of { "points": PackedVector2Array, "edge_mats": PackedInt32Array, "base": int, "kind": String }
var polygons: Array[Dictionary] = []
## Hazard zones: Array of { "type": String, "points": PackedVector2Array, "rect": Rect2 }
var zones: Array[Dictionary] = []
## Force fields (not hazards): Array of { "type": "gravity", "points", "rect", "scale": float,
## "vector": Vector2 (absolute gravity, used when "has_vector") }. See PHYSICS_SPEC.md §6.
var fields: Array[Dictionary] = []
## Upward-facing edges of water zones. Solid (as ice) only for balls that freeze water.
var water_a: PackedVector2Array = PackedVector2Array()
var water_b: PackedVector2Array = PackedVector2Array()
var water_n: PackedVector2Array = PackedVector2Array()
var ice_mat: int = -1

var tee: Vector2 = Vector2.ZERO
var cup_pos: Vector2 = Vector2.ZERO        ## Center of the cup mouth (surface level).
var cup_floor_y: float = 0.0
var cup_left: float = 0.0
var cup_right: float = 0.0
var has_cup: bool = false

var _grid: Dictionary = {}  # Vector2i -> PackedInt32Array


func material_index(mat_name: String) -> int:
	var idx := material_names.find(mat_name)
	if idx == -1:
		material_names.append(mat_name)
		idx = material_names.size() - 1
	return idx


func build(hole: Dictionary) -> void:
	hole_id = str(hole.get("id", ""))
	var bd: Dictionary = hole.get("bounds", {})
	bounds = Rect2(float(bd.get("x", 0)), float(bd.get("y", -1200)), float(bd.get("w", 3000)), float(bd.get("h", 1800)))
	var tee_d: Dictionary = hole.get("tee", {})
	tee = Vector2(float(tee_d.get("x", 0)), float(tee_d.get("y", 0)))
	var cup_d: Dictionary = hole.get("cup", {})

	for poly_d: Dictionary in hole.get("terrain", []):
		var base_mat := str(poly_d.get("material", "grass"))
		var smooth := bool(poly_d.get("smooth", true))
		var result := _expand_polygon(poly_d.get("points", []), base_mat, smooth)
		var pts: PackedVector2Array = result[0]
		var mats: PackedInt32Array = result[1]
		if pts.size() < 3:
			continue
		polygons.append({
			"points": pts, "edge_mats": mats, "base": material_index(base_mat),
			"kind": str(poly_d.get("kind", "ground")),
		})

	if not cup_d.is_empty():
		_cut_cup(float(cup_d.get("x", 0)), float(cup_d.get("y", 0)))

	for poly in polygons:
		_add_polygon_segments(poly["points"], poly["edge_mats"])
		poly["rect"] = _rect_of(poly["points"])

	for zone_d: Dictionary in hole.get("zones", []):
		var zp := PackedVector2Array()
		for p in zone_d.get("points", []):
			zp.append(Vector2(float(p[0]), float(p[1])))
		if zp.size() >= 3:
			var r := Rect2(zp[0], Vector2.ZERO)
			for v in zp:
				r = r.expand(v)
			var ztype := str(zone_d.get("type", "water"))
			zones.append({"type": ztype, "points": zp, "rect": r})
			if ztype == "water":
				_add_water_tops(zp)

	for field_d: Dictionary in hole.get("fields", []):
		var fp := PackedVector2Array()
		for p in field_d.get("points", []):
			fp.append(Vector2(float(p[0]), float(p[1])))
		if fp.size() < 3:
			continue
		var fr := Rect2(fp[0], Vector2.ZERO)
		for v in fp:
			fr = fr.expand(v)
		var vec: Array = field_d.get("vector", [])
		fields.append({"type": str(field_d.get("type", "gravity")), "points": fp, "rect": fr,
			"scale": float(field_d.get("scale", 1.0)),
			"has_vector": vec.size() == 2,
			"vector": Vector2(float(vec[0]), float(vec[1])) if vec.size() == 2 else Vector2.ZERO})
	if not water_a.is_empty():
		ice_mat = material_index("ice")

	_build_grid()


# ---------------------------------------------------------------------------
# Polygon expansion
# ---------------------------------------------------------------------------

func _expand_polygon(raw: Array, base_mat: String, smooth: bool) -> Array:
	var ctrl := PackedVector2Array()
	var corner: Array[bool] = []
	var mats := PackedInt32Array()
	var base_idx := material_index(base_mat)
	for p in raw:
		ctrl.append(Vector2(float(p[0]), float(p[1])))
		var flags: Dictionary = p[2] if p.size() > 2 and p[2] is Dictionary else {}
		corner.append(bool(flags.get("c", false)) or not smooth)
		mats.append(material_index(str(flags["m"])) if flags.has("m") else base_idx)

	# Normalise winding so the signed area is positive (clockwise on screen):
	# the outward normal of edge a->b is then (d.y, -d.x).
	if _signed_area(ctrl) < 0.0:
		ctrl.reverse()
		corner.reverse()
		# Edge materials belong to the edge starting at each point; after reversing,
		# the edge i->i+1 corresponds to the old edge (i+1)->i which started at old i+1.
		var old := mats.duplicate()
		var n := old.size()
		for i in n:
			mats[i] = old[(n - 2 - i + n) % n]

	var out_pts := PackedVector2Array()
	var out_mats := PackedInt32Array()
	var count := ctrl.size()
	for i in count:
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % count]
		var m := mats[i]
		if corner[i] and corner[(i + 1) % count]:
			out_pts.append(p1)
			out_mats.append(m)
			continue
		var p0 := ctrl[(i - 1 + count) % count] if not corner[i] else p1 - (p2 - p1)
		var p3 := ctrl[(i + 2) % count] if not corner[(i + 1) % count] else p2 + (p2 - p1)
		var steps := maxi(1, ceili(p1.distance_to(p2) / SMOOTH_STEP))
		for s in steps:
			out_pts.append(_catmull_rom(p0, p1, p2, p3, float(s) / float(steps)))
			out_mats.append(m)
	return [out_pts, out_mats]


static func _signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p := pts[i]
		var q := pts[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Centripetal parameterisation (alpha = 0.5) avoids cusps and self-intersections.
	var t0 := 0.0
	var t1 := t0 + pow(maxf(p0.distance_to(p1), 0.001), 0.5)
	var t2 := t1 + pow(maxf(p1.distance_to(p2), 0.001), 0.5)
	var t3 := t2 + pow(maxf(p2.distance_to(p3), 0.001), 0.5)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


# ---------------------------------------------------------------------------
# Cup
# ---------------------------------------------------------------------------

func _cut_cup(cx: float, hint_y: float) -> void:
	var left := cx - CUP_WIDTH * 0.5
	var right := cx + CUP_WIDTH * 0.5
	var best_poly := -1
	var best_i := -1
	var best_j := -1
	var best_err := INF
	for pi in polygons.size():
		var pts: PackedVector2Array = polygons[pi]["points"]
		var n := pts.size()
		# Top surfaces run left -> right with positive-area winding.
		var i_l := -1
		var i_r := -1
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if b.x <= a.x:
				continue
			if a.x <= left and left < b.x and i_l == -1 and absf(_y_at(a, b, left) - hint_y) < 140.0:
				i_l = i
			if a.x < right and right <= b.x and i_l != -1 and absf(_y_at(a, b, right) - hint_y) < 140.0:
				i_r = i
				break
		if i_l != -1 and i_r != -1:
			var y_mid := _y_at(pts[i_l], pts[(i_l + 1) % n], left)
			var err := absf(y_mid - hint_y)
			if err < best_err:
				best_err = err
				best_poly = pi
				best_i = i_l
				best_j = i_r
	if best_poly == -1:
		push_warning("Hole %s: could not place cup at x=%s" % [hole_id, cx])
		return

	var poly := polygons[best_poly]
	var pts: PackedVector2Array = poly["points"]
	var mats: PackedInt32Array = poly["edge_mats"]
	var n := pts.size()
	var y_l := _y_at(pts[best_i], pts[(best_i + 1) % n], left)
	var y_r := _y_at(pts[best_j], pts[(best_j + 1) % n], right)
	var floor_y := maxf(y_l, y_r) + CUP_DEPTH
	var cup_mat := material_index("cup")
	var surf_mat_l := mats[best_i]
	var surf_mat_r := mats[best_j]

	var new_pts := PackedVector2Array()
	var new_mats := PackedInt32Array()
	# Walk the polygon starting just after best_j so the notch splice is contiguous.
	for k in n:
		var i := (best_j + 1 + k) % n
		# Skip points strictly between the left and right crossing edges.
		var in_cut := false
		if best_i <= best_j:
			in_cut = i > best_i and i <= best_j
		else:
			in_cut = i > best_i or i <= best_j
		if in_cut:
			continue
		new_pts.append(pts[i])
		new_mats.append(mats[i])
		if i == best_i:
			new_mats[new_mats.size() - 1] = surf_mat_l
			new_pts.append(Vector2(left, y_l));   new_mats.append(cup_mat)
			new_pts.append(Vector2(left, floor_y)); new_mats.append(cup_mat)
			new_pts.append(Vector2(right, floor_y)); new_mats.append(cup_mat)
			new_pts.append(Vector2(right, y_r));  new_mats.append(surf_mat_r)
	poly["points"] = new_pts
	poly["edge_mats"] = new_mats
	has_cup = true
	cup_left = left
	cup_right = right
	cup_floor_y = floor_y
	cup_pos = Vector2(cx, (y_l + y_r) * 0.5)


static func _y_at(a: Vector2, b: Vector2, x: float) -> float:
	if absf(b.x - a.x) < 0.0001:
		return a.y
	return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))


const CUP_CAPTURE_SPEED := 620.0

## True when the ball counts as holed: it has fallen deep into the cup at any speed,
## or it has dipped into the cup mouth while moving slowly enough (arcade-forgiving lip).
## Only the cup's own cavity counts: a ball further below (e.g. on a floor under an upper-deck
## green, or in water under an island green) is not in the cup.
func cup_captures(pos: Vector2, radius: float, speed: float) -> bool:
	if not has_cup:
		return false
	if pos.x <= cup_left + 1.0 or pos.x >= cup_right - 1.0:
		return false
	if pos.y > cup_floor_y + 2.0:
		return false
	if pos.y > cup_pos.y + radius * 0.9:
		return true
	var inner := pos.x > cup_left + radius * 0.45 and pos.x < cup_right - radius * 0.45
	return inner and pos.y > cup_pos.y - radius + 2.5 and speed < CUP_CAPTURE_SPEED


# ---------------------------------------------------------------------------
# Segments & grid
# ---------------------------------------------------------------------------

func _add_polygon_segments(pts: PackedVector2Array, mats: PackedInt32Array) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		if d.length_squared() < 0.0001:
			continue
		seg_a.append(a)
		seg_b.append(b)
		seg_n.append(Vector2(d.y, -d.x).normalized())
		seg_mat.append(mats[i])


func _build_grid() -> void:
	_grid.clear()
	for i in seg_a.size():
		var a := seg_a[i]
		var b := seg_b[i]
		var x0 := floori((minf(a.x, b.x) - GRID_MARGIN) / CELL)
		var x1 := floori((maxf(a.x, b.x) + GRID_MARGIN) / CELL)
		var y0 := floori((minf(a.y, b.y) - GRID_MARGIN) / CELL)
		var y1 := floori((maxf(a.y, b.y) + GRID_MARGIN) / CELL)
		for cx in range(x0, x1 + 1):
			for cy in range(y0, y1 + 1):
				var key := Vector2i(cx, cy)
				var arr: PackedInt32Array = _grid.get(key, PackedInt32Array())
				arr.append(i)
				_grid[key] = arr


var _empty := PackedInt32Array()

## Segment indices that may touch a circle of radius <= GRID_MARGIN centred at pos.
func query(pos: Vector2) -> PackedInt32Array:
	return _grid.get(Vector2i(floori(pos.x / CELL), floori(pos.y / CELL)), _empty)


func is_point_solid(p: Vector2) -> bool:
	for poly in polygons:
		if poly["rect"].has_point(p) and point_in_polygon(p, poly["points"]):
			return true
	return false


## Exact point-in-polygon by winding number. Geometry2D.is_point_in_polygon returns false
## positives on large finely subdivided polygons (seen on Sunny Meadows holes 2 and 9), which
## could snap a flying ball onto the ground through the recovery path.
static func point_in_polygon(p: Vector2, pts: PackedVector2Array) -> bool:
	var w := 0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		if a.y <= p.y:
			if b.y > p.y and (b - a).cross(p - a) > 0.0:
				w += 1
		elif b.y <= p.y and (b - a).cross(p - a) < 0.0:
			w -= 1
	return w != 0


static func _rect_of(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for v in pts:
		r = r.expand(v)
	return r


## Returns {hit: bool, pos: Vector2, normal: Vector2, mat: int, dist: float}
func raycast(from: Vector2, dir: Vector2, max_dist: float) -> Dictionary:
	var to := from + dir * max_dist
	var best := max_dist
	var best_i := -1
	var best_p := Vector2.ZERO
	var rmin := Vector2(minf(from.x, to.x), minf(from.y, to.y))
	var rmax := Vector2(maxf(from.x, to.x), maxf(from.y, to.y))
	for i in seg_a.size():
		var a := seg_a[i]
		var b := seg_b[i]
		if maxf(a.x, b.x) < rmin.x or minf(a.x, b.x) > rmax.x or maxf(a.y, b.y) < rmin.y or minf(a.y, b.y) > rmax.y:
			continue
		var hit: Variant = Geometry2D.segment_intersects_segment(from, to, a, b)
		if hit != null:
			var d := from.distance_to(hit)
			if d < best:
				best = d
				best_i = i
				best_p = hit
	if best_i == -1:
		return {"hit": false}
	return {"hit": true, "pos": best_p, "normal": seg_n[best_i], "mat": seg_mat[best_i], "dist": best}


func _add_water_tops(zp: PackedVector2Array) -> void:
	var n := zp.size()
	var area := _signed_area(zp)
	for i in n:
		var a := zp[i]
		var b := zp[(i + 1) % n]
		var d := b - a
		if d.length_squared() < 0.0001:
			continue
		var nrm := Vector2(d.y, -d.x).normalized()
		if area < 0.0:
			nrm = -nrm
		if nrm.y < -0.5:
			water_a.append(a)
			water_b.append(b)
			water_n.append(nrm)


## Gravity at p: `base` unless a gravity field covers p (absolute vector, or scale of base).
func gravity_at(p: Vector2, base: Vector2) -> Vector2:
	for f in fields:
		if f["rect"].has_point(p) and point_in_polygon(p, f["points"]):
			if f["type"] == "gravity":
				return f["vector"] if f["has_vector"] else base * float(f["scale"])
	return base


func zone_at(p: Vector2) -> String:
	for z in zones:
		if z["rect"].has_point(p) and point_in_polygon(p, z["points"]):
			return z["type"]
	return ""


## Surface point under x for placing balls (first hit scanning downward from above).
func surface_below(p: Vector2, max_dist: float = 3000.0) -> Dictionary:
	return raycast(p, Vector2.DOWN, max_dist)
