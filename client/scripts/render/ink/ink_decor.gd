class_name InkDecor
extends Node2D
## Hand-drawn course decoration (never collision) for all six worlds. The origin is the ground
## point (or the waterline / ceiling point for anchored decor). Static parts are drawn once;
## moving parts (canopies, blades, flags, critters) animate by transform only, never by redraw.

const TYPES := ["tree", "bush", "flowers", "rock", "palm", "pine", "snowman", "crystal", "pipe", "vat_pipe",
	"mushroom", "windmill", "lab_light", "pinwheel", "console", "ice_chunk", "gear", "shell", "crab", "vine",
	"grass_tuft", "umbrella", "lighthouse", "buoy", "arrow_up", "arrow_down", "fan", "flag_slalom", "summit_flag",
	"icicle", "flag_small", "balloon"]
const ANCHORS := {"buoy": "water", "icicle": "ceiling", "vine": "ceiling", "balloon": "free"}
## Approximate footprint widths (for standing decor level on slopes).
const FOOTPRINT := {"tree": 90.0, "palm": 70.0, "pine": 70.0, "bush": 60.0, "flowers": 70.0, "rock": 50.0, "snowman": 40.0,
	"crystal": 40.0, "pipe": 30.0, "vat_pipe": 40.0, "mushroom": 34.0, "windmill": 70.0, "lab_light": 20.0, "pinwheel": 20.0,
	"console": 50.0, "ice_chunk": 50.0, "gear": 50.0, "shell": 20.0, "crab": 30.0, "grass_tuft": 20.0, "umbrella": 60.0,
	"lighthouse": 70.0, "arrow_up": 30.0, "arrow_down": 30.0, "fan": 50.0, "flag_slalom": 20.0, "summit_flag": 20.0, "flag_small": 16.0}
const NO_FLIP := ["lighthouse", "arrow_up", "arrow_down", "console", "windmill"]

var kind := "tree"
var pal: Dictionary = {}
var seed_value := 0
var _part: Node2D          ## the moving part, if any
var _motion := ""          ## sway | spin | bob | blink | scuttle | wave
var _speed := 1.0
var _t := 0.0


static func make(type: String, palette: Dictionary, seed_v: int) -> InkDecor:
	if type not in TYPES:
		return null
	var d := InkDecor.new()
	d.kind = type
	d.pal = palette
	d.seed_value = seed_v
	return d


static func anchor(type: String) -> String:
	return str(ANCHORS.get(type, "ground"))


static func footprint(type: String) -> float:
	return float(FOOTPRINT.get(type, 40.0))


static func can_flip(type: String) -> bool:
	return type not in NO_FLIP


func _part_canvas(pos: Vector2, cv: InkCanvas, motion: String, speed: float = 1.0) -> void:
	var st := InkStatic.new()
	st.position = pos
	st.canvas = cv
	_part = st
	_motion = motion
	_speed = speed


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_t = rng.randf() * 10.0
	var base := InkCanvas.new()
	match kind:
		"tree":
			_tree_trunk(base, rng)
			_part_canvas(Vector2(0, -86), _tree_canopy(rng), "sway")
		"palm":
			_palm_trunk(base, rng)
			_part_canvas(Vector2(14, -132), _palm_fronds(rng), "sway")
		"pine":
			_pine(base, rng)
		"bush":
			_bush(base, rng)
		"flowers":
			_flowers(base, rng)
		"rock":
			_rock(base, rng)
		"snowman":
			_snowman(base, rng)
		"crystal":
			_crystal(base, rng)
		"pipe", "vat_pipe":
			_pipe(base, rng)
		"mushroom":
			_mushroom(base, rng)
		"windmill":
			_windmill(base)
			_part_canvas(Vector2(0, -118), _blades(4, 54.0, Color("fbf6ec")), "spin", 0.9)
		"pinwheel":
			cv_stick(base, 46.0)
			_part_canvas(Vector2(0, -46), _pinwheel(), "spin", 2.6)
		"fan":
			_fan_body(base)
			_part_canvas(Vector2(0, -36), _blades(3, 24.0, _c("metal")), "spin", 7.0)
		"gear":
			_part_canvas(Vector2(0, -26), _gear(26.0), "spin", 0.6)
		"lab_light":
			_lab_light(base)
			var bulb := InkCanvas.new()
			bulb.dot(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.3, 0.9))
			bulb.dot(Vector2.ZERO, 11.0, Color(1.0, 0.85, 0.3, 0.25))
			_part_canvas(Vector2(0, -58), bulb, "blink", 1.6)
		"console":
			_console(base, rng)
		"ice_chunk":
			_ice_chunk(base, rng)
		"shell":
			_shell(base, rng)
		"crab":
			_part_canvas(Vector2.ZERO, _crab(), "scuttle", 1.0)
		"vine":
			_part_canvas(Vector2.ZERO, _vine(rng), "sway", 0.7)
		"icicle":
			_icicles(base, rng)
		"grass_tuft":
			_grass_tuft(base, rng)
		"umbrella":
			_umbrella(base, rng)
		"lighthouse":
			_lighthouse(base)
			var beam := InkCanvas.new()
			beam.fill(PackedVector2Array([Vector2.ZERO, Vector2(120, -18), Vector2(120, 18)]), Color(1.0, 0.92, 0.6, 0.28))
			_part_canvas(Vector2(0, -163), beam, "spin", 0.5)
		"buoy":
			_part_canvas(Vector2.ZERO, _buoy(), "bob", 1.0)
		"arrow_up", "arrow_down":
			_sign_arrow(base, kind == "arrow_up")
		"flag_slalom", "summit_flag", "flag_small":
			var h := 70.0 if kind == "flag_small" else (96.0 if kind == "summit_flag" else 84.0)
			cv_stick(base, h)
			var col := Color("e8543a") if kind != "flag_slalom" else (Color("3c6fe0") if rng.randf() < 0.5 else Color("e8543a"))
			_part_canvas(Vector2(1, -h), _pennant(col, 0.75 if kind == "flag_small" else 1.0), "wave", 1.0)
		"balloon":
			_part_canvas(Vector2.ZERO, _balloon(rng), "bob", 0.6)
	if not base.pts.is_empty():
		var st := InkStatic.new()
		st.canvas = base
		add_child(st)
	if _part:
		add_child(_part)
	set_process(_part != null)


func _process(delta: float) -> void:
	_t += delta * _speed
	match _motion:
		"sway":
			_part.rotation = sin(_t * 1.05) * 0.022 + sin(_t * 2.4) * 0.008
		"spin":
			_part.rotation = _t
		"bob":
			_part.position.y = sin(_t * 1.8) * 3.0
			_part.rotation = sin(_t * 1.3) * 0.06
		"blink":
			_part.modulate.a = 0.35 + 0.65 * absf(sin(_t * 2.0))
		"scuttle":
			_part.position.x = sin(_t * 0.7) * 10.0
			_part.position.y = -absf(sin(_t * 9.0)) * 1.2
		"wave":
			_part.skew = sin(_t * 4.0) * 0.12
			_part.scale.y = 1.0 + sin(_t * 5.3) * 0.05


func _c(key: String) -> Color:
	return InkThemes.col(pal, key)


static func _blob_union(blobs: Array, seg: int = 18) -> PackedVector2Array:
	var merged := PackedVector2Array()
	for b: Vector3 in blobs:
		var e := InkCanvas.ellipse_pts(Vector2(b.x, b.y), Vector2(b.z, b.z * 0.92), 0.0, seg)
		if merged.is_empty():
			merged = e
			continue
		var res := Geometry2D.merge_polygons(merged, e)
		var best := merged
		var best_a := 0.0
		for r in res:
			if Geometry2D.is_polygon_clockwise(r) != Geometry2D.is_polygon_clockwise(merged):
				continue
			var bb := Rect2(r[0], Vector2.ZERO)
			for v in r:
				bb = bb.expand(v)
			if bb.get_area() > best_a:
				best_a = bb.get_area()
				best = r
		merged = best
	return merged


func _tree_trunk(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var bark := Color("8a5c3a")
	var lean := rng.randf_range(-8.0, 8.0)
	var left := InkCanvas.cubic_bez(Vector2(-10, 4), Vector2(-6, -30), Vector2(-9 + lean, -60), Vector2(-6 + lean, -92), 10)
	var right := InkCanvas.cubic_bez(Vector2(6 + lean, -92), Vector2(5 + lean, -60), Vector2(4, -30), Vector2(12, 4), 10)
	var trunk := left + right
	cv.fill(trunk, bark)
	# A curling branch, the classic swirl motif.
	var br := InkCanvas.cubic_bez(Vector2(2 + lean * 0.6, -58), Vector2(16, -66), Vector2(26, -62), Vector2(24, -74), 8)
	cv.stroke(br, 4.2, bark, 0.05, 0.6)
	cv.stroke(br, 1.8, InkCanvas.INK, 0.05, 0.6, 1.0)
	cv.fill(PackedVector2Array([Vector2(-2, -20), Vector2(3, -46), Vector2(5, -20)]), bark.darkened(0.15))
	for k in 3:
		var y := -18.0 - k * 22.0
		cv.stroke(InkCanvas.quad_bez(Vector2(-4, y), Vector2(-1, y - 5), Vector2(-3, y - 10), 4), 1.4, Color(InkCanvas.INK, 0.55), 0.3, 0.3)
	cv.outline(trunk, 2.6, InkCanvas.INK, 3.0, 0.15, 0.3)


func _tree_canopy(rng: RandomNumberGenerator) -> InkCanvas:
	var cv := InkCanvas.new()
	var leaf := _c("near_tree")
	var dark := _c("near_tree_dark")
	var blobs := []
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.25, 0.25)
		blobs.append(Vector3(cos(a) * 36.0, sin(a) * 22.0 - 20.0, rng.randf_range(24, 32)))
	blobs.append(Vector3(0, -30, 34))
	var shape := _blob_union(blobs)
	cv.fill(shape, leaf)
	# Inner shade on the lower right and light blobs on the upper left.
	var shade := _blob_union([Vector3(14, 4, 26), Vector3(30, -8, 18), Vector3(-6, 10, 20)])
	var clipped := Geometry2D.intersect_polygons(shade, shape)
	for p in clipped:
		cv.fill(p, dark.lerp(leaf, 0.35))
	for b in [Vector3(-16, -42, 13), Vector3(4, -50, 10), Vector3(-30, -24, 9)]:
		cv.ellipse(Vector2(b.x, b.y), Vector2(b.z, b.z * 0.8), leaf.lightened(0.14))
	# Leaf marks.
	for k in 12:
		var p := Vector2(rng.randf_range(-38, 38), rng.randf_range(-48, 10))
		if not Geometry2D.is_point_in_polygon(p, shape):
			continue
		cv.stroke(PackedVector2Array([p + Vector2(-3, -2), p, p + Vector2(3, -2.5)]), 1.6, Color(dark, 0.85), 0.3, 0.3)
	cv.outline(shape, 2.6, dark.darkened(0.45), 7.0, 0.15, 0.4)
	return cv


func _bush(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var leaf := _c("near_tree").lightened(0.04)
	var dark := _c("near_tree_dark")
	var blobs := [Vector3(-22, -12, 16), Vector3(0, -20, 21), Vector3(22, -12, 16), Vector3(-10, -6, 14), Vector3(12, -6, 14)]
	var shape := _blob_union(blobs)
	cv.fill(shape, leaf)
	for b in [Vector3(-8, -28, 8), Vector3(12, -22, 6)]:
		cv.ellipse(Vector2(b.x, b.y), Vector2(b.z, b.z * 0.8), leaf.lightened(0.15))
	for k in 6:
		var p := Vector2(rng.randf_range(-26, 26), rng.randf_range(-26, -4))
		if Geometry2D.is_point_in_polygon(p, shape):
			cv.stroke(PackedVector2Array([p + Vector2(-2.5, -1.5), p, p + Vector2(2.5, -2)]), 1.4, Color(dark, 0.8), 0.3, 0.3)
	if rng.randf() < 0.6:
		for k in 4:
			var p := Vector2(rng.randf_range(-22, 22), rng.randf_range(-26, -8))
			if Geometry2D.is_point_in_polygon(p, shape):
				cv.dot(p, 2.4, Color("e8543a"))
	cv.outline(shape, 2.4, dark.darkened(0.45), 2.0, 0.15, 0.4)


func _flowers(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var stem := _c("grass_dark")
	var cols: Array = pal.get("flowers", ["#ffffff"])
	for i in 6:
		var x := rng.randf_range(-36, 36)
		var h := rng.randf_range(14, 26)
		var top := Vector2(x + rng.randf_range(-5, 5), -h)
		cv.stroke(InkCanvas.quad_bez(Vector2(x, 3), Vector2(x, -h * 0.5), top, 4), 1.8, stem, 0.05, 0.2)
		cv.stroke(PackedVector2Array([Vector2(x, -h * 0.4), Vector2(x + 5, -h * 0.55)]), 1.6, stem, 0.1, 0.6)
		var fc := Color(str(cols[rng.randi() % cols.size()]))
		var petals := PackedVector2Array()
		for k in 10:
			petals.append(top + Vector2.from_angle(TAU * k / 10.0) * (5.2 if k % 2 == 0 else 2.6))
		cv.fill(InkCanvas.spline(petals, 2, true), fc)
		cv.outline(InkCanvas.spline(petals, 2, true), 1.3, Color(InkCanvas.INK, 0.8), i)
		cv.dot(top, 1.8, Color("f2b630"))


func _rock(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		pts.append(Vector2(cos(a) * rng.randf_range(20, 28), sin(a) * rng.randf_range(14, 22) + 4))
	var shape := InkCanvas.spline(pts, 3)
	cv.fill(shape, _c("rock"))
	cv.fill(PackedVector2Array([shape[2] + Vector2(3, 4), shape[6] + Vector2(0, 5), shape[8] + Vector2(-2, 6)]), _c("rock").lightened(0.15))
	for k in 5:
		var p := Vector2(rng.randf_range(-6, 18), rng.randf_range(-12, 0))
		cv.stroke(PackedVector2Array([p, p + Vector2(4, 3)]), 1.2, Color(_c("rock_dark"), 0.9), 0.3, 0.3)
	cv.outline(shape, 2.6, InkCanvas.INK, 1.0, 0.15, 0.3)


func _palm_trunk(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var path := InkCanvas.cubic_bez(Vector2(0, 4), Vector2(-4, -50), Vector2(4, -100), Vector2(14, -132), 14)
	var left := InkCanvas.offset_line(path, 6.0)
	var right := InkCanvas.offset_line(path, -6.0)
	right.reverse()
	var trunk := left + right
	cv.fill(trunk, Color("b98a57"))
	for i in range(1, path.size() - 1):
		var d := (path[i + 1] - path[i - 1]).normalized()
		var n := Vector2(-d.y, d.x)
		cv.stroke(PackedVector2Array([path[i] - n * 5.0, path[i] + d * 2.0, path[i] + n * 5.0]), 1.3, Color(InkCanvas.INK, 0.5), 0.2, 0.2)
	cv.outline(trunk, 2.5, InkCanvas.INK)


func _palm_fronds(rng: RandomNumberGenerator) -> InkCanvas:
	var cv := InkCanvas.new()
	var leaf := _c("near_tree")
	for k in 6:
		var a := -PI * 0.5 + (k - 2.5) * 0.55 + rng.randf_range(-0.1, 0.1)
		var tip := Vector2.from_angle(a) * 62.0 + Vector2(0, 26)
		var mid := Vector2.from_angle(a) * 32.0 + Vector2(0, -6)
		var spine := InkCanvas.quad_bez(Vector2.ZERO, mid, tip, 10)
		var upper := InkCanvas.offset_line(spine, 7.0)
		var lower := InkCanvas.offset_line(spine, -5.0)
		for i in upper.size():
			var w := sin(PI * float(i) / (upper.size() - 1))
			upper[i] = spine[i].lerp(upper[i], w)
			lower[i] = spine[i].lerp(lower[i], w)
		lower.reverse()
		var f := upper + lower
		cv.fill(f, leaf if k % 2 == 0 else leaf.darkened(0.1))
		cv.stroke(spine, 1.5, Color(_c("near_tree_dark"), 0.9), 0.1, 0.5)
		cv.outline(f, 2.2, _c("near_tree_dark").darkened(0.4), k)
	cv.dot(Vector2(-4, 4), 5.0, Color("7a5230"))
	cv.dot(Vector2(5, 6), 5.0, Color("6a4428"))
	return cv


func _pine(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(110, 150)
	cv.fill(PackedVector2Array([Vector2(-5, 4), Vector2(-4, -20), Vector2(4, -20), Vector2(5, 4)]), Color("6d4c34"))
	cv.outline(PackedVector2Array([Vector2(-5, 4), Vector2(-4, -20), Vector2(4, -20), Vector2(5, 4)]), 2.2, InkCanvas.INK)
	var leaf := _c("near_tree")
	for tier in 4:
		var y0 := -18.0 - tier * h * 0.21
		var w := 34.0 - tier * 7.0
		var tri := PackedVector2Array([Vector2(-w, y0), Vector2(-w * 0.55, y0 - 6), Vector2(0, y0 - h * 0.34), Vector2(w * 0.55, y0 - 6), Vector2(w, y0), Vector2(w * 0.3, y0 + 4), Vector2(-w * 0.3, y0 + 4)])
		cv.fill(tri, leaf.darkened(tier * 0.03))
		if str(pal.get("id", "")) == "snow":
			cv.fill(PackedVector2Array([Vector2(-w * 0.5, y0 - 8), Vector2(0, y0 - h * 0.33), Vector2(w * 0.5, y0 - 8), Vector2(0, y0 - 14)]), Color(1, 1, 1, 0.9))
		cv.outline(tri, 2.2, _c("near_tree_dark").darkened(0.4), tier)


func _snowman(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	for b: Vector3 in [Vector3(0, -16, 18), Vector3(0, -44, 13), Vector3(0, -64, 9)]:
		cv.ellipse(Vector2(b.x, b.y), Vector2(b.z, b.z), Color("fbfdff"))
		cv.ink_circle(Vector2(b.x, b.y), Vector2(b.z, b.z), 2.3, InkCanvas.INK, b.y)
	cv.dot(Vector2(3, -66), 1.6, InkCanvas.INK)
	cv.dot(Vector2(-3, -66), 1.6, InkCanvas.INK)
	cv.shape(PackedVector2Array([Vector2(0, -62), Vector2(12, -60), Vector2(0, -59)]), Color("f28c38"), 1.2)
	cv.stroke(PackedVector2Array([Vector2(-12, -48), Vector2(-26, -58)]), 2.0, Color("6d4c34"), 0.1, 0.5)
	cv.stroke(PackedVector2Array([Vector2(12, -48), Vector2(26, -60)]), 2.0, Color("6d4c34"), 0.1, 0.5)


func _crystal(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var x := (k - 1) * 12.0
		var h := rng.randf_range(26, 46) * (1.3 if k == 1 else 1.0)
		var shard := PackedVector2Array([Vector2(x - 7, 4), Vector2(x - 6, -h * 0.7), Vector2(x, -h), Vector2(x + 6, -h * 0.7), Vector2(x + 7, 4)])
		cv.fill(shard, Color("9ad6f2").lerp(Color("b49ae8"), k * 0.35))
		cv.fill(PackedVector2Array([Vector2(x - 4, 0), Vector2(x - 3, -h * 0.65), Vector2(x, -h * 0.92), Vector2(x - 0.5, 0)]), Color(1, 1, 1, 0.45))
		cv.outline(shard, 2.2, InkCanvas.INK, k)


func _pipe(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	var body := PackedVector2Array([Vector2(-12, 4), Vector2(-12, -60), Vector2(12, -60), Vector2(12, 4)])
	cv.shape(body, _c("metal"), 2.5)
	cv.shape(PackedVector2Array([Vector2(-17, -60), Vector2(-17, -72), Vector2(17, -72), Vector2(17, -60)]), _c("metal").darkened(0.1), 2.5)
	cv.stroke(PackedVector2Array([Vector2(-6, -2), Vector2(-6, -56)]), 2.2, Color(1, 1, 1, 0.6), 0.1, 0.1)
	for y: float in [-14.0, -40.0]:
		cv.dot(Vector2(8, y), 1.6, _c("metal_dark"))


func _mushroom(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	cv.shape(PackedVector2Array([Vector2(-5, 4), Vector2(-4, -18), Vector2(4, -18), Vector2(5, 4)]), Color("f4ecda"), 2.0)
	var cap := InkCanvas.arc_pts(Vector2(0, -16), 17.0, PI, TAU, 12)
	cv.shape(cap, Color("e8543a"), 2.4)
	for v: Vector2 in [Vector2(-8, -24), Vector2(4, -28), Vector2(9, -20)]:
		cv.dot(v, 2.6, Color("fbf6ec"))


# ---------------------------------------------------------------------------
# Props of the later worlds
# ---------------------------------------------------------------------------

func cv_stick(cv: InkCanvas, h: float) -> void:
	var pole := PackedVector2Array([Vector2(0, 4), Vector2(0.8, -h * 0.5), Vector2(1, -h)])
	cv.stroke(pole, 5.4, InkCanvas.INK, 0.02, 0.05)
	cv.stroke(pole, 2.4, Color("f6f2ea"), 0.02, 0.05)


func _pennant(col: Color, k: float) -> InkCanvas:
	var cv := InkCanvas.new()
	var f := PackedVector2Array([Vector2(0, 0), Vector2(34 * k, 6 * k), Vector2(30 * k, 13 * k), Vector2(0, 22 * k)])
	cv.shape(InkCanvas.spline(f, 3, true), col, 2.2)
	return cv


func _blades(n: int, length: float, col: Color) -> InkCanvas:
	var cv := InkCanvas.new()
	for k in n:
		var a := TAU * k / n
		var d := Vector2.from_angle(a)
		var nn := Vector2(-d.y, d.x)
		var blade := PackedVector2Array([d * 4.0 + nn * 3.0, d * length + nn * (length * 0.18), d * (length + 4.0), d * length - nn * (length * 0.05), d * 4.0 - nn * 3.0])
		cv.shape(blade, col if k % 2 == 0 else col.darkened(0.12), 2.2)
	cv.ellipse(Vector2.ZERO, Vector2(5, 5), Color("6c757d"))
	cv.ink_circle(Vector2.ZERO, Vector2(5, 5), 2.0, InkCanvas.INK, 1.0)
	return cv


func _windmill(cv: InkCanvas) -> void:
	var tower := PackedVector2Array([Vector2(-24, 4), Vector2(-13, -110), Vector2(13, -110), Vector2(24, 4)])
	cv.fill(tower, Color("e9dcc0"))
	for y: float in [-30.0, -64.0]:
		cv.stroke(PackedVector2Array([Vector2(-20, y), Vector2(20, y)]), 1.4, Color(InkCanvas.INK, 0.4), 0.2, 0.2)
	cv.fill(PackedVector2Array([Vector2(-7, 4), Vector2(-7, -18), Vector2(7, -18), Vector2(7, 4)]), Color("8a5c3a"))
	cv.outline(tower, 2.6, InkCanvas.INK, 2.0)
	cv.shape(PackedVector2Array([Vector2(-18, -108), Vector2(0, -134), Vector2(18, -108)]), Color("c44a3c"), 2.4)


func _pinwheel() -> InkCanvas:
	var cv := InkCanvas.new()
	var cols := [Color("e8543a"), Color("f2b630"), Color("3fa3e8"), Color("3dbf7f")]
	for k in 4:
		var a := TAU * k / 4.0
		cv.shape(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a) * 16.0, Vector2.from_angle(a + 0.9) * 13.0]), cols[k], 1.6)
	cv.dot(Vector2.ZERO, 2.4, InkCanvas.INK)
	return cv


func _fan_body(cv: InkCanvas) -> void:
	cv.shape(PackedVector2Array([Vector2(-16, 4), Vector2(-6, -20), Vector2(6, -20), Vector2(16, 4)]), _c("metal_dark"), 2.4)
	cv.ellipse(Vector2(0, -36), Vector2(28, 28), Color(_c("metal"), 0.35))
	cv.ink_circle(Vector2(0, -36), Vector2(28, 28), 2.6, InkCanvas.INK, 3.0)
	for k in 3:
		cv.ink_circle(Vector2(0, -36), Vector2(28 - k * 8, 28 - k * 8), 1.0, Color(InkCanvas.INK, 0.35), k, 0.0, 0.0, 0.0)


func _gear(r: float) -> InkCanvas:
	var cv := InkCanvas.new()
	var g := PackedVector2Array()
	for q in 40:
		g.append(Vector2.from_angle(TAU * q / 40.0) * r * (1.0 if (q / 2) % 2 == 0 else 0.78))
	cv.shape(g, _c("metal"), 2.4)
	cv.ellipse(Vector2.ZERO, Vector2(r * 0.32, r * 0.32), _c("metal_dark"))
	cv.ink_circle(Vector2.ZERO, Vector2(r * 0.32, r * 0.32), 2.0, InkCanvas.INK, 2.0)
	cv.stroke(InkCanvas.arc_pts(Vector2.ZERO, r * 0.6, -2.4, -1.4, 6), 1.8, Color(1, 1, 1, 0.6), 0.2, 0.2)
	return cv


func _lab_light(cv: InkCanvas) -> void:
	cv.stroke(PackedVector2Array([Vector2(0, 4), Vector2(0, -52)]), 3.6, _c("metal_dark"), 0.02, 0.02)
	cv.shape(PackedVector2Array([Vector2(-9, -50), Vector2(9, -50), Vector2(7, -66), Vector2(-7, -66)]), _c("metal"), 2.2)


func _console(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	cv.shape(PackedVector2Array([Vector2(-26, 4), Vector2(-24, -40), Vector2(24, -46), Vector2(26, 4)]), _c("metal"), 2.6)
	cv.shape(PackedVector2Array([Vector2(-17, -34), Vector2(16, -38), Vector2(16, -20), Vector2(-17, -18)]), Color("2b3a55"), 1.8)
	cv.stroke(PackedVector2Array([Vector2(-13, -26), Vector2(-6, -30), Vector2(1, -24), Vector2(10, -32)]), 1.6, Color("7cf2c9"), 0.1, 0.1)
	var lights := [Color("e8543a"), Color("f2b630"), Color("3dbf7f")]
	for k in 3:
		cv.dot(Vector2(-14 + k * 10, -8), 2.6, lights[k])
		cv.ink_circle(Vector2(-14 + k * 10, -8), Vector2(2.6, 2.6), 1.0, InkCanvas.INK, k)


func _ice_chunk(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array([Vector2(-24, 4), Vector2(-20, -18), Vector2(-6, -30), Vector2(10, -26), Vector2(22, -12), Vector2(25, 4)])
	cv.fill(pts, Color("cdeefb"))
	cv.fill(PackedVector2Array([Vector2(-14, -14), Vector2(-6, -26), Vector2(2, -24), Vector2(-6, -10)]), Color(1, 1, 1, 0.75))
	cv.stroke(PackedVector2Array([Vector2(4, -20), Vector2(10, -6), Vector2(6, 2)]), 1.2, Color("8ccbe6"), 0.2, 0.2)
	cv.outline(pts, 2.4, Color("245e8e"), 2.0)


func _icicles(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var x := (k - 1.5) * 9.0 + rng.randf_range(-2, 2)
		var l := rng.randf_range(14, 34)
		var sp := PackedVector2Array([Vector2(x - 4, -2), Vector2(x + 4, -2), Vector2(x + 0.5, l)])
		cv.fill(sp, Color("dff4fd"))
		cv.stroke(PackedVector2Array([Vector2(x - 1.5, 2), Vector2(x - 0.5, l * 0.6)]), 1.1, Color(1, 1, 1, 0.9), 0.2, 0.3)
		cv.outline(sp, 1.6, Color("245e8e"), k)


func _vine(rng: RandomNumberGenerator) -> InkCanvas:
	var cv := InkCanvas.new()
	var leaf := _c("near_tree")
	var line := PackedVector2Array()
	var length := rng.randf_range(60, 110)
	for k in 9:
		line.append(Vector2(sin(k * 0.9) * 5.0, length * k / 8.0))
	var smooth := InkCanvas.spline(line, 3)
	cv.stroke(smooth, 3.0, _c("grass_dark").darkened(0.15), 0.05, 0.4)
	for k in range(1, 8):
		var p := smooth[int(k * (smooth.size() - 1) / 8.0)]
		var side := 1.0 if k % 2 == 0 else -1.0
		cv.shape(InkCanvas.spline(PackedVector2Array([p, p + Vector2(side * 9, 2), p + Vector2(side * 4, 8)]), 2, true), leaf, 1.4)
	return cv


func _grass_tuft(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	for k in 5:
		var x := (k - 2) * 3.5
		var h := rng.randf_range(10, 18) * (1.3 if k == 2 else 1.0)
		cv.stroke(InkCanvas.quad_bez(Vector2(x, 3), Vector2(x, -h * 0.6), Vector2(x + (k - 2) * 2.5, -h), 4), 2.2, _c("grass_dark") if k % 2 == 0 else _c("grass"), 0.05, 0.85)


func _shell(cv: InkCanvas, _rng: RandomNumberGenerator) -> void:
	cv.shape(InkCanvas.arc_pts(Vector2(0, 2), 10.0, PI, TAU, 10), Color("f7c6d6"), 1.8)
	for k in 4:
		var a := PI + PI * (k + 0.5) / 4.0
		cv.stroke(PackedVector2Array([Vector2(0, 2), Vector2(0, 2) + Vector2.from_angle(a) * 9.0]), 1.0, Color(InkCanvas.INK, 0.5), 0.1, 0.3)


func _crab() -> InkCanvas:
	var cv := InkCanvas.new()
	var red := Color("e8543a")
	for side: float in [-1.0, 1.0]:
		for k in 3:
			cv.stroke(PackedVector2Array([Vector2(side * 6, -5), Vector2(side * (12 + k * 2), -3 + k * 2), Vector2(side * (14 + k * 2), 2)]), 1.6, InkCanvas.INK, 0.05, 0.3)
		cv.stroke(PackedVector2Array([Vector2(side * 8, -8), Vector2(side * 14, -16)]), 1.8, InkCanvas.INK, 0.05, 0.1)
		cv.shape(InkCanvas.ellipse_pts(Vector2(side * 15, -19), Vector2(4.5, 3.5), side * 0.4, 10), red, 1.4)
	cv.shape(InkCanvas.ellipse_pts(Vector2(0, -7), Vector2(11, 7), 0.0, 16), red, 2.0)
	for side: float in [-1.0, 1.0]:
		cv.stroke(PackedVector2Array([Vector2(side * 3, -12), Vector2(side * 4, -17)]), 1.4, InkCanvas.INK, 0.05, 0.05)
		cv.dot(Vector2(side * 4, -18), 1.8, InkCanvas.INK)
	return cv


func _umbrella(cv: InkCanvas, rng: RandomNumberGenerator) -> void:
	cv.stroke(PackedVector2Array([Vector2(0, 6), Vector2(2, -74)]), 3.0, Color("8a5c3a"), 0.02, 0.02)
	var top := Vector2(2, -76)
	var canopy := InkCanvas.arc_pts(top + Vector2(0, 16), 44.0, PI * 1.08, PI * 1.92, 14)
	var hem := PackedVector2Array()
	for k in 7:
		hem.append(top + Vector2(40.0 - k * (80.0 / 6.0), 10 + (3.0 if k % 2 == 1 else 0.0)))
	var shape := canopy + hem
	cv.fill(shape, Color("e8543a") if rng.randf() < 0.5 else Color("3fa3e8"))
	for k in 3:
		var x := -26.0 + k * 26.0
		cv.fill(PackedVector2Array([top + Vector2(0, -26), top + Vector2(x - 6, 10), top + Vector2(x + 6, 10)]), Color("fbf6ec"))
	cv.outline(shape, 2.4, InkCanvas.INK, 2.0)


func _lighthouse(cv: InkCanvas) -> void:
	var tower := PackedVector2Array([Vector2(-26, 4), Vector2(-16, -150), Vector2(16, -150), Vector2(26, 4)])
	cv.fill(tower, Color("fbf6ec"))
	for k in 3:
		var y0 := -20.0 - k * 46.0
		cv.fill(PackedVector2Array([Vector2(-24.0 + k * 3.0, y0), Vector2(-22.5 + k * 3.0, y0 - 20), Vector2(22.5 - k * 3.0, y0 - 20), Vector2(24.0 - k * 3.0, y0)]), Color("d6304a"))
	cv.outline(tower, 2.8, InkCanvas.INK, 1.0)
	cv.shape(PackedVector2Array([Vector2(-14, -150), Vector2(-14, -176), Vector2(14, -176), Vector2(14, -150)]), Color("ffe08a"), 2.4)
	cv.shape(PackedVector2Array([Vector2(-19, -176), Vector2(0, -196), Vector2(19, -176)]), Color("2b3a55"), 2.4)
	cv.stroke(PackedVector2Array([Vector2(-22, -150), Vector2(22, -150)]), 3.4, InkCanvas.INK, 0.02, 0.02)


func _buoy() -> InkCanvas:
	var cv := InkCanvas.new()
	var body := PackedVector2Array([Vector2(-14, 6), Vector2(-10, -18), Vector2(10, -18), Vector2(14, 6)])
	cv.fill(body, Color("e8543a"))
	cv.fill(PackedVector2Array([Vector2(-12, -4), Vector2(-11, -10), Vector2(11, -10), Vector2(12, -4)]), Color("fbf6ec"))
	cv.outline(body, 2.4, InkCanvas.INK, 2.0)
	cv.stroke(PackedVector2Array([Vector2(0, -18), Vector2(0, -32)]), 2.2, InkCanvas.INK, 0.05, 0.05)
	cv.dot(Vector2(0, -34), 4.0, Color("f2b630"))
	cv.ink_circle(Vector2(0, -34), Vector2(4, 4), 1.6, InkCanvas.INK, 1.0)
	return cv


func _sign_arrow(cv: InkCanvas, up: bool) -> void:
	cv_stick(cv, 56.0)
	cv.shape(PackedVector2Array([Vector2(-18, -82), Vector2(18, -84), Vector2(17, -52), Vector2(-17, -50)]), Color("f2b630"), 2.4)
	var d := -1.0 if up else 1.0
	cv.shape(PackedVector2Array([Vector2(0, -67 + d * 12), Vector2(9, -67), Vector2(4, -67), Vector2(4, -67 - d * 10), Vector2(-4, -67 - d * 10), Vector2(-4, -67), Vector2(-9, -67)]), InkCanvas.INK, 1.0)


func _balloon(rng: RandomNumberGenerator) -> InkCanvas:
	var cv := InkCanvas.new()
	var cols := [Color("e8543a"), Color("3fa3e8"), Color("f2b630"), Color("9b6be8")]
	var col: Color = cols[rng.randi() % 4]
	cv.stroke(InkCanvas.quad_bez(Vector2(0, 0), Vector2(6, 26), Vector2(0, 50), 6), 1.2, InkCanvas.INK, 0.05, 0.2)
	cv.ellipse(Vector2(0, -16), Vector2(15, 18), col)
	cv.crescent(Vector2(0, -16), 15.0, Vector2(-4, -5), col.darkened(0.15))
	cv.ink_circle(Vector2(0, -16), Vector2(15, 18), 2.2, InkCanvas.INK, 2.0)
	cv.stroke(InkCanvas.arc_pts(Vector2(-4, -22), 7.0, PI * 1.1, PI * 1.5, 4), 2.0, Color(1, 1, 1, 0.7), 0.2, 0.2)
	return cv
