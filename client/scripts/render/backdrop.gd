class_name Backdrop
extends CanvasLayer
## Hand-drawn layered scenery (docs/INK_ART_SPEC.md §9): a paper-sky shader plus seeded,
## horizontally tiling vector layers (far mountains, clouds, mid hills, near tree line) whose
## colours fade toward the sky with depth. Each layer is built once into one mesh shared by its
## three tile copies; following the camera only moves nodes.
## Call `follow(camera_world_pos, zoom)` every frame.

const TILE := 2400.0

var theme: Dictionary = {}
var pal: Dictionary = {}
var _sky: ColorRect
var _layers: Array[Dictionary] = []   ## {node, factor, y, drift}
var _t: float = 0.0
var _scroll := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(p_theme: Dictionary, seed_value: int) -> void:
	theme = p_theme
	pal = InkThemes.get_palette(theme)
	layer = -50
	# Pool matches change world between holes: start from a clean stack.
	for c in get_children():
		c.queue_free()
	_layers.clear()
	_rng.seed = seed_value
	_sky = ColorRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/paper_sky.gdshader")
	mat.set_shader_parameter("top_color", _c("sky_top"))
	mat.set_shader_parameter("bottom_color", _c("sky_bottom"))
	mat.set_shader_parameter("swirl_color", _c("swirl"))
	var reduced := bool(Settings.get_value("gameplay", "reduced_motion"))
	mat.set_shader_parameter("grain", 0.0 if reduced else float(pal.get("grain", 0.05)))
	_sky.material = mat
	add_child(_sky)
	var kinds: Array = pal.get("layers", ["mountains", "clouds", "hills", "trees"])
	_add(_far(str(kinds[0])), 0.05, 60.0, 0.0)
	_add(_clouds(), 0.025, -150.0, 7.0)
	_add(_mid(str(kinds[2])), 0.12, 140.0, 0.0)
	_add(_clouds(true), 0.07, -60.0, 12.0)
	_add(_near(str(kinds[3])), 0.22, 250.0, 0.0)


func _c(key: String) -> Color:
	return InkThemes.col(pal, key)


func _sky_mix(col: Color, k: float) -> Color:
	return col.lerp(_c("sky_bottom"), k)


func _add(cv: InkCanvas, factor: float, y: float, drift: float) -> void:
	var mask := OS.get_cmdline_user_args().find("--dev-backdrop-mask")
	if mask != -1 and not (int(OS.get_cmdline_user_args()[mask + 1]) & (1 << _layers.size())):
		_layers.append({"node": Node2D.new(), "factor": factor, "y": y, "drift": drift})
		return
	var node := Node2D.new()
	var mesh := cv.to_mesh()
	for i in 3:
		var st := InkStatic.new()
		st.mesh = mesh
		st.position = Vector2(TILE * (i - 1), 0)
		node.add_child(st)
	add_child(node)
	_layers.append({"node": node, "factor": factor, "y": y, "drift": drift})


## Periodic height function over one tile: sum of sines with whole cycles per tile.
func _profile(amps: Array, phases: Array, x: float) -> float:
	var y := 0.0
	for i in amps.size():
		y += sin(x / TILE * TAU * float(i + 1) * 2.0 + float(phases[i])) * float(amps[i])
	return y


func _ridge(amp: Array, steps: int, peaky: bool) -> PackedVector2Array:
	var phases := []
	for i in amp.size():
		phases.append(_rng.randf() * TAU)
	var top := PackedVector2Array()
	for i in steps + 1:
		var x := TILE * float(i) / float(steps)
		var y := _profile(amp, phases, x)
		if peaky:
			y = -absf(y) * 1.3 + float(amp[0]) * 0.2
		top.append(Vector2(x, y))
	return top


func _hill_poly(top: PackedVector2Array) -> PackedVector2Array:
	var poly := top.duplicate()
	poly.append(Vector2(TILE, 2600))
	poly.append(Vector2(0, 2600))
	return poly


func _far(kind: String) -> InkCanvas:
	var cv := InkCanvas.new()
	var fill := _sky_mix(_c("far"), 0.2)
	var line := _sky_mix(_c("far_line"), 0.2)
	var flat := kind == "mesas"
	var top := _ridge([150.0, 70.0, 30.0], 120, not flat and kind != "sea")
	if flat:
		for i in top.size():
			top[i].y = snappedf(top[i].y, 60.0) - 40.0
		top = InkCanvas.spline(top, 2)
	if kind == "sea":
		for i in top.size():
			top[i].y = -60.0 + sin(top[i].x * 0.004) * 6.0
	cv.fill(_hill_poly(top), fill)
	if kind in ["mountains", "peaks"]:
		# Snow caps hanging from the highest peaks, with a zigzag lower edge.
		for i in range(2, top.size() - 2):
			var p := top[i]
			if p.y < top[i - 1].y and p.y < top[i + 1].y and p.y < -110.0:
				var w := 60.0 + _rng.randf_range(0, 40)
				var cap := PackedVector2Array([p])
				var k := 0
				for s in range(1, 7):
					var x := p.x + w * (s / 6.0)
					var j := clampi(i + s * 2, 0, top.size() - 1)
					var y := lerpf(p.y, top[j].y, 0.5) + 26.0 + (10.0 if s % 2 == 0 else -4.0)
					cap.append(Vector2(x, maxf(y, _interp(top, x) + 2.0)))
					k += 1
				for s in range(5, 0, -1):
					var x2 := p.x - w * (s / 6.0)
					var y2 := p.y + 32.0 - s * 2.0 + (8.0 if s % 2 == 0 else -6.0)
					cap.append(Vector2(x2, maxf(y2, _interp(top, x2) + 2.0)))
				var snow := _c("far_snow")
				cv.fill(cap, snow)
				cv.outline(cap, 1.4, Color(line, 0.6), p.x)
		# Ridge strokes down the slopes.
		for i in 26:
			var x := _rng.randf_range(0, TILE)
			var y := _interp(top, x)
			cv.stroke(InkCanvas.quad_bez(Vector2(x, y + 6), Vector2(x + 14, y + 40), Vector2(x + 6, y + 80), 5), 1.5, Color(line, 0.5), 0.3, 0.5, x)
	elif kind == "sea":
		for i in 40:
			var x := _rng.randf_range(0, TILE)
			var y := -40.0 + _rng.randf_range(0, 120)
			cv.stroke(InkCanvas.quad_bez(Vector2(x, y), Vector2(x + 9, y - 3), Vector2(x + 18, y), 4), 1.6, Color(1, 1, 1, 0.55), 0.3, 0.3)
	elif kind == "towers":
		for i in 9:
			var x := _rng.randf_range(0, TILE)
			var w := _rng.randf_range(40, 90)
			var h := _rng.randf_range(160, 320)
			var tw := PackedVector2Array([Vector2(x, 40), Vector2(x, -h), Vector2(x + w * 0.5, -h - 30), Vector2(x + w, -h), Vector2(x + w, 40)])
			cv.fill(tw, fill.darkened(0.04))
			cv.outline(tw, 1.6, Color(line, 0.7), x)
			for k in 4:
				cv.dot(Vector2(x + w * 0.5, -h + 40 + k * 50), 4.0, Color(_c("sky_bottom"), 0.9))
	cv.stroke(top, 2.0, line, 0.0001, 0.0001, 1.0, 0.15, 0.6)
	return cv


func _interp(line: PackedVector2Array, x: float) -> float:
	var step := TILE / float(line.size() - 1)
	var i := clampi(int(x / step), 0, line.size() - 2)
	var f := clampf((x - line[i].x) / maxf(line[i + 1].x - line[i].x, 0.001), 0.0, 1.0)
	return lerpf(line[i].y, line[i + 1].y, f)


func _clouds(small: bool = false) -> InkCanvas:
	var cv := InkCanvas.new()
	var fill := _c("cloud")
	var line := _c("cloud_line")
	var n := 4 if small else 6
	for i in n:
		var cx := TILE * (float(i) + _rng.randf_range(0.1, 0.8)) / float(n)
		var cy := _rng.randf_range(-220, 40)
		var s := _rng.randf_range(0.7, 1.25) * (0.65 if small else 1.0)
		var puffs := []
		var count := _rng.randi_range(4, 6)
		for k in count:
			var x := lerpf(-90.0, 90.0, float(k) / float(count - 1)) * s
			var r := _rng.randf_range(30, 50) * (1.0 - absf(x) / (240.0 * s)) * s
			puffs.append(Vector3(cx + x, cy - r * 0.4 + _rng.randf_range(-6, 6), r))
		var shape := InkDecor._blob_union(puffs, 20)
		# Flatten the underside a little: classic cartoon cloud.
		var base_y := cy + 10.0 * s
		for k in shape.size():
			if shape[k].y > base_y:
				shape[k].y = lerpf(shape[k].y, base_y, 0.7)
		cv.fill(shape, fill)
		var shade := InkCanvas.ellipse_pts(Vector2(cx, base_y - 4.0 * s), Vector2(80.0 * s, 10.0 * s), 0.0, 20)
		for part in Geometry2D.intersect_polygons(shade, shape):
			cv.fill(part, Color(line, 0.25))
		cv.outline(shape, 2.0 if not small else 1.6, Color(line, 0.9), cx, 0.15, 0.6)
		for k in 2:
			var a := Vector2(cx - 30.0 * s + k * 34.0 * s, cy - 18.0 * s)
			cv.stroke(InkCanvas.arc_pts(a, 14.0 * s, PI * 1.1, PI * 1.6, 5), 1.4, Color(line, 0.5), 0.3, 0.3)
	return cv


func _mid(kind: String) -> InkCanvas:
	var cv := InkCanvas.new()
	var fill := _sky_mix(_c("mid"), 0.12)
	var line := _sky_mix(_c("mid_line"), 0.12)
	var top := _ridge([60.0, 34.0, 14.0], 160, false)
	cv.fill(_hill_poly(top), fill)
	# A second, darker roll in front for depth.
	var top2 := _ridge([40.0, 22.0, 10.0], 160, false)
	for i in top2.size():
		top2[i].y += 90.0
	cv.fill(_hill_poly(top2), fill.darkened(0.05))
	cv.stroke(top2, 1.6, Color(line, 0.7), 0.0001, 0.0001, 2.0, 0.15, 0.6)
	var tree := _sky_mix(_c("mid_tree"), 0.1)
	for i in 30:
		var x := _rng.randf_range(0, TILE)
		var y := _interp(top, x)
		if kind in ["dunes", "snowhills"]:
			if _rng.randf() < 0.5:
				cv.stroke(InkCanvas.quad_bez(Vector2(x, y + 10), Vector2(x + 14, y + 6), Vector2(x + 28, y + 12), 4), 1.4, Color(line, 0.6), 0.3, 0.3)
			continue
		var r := _rng.randf_range(10, 18)
		cv.stroke(PackedVector2Array([Vector2(x, y + 4), Vector2(x, y - r)]), 2.0, line.darkened(0.15), 0.1, 0.1)
		cv.ellipse(Vector2(x, y - r - r * 0.6), Vector2(r * 0.8, r), tree)
		cv.ink_circle(Vector2(x, y - r - r * 0.6), Vector2(r * 0.8, r), 1.5, Color(line.darkened(0.12), 0.9), x)
	for i in 50:
		var x := _rng.randf_range(0, TILE)
		var y := _interp(top, x) + _rng.randf_range(10, 70)
		cv.stroke(PackedVector2Array([Vector2(x, y), Vector2(x + 3, y - 6)]), 1.3, Color(line, 0.5), 0.3, 0.6)
	cv.stroke(top, 2.0, line, 0.0001, 0.0001, 1.0, 0.15, 0.6)
	return cv


func _near(kind: String) -> InkCanvas:
	var cv := InkCanvas.new()
	var fill := _sky_mix(_c("near"), 0.06)
	var line := _sky_mix(_c("near_line"), 0.06)
	var top := _ridge([40.0, 24.0, 10.0], 160, false)
	var leaf := _sky_mix(_c("near_tree"), 0.05)
	var dark := _sky_mix(_c("near_tree_dark"), 0.05)
	# Tree line behind the near hill.
	var x := 0.0
	while x < TILE:
		var y := _interp(top, fposmod(x, TILE))
		match kind:
			"pines", "machines", "swirls", "palms":
				_near_prop(cv, kind, x, y, leaf, dark)
				x += _rng.randf_range(70, 150)
			_:
				var r := _rng.randf_range(34, 58)
				var blobs := [Vector3(x, y - r * 0.9, r), Vector3(x - r * 0.7, y - r * 0.4, r * 0.7), Vector3(x + r * 0.7, y - r * 0.45, r * 0.75)]
				var shape := InkDecor._blob_union(blobs, 16)
				cv.stroke(PackedVector2Array([Vector2(x, y + 10), Vector2(x, y - r * 0.5)]), 6.0, dark.darkened(0.25), 0.05, 0.05)
				cv.fill(shape, leaf)
				cv.ellipse(Vector2(x - r * 0.3, y - r * 1.3), Vector2(r * 0.35, r * 0.28), leaf.lightened(0.1))
				for k in 4:
					var p := Vector2(x + _rng.randf_range(-r, r) * 0.7, y - _rng.randf_range(0.2, 1.4) * r)
					if Geometry2D.is_point_in_polygon(p, shape):
						cv.stroke(PackedVector2Array([p + Vector2(-3, -2), p, p + Vector2(3, -2.5)]), 1.5, Color(dark, 0.7), 0.3, 0.3)
				cv.outline(shape, 2.0, dark.darkened(0.3), x, 0.15, 0.5)
				x += r * _rng.randf_range(1.1, 1.9)
	cv.fill(_hill_poly(top), fill)
	for i in 70:
		var gx := _rng.randf_range(0, TILE)
		var gy := _interp(top, gx) + _rng.randf_range(8, 90)
		cv.stroke(PackedVector2Array([Vector2(gx, gy), Vector2(gx + 2, gy - 7)]), 1.5, Color(line, 0.55), 0.3, 0.7)
	cv.stroke(top, 2.4, line, 0.0001, 0.0001, 4.0, 0.15, 0.6)
	return cv


func _near_prop(cv: InkCanvas, kind: String, x: float, y: float, leaf: Color, dark: Color) -> void:
	match kind:
		"pines":
			var h := _rng.randf_range(90, 150)
			var tri := PackedVector2Array([Vector2(x - 30, y + 5), Vector2(x, y - h), Vector2(x + 30, y + 5)])
			cv.fill(tri, leaf)
			cv.fill(PackedVector2Array([Vector2(x - 14, y - h * 0.5), Vector2(x, y - h), Vector2(x + 14, y - h * 0.5)]), Color(1, 1, 1, 0.75))
			cv.outline(tri, 1.8, dark.darkened(0.3), x)
		"palms":
			var trunk := InkCanvas.quad_bez(Vector2(x, y + 6), Vector2(x - 6, y - 50), Vector2(x + 10, y - 100), 6)
			cv.stroke(trunk, 6.0, Color("b98a57").lerp(_c("sky_bottom"), 0.1), 0.05, 0.2)
			for k in 5:
				var a := -PI * 0.5 + (k - 2) * 0.6
				var tip := trunk[trunk.size() - 1] + Vector2.from_angle(a) * 46.0 + Vector2(0, 18)
				cv.stroke(InkCanvas.quad_bez(trunk[trunk.size() - 1], trunk[trunk.size() - 1] + Vector2.from_angle(a) * 26.0 + Vector2(0, -8), tip, 6), 9.0, leaf, 0.1, 0.8)
		"machines":
			var w := _rng.randf_range(40, 70)
			var h2 := _rng.randf_range(60, 120)
			var box := PackedVector2Array([Vector2(x, y + 6), Vector2(x, y - h2), Vector2(x + w, y - h2), Vector2(x + w, y + 6)])
			cv.fill(box, leaf)
			cv.outline(box, 1.8, dark.darkened(0.3), x)
			cv.ink_circle(Vector2(x + w * 0.5, y - h2 * 0.6), Vector2(w * 0.25, w * 0.25), 1.6, dark, x)
			cv.stroke(PackedVector2Array([Vector2(x + w * 0.5, y - h2), Vector2(x + w * 0.5, y - h2 - 30)]), 2.0, dark, 0.1, 0.1)
			cv.dot(Vector2(x + w * 0.5, y - h2 - 32), 4.0, Color("f2b630"))
		"swirls":
			var r := _rng.randf_range(24, 40)
			var spiral := PackedVector2Array()
			for k in 30:
				var a := k * 0.42
				spiral.append(Vector2(x, y - r * 1.6) + Vector2.from_angle(a) * r * (1.0 - k / 34.0))
			cv.stroke(PackedVector2Array([Vector2(x, y + 6), Vector2(x, y - r * 0.8)]), 4.0, dark, 0.05, 0.1)
			cv.stroke(spiral, 6.0, leaf, 0.05, 0.6)
			cv.stroke(spiral, 1.6, dark.darkened(0.3), 0.05, 0.6)


func follow(cam: Vector2, zoom: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var center := size * 0.5
	var sky_mat := _sky.material as ShaderMaterial
	sky_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	sky_mat.set_shader_parameter("horizon_shift", clampf(cam.y * 0.00012, -0.15, 0.15))
	sky_mat.set_shader_parameter("scroll", cam * 0.001)
	var z := lerpf(1.0, zoom, 0.35) * clampf(size.y / 1080.0, 0.5, 3.0)
	for l in _layers:
		var f: float = l.factor
		var n: Node2D = l.node
		var x := fposmod(-cam.x * f * z + _t * float(l.drift) * z, TILE * z) - TILE * z
		n.position = Vector2(center.x + x, center.y + (float(l.y) - cam.y * f * 0.8 - 120.0) * z)
		n.scale = Vector2(z, z)


func _process(delta: float) -> void:
	_t += delta
