class_name TerrainView
extends Node2D
## Renders one hole: soil fill, material surface bands, outlines, cup, flag, hazards and decor.
## Everything static is drawn once; only the flag, water and swaying decor animate.

const MATERIAL_COLORS := {
	"sand": [Color("f4d58d"), Color("d9b062")],
	"ice": [Color("c9f2ff"), Color("8fd6f5")],
	"sticky": [Color("b65cff"), Color("7b2cbf")],
	"bouncy": [Color("ff4d6d"), Color("fff1f3")],
	"rock": [Color("9aa5b8"), Color("6b7489")],
	"wood": [Color("c08552"), Color("8d5b33")],
	"rough": [Color("4fa83a"), Color("2f7a25")],
}

var terrain: SimTerrain
var theme: Dictionary
var hole: Dictionary
var hole_number: int = 1
var _water: _Water
## Authored world art (textures, caps, decor sprites); null = procedural fallback.
var art: WorldArt
## Visual-only ground that continues past the world's left/right edges so the camera never
## shows a cut-off cliff. Each entry: {poly: PackedVector2Array, top: PackedVector2Array}.
var skirts: Array[Dictionary] = []

const SKIRT_LEN := 4000.0


func build(p_terrain: SimTerrain, p_hole: Dictionary, p_theme: Dictionary, p_hole_number: int) -> void:
	terrain = p_terrain
	hole = p_hole
	theme = p_theme
	hole_number = p_hole_number
	for c in get_children():
		c.queue_free()
	art = WorldArt.load_for(theme)
	var forces := ForceOverlay.new()
	forces.setup(terrain, GameData.materials, float(GameData.balance.physics.gravity))
	if art:
		_build_art()
		add_child(forces)
		return

	var decor_back := Node2D.new()
	decor_back.name = "DecorBack"
	add_child(decor_back)

	var fill_mat := ShaderMaterial.new()
	fill_mat.shader = load("res://assets/shaders/terrain_fill.gdshader")
	fill_mat.set_shader_parameter("top_color", _c("ground_top", "#8a5a3c"))
	fill_mat.set_shader_parameter("bottom_color", _c("ground_bottom", "#5b3a29"))
	fill_mat.set_shader_parameter("strata_color", _c("ground_strata", "#7a4e34"))
	var min_y := INF
	for poly in terrain.polygons:
		for v: Vector2 in poly.points:
			min_y = minf(min_y, v.y)
	fill_mat.set_shader_parameter("top_y", min_y)

	var cup := _Cup.new()
	cup.terrain = terrain
	add_child(cup)

	for poly in terrain.polygons:
		var p2d := Polygon2D.new()
		p2d.polygon = poly.points
		p2d.material = fill_mat
		p2d.antialiased = true
		add_child(p2d)
	_build_skirts()
	for sk in skirts:
		var s2d := Polygon2D.new()
		s2d.polygon = sk.poly
		s2d.material = fill_mat
		add_child(s2d)

	var edges := _Edges.new()
	edges.view = self
	add_child(edges)

	_water = _Water.new()
	_water.terrain = terrain
	_water.theme = theme
	add_child(_water)

	if terrain.has_cup:
		var flag := _Flag.new()
		flag.position = terrain.cup_pos
		flag.number = hole_number
		add_child(flag)

	_build_decor(decor_back)
	add_child(forces)


## Authored-art build: same geometry as the procedural path, dressed in world materials.
func _build_art() -> void:
	var decor_back := Node2D.new()
	decor_back.name = "DecorBack"
	add_child(decor_back)
	var cup := _Cup.new()
	cup.terrain = terrain
	add_child(cup)
	var sm := art.material("soil")
	var soil := art.tex(str(sm.get("fill", "")))
	var min_y := INF
	for poly in terrain.polygons:
		for v: Vector2 in poly.points:
			min_y = minf(min_y, v.y)
	var soil_mat := ShaderMaterial.new()
	soil_mat.shader = load("res://assets/shaders/world_soil.gdshader")
	soil_mat.set_shader_parameter("top_y", min_y + 60.0)
	soil_mat.set_shader_parameter("depth_px", float(sm.get("depth_px", 700)))
	soil_mat.set_shader_parameter("dark", float(sm.get("depth_dark", 0.5)))
	_build_skirts()
	for poly in terrain.polygons:
		var p := art.textured_polygon(poly.points, soil)
		p.material = soil_mat
		add_child(p)
	for sk in skirts:
		var p := art.textured_polygon(sk.poly, soil)
		p.material = soil_mat
		add_child(p)
	var ink := _ArtInk.new()
	ink.view = self
	ink.width = art.scale * 1.5
	add_child(ink)
	var ed := _Edges.new()
	ed.view = self
	for poly in terrain.polygons:
		for run in ed._runs(poly.points, poly.edge_mats, terrain):
			if run.mat == "cup" or not (run.top or run.mat in ["sticky", "bouncy", "ice", "sand"]):
				continue
			_add_cap(run.points, run.normals, str(run.mat))
	ed.free()
	for sk in skirts:
		var tp: PackedVector2Array = sk.top
		if tp.size() >= 2:
			_add_cap(tp, PackedVector2Array([Vector2.UP, Vector2.UP]), "grass")
	_water = _Water.new()
	_water.terrain = terrain
	_water.theme = theme
	_water.art = art
	_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_water)
	if terrain.has_cup:
		var fd: Dictionary = art.data.get("flag", {})
		if not fd.is_empty():
			var flag := _ArtFlag.new()
			flag.setup(art, fd)
			flag.position = terrain.cup_pos
			add_child(flag)
	_build_art_decor(decor_back)


func _add_cap(points: PackedVector2Array, normals: PackedVector2Array, mat: String) -> void:
	var m := art.material(mat)
	var t := art.tex(str(m.get("cap", "")))
	if t == null:
		return
	add_child(art.cap_line(points, normals, t, float(m.get("cap_base", 4))))


func _build_art_decor(parent: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hole.get("id", ""))
	for d: Dictionary in hole.get("decor", []):
		var variants := art.decor_variants(str(d.get("type", "")))
		if variants.is_empty():
			continue
		var pos := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		var t := art.tex(str(variants[rng.randi() % variants.size()]))
		if t == null:
			continue
		var flip := rng.randf() < 0.5
		# world.json "decor_anchor": ground (default) | free (at x, y) | water (floats on the
		# water surface under x) | ceiling (hangs from the surface above; ground if none).
		var anchor := str((art.data.get("decor_anchor", {}) as Dictionary).get(str(d.get("type", "")), "ground"))
		if anchor == "free":
			parent.add_child(art.ground_sprite(t, pos, flip))
			continue
		if anchor == "water":
			var placed := false
			for z in terrain.zones:
				var zr: Rect2 = z["rect"]
				if z["type"] == "water" and pos.x >= zr.position.x and pos.x <= zr.end.x:
					parent.add_child(art.ground_sprite(t, Vector2(pos.x, zr.position.y + art.scale * 4.0), flip))
					placed = true
					break
			if placed:
				continue
		if anchor == "ceiling":
			var up := terrain.raycast(pos + Vector2(0, 40), Vector2.UP, 400.0)
			if up.hit and up.normal.y > 0.5:
				var sp := art.ground_sprite(t, up.pos, flip)
				sp.offset = Vector2(-t.get_width() * 0.5, 0)
				parent.add_child(sp)
				continue
		var hit := terrain.raycast(pos + Vector2(0, -400), Vector2.DOWN, 1400.0)
		if hit.hit:
			pos = hit.pos
		parent.add_child(art.ground_sprite(t, pos + Vector2(0, art.scale * 3.0), flip))


## Finds terrain edges lying on the world's left/right bounds and extends them outward as flat
## plateaus at the same height.
func _build_skirts() -> void:
	skirts.clear()
	var bd := terrain.bounds
	for poly in terrain.polygons:
		var pts: PackedVector2Array = poly.points
		for side: float in [-1.0, 1.0]:
			var edge_x: float = bd.position.x if side < 0.0 else bd.end.x
			var top := INF
			var bottom := -INF
			for v in pts:
				if absf(v.x - edge_x) < 0.5:
					top = minf(top, v.y)
					bottom = maxf(bottom, v.y)
			if top == INF or bottom - top < 1.0:
				continue
			var far := edge_x + side * SKIRT_LEN
			# Overlap the real polygon by 1px so no hairline seam shows.
			var near := edge_x - side * 1.0
			skirts.append({
				"poly": PackedVector2Array([Vector2(near, top), Vector2(far, top), Vector2(far, bottom + 2000.0), Vector2(near, bottom + 2000.0)]),
				"top": PackedVector2Array([Vector2(edge_x, top), Vector2(far, top)]) if side > 0.0 else PackedVector2Array([Vector2(far, top), Vector2(edge_x, top)]),
				"edge_x": edge_x,
			})
		# Bedrock under the world's bottom edge.
		var bottom_pts := 0
		for v in pts:
			if absf(v.y - bd.end.y) < 0.5:
				bottom_pts += 1
		if bottom_pts >= 2:
			var y0 := bd.end.y - 1.0
			skirts.append({
				"poly": PackedVector2Array([Vector2(bd.position.x - SKIRT_LEN, y0), Vector2(bd.end.x + SKIRT_LEN, y0),
					Vector2(bd.end.x + SKIRT_LEN, y0 + 3000.0), Vector2(bd.position.x - SKIRT_LEN, y0 + 3000.0)]),
				"top": PackedVector2Array(), "edge_y": bd.end.y,
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


func _c(key: String, fallback: String) -> Color:
	return Color(theme.get(key, fallback))


func _build_decor(parent: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hole.get("id", ""))
	for d: Dictionary in hole.get("decor", []):
		var pos := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		var hit := terrain.raycast(pos + Vector2(0, -400), Vector2.DOWN, 1400.0)
		if hit.hit:
			pos = hit.pos
		var sc := float(d.get("scale", 1.0))
		var node: Node2D
		match str(d.get("type", "")):
			"tree":
				var t := _Tree.new()
				t.leaf = _c("grass", "#6ccf4a").darkened(0.08)
				t.leaf_dark = _c("grass_dark", "#3d9a2f")
				t.leaf_light = _c("grass_light", "#9be36b")
				t.trunk = Color("7a4e34")
				t.line = _c("outline", "#2a3a2a")
				t.seed_value = rng.randi()
				node = t
			"bush":
				var b := _Bush.new()
				b.col = _c("grass_dark", "#3d9a2f").lightened(0.05)
				b.light = _c("grass", "#6ccf4a")
				b.line = _c("outline", "#2a3a2a")
				b.seed_value = rng.randi()
				node = b
			"flowers":
				var f := _Flowers.new()
				f.stem = _c("grass_dark", "#3d9a2f")
				f.seed_value = rng.randi()
				node = f
			"rock":
				var r := _Rock.new()
				r.seed_value = rng.randi()
				node = r
			_:
				continue
		node.position = pos + Vector2(0, 4)
		node.scale = Vector2(sc, sc)
		parent.add_child(node)


# ---------------------------------------------------------------------------
# Static edge bands
# ---------------------------------------------------------------------------

class _Edges extends Node2D:
	var view: TerrainView

	func _draw() -> void:
		var t := view.terrain
		var outline := view._c("outline", "#2a3a2a")
		var soil_light := view._c("ground_top", "#8a5a3c").lightened(0.12)
		var wall := view._c("ground_strata", "#7a4e34").darkened(0.15)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		for poly in t.polygons:
			var pts: PackedVector2Array = poly.points
			var mats: PackedInt32Array = poly.edge_mats
			var n := pts.size()
			var runs := _runs(pts, mats, t)
			# Topsoil and wall bands first.
			for run in runs:
				var rp: PackedVector2Array = run.points
				var rn: PackedVector2Array = run.normals
				if run.top and run.mat != "cup":
					draw_polyline(_offset(rp, rn, -16.0), soil_light, 26.0, true)
				elif not run.top and run.mat not in ["cup", "sticky", "bouncy", "ice", "sand"]:
					for part in _split_seams(_offset(rp, rn, -5.0), rp):
						draw_polyline(part, wall, 9.0, true)
			for run in runs:
				# Gameplay-relevant materials are always drawn, even on walls and ceilings.
				if run.mat != "cup" and (run.top or run.mat in ["sticky", "bouncy", "ice", "sand"]):
					_surface(run, rng)
			# Outline, broken at hidden seams where the ground continues past the world edge.
			var line := PackedVector2Array()
			for i in n + 1:
				var a := pts[i % n]
				if i > 0 and view.is_seam(pts[i - 1], a):
					if line.size() >= 2:
						draw_polyline(line, outline, 3.5, true)
					line = PackedVector2Array()
				line.append(a)
			if line.size() >= 2:
				draw_polyline(line, outline, 3.5, true)
		for sk in view.skirts:
			var tp: PackedVector2Array = sk.top
			if tp.size() < 2:
				continue
			var tn := PackedVector2Array([Vector2.UP, Vector2.UP])
			draw_polyline(_offset(tp, tn, -16.0), soil_light, 26.0, true)
			_surface({"points": tp, "normals": tn, "mat": "grass", "top": true}, rng)
			draw_polyline(tp, outline, 3.5, true)

	func _runs(pts: PackedVector2Array, mats: PackedInt32Array, t: SimTerrain) -> Array[Dictionary]:
		var n := pts.size()
		var cls: Array[Dictionary] = []
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var d := b - a
			var nrm := Vector2(d.y, -d.x).normalized()
			var mname := t.material_names[mats[i]]
			cls.append({"top": nrm.y < -0.42, "mat": mname, "n": nrm})
		# Find a boundary to start from so runs don't split at index 0.
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
			var c: Dictionary = cls[i]
			if cur.is_empty() or cur.top != c.top or cur.mat != c.mat:
				if not cur.is_empty():
					cur.points.append(pts[i])
					cur.normals.append(cur.last_n)
					runs.append(cur)
				cur = {"top": c.top, "mat": c.mat, "points": PackedVector2Array(), "normals": PackedVector2Array(), "last_n": c.n}
			var prev_n: Vector2 = cls[(i - 1 + n) % n].n
			var vn: Vector2 = c.n if cur.points.is_empty() else (prev_n + c.n).normalized()
			cur.points.append(pts[i])
			cur.normals.append(vn)
			cur.last_n = c.n
		if not cur.is_empty():
			cur.points.append(pts[(start) % n])
			cur.normals.append(cur.last_n)
			runs.append(cur)
		return runs

	## Splits `line` (parallel to `src`) wherever the source segment is a hidden world-edge seam.
	func _split_seams(line: PackedVector2Array, src: PackedVector2Array) -> Array[PackedVector2Array]:
		var parts: Array[PackedVector2Array] = []
		var cur := PackedVector2Array()
		for i in line.size():
			if i > 0 and view.is_seam(src[i - 1], src[i]):
				if cur.size() >= 2:
					parts.append(cur)
				cur = PackedVector2Array()
			cur.append(line[i])
		if cur.size() >= 2:
			parts.append(cur)
		return parts

	func _offset(pts: PackedVector2Array, nrm: PackedVector2Array, dist: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(pts.size())
		for i in pts.size():
			out[i] = pts[i] + nrm[i] * dist
		return out

	func _surface(run: Dictionary, rng: RandomNumberGenerator) -> void:
		var rp: PackedVector2Array = run.points
		var rn: PackedVector2Array = run.normals
		var mat: String = run.mat
		match mat:
			"grass", "rough":
				var grass := view._c("grass", "#6ccf4a")
				var dark := view._c("grass_dark", "#3d9a2f")
				var light := view._c("grass_light", "#9be36b")
				if mat == "rough":
					grass = grass.darkened(0.15)
					light = light.darkened(0.15)
				_scallops(rp, rn, -13.0, 16.0, 6.5, dark)
				draw_polyline(_offset(rp, rn, -8.0), dark, 15.0, true)
				draw_polyline(_offset(rp, rn, -5.5), grass, 10.0, true)
				draw_polyline(_offset(rp, rn, -2.5), light, 3.0, true)
				_tufts(rp, rn, rng, dark, grass)
			"sand":
				var cols: Array = MATERIAL_COLORS.sand
				draw_polyline(_offset(rp, rn, -9.0), cols[1], 16.0, true)
				draw_polyline(_offset(rp, rn, -6.0), cols[0], 11.0, true)
				_speckles(rp, rn, rng, cols[1], 2.0)
			"ice":
				var cols2: Array = MATERIAL_COLORS.ice
				draw_polyline(_offset(rp, rn, -8.0), cols2[1], 15.0, true)
				draw_polyline(_offset(rp, rn, -5.0), cols2[0], 9.0, true)
				draw_polyline(_offset(rp, rn, -2.0), Color.WHITE, 2.5, true)
				_glints(rp, rn, rng)
			"snow":
				# Soft, matte, pillowy (contrast with glossy ice): thick white band, blue shadow scallops.
				_scallops(rp, rn, -14.0, 22.0, 9.0, Color("c9d6ea"))
				draw_polyline(_offset(rp, rn, -9.0), Color("dfe8f5"), 18.0, true)
				draw_polyline(_offset(rp, rn, -6.0), Color("f7fbff"), 12.0, true)
				_speckles(rp, rn, rng, Color("c3d3ec"), 1.6)
			"sticky":
				var cols3: Array = MATERIAL_COLORS.sticky
				_drips(rp, rn, rng, cols3[1])
				draw_polyline(_offset(rp, rn, -7.0), cols3[1], 14.0, true)
				draw_polyline(_offset(rp, rn, -5.0), cols3[0], 9.0, true)
				draw_polyline(_offset(rp, rn, -2.5), cols3[0].lightened(0.35), 2.5, true)
			"bouncy":
				var cols4: Array = MATERIAL_COLORS.bouncy
				draw_polyline(_offset(rp, rn, -7.0), cols4[0].darkened(0.3), 14.0, true)
				_stripes(rp, rn, cols4[0], cols4[1])
			"rock", "wood":
				var cols5: Array = MATERIAL_COLORS[mat]
				draw_polyline(_offset(rp, rn, -6.0), cols5[1], 12.0, true)
				draw_polyline(_offset(rp, rn, -4.0), cols5[0], 7.0, true)
			_:
				pass

	func _walk(pts: PackedVector2Array, spacing: float, cb: Callable) -> void:
		var acc := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var len := a.distance_to(b)
			var d := 0.0
			while acc + (len - d) >= spacing:
				d += spacing - acc
				acc = 0.0
				cb.call(a.lerp(b, d / len), i)
			acc += len - d

	func _scallops(pts: PackedVector2Array, nrm: PackedVector2Array, off: float, spacing: float, r: float, col: Color) -> void:
		_walk(pts, spacing, func(p: Vector2, i: int) -> void:
			draw_circle(p + nrm[i] * off, r, col, true, -1.0, true))

	func _tufts(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator, dark: Color, grass: Color) -> void:
		_walk(pts, 34.0, func(p: Vector2, i: int) -> void:
			if rng.randf() < 0.45:
				return
			var n := nrm[i]
			var tng := Vector2(-n.y, n.x)
			var base := p + n * -1.0
			for k in 3:
				var off := float(k - 1) * 3.5
				var h := rng.randf_range(6.0, 11.0) * (1.25 if k == 1 else 1.0)
				var lean := float(k - 1) * 0.35 + rng.randf_range(-0.15, 0.15)
				var tip := base + tng * (off + lean * h) + n * h
				draw_colored_polygon(PackedVector2Array([base + tng * (off - 2.2), tip, base + tng * (off + 2.2)]), dark if k != 1 else grass))

	func _speckles(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator, col: Color, r: float) -> void:
		_walk(pts, 9.0, func(p: Vector2, i: int) -> void:
			draw_circle(p + nrm[i] * rng.randf_range(-12.0, -3.0) + Vector2(rng.randf_range(-3, 3), 0), r * rng.randf_range(0.5, 1.0), col, true, -1.0, true))

	func _glints(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator) -> void:
		_walk(pts, 60.0, func(p: Vector2, i: int) -> void:
			var c := p + nrm[i] * -6.0
			draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), Color(1, 1, 1, 0.8), 1.6, true)
			draw_line(c + Vector2(0, -4), c + Vector2(0, 4), Color(1, 1, 1, 0.8), 1.6, true))

	func _drips(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator, col: Color) -> void:
		_walk(pts, 22.0, func(p: Vector2, i: int) -> void:
			var len := rng.randf_range(4.0, 16.0)
			var a := p + nrm[i] * -8.0
			var b := a + nrm[i] * -len
			draw_line(a, b, col, 6.0, true)
			draw_circle(b, 4.0, col, true, -1.0, true))

	func _stripes(pts: PackedVector2Array, nrm: PackedVector2Array, a: Color, b: Color) -> void:
		var toggle := [false]
		var prev := [pts[0]]
		_walk(pts, 14.0, func(p: Vector2, i: int) -> void:
			var c: Color = a if toggle[0] else b
			draw_line(prev[0] + nrm[i] * -5.5, p + nrm[i] * -5.5, c, 9.0, false)
			prev[0] = p
			toggle[0] = not toggle[0])


# ---------------------------------------------------------------------------
# Cup & flag
# ---------------------------------------------------------------------------

class _Cup extends Node2D:
	var terrain: SimTerrain

	func _draw() -> void:
		if not terrain.has_cup:
			return
		var l := terrain.cup_left
		var r := terrain.cup_right
		var top := terrain.cup_pos.y - 6.0
		var bottom := terrain.cup_floor_y
		draw_rect(Rect2(l, top, r - l, bottom - top), Color("15161f"))
		draw_rect(Rect2(l, top, r - l, (bottom - top) * 0.45), Color("23253a"))
		draw_rect(Rect2(l, top + 4, 3.5, bottom - top - 4), Color("f4f4f8"))
		draw_rect(Rect2(r - 3.5, top + 4, 3.5, bottom - top - 4), Color("d0d4e4"))


class _Flag extends Node2D:
	var number := 1
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var h := 128.0
		var top := Vector2(0, -h)
		draw_line(Vector2(0, 26), top, Color("2b2d42"), 5.0, true)
		draw_line(Vector2(0, 26), top, Color("f4f4f8"), 2.5, true)
		var pts := PackedVector2Array()
		var pts2 := PackedVector2Array()
		var w := 58.0
		var hh := 38.0
		for i in 13:
			var u := float(i) / 12.0
			var wave := sin(_t * 5.0 - u * 4.5) * 4.0 * u
			pts.append(top + Vector2(u * w, wave + u * hh * 0.5 * 0.0))
		for i in 13:
			var u := 1.0 - float(i) / 12.0
			var wave := sin(_t * 5.0 - u * 4.5) * 4.0 * u
			pts2.append(top + Vector2(u * w * 0.98, hh - u * hh * 0.05 + wave))
		var poly := pts + pts2
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_colored_polygon(poly, Color("ff4d6d"))
		draw_polyline(outline, Color("2b2d42"), 3.0, true)
		var font := UITheme.heading_font()
		var mid := top + Vector2(w * 0.42, hh * 0.5 + sin(_t * 5.0 - 2.0) * 2.0)
		draw_string_outline(font, mid + Vector2(-9, 9), str(number), HORIZONTAL_ALIGNMENT_CENTER, 18, 26, 6, Color("2b2d42"))
		draw_string(font, mid + Vector2(-9, 9), str(number), HORIZONTAL_ALIGNMENT_CENTER, 18, 26, Color.WHITE)
		draw_circle(top, 4.0, Color("ffd166"), true, -1.0, true)


# ---------------------------------------------------------------------------
# Hazard zones (water / lava)
# ---------------------------------------------------------------------------

## Crisp ink outline round terrain polygons (art mode), broken at hidden world-edge seams.
class _ArtInk extends Node2D:
	var view: TerrainView
	var width := 3.0

	func _draw() -> void:
		var ink := Color(view.art.data.get("ink", "#20141e"))
		for poly in view.terrain.polygons:
			var pts: PackedVector2Array = poly.points
			var n := pts.size()
			var line := PackedVector2Array()
			for i in n + 1:
				var a := pts[i % n]
				if i > 0 and view.is_seam(pts[i - 1], a):
					if line.size() >= 2:
						draw_polyline(line, ink, width, false)
					line = PackedVector2Array()
				line.append(a)
			if line.size() >= 2:
				draw_polyline(line, ink, width, false)


## Sprite flag flipbook planted in the cup.
class _ArtFlag extends Sprite2D:
	var _frames := 1
	var _fps := 10.0
	var _t := 0.0

	func setup(art: WorldArt, d: Dictionary) -> void:
		texture = art.tex(str(d.sheet))
		_frames = int(d.frames)
		_fps = float(d.get("fps", 10))
		hframes = _frames
		centered = false
		var pv: Array = d.pivot
		offset = Vector2(-float(pv[0]), -float(pv[1]))
		scale = Vector2(art.scale, art.scale)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		frame = int(_t * _fps) % _frames


class _Water extends Node2D:
	var terrain: SimTerrain
	var theme: Dictionary
	var art: WorldArt
	var _bodies: Dictionary = {}   ## zone key -> [Polygon2D] (art mode)
	var _t := 0.0

	func _process(delta: float) -> void:
		if terrain.zones.is_empty():
			set_process(false)
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for z in terrain.zones:
			var rect: Rect2 = z.rect
			var kind: String = z.type
			var top_col := Color(theme.get("water_top", "#4fc3f7"))
			var bot_col := Color(theme.get("water_bottom", "#1e6fb8"))
			if kind == "lava":
				top_col = Color("ffb347")
				bot_col = Color("d62828")
			elif kind == "acid":
				top_col = Color("b8f35a")
				bot_col = Color("3f8f2a")
			var surf := PackedVector2Array()
			var cols := PackedColorArray()
			var steps := maxi(4, int(rect.size.x / 14.0))
			for i in steps + 1:
				var x := rect.position.x + rect.size.x * float(i) / float(steps)
				var y := rect.position.y + sin(x * 0.035 + _t * 2.2) * 2.5 + sin(x * 0.011 - _t * 1.3) * 1.5
				surf.append(Vector2(x, y))
			var poly := surf.duplicate()
			poly.append(rect.end)
			poly.append(Vector2(rect.position.x, rect.end.y))
			# Only draw water in open air: subtract every solid terrain polygon.
			var parts: Array[PackedVector2Array] = [poly]
			for tp in terrain.polygons:
				var next: Array[PackedVector2Array] = []
				for part in parts:
					for clipped in Geometry2D.clip_polygons(part, tp.points):
						if not Geometry2D.is_polygon_clockwise(clipped):
							next.append(clipped)
				parts = next
			if art:
				_draw_art_zone(kind, parts, surf, rect)
				continue
			for part in parts:
				cols = PackedColorArray()
				for v in part:
					var k := clampf((v.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
					var c := top_col.lerp(bot_col, k)
					c.a = 0.9
					cols.append(c)
				draw_polygon(part, cols)
			draw_polyline(surf, Color(1, 1, 1, 0.75) if kind == "water" else top_col.lightened(0.4), 3.0, true)
			# Shimmer dashes.
			for i in int(rect.size.x / 70.0):
				var x := rect.position.x + fposmod(float(i) * 70.0 + _t * 18.0, rect.size.x)
				var y := rect.position.y + 10.0 + fmod(float(i) * 23.0, maxf(rect.size.y - 20.0, 1.0))
				draw_line(Vector2(x, y), Vector2(x + 16, y), Color(1, 1, 1, 0.25), 2.0, true)


	## Authored water/lava: tiled material texture drifting slowly, a crisp foam line, sparkles.
	func _draw_art_zone(kind: String, parts: Array[PackedVector2Array], surf: PackedVector2Array, rect: Rect2) -> void:
		var m := art.material(kind)
		var t := art.tex(str(m.get("fill", "")))
		var span := Vector2(t.get_width(), t.get_height()) * art.scale if t else Vector2.ONE
		var drift := Vector2(_t * 6.0, sin(_t * 0.7) * 3.0)
		# Water body: textured Polygon2D children behind this node (crisp, repeating, drifting).
		var key := "%s:%s" % [kind, rect]
		if not _bodies.has(key):
			_bodies[key] = []
		var pool: Array = _bodies[key]
		while pool.size() < parts.size():
			var p2 := art.textured_polygon(PackedVector2Array(), t)
			p2.show_behind_parent = true
			p2.color = Color(1, 1, 1, float(m.get("alpha", 0.92)))
			add_child(p2)
			pool.append(p2)
		for i in pool.size():
			var p2: Polygon2D = pool[i]
			p2.visible = i < parts.size()
			if p2.visible:
				p2.polygon = parts[i]
				p2.texture_offset = drift
		var foam := Color(m.get("foam", "#e8fbff"))
		var deep := Color(m.get("edge", "#1b4f8c"))
		var s := art.scale
		var top := PackedVector2Array()
		for v in surf:
			top.append(Vector2(roundf(v.x / s) * s, roundf(v.y / s) * s))
		draw_polyline(top, deep, s * 3.0, false)
		draw_polyline(top, foam, s, false)
		# Sparkles: 2x2 art-pixel glints that blink along the surface band.
		for i in int(rect.size.x / 46.0):
			var ph := fposmod(_t * 1.7 + float(i) * 0.61, 2.0)
			if ph > 0.5:
				continue
			var x := rect.position.x + fposmod(float(i) * 46.0 + _t * 9.0, rect.size.x)
			var y := rect.position.y + s * (4.0 + float(i % 4) * 3.0)
			draw_rect(Rect2(Vector2(roundf(x / s) * s, roundf(y / s) * s), Vector2(s, s)), foam)


# ---------------------------------------------------------------------------
# Decor
# ---------------------------------------------------------------------------

class _Tree extends Node2D:
	var leaf := Color.GREEN
	var leaf_dark := Color.DARK_GREEN
	var leaf_light := Color.LIGHT_GREEN
	var trunk := Color.BROWN
	var line := Color.BLACK
	var seed_value := 0
	var _canopy: Node2D
	var _t := 0.0

	func _ready() -> void:
		_canopy = _Canopy.new()
		_canopy.tree = self
		_canopy.position = Vector2(0, -78)
		add_child(_canopy)
		_t = float(seed_value % 100)

	func _process(delta: float) -> void:
		_t += delta
		_canopy.rotation = sin(_t * 1.1) * 0.025 + sin(_t * 2.3) * 0.01

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(-9, 2), Vector2(-5, -40), Vector2(-14, -70), Vector2(-3, -66), Vector2(0, -84),
			Vector2(4, -66), Vector2(15, -74), Vector2(6, -40), Vector2(10, 2)])
		draw_colored_polygon(pts, trunk)
		var o := pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, line, 3.0, true)
		draw_line(Vector2(1, -8), Vector2(2, -34), trunk.darkened(0.25), 2.5, true)

	class _Canopy extends Node2D:
		var tree: _Tree

		func _draw() -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = tree.seed_value
			var blobs: Array[Vector3] = []
			for i in 7:
				var a := TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
				blobs.append(Vector3(cos(a) * 34.0, sin(a) * 22.0 - 18.0, rng.randf_range(26, 34)))
			blobs.append(Vector3(0, -24, 36))
			for b in blobs:
				draw_circle(Vector2(b.x, b.y), b.z + 3.0, tree.line, true, -1.0, true)
			for b in blobs:
				draw_circle(Vector2(b.x, b.y), b.z, tree.leaf_dark, true, -1.0, true)
			for b in blobs:
				draw_circle(Vector2(b.x - 4, b.y - 6), b.z * 0.82, tree.leaf, true, -1.0, true)
			for b in blobs:
				if b.y < -20:
					draw_circle(Vector2(b.x - 8, b.y - 12), b.z * 0.38, tree.leaf_light, true, -1.0, true)


class _Bush extends Node2D:
	var col := Color.GREEN
	var light := Color.LIGHT_GREEN
	var line := Color.BLACK
	var seed_value := 0

	func _draw() -> void:
		var blobs := [Vector3(-22, -14, 18), Vector3(0, -22, 24), Vector3(22, -14, 18), Vector3(-10, -8, 14), Vector3(12, -8, 14)]
		for b: Vector3 in blobs:
			draw_circle(Vector2(b.x, b.y), b.z + 3.0, line, true, -1.0, true)
		for b: Vector3 in blobs:
			draw_circle(Vector2(b.x, b.y), b.z, col, true, -1.0, true)
		for b: Vector3 in blobs:
			draw_circle(Vector2(b.x - 3, b.y - 5), b.z * 0.55, light, true, -1.0, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in 4:
			draw_circle(Vector2(rng.randf_range(-24, 24), rng.randf_range(-30, -10)), 3.0, Color("ff8fab"), true, -1.0, true)


class _Flowers extends Node2D:
	var stem := Color.DARK_GREEN
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var palette := [Color("ff8fab"), Color("ffd166"), Color("ffffff"), Color("c77dff"), Color("ff6b6b")]
		for i in 7:
			var x := rng.randf_range(-40, 40)
			var h := rng.randf_range(14, 28)
			var top := Vector2(x + rng.randf_range(-4, 4), -h)
			draw_line(Vector2(x, 2), top, stem, 2.2, true)
			var c: Color = palette[rng.randi() % palette.size()]
			for k in 5:
				var a := TAU * float(k) / 5.0
				draw_circle(top + Vector2(cos(a), sin(a)) * 4.0, 3.4, c, true, -1.0, true)
			draw_circle(top, 2.6, Color("ffb703") if c != Color("ffd166") else Color("fb8500"), true, -1.0, true)


class _Rock extends Node2D:
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI + PI * float(i) / 8.0
			pts.append(Vector2(cos(a) * rng.randf_range(20, 28), sin(a) * rng.randf_range(14, 22) + 4))
		draw_colored_polygon(pts, Color("9aa5b8"))
		var o := pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, Color("2b2d42"), 3.0, true)
		draw_line(pts[2] + Vector2(3, 4), pts[4] + Vector2(0, 6), Color("c7cfdc"), 3.0, true)
