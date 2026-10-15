class_name Backdrop
extends CanvasLayer
## Screen-space sky plus layered parallax scenery (mountains, hills, clouds).
## Call `follow(camera_world_pos, zoom)` every frame.

const TILE := 2400.0

var theme: Dictionary = {}
var _sky: ColorRect
var _layers: Array[Dictionary] = []   ## {node: Node2D, factor: float, y: float}
var _clouds: Array[Dictionary] = []
var _t: float = 0.0
## Authored parallax layers (world.json "backdrop"): {node, factor, y, w, drift}.
var _art_layers: Array[Dictionary] = []
var _art_sky: TextureRect


func setup(p_theme: Dictionary, seed_value: int) -> void:
	theme = p_theme
	layer = -50
	var art := WorldArt.load_for(theme)
	if art and art.data.has("backdrop"):
		_setup_art(art)
		return
	_sky = ColorRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sky.gdshader")
	mat.set_shader_parameter("top_color", Color(theme.get("sky_top", "#3fa9f5")))
	mat.set_shader_parameter("bottom_color", Color(theme.get("sky_bottom", "#c9f0ff")))
	mat.set_shader_parameter("sun_color", Color(theme.get("sun", "#fff3c4")))
	_sky.material = mat
	add_child(_sky)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sky_bottom := Color(theme.get("sky_bottom", "#c9f0ff"))
	var far := Color(theme.get("far_hills", "#9fd8b4"))
	var mid := Color(theme.get("mid_hills", "#73c27f"))

	_add_clouds(rng, 0.03, 0.55, 7, 150.0, 0.0)
	_add_hills(rng, far.lerp(sky_bottom, 0.45), 0.06, 300.0, 260.0, 3, "mountains")
	_add_hills(rng, far, 0.12, 380.0, 150.0, 4, "hills")
	_add_clouds(rng, 0.09, 0.85, 5, 320.0, 0.25)
	_add_hills(rng, mid.lerp(far, 0.35), 0.2, 470.0, 110.0, 5, "trees")
	_add_hills(rng, mid, 0.3, 560.0, 90.0, 6, "bushes")


func _add_hills(rng: RandomNumberGenerator, col: Color, factor: float, base_y: float, amp: float, freq: int, deco: String) -> void:
	var node := Node2D.new()
	var phases: Array[float] = []
	for i in 4:
		phases.append(rng.randf() * TAU)
	var pts := PackedVector2Array()
	var top_pts := PackedVector2Array()
	var steps := 160
	for i in steps + 1:
		var x := TILE * 3.0 * float(i) / float(steps) - TILE
		var u := x / TILE * TAU
		var y := 0.0
		if deco == "mountains":
			y = -absf(sin(u * freq * 0.5 + phases[0])) * amp - sin(u * freq + phases[1]) * amp * 0.25
		else:
			y = -sin(u * freq + phases[0]) * amp * 0.6 - sin(u * (freq + 2) + phases[1]) * amp * 0.3 - amp * 0.3
		top_pts.append(Vector2(x, y))
	pts.append_array(top_pts)
	pts.append(Vector2(TILE * 2.0, 2200))
	pts.append(Vector2(-TILE, 2200))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	poly.antialiased = true
	node.add_child(poly)
	var line := Line2D.new()
	line.points = top_pts
	line.width = 3.0
	line.default_color = col.lightened(0.18)
	line.antialiased = true
	node.add_child(line)
	if deco == "mountains":
		# Snow caps / light ridges on peaks.
		for i in range(1, top_pts.size() - 1):
			var p := top_pts[i]
			if p.y < top_pts[i - 1].y and p.y < top_pts[i + 1].y and p.y < -amp * 0.75:
				var cap := Polygon2D.new()
				cap.polygon = PackedVector2Array([p, p + Vector2(46, 34), p + Vector2(20, 28), p + Vector2(0, 38), p + Vector2(-22, 26), p + Vector2(-44, 34)])
				cap.color = col.lightened(0.55)
				node.add_child(cap)
	elif deco == "trees" or deco == "bushes":
		var count := 26 if deco == "trees" else 18
		var deco_node := _DecoBlobs.new()
		deco_node.color = col.darkened(0.12)
		deco_node.highlight = col.lightened(0.1)
		for i in count:
			var x := rng.randf_range(-TILE, TILE * 2.0)
			var idx := clampi(int((x + TILE) / (TILE * 3.0) * steps), 0, top_pts.size() - 1)
			var y := top_pts[idx].y
			deco_node.items.append({"pos": Vector2(x, y + 6), "r": rng.randf_range(16, 30) * (1.3 if deco == "trees" else 1.0), "tree": deco == "trees"})
		node.add_child(deco_node)
	add_child(node)
	_layers.append({"node": node, "factor": factor, "y": base_y})


func _add_clouds(rng: RandomNumberGenerator, factor: float, scale_mul: float, count: int, base_y: float, alpha_drop: float) -> void:
	var node := Node2D.new()
	var cloud_col := Color(theme.get("cloud", "#ffffff"))
	for i in count:
		var c := _Cloud.new()
		c.color = Color(cloud_col, 0.92 - alpha_drop)
		c.position = Vector2(rng.randf_range(0, TILE), rng.randf_range(-260, 60))
		c.scale = Vector2.ONE * rng.randf_range(0.8, 1.4) * scale_mul
		c.seed_value = rng.randi()
		node.add_child(c)
	add_child(node)
	_clouds.append({"node": node, "factor": factor, "y": base_y, "drift": rng.randf_range(6.0, 14.0) * (1.0 + factor * 4.0)})


## Illustrated backdrop: a screen-filling sky painting plus horizontally repeating layers.
func _setup_art(art: WorldArt) -> void:
	for l: Dictionary in art.data.backdrop:
		var t := art.tex(str(l.tex))
		if t == null:
			continue
		var k := float(l.get("scale", art.scale))
		if str(l.get("mode", "")) == "sky":
			_art_sky = TextureRect.new()
			_art_sky.texture = t
			_art_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_art_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_art_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_art_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_art_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_art_sky)
			continue
		var node := Node2D.new()
		var w := float(t.get_width()) * k
		var copies := maxi(4, ceili(4096.0 / w) + 2)
		if bool(l.get("mirror", false)) and copies % 2 == 1:
			copies += 1
		for i in copies:
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			sp.offset = Vector2(0, -t.get_height())
			sp.scale = Vector2(k, k)
			sp.position = Vector2(w * i, 0)
			# Mirrored repeats hide the seam of art that does not tile on its own.
			if bool(l.get("mirror", false)) and i % 2 == 1:
				sp.flip_h = true
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.add_child(sp)
		# Continue the layer below its painted bottom edge in its own base colour, so terrain
		# dips never reveal a hard edge with the sky behind it.
		var img := t.get_image()
		var base := Color(0, 0, 0, 0)
		var n := 0
		for y in range(int(img.get_height() * 0.8), img.get_height()):
			for x in range(0, img.get_width(), 3):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					base += c
					n += 1
		if n > 0:
			var under := ColorRect.new()
			under.color = Color(base.r / n, base.g / n, base.b / n, 1.0)
			under.position = Vector2(0, -1)
			under.size = Vector2(w * copies, 4000)
			under.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(under)
			node.move_child(under, 0)
		add_child(node)
		_art_layers.append({"node": node, "factor": float(l.get("factor", 0.1)), "y": float(l.get("y", 0)),
			"w": w, "mirror": bool(l.get("mirror", false)), "drift": float(l.get("drift", 0.0)), "fill": Color(l.get("fill", "#00000000"))})


func _follow_art(cam: Vector2, zoom: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var z := lerpf(1.0, zoom, 0.25)
	for l in _art_layers:
		var f: float = l.factor
		var n: Node2D = l.node
		var w: float = float(l.w) * z * (2.0 if l.mirror else 1.0)
		var x := fposmod(-cam.x * f * z + _t * float(l.drift) * z, w) - w
		# Layer baseline: `y` px below the screen centre when the camera sits at world y 0.
		n.position = Vector2(roundf(x), roundf(size.y * 0.5 + float(l.y) * z - cam.y * f * z))
		n.scale = Vector2(z, z)


## cam: world position at screen centre. zoom: camera zoom (1 = default).
func follow(cam: Vector2, zoom: float) -> void:
	if _sky == null:
		_follow_art(cam, zoom)
		return
	var size := get_viewport().get_visible_rect().size
	var center := size * 0.5
	var sky_mat := _sky.material as ShaderMaterial
	sky_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	sky_mat.set_shader_parameter("horizon_shift", clampf(cam.y * 0.00012, -0.15, 0.15))
	var z := lerpf(1.0, zoom, 0.35)
	for l in _layers:
		var f: float = l.factor
		var n: Node2D = l.node
		var x := fposmod(-cam.x * f * z, TILE * z) - TILE * z
		n.position = Vector2(center.x + x, center.y + float(l.y) - cam.y * f * 0.8 * z - 120.0)
		n.scale = Vector2(z, z)
	for c in _clouds:
		var f: float = c.factor
		var n: Node2D = c.node
		var x := fposmod(-cam.x * f + _t * float(c.drift), TILE) - TILE
		n.position = Vector2(x, float(c.y) - cam.y * f * 0.5)


func _process(delta: float) -> void:
	_t += delta


class _Cloud extends Node2D:
	var color := Color.WHITE
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var puffs: Array[Vector3] = []
		var n := rng.randi_range(4, 6)
		for i in n:
			var x := lerpf(-80.0, 80.0, float(i) / float(n - 1)) + rng.randf_range(-10, 10)
			var r := rng.randf_range(30, 52) * (1.0 - absf(x) / 200.0)
			puffs.append(Vector3(x, -r * 0.45 + rng.randf_range(-6, 6), r))
		# Repeat the cloud so it wraps across tile boundaries.
		for off in [0.0, Backdrop.TILE, Backdrop.TILE * 2.0]:
			for p in puffs:
				draw_circle(Vector2(p.x + off, p.y + 6), p.z, Color(color.darkened(0.12), color.a * 0.5), true, -1.0, true)
			for p in puffs:
				draw_circle(Vector2(p.x + off, p.y), p.z, color, true, -1.0, true)
			for p in puffs:
				draw_circle(Vector2(p.x + off - p.z * 0.25, p.y - p.z * 0.3), p.z * 0.45, Color(1, 1, 1, 0.35 * color.a), true, -1.0, true)


class _DecoBlobs extends Node2D:
	var items: Array[Dictionary] = []
	var color := Color.DARK_GREEN
	var highlight := Color.GREEN

	func _draw() -> void:
		for it in items:
			var p: Vector2 = it.pos
			var r: float = it.r
			if it.tree:
				draw_rect(Rect2(p.x - 3, p.y - r * 1.2, 6, r * 1.2), color.darkened(0.2))
				draw_circle(p + Vector2(0, -r * 1.5), r, color, true, -1.0, true)
				draw_circle(p + Vector2(-r * 0.25, -r * 1.75), r * 0.55, highlight, true, -1.0, true)
			else:
				draw_circle(p + Vector2(-r * 0.6, -r * 0.3), r * 0.7, color, true, -1.0, true)
				draw_circle(p + Vector2(r * 0.5, -r * 0.25), r * 0.75, color, true, -1.0, true)
				draw_circle(p + Vector2(0, -r * 0.6), r * 0.8, color, true, -1.0, true)
				draw_circle(p + Vector2(-r * 0.15, -r * 0.85), r * 0.38, highlight, true, -1.0, true)
