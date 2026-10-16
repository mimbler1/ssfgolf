class_name CharacterSkin
extends RefCounted
## Painter for the roster characters: full-bodied cartoon golfers drawn over the Golfer rig's
## solved skeleton. Only the sprite baker (scripts/dev/sprite_baker.gd) runs this; the game
## plays the baked sheets. Every part is a polygon that gets a thin ink line, a flat fill, a
## shadow crescent (lower-right) and a highlight crescent (upper-left), so parts overlap with
## clean inner lines. The baker adds the thick outer silhouette outline afterwards.
##
## Local space: origin on the ground between the feet, +x is forward, y is down.

const INK := Color("1d1a2b")
const LINE := 1.5          ## inner line width (rig units)
const LIGHT := Vector2(-0.55, -0.85)   ## direction the light comes from

## Roster. `head` scales the head radius (rig default 12.5), `scale` the whole body.
## Colours are named per character; painters below pick them up by key.
const ROSTER := {
	"ace": {
		"name": "Ace", "tagline": "Tour pro. Fairways fear him.",
		"head": 1.22, "scale": 1.0, "arm": 6.2, "thigh": 8.2, "shin": 6.6, "shoulders": 17.0, "waist": 13.0,
		"skin": "#f1b98c", "hair": "#5b3a29", "shirt": "#1f4e8c", "shirt2": "#ffffff", "pants": "#d9c8a2",
		"shoe": "#ffffff", "shoe2": "#6b3f26", "glove": "#ffffff", "hat": "#ffffff", "hat2": "#1f4e8c",
		"brow": "#4a2e20", "ball": "#ffffff", "trail": "#4cc9f0",
	},
	"nana": {
		"name": "Nana Birdie", "tagline": "Eighty-one years young. Still outdrives you.",
		"head": 1.2, "scale": 0.96, "arm": 5.8, "thigh": 9.0, "shin": 5.4, "shoulders": 15.5, "waist": 16.5,
		"skin": "#f6d2b8", "hair": "#e6e3ef", "shirt": "#ff8fab", "shirt2": "#fff6f0", "pants": "#9d8df1",
		"shoe": "#7a4b3a", "shoe2": "#5a3328", "glove": "#f6d2b8", "hat": "#ffd166", "hat2": "#ef476f",
		"brow": "#b8b4c8", "ball": "#ffd6e5", "trail": "#ff8fab",
	},
	"brick": {
		"name": "Brick", "tagline": "Lumberjack. Swings like he's felling an oak.",
		"head": 1.22, "scale": 1.06, "arm": 8.4, "thigh": 10.0, "shin": 8.4, "shoulders": 23.0, "waist": 19.0,
		"skin": "#e9a87c", "hair": "#c8562a", "shirt": "#c62f3a", "shirt2": "#2b1f2a", "pants": "#3e5f9e",
		"shoe": "#6b4426", "shoe2": "#3b2414", "glove": "#e9a87c", "hat": "#2a9d8f", "hat2": "#1f7368",
		"brow": "#a8441f", "ball": "#ffe1c4", "trail": "#c62f3a",
	},
	"bolt": {
		"name": "Bolt", "tagline": "Caddie bot 3000. Calculates every bounce.",
		"head": 1.24, "scale": 1.0, "arm": 6.4, "thigh": 7.6, "shin": 7.0, "shoulders": 18.0, "waist": 12.0,
		"skin": "#b8c4d6", "hair": "#7d8ba3", "shirt": "#3fb6b2", "shirt2": "#1e7c80", "pants": "#7d8ba3",
		"shoe": "#3d4a63", "shoe2": "#232c3d", "glove": "#3d4a63", "hat": "#ffd166", "hat2": "#ef476f",
		"brow": "#232c3d", "ball": "#c9fffd", "trail": "#3fe0d0", "screen": "#132033", "led": "#5ff3ff",
	},
	"skipper": {
		"name": "Skipper", "tagline": "Ten years old. Already has a hole-in-one.",
		"head": 1.36, "scale": 0.86, "arm": 5.6, "thigh": 7.2, "shin": 5.6, "shoulders": 14.5, "waist": 12.5,
		"skin": "#c98a5e", "hair": "#2b1d16", "shirt": "#ffd166", "shirt2": "#ef476f", "pants": "#2f6fb5",
		"shoe": "#ef476f", "shoe2": "#ffffff", "glove": "#c98a5e", "hat": "#4361ee", "hat2": "#ef476f",
		"brow": "#2b1d16", "ball": "#fff3b0", "trail": "#ffd166",
	},
	"frost": {
		"name": "Frost", "tagline": "Gentle yeti. Plays every course barefoot.",
		"head": 1.24, "scale": 1.08, "arm": 8.6, "thigh": 10.4, "shin": 9.0, "shoulders": 22.0, "waist": 21.0,
		"skin": "#9fb7d6", "hair": "#f4f8ff", "shirt": "#f4f8ff", "shirt2": "#dfe8f6", "pants": "#f4f8ff",
		"shoe": "#9fb7d6", "shoe2": "#7f97b8", "glove": "#9fb7d6", "hat": "#ef476f", "hat2": "#b02a4d",
		"brow": "#6f86a8", "ball": "#e6f7ff", "trail": "#9fe3ff",
	},
}

static var _ci: CanvasItem
static var _d: Dictionary
static var _t: float


static func ids() -> Array:
	return ROSTER.keys()


static func col(key: String) -> Color:
	return Color(str(_d.get(key, "#ff00ff")))


## Paints the character `id` for pose `p` (from Golfer._solve) onto `ci`.
## `expr` is the rig's expression override; `blink` closes the eyes.
static func paint(ci: CanvasItem, id: String, p: Dictionary, expr: Dictionary, t: float, blink: bool) -> void:
	_ci = ci
	_d = ROSTER.get(id, ROSTER.ace)
	_t = t
	var furry := id == "frost"
	# 1. Back arm, back leg.
	_arm(p.r_sh, p.r_elbow, p.r_hand, true, id)
	_leg(p.hip_r, p.r_knee, p.r_foot, true, id)
	if p.club:
		_club(p.grip, p.club_end)
	# 2. Front leg, hips, torso.
	_leg(p.hip_l, p.l_knee, p.l_foot, false, id)
	_torso(p, id)
	# 3. Head.
	_head(p, id, expr, blink)
	# 4. Front arm on top.
	_arm(p.l_sh, p.l_elbow, p.l_hand, false, id)
	if p.thumb:
		var tb: Vector2 = p.l_hand + Vector2(0.4, -2.0)
		_part(_capsule(tb, tb + Vector2(0.6, -5.0), 1.9, 1.7), col("glove"))
	if furry:
		_scarf_front(p)


# ---------------------------------------------------------------------------
# Shape helpers
# ---------------------------------------------------------------------------

## Tapered capsule polygon from a (radius ra) to b (radius rb).
static func _capsule(a: Vector2, b: Vector2, ra: float, rb: float, seg: int = 10) -> PackedVector2Array:
	var d := (b - a)
	if d.length() < 0.01:
		d = Vector2(0, 0.01)
	var ang := d.angle()
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a2 := ang - PI * 0.5 + PI * float(i) / float(seg)
		pts.append(b + Vector2.from_angle(a2) * rb)
	for i in seg + 1:
		var a2 := ang + PI * 0.5 + PI * float(i) / float(seg)
		pts.append(a + Vector2.from_angle(a2) * ra)
	return pts


static func _ellipse(c: Vector2, r: Vector2, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## Union of two overlapping shapes (largest resulting outline; holes are ignored).
static func _union(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var best := a
	var best_area := -1.0
	for poly: PackedVector2Array in Geometry2D.merge_polygons(a, b):
		var ar := absf(_area(poly))
		if ar > best_area:
			best_area = ar
			best = poly
	return best


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


static func _shift(poly: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = poly[i] + off
	return out


## Draws one part: ink line, fill, shadow and highlight crescents.
static func _part(poly: PackedVector2Array, fill: Color, shade: float = 0.16, line: float = LINE, hl: float = 0.10) -> void:
	if poly.size() < 3:
		return
	if Geometry2D.triangulate_polygon(poly).is_empty():
		# Self-intersecting (e.g. fur on a tightly bent limb): redraw each clean piece.
		for piece: PackedVector2Array in Geometry2D.offset_polygon(poly, 0.01):
			if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
				_part(piece, fill, shade, line, hl)
		return
	if line > 0.0:
		for g: PackedVector2Array in Geometry2D.offset_polygon(poly, line, Geometry2D.JOIN_ROUND):
			_fill(g, INK)
	_fill(poly, fill)
	_crescents(poly, fill, shade, hl)


static func _crescents(poly: PackedVector2Array, fill: Color, shade: float, hl: float) -> void:
	var size := _extent(poly)
	var k := clampf(minf(size.x, size.y) * 0.16, 0.8, 3.2)
	if shade > 0.0:
		for s: PackedVector2Array in Geometry2D.clip_polygons(poly, _shift(poly, LIGHT * k)):
			if s.size() >= 3:
				_fill(s, fill.darkened(shade))
	if hl > 0.0:
		for s: PackedVector2Array in Geometry2D.clip_polygons(poly, _shift(poly, -LIGHT * k * 0.6)):
			if s.size() >= 3:
				_fill(s, fill.lightened(hl))


static func _extent(poly: PackedVector2Array) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in poly:
		lo = lo.min(v)
		hi = hi.max(v)
	return hi - lo


## Fills a polygon, skipping degenerate slivers that cannot be triangulated.
static func _fill(poly: PackedVector2Array, c: Color) -> void:
	if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
		_ci.draw_colored_polygon(poly, c)


static func _line(a: Vector2, b: Vector2, c: Color, w: float = LINE) -> void:
	_ci.draw_line(a, b, c, w, true)


static func _dot(c: Vector2, r: float, color: Color) -> void:
	_ci.draw_circle(c, r, color, true, -1.0, true)


# ---------------------------------------------------------------------------
# Limbs
# ---------------------------------------------------------------------------

static func _leg(hip: Vector2, knee: Vector2, foot: Vector2, back: bool, id: String) -> void:
	var th := float(_d.thigh) * 0.5
	var sh := float(_d.shin) * 0.5
	var ankle := foot + Vector2(0, -3.0)
	var dim := 0.1 if back else 0.0
	var pants := col("pants").darkened(dim)
	var skin := col("skin").darkened(dim)
	match id:
		"nana":
			# Pleated skirt covers the thigh; stockinged shins below.
			_part(_capsule(knee, ankle, sh * 0.85, sh * 0.75), Color("e9d8cf").darkened(dim))
		"skipper":
			_part(_capsule(knee, ankle, sh, sh * 0.85), skin)
			_part(_capsule(hip, hip.lerp(knee, 0.85), th, th * 0.95), pants)
		"frost":
			var leg := _union(_capsule(hip, knee, th, sh * 1.05), _capsule(knee, ankle, sh * 1.05, sh))
			_part(_fur(leg, 1.4), col("hair").darkened(dim + 0.04), 0.12)
		"bolt":
			_part(_capsule(hip, knee, th * 0.7, th * 0.6), pants.darkened(0.1))
			_part(_capsule(knee, ankle, sh * 0.8, sh * 0.7), col("skin").darkened(dim))
			_part(_ellipse(knee, Vector2(th * 0.85, th * 0.85)), col("shirt").darkened(dim + 0.05))
		_:
			var leg2 := _union(_capsule(hip, knee, th, sh * 1.02), _capsule(knee, ankle, sh * 1.02, sh * 0.92))
			_part(leg2, pants)
			if id == "brick":
				# Rolled jean cuff.
				var cuff_a := knee.lerp(ankle, 0.82)
				_part(_capsule(cuff_a, ankle, sh * 1.12, sh * 1.08), pants.lightened(0.12), 0.1)
	_shoe(foot, back, id)


static func _shoe(foot: Vector2, back: bool, id: String) -> void:
	var dim := 0.12 if back else 0.0
	var c := col("shoe").darkened(dim)
	var c2 := col("shoe2").darkened(dim)
	var len := 7.5
	var h := 5.2
	if id == "brick":
		len = 9.0; h = 6.5
	elif id == "frost":
		len = 9.5; h = 5.5
	elif id == "skipper":
		len = 7.5; h = 5.8
	var pts := PackedVector2Array()
	# Heel to toe: flat sole, rounded toe cap.
	pts.append(foot + Vector2(-4.5, 0))
	pts.append(foot + Vector2(-5.0, -h * 0.8))
	pts.append(foot + Vector2(-2.0, -h))
	for i in 9:
		var a := -PI * 0.5 + PI * 0.5 * float(i) / 8.0
		pts.append(foot + Vector2(len - h * 0.55, -h * 0.55) + Vector2(cos(a) * h * 0.55, sin(a) * h * 0.55 * 0.9 - h * 0.05 * (1.0 - float(i) / 8.0)) * Vector2(1.6, 1.0))
	pts.append(foot + Vector2(len, 0))
	if id == "frost":
		_part(_fur(pts, 0.9), col("hair").darkened(dim + 0.06), 0.12)
		for k in 3:
			_dot(foot + Vector2(len - 1.2, -1.2 - k * 1.5), 0.8, col("skin").darkened(0.2))
		return
	_part(pts, c)
	# Sole.
	var sole := PackedVector2Array([foot + Vector2(-4.6, 0.6), foot + Vector2(len + 0.6, 0.6), foot + Vector2(len + 0.4, -1.4), foot + Vector2(-4.8, -1.4)])
	_fill(sole, c2)
	match id:
		"ace":
			_fill(_ellipse(foot + Vector2(len - 2.5, -h * 0.55), Vector2(2.3, 1.6)), c2)
		"skipper":
			_line(foot + Vector2(-1.0, -h * 0.75), foot + Vector2(2.5, -h * 0.55), c2, 1.1)
			_line(foot + Vector2(0.5, -h * 0.85), foot + Vector2(3.5, -h * 0.65), c2, 1.1)


static func _arm(sh: Vector2, el: Vector2, hand: Vector2, back: bool, id: String) -> void:
	var w := float(_d.arm) * 0.5
	var dim := 0.1 if back else 0.0
	var skin := col("skin").darkened(dim)
	var sleeve := col("shirt").darkened(dim)
	var wrist := el.lerp(hand, 0.82)
	match id:
		"frost":
			var arm := _union(_capsule(sh, el, w * 1.1, w), _capsule(el, wrist, w, w * 0.9))
			_part(_fur(arm, 1.3), col("hair").darkened(dim + 0.04), 0.12)
		"bolt":
			_part(_capsule(sh, el, w * 0.6, w * 0.55), col("pants").darkened(dim + 0.1))
			_part(_capsule(el, wrist, w * 0.75, w * 0.7), col("skin").darkened(dim))
			_part(_ellipse(sh, Vector2(w * 1.15, w * 1.15)), col("shirt").darkened(dim))
			_part(_ellipse(el, Vector2(w * 0.8, w * 0.8)), col("shirt").darkened(dim + 0.05))
		"brick":
			# Rolled sleeves, hairy forearms.
			_part(_capsule(el, wrist, w * 0.95, w * 0.85), skin)
			_part(_capsule(sh, el, w * 1.15, w * 1.05), sleeve)
			_part(_capsule(el + (el - sh).normalized() * -1.0, el + (wrist - el).normalized() * 2.0, w * 1.15, w * 1.12), sleeve.lightened(0.08), 0.1)
		"nana":
			_part(_union(_capsule(sh, el, w * 1.05, w), _capsule(el, wrist, w, w * 0.92)), sleeve)
			_part(_capsule(wrist + (wrist - el).normalized() * -2.0, wrist, w * 1.05, w * 1.05), col("shirt2").darkened(dim), 0.08)
		"skipper":
			_part(_capsule(el, wrist, w * 0.9, w * 0.85), skin)
			_part(_capsule(sh, sh.lerp(el, 0.6), w * 1.2, w * 1.1), sleeve)
		_:
			_part(_capsule(el, wrist, w * 0.9, w * 0.85), skin)
			_part(_capsule(sh, sh.lerp(el, 0.7), w * 1.15, w * 1.08), sleeve)
	# Hand / glove.
	var hc := col("glove").darkened(dim)
	if id == "ace" and back:
		hc = col("skin").darkened(dim)
	var hr := w * 1.0
	_part(_ellipse(hand, Vector2(hr, hr * 0.92), 0.0, 18), hc, 0.12)


static func _club(grip: Vector2, head: Vector2) -> void:
	var dir := (head - grip).normalized()
	_line(grip, head, INK, 3.4)
	_line(grip, head, Color("d8dde8"), 1.6)
	_line(grip - dir * 1.0, grip + dir * 7.0, Color("1b1b24"), 3.0)
	var perp := Vector2(-dir.y, dir.x)
	var face := head + dir * 1.0
	_part(PackedVector2Array([face - perp * 1.5, face + perp * 7.0, face + perp * 7.5 + dir * 4.0, face - perp * 1.5 + dir * 4.5]), Color("aab4c6"), 0.2)


## Wobbly fur edge: pushes polygon points out/in alternately.
static func _fur(poly: PackedVector2Array, amp: float) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var steps := maxi(1, int(a.distance_to(b) / 2.2))
		for k in steps:
			dense.append(a.lerp(b, float(k) / float(steps)))
	var c := Vector2.ZERO
	for v in dense:
		c += v
	c /= float(maxi(1, dense.size()))
	var out := PackedVector2Array()
	for i in dense.size():
		var v := dense[i]
		var o := (v - c).normalized() * (amp if i % 2 == 0 else -amp * 0.3)
		out.append(v + o)
	return out


# ---------------------------------------------------------------------------
# Torso
# ---------------------------------------------------------------------------

static func _torso_poly(p: Dictionary, top_w: float, bot_w: float, top_off: float = 1.5, bot_off: float = 3.0) -> PackedVector2Array:
	var up: Vector2 = (p.neck - p.hip).normalized()
	var side := Vector2(-up.y, up.x)
	var top: Vector2 = p.neck - up * top_off
	var bot: Vector2 = p.hip - up * bot_off
	var pts := PackedVector2Array()
	for i in 11:
		var a := PI * float(i) / 10.0
		pts.append(top + side * cos(a) * top_w * 0.5 + up * sin(a) * 3.5)
	for i in 11:
		var a := PI + PI * float(i) / 10.0
		pts.append(bot + side * cos(a) * bot_w * 0.5 + up * sin(a) * 2.5)
	return pts


static func _torso(p: Dictionary, id: String) -> void:
	var up: Vector2 = (p.neck - p.hip).normalized()
	var side := Vector2(-up.y, up.x)   # points backward (-x) when upright
	var fwd := -side
	var sw := float(_d.shoulders)
	var ww := float(_d.waist)
	var shirt := col("shirt")
	var hip: Vector2 = p.hip
	var neck: Vector2 = p.neck
	match id:
		"ace":
			_part(_ellipse(hip + up * 1.0, Vector2(ww * 0.55, 5.0), up.angle() + PI * 0.5), col("pants"))
			_part(_torso_poly(p, sw, ww), shirt)
			# Collar and placket.
			var c := neck - up * 2.5
			_part(PackedVector2Array([c + side * 4.5, c + fwd * 1.0 + up * 3.0, c + fwd * 2.0 - up * 2.5]), col("shirt2"), 0.1)
			_part(PackedVector2Array([c - side * 4.5 + fwd * 1.5, c + fwd * 1.0 + up * 3.0, c + fwd * 1.0 - up * 3.5]), col("shirt2"), 0.1)
			_line(c - up * 3.0 + fwd * 1.0, c - up * 7.0 + fwd * 1.2, shirt.darkened(0.35), 1.0)
			_dot(c - up * 5.0 + fwd * 1.1, 0.7, Color.WHITE)
			# Belt.
			var b := hip + up * 2.2
			_part(_capsule(b + side * ww * 0.48, b - side * ww * 0.48, 1.6, 1.6), Color("2b2d42"), 0.0, 1.0, 0.0)
			_part(_ellipse(b + fwd * 2.0, Vector2(1.6, 1.4)), Color("ffd166"), 0.1, 0.8)
		"nana":
			# Pleated skirt (A-line) over the hips.
			var s1 := hip + up * 3.0
			var s2 := hip - up * 13.0
			var skirt := PackedVector2Array([s1 + side * ww * 0.45, s1 - side * ww * 0.45, s2 - side * ww * 0.72, s2 + side * ww * 0.72])
			_part(skirt, col("pants"))
			for k in 4:
				var u := lerpf(-0.45, 0.45, float(k) / 3.0)
				_line(s1 + side * ww * u * 0.9 - up * 2.0, s2 + side * ww * u * 1.45, col("pants").darkened(0.22), 0.9)
			# Cardigan over blouse.
			_part(_torso_poly(p, sw, ww * 1.05), shirt)
			var c2 := neck - up * 2.0
			_part(PackedVector2Array([c2 + side * 2.5, c2 + fwd * 3.0, hip + up * 6.0 + fwd * 2.5, hip + up * 6.0 + side * 1.0]), col("shirt2"), 0.08)
			for k in 3:
				_dot(c2.lerp(hip + up * 6.0, 0.25 + k * 0.25) + fwd * 2.6, 0.75, Color("ffd166"))
			# Pearls.
			for k in 7:
				var a := lerpf(-0.9, 0.9, float(k) / 6.0)
				_dot(c2 - up * (2.2 - absf(a) * 1.4) + fwd * (a * 4.0 + 0.5), 0.95, Color("fffaf0"))
		"brick":
			_part(_ellipse(hip + up * 1.0, Vector2(ww * 0.55, 6.0), up.angle() + PI * 0.5), col("pants"))
			var tp := _torso_poly(p, sw, ww, 1.0, 3.5)
			_part(tp, shirt)
			# Plaid: dark bands clipped to the shirt.
			_plaid(tp, up, side, col("shirt2"))
			var c3 := neck - up * 2.5
			_part(PackedVector2Array([c3 + side * 5.0, c3 + fwd * 1.5 + up * 3.0, c3 + fwd * 2.5 - up * 3.0]), shirt.lightened(0.08), 0.1)
			# Belt and buckle.
			var b2 := hip + up * 2.5
			_part(_capsule(b2 + side * ww * 0.5, b2 - side * ww * 0.5, 1.9, 1.9), Color("4a2e1d"), 0.0, 1.0, 0.0)
			_part(_ellipse(b2 + fwd * 3.0, Vector2(2.2, 1.8)), Color("c9cdd6"), 0.15, 0.8)
		"bolt":
			_part(_ellipse(hip + up * 1.5, Vector2(ww * 0.55, 4.5), up.angle() + PI * 0.5), col("pants").darkened(0.1))
			var body := _torso_poly(p, sw, ww, 1.0, 2.5)
			_part(body, shirt, 0.2, LINE, 0.16)
			# Chest panel with a status light.
			var pc := neck.lerp(hip, 0.42) + fwd * 1.5
			_part(_round_rect(pc, Vector2(5.5, 4.0), up.angle() + PI * 0.5, 1.5), col("screen"), 0.0, 1.0, 0.0)
			var blink := 0.5 + 0.5 * sin(_t * TAU / 1.5)
			_dot(pc + side * 2.2, 1.0, Color("ef476f").lerp(Color("ffd166"), blink))
			_line(pc - side * 0.6 - up * 0.8, pc - side * 3.6 - up * 0.8, col("led"), 0.9)
			_line(pc - side * 0.6 + up * 0.8, pc - side * 2.6 + up * 0.8, col("led"), 0.9)
			for k in 2:
				_dot(neck - up * 3.0 + side * (6.0 - k * 12.0) * 0.6, 0.8, col("shirt2"))
		"skipper":
			_part(_ellipse(hip + up * 1.0, Vector2(ww * 0.55, 5.0), up.angle() + PI * 0.5), col("pants"))
			var tp2 := _torso_poly(p, sw, ww)
			_part(tp2, shirt)
			_stripes(tp2, up, col("shirt2"))
			_ci.draw_arc(neck - up * 1.8 + fwd * 0.5, 3.2, up.angle() + 0.3, up.angle() + PI - 0.3, 10, shirt.darkened(0.3), 1.2, true)
		"frost":
			var belly := _torso_poly(p, sw, ww * 1.12, 0.5, 4.5)
			_part(_fur(belly, 1.5), col("hair"), 0.12)
			var bc := neck.lerp(hip, 0.6) + fwd * 2.5
			_part(_ellipse(bc, Vector2(5.5, 7.5), up.angle() + PI * 0.5), col("shirt2"), 0.08, 1.0, 0.0)
			_scarf_back(p)


static func _round_rect(c: Vector2, half: Vector2, rot: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for k in 4:
		for i in 5:
			var a := PI * 0.5 * k + PI * 0.5 * float(i) / 4.0
			pts.append(c + (corners[k] + Vector2(cos(a), sin(a)) * r).rotated(rot))
	return pts


static func _plaid(poly: PackedVector2Array, up: Vector2, side: Vector2, dark: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in poly:
		lo = lo.min(v); hi = hi.max(v)
	var c := (lo + hi) * 0.5
	var ext := (hi - lo).length()
	for k in range(-4, 5):
		var o := float(k) * 5.0
		for dir: Vector2 in [up, side]:
			var perp := Vector2(-dir.y, dir.x)
			var band := PackedVector2Array([c + perp * (o - 1.0) - dir * ext, c + perp * (o - 1.0) + dir * ext,
				c + perp * (o + 1.0) + dir * ext, c + perp * (o + 1.0) - dir * ext])
			for s: PackedVector2Array in Geometry2D.intersect_polygons(poly, band):
				_fill(s, Color(dark, 0.38))


static func _stripes(poly: PackedVector2Array, up: Vector2, c2: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in poly:
		lo = lo.min(v); hi = hi.max(v)
	var c := (lo + hi) * 0.5
	var side := Vector2(-up.y, up.x)
	for k in range(-2, 3):
		var o := float(k) * 6.0
		var band := PackedVector2Array([c + up * (o - 1.4) - side * 30.0, c + up * (o - 1.4) + side * 30.0,
			c + up * (o + 1.4) + side * 30.0, c + up * (o + 1.4) - side * 30.0])
		for s: PackedVector2Array in Geometry2D.intersect_polygons(poly, band):
			_fill(s, c2)


static func _scarf_back(p: Dictionary) -> void:
	var n: Vector2 = p.neck
	var flap := sin(_t * TAU / 0.75) * 1.5
	var tail := PackedVector2Array([n + Vector2(-3, 1), n + Vector2(-13, 4 + flap), n + Vector2(-14, 8 + flap), n + Vector2(-4, 5)])
	_part(tail, col("hat").darkened(0.08))


static func _scarf_front(p: Dictionary) -> void:
	var n: Vector2 = p.neck
	var up: Vector2 = (p.neck - p.hip).normalized()
	_part(_capsule(n + Vector2(-7, 1) - up * 1.0, n + Vector2(7, 1) - up * 1.0, 3.2, 3.2), col("hat"), 0.14)
	_line(n + Vector2(-4, -1), n + Vector2(-4, 3), col("hat2"), 1.0)
	_line(n + Vector2(3, -1), n + Vector2(3, 3), col("hat2"), 1.0)


# ---------------------------------------------------------------------------
# Heads
# ---------------------------------------------------------------------------

static var _hc: Vector2
static var _hr: float
static var _hrot: float


## Head-space point: x forward, y down, in head radii.
static func H(x: float, y: float) -> Vector2:
	return _hc + Vector2(x * _hr, y * _hr).rotated(_hrot)


static func _hpoly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(H(v.x, v.y))
	return out


static func _hellipse(cx: float, cy: float, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	return _ellipse(H(cx, cy), Vector2(rx * _hr, ry * _hr), _hrot, n)


static func _head(p: Dictionary, id: String, expr: Dictionary, blink: bool) -> void:
	_hc = p.head
	_hr = p.head_r
	_hrot = p.head_rot
	var skin := col("skin")
	match id:
		"ace":
			_ear(skin)
			_part(_face_shape(1.0), skin)
			_part(_hpoly([Vector2(-1.0, -0.15), Vector2(-1.02, -0.55), Vector2(-0.6, -0.98), Vector2(0.1, -1.08), Vector2(0.7, -0.9),
				Vector2(0.9, -0.55), Vector2(0.55, -0.62), Vector2(0.1, -0.5), Vector2(-0.45, -0.45), Vector2(-0.62, -0.1)]), col("hair"))
			_face(expr, blink, {"cheeks": false})
			# Visor: band + brim.
			_part(_hpoly([Vector2(-1.0, -0.62), Vector2(0.75, -0.72), Vector2(0.82, -0.48), Vector2(-0.98, -0.38)]), col("hat"), 0.12)
			_part(_hpoly([Vector2(0.55, -0.68), Vector2(1.55, -0.58), Vector2(1.5, -0.42), Vector2(0.6, -0.46)]), col("hat2"), 0.15)
		"nana":
			_part(_hellipse(-0.82, -0.62, 0.42, 0.42), col("hair"), 0.12)   # bun
			_ear(skin)
			_part(_face_shape(1.0), skin)
			var cap := _hpoly([Vector2(-1.0, 0.15), Vector2(-1.02, -0.45), Vector2(-0.7, -0.92), Vector2(-0.1, -1.06), Vector2(0.5, -0.9), Vector2(0.82, -0.55),
				Vector2(0.4, -0.6), Vector2(-0.2, -0.55), Vector2(-0.6, -0.3), Vector2(-0.72, 0.1)])
			var curls := _curls([Vector2(-0.95, 0.1), Vector2(-1.0, -0.25), Vector2(-0.9, -0.6), Vector2(-0.6, -0.88), Vector2(-0.2, -1.0),
				Vector2(0.2, -0.95), Vector2(0.55, -0.78), Vector2(0.78, -0.55)], 0.27)
			_part(_union(cap, curls), col("hair"), 0.12)
			for cv: Vector2 in [Vector2(-0.6, -0.62), Vector2(-0.15, -0.75), Vector2(0.3, -0.7), Vector2(-0.8, -0.2)]:
				_ci.draw_arc(H(cv.x, cv.y), _hr * 0.13, 0.5 + _hrot, 3.6 + _hrot, 8, col("hair").darkened(0.18), 1.0, true)
			_face(expr, blink, {"cheeks": true, "lashes": true})
			# Round glasses.
			for ex: float in [0.22, 0.68]:
				_ci.draw_arc(H(ex, -0.12), _hr * 0.2, 0.0, TAU, 20, Color("8a5a9a"), 1.2, true)
			_line(H(0.42, -0.14), H(0.48, -0.14), Color("8a5a9a"), 1.0)
			_line(H(0.02, -0.14), H(-0.45, -0.25), Color("8a5a9a"), 1.0)
		"brick":
			_ear(skin)
			_part(_face_shape(1.04), skin)
			_face(expr, blink, {"cheeks": false, "thick_brows": true, "beard": true})
			# Beanie with a folded cuff.
			_part(_hpoly([Vector2(-1.08, -0.45), Vector2(-1.0, -0.92), Vector2(-0.5, -1.28), Vector2(0.2, -1.32), Vector2(0.75, -1.1), Vector2(0.98, -0.62), Vector2(0.95, -0.46)]), col("hat"), 0.14)
			_part(_hpoly([Vector2(-1.12, -0.36), Vector2(0.98, -0.4), Vector2(1.0, -0.66), Vector2(-1.1, -0.64)]), col("hat2"), 0.1)
			for k in 6:
				var x := lerpf(-0.9, 0.8, float(k) / 5.0)
				_line(H(x, -0.4), H(x, -0.62), col("hat2").darkened(0.25), 0.9)
		"bolt":
			_part(_hpoly([Vector2(-0.95, -0.85), Vector2(0.9, -0.92), Vector2(1.0, 0.75), Vector2(-0.9, 0.8)]), col("skin"), 0.2, LINE, 0.18)
			_part(_round_rect(H(0.12, -0.04), Vector2(_hr * 0.72, _hr * 0.58), _hrot, _hr * 0.2), col("screen"), 0.0, 1.0, 0.0)
			_bolt_face(expr, blink)
			# Ear bolts and antenna.
			_part(_hellipse(-0.98, 0.0, 0.18, 0.28), col("shirt"), 0.15)
			var tip := H(-0.2, -1.6) + Vector2(sin(_t * TAU / 1.5) * 1.2, 0).rotated(_hrot)
			_line(H(-0.2, -0.9), tip, INK, 2.4)
			_line(H(-0.2, -0.9), tip, col("hair"), 1.0)
			_part(_ellipse(tip, Vector2(_hr * 0.17, _hr * 0.17)), col("hat"), 0.1)
		"skipper":
			_ear(skin, 1.25)
			_part(_face_shape(1.0), skin)
			_part(_hpoly([Vector2(-0.95, -0.2), Vector2(-0.85, -0.7), Vector2(-0.2, -0.95), Vector2(0.5, -0.85), Vector2(0.8, -0.55), Vector2(0.3, -0.48), Vector2(-0.6, -0.3)]), col("hair"))
			_face(expr, blink, {"cheeks": false, "freckles": true})
			# Propeller cap: two-tone dome, brim, spinning propeller.
			_part(_hpoly([Vector2(-1.0, -0.42), Vector2(-0.85, -0.9), Vector2(-0.3, -1.12), Vector2(0.3, -1.1), Vector2(0.8, -0.8), Vector2(0.95, -0.42)]), col("hat"), 0.14)
			_part(_hpoly([Vector2(-0.3, -1.12), Vector2(0.3, -1.1), Vector2(0.35, -0.48), Vector2(-0.2, -0.45)]), col("hat2"), 0.1, 1.0)
			_part(_hpoly([Vector2(0.7, -0.5), Vector2(1.5, -0.44), Vector2(1.45, -0.3), Vector2(0.7, -0.34)]), col("hat"), 0.18)
			var hub := H(0.0, -1.2)
			_line(hub, H(0.0, -1.38), INK, 2.2)
			var spin := cos(_t * TAU * 3.0)
			var blade := Vector2(_hr * 0.75 * spin, 0).rotated(_hrot)
			var top := H(0.0, -1.42)
			_part(_capsule(top - blade, top + blade, 1.6, 1.6), Color("ffd166"), 0.15, 1.2)
			_dot(top, 1.4, col("hat2"))
		"frost":
			# Horns behind, fur head, pale face patch.
			_part(_hpoly([Vector2(-0.55, -0.75), Vector2(-0.95, -1.35), Vector2(-0.3, -0.92)]), Color("e9dcc6"), 0.15)
			_part(_fur(_face_shape(1.12), 1.3), col("hair"), 0.12)
			_part(_hellipse(0.46, 0.02, 0.56, 0.6, 28), skin, 0.12)
			_part(_hpoly([Vector2(0.35, -0.8), Vector2(0.6, -1.4), Vector2(0.7, -0.78)]), Color("e9dcc6"), 0.15)
			_face(expr, blink, {"cheeks": true, "no_nose": true, "snout": true})


static func _face_shape(s: float) -> PackedVector2Array:
	# Rounded head with a slightly fuller jaw on the face side.
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		var v := Vector2(cos(a), sin(a))
		var rx := 0.98 + 0.06 * maxf(0.0, v.x) * maxf(0.0, v.y)
		var ry := 0.98 + 0.05 * maxf(0.0, v.y)
		pts.append(H(v.x * rx * s, v.y * ry * s))
	return pts


static func _ear(skin: Color, s: float = 1.0) -> void:
	_part(_hellipse(-0.52, 0.05, 0.2 * s, 0.26 * s), skin.darkened(0.04), 0.14)
	_ci.draw_arc(H(-0.5, 0.06), _hr * 0.1 * s, -0.8 + _hrot, 2.2 + _hrot, 8, skin.darkened(0.3), 1.0, true)


static func _curls(path: Array, r: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for v: Vector2 in path:
		poly = _union(poly, _hellipse(v.x, v.y, r, r, 14)) if not poly.is_empty() else _hellipse(v.x, v.y, r, r, 14)
	return poly


## Cartoon face: eyes, brows, nose, mouth, extras. Eyes sit on the forward half of the head.
static func _face(expr: Dictionary, blink: bool, opt: Dictionary) -> void:
	var eyes := str(expr.get("eyes", "normal"))
	var mouth := str(expr.get("mouth", "smile"))
	var dark := Color("1d1a2b")
	var brow := col("brow")
	var e1 := H(0.2, -0.12)
	var e2 := H(0.66, -0.14)
	var er := _hr * 0.1
	var bw := 2.2 if opt.get("thick_brows", false) else 1.4
	# Brow tilt: + raises the inner (forward) end.
	var tilt := {"fierce": -0.12, "focus": -0.06, "sad": 0.12, "wide": 0.0}.get(eyes, 0.0)
	var lift := 0.06 if eyes in ["wide", "joy"] else 0.0
	for i in 2:
		var e: Vector2 = [e1, e2][i]
		var bx := 0.2 if i == 0 else 0.66
		var inner := 1.0 if i == 0 else -1.0
		var y0 := -0.38 - lift
		var a := H(bx - 0.13, y0 + tilt * inner)
		var b := H(bx + 0.13, y0 - tilt * inner)
		_line(a, b, brow, bw)
		var ex := eyes
		if blink and ex in ["normal", "fierce", "focus", "sad", "wide"]:
			ex = "closed"
		if ex == "wink":
			ex = "normal" if i == 0 else "joy"
		match ex:
			"normal", "fierce", "focus", "sad":
				_fill(_ellipse(e, Vector2(er * 0.85, er * 1.25), _hrot, 16), dark)
				_dot(e + Vector2(er * 0.3, -er * 0.5).rotated(_hrot), er * 0.38, Color.WHITE)
			"wide":
				_fill(_ellipse(e, Vector2(er * 1.55, er * 1.75), _hrot, 18), dark)
				_fill(_ellipse(e, Vector2(er * 1.3, er * 1.5), _hrot, 18), Color.WHITE)
				_dot(e + Vector2(er * 0.2, 0).rotated(_hrot), er * 0.7, dark)
				_dot(e + Vector2(er * 0.45, -er * 0.35).rotated(_hrot), er * 0.25, Color.WHITE)
			"joy":
				_ci.draw_arc(e + Vector2(0, er * 0.5).rotated(_hrot), er * 1.1, PI + 0.3 + _hrot, TAU - 0.3 + _hrot, 10, dark, 1.6, true)
			"closed":
				_ci.draw_arc(e + Vector2(0, -er * 0.4).rotated(_hrot), er * 1.0, 0.3 + _hrot, PI - 0.3 + _hrot, 10, dark, 1.5, true)
		if opt.get("lashes", false) and ex in ["normal", "wide"]:
			_line(e + Vector2(er * 0.7, -er * 1.0).rotated(_hrot), e + Vector2(er * 1.4, -er * 1.5).rotated(_hrot), dark, 0.9)
	# Cheeks, freckles.
	if opt.get("cheeks", false):
		_fill(_ellipse(H(0.62, 0.2), Vector2(_hr * 0.16, _hr * 0.09), _hrot, 14), Color(1.0, 0.45, 0.5, 0.35))
	if opt.get("freckles", false):
		for f: Vector2 in [Vector2(0.45, 0.12), Vector2(0.55, 0.18), Vector2(0.4, 0.22), Vector2(0.78, 0.14), Vector2(0.86, 0.2)]:
			_dot(H(f.x, f.y), 0.55, col("skin").darkened(0.35))
	# Snout / nose.
	if opt.get("snout", false):
		_fill(_hellipse(0.9, 0.12, 0.13, 0.09, 12), Color("4a5d7a"))
	elif not opt.get("no_nose", false) and not opt.get("beard", false):
		var n := PackedVector2Array([H(0.86, -0.02), H(1.08, 0.14), H(0.98, 0.22), H(0.84, 0.2)])
		_part(n, col("skin").darkened(0.03), 0.14, 1.1, 0.0)
	# Beard sits over the jaw before the mouth so the mouth shows through.
	if opt.get("beard", false):
		var beard := _union(_hpoly([Vector2(-0.6, 0.05), Vector2(-0.35, 0.18), Vector2(0.3, 0.32), Vector2(0.92, 0.26), Vector2(1.05, 0.48),
			Vector2(0.8, 0.95), Vector2(0.2, 1.22), Vector2(-0.4, 0.95), Vector2(-0.7, 0.45)]), _hellipse(0.25, 0.85, 0.5, 0.42))
		_part(_fur(beard, 0.8), col("hair"), 0.14)
		_part(_hpoly([Vector2(0.45, 0.3), Vector2(0.75, 0.24), Vector2(1.08, 0.36), Vector2(0.95, 0.46), Vector2(0.7, 0.38), Vector2(0.45, 0.44)]), col("hair").darkened(0.08), 0.1, 1.1)
		var n2 := PackedVector2Array([H(0.86, -0.02), H(1.1, 0.14), H(1.0, 0.24), H(0.84, 0.22)])
		_part(n2, col("skin").darkened(0.03), 0.14, 1.1, 0.0)
	_mouth(mouth, H(0.62, 0.56) if opt.get("beard", false) else H(0.62, 0.48))


static func _mouth(kind: String, m: Vector2) -> void:
	var dark := Color("4a1f2a")
	var r := _hr
	var rot := _hrot
	match kind:
		"smile":
			_ci.draw_arc(m + Vector2(0, -r * 0.12).rotated(rot), r * 0.22, 0.4 + rot, PI - 0.4 + rot, 12, Color("1d1a2b"), 1.5, true)
		"grin":
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(0.0, PI, float(i) / 12.0)
				pts.append(m + Vector2(cos(a) * r * 0.27, -r * 0.08 + sin(a) * r * 0.2).rotated(rot))
			_part(pts, dark, 0.0, 1.1, 0.0)
			var teeth := Geometry2D.intersect_polygons(pts, _ellipse(m + Vector2(0, -r * 0.1).rotated(rot), Vector2(r * 0.3, r * 0.08), rot))
			for t: PackedVector2Array in teeth:
				_fill(t, Color.WHITE)
		"open", "laugh":
			var big := 1.25 if kind == "laugh" else 1.0
			var pts2 := PackedVector2Array()
			for i in 15:
				var a := lerpf(0.0, PI, float(i) / 14.0)
				pts2.append(m + Vector2(cos(a) * r * 0.22 * big, -r * 0.08 + sin(a) * r * 0.26 * big).rotated(rot))
			_part(pts2, dark, 0.0, 1.1, 0.0)
			for t2: PackedVector2Array in Geometry2D.intersect_polygons(pts2, _ellipse(m + Vector2(0, r * 0.16 * big).rotated(rot), Vector2(r * 0.14 * big, r * 0.09 * big), rot)):
				_fill(t2, Color("e86a7a"))
		"o":
			_part(_ellipse(m + Vector2(0, -r * 0.02).rotated(rot), Vector2(r * 0.1, r * 0.14), rot, 16), dark, 0.0, 1.1, 0.0)
		"frown":
			_ci.draw_arc(m + Vector2(0, r * 0.14).rotated(rot), r * 0.18, PI + 0.5 + rot, TAU - 0.5 + rot, 10, Color("1d1a2b"), 1.5, true)
		"flat":
			_line(m + Vector2(-r * 0.15, 0).rotated(rot), m + Vector2(r * 0.15, 0).rotated(rot), Color("1d1a2b"), 1.5)
		"smirk":
			_ci.draw_arc(m + Vector2(r * 0.05, -r * 0.16).rotated(rot), r * 0.2, 0.5 + rot, PI * 0.55 + rot, 10, Color("1d1a2b"), 1.5, true)


## Bolt's LED screen face: expressions as glowing shapes.
static func _bolt_face(expr: Dictionary, blink: bool) -> void:
	var led := col("led")
	var eyes := str(expr.get("eyes", "normal"))
	var mouth := str(expr.get("mouth", "smile"))
	var glow := Color(led, 0.25)
	for i in 2:
		var e := H(0.0 + i * 0.45, -0.16)
		var ex := eyes
		if blink and ex not in ["joy", "closed"]:
			ex = "closed"
		if ex == "wink":
			ex = "normal" if i == 0 else "joy"
		match ex:
			"joy":
				_ci.draw_arc(e + Vector2(0, _hr * 0.06).rotated(_hrot), _hr * 0.11, PI + 0.2 + _hrot, TAU - 0.2 + _hrot, 8, led, 2.0, true)
			"closed":
				_line(e + Vector2(-_hr * 0.1, 0).rotated(_hrot), e + Vector2(_hr * 0.1, 0).rotated(_hrot), led, 2.0)
			"wide":
				_ci.draw_arc(e, _hr * 0.13, 0.0, TAU, 14, led, 2.0, true)
				_dot(e, _hr * 0.05, led)
			"fierce", "focus":
				var s := 1.0 if i == 0 else -1.0
				_fill(PackedVector2Array([e + Vector2(-_hr * 0.11, -_hr * 0.06 * s).rotated(_hrot), e + Vector2(_hr * 0.11, _hr * 0.06 * s).rotated(_hrot),
					e + Vector2(_hr * 0.11, _hr * 0.12).rotated(_hrot), e + Vector2(-_hr * 0.11, _hr * 0.12).rotated(_hrot)]), led)
			"sad":
				_ci.draw_arc(e + Vector2(0, -_hr * 0.04).rotated(_hrot), _hr * 0.1, 0.2 + _hrot, PI - 0.2 + _hrot, 8, led, 2.0, true)
			_:
				_dot(e, _hr * 0.13, glow)
				_dot(e, _hr * 0.085, led)
	var m := H(0.24, 0.24)
	match mouth:
		"open", "laugh", "o":
			_fill(_ellipse(m, Vector2(_hr * (0.1 if mouth == "o" else 0.2), _hr * 0.12), _hrot, 14), led)
		"frown":
			_ci.draw_arc(m + Vector2(0, _hr * 0.12).rotated(_hrot), _hr * 0.16, PI + 0.5 + _hrot, TAU - 0.5 + _hrot, 8, led, 1.8, true)
		"flat":
			_line(m + Vector2(-_hr * 0.15, 0).rotated(_hrot), m + Vector2(_hr * 0.15, 0).rotated(_hrot), led, 1.8)
		"grin":
			_ci.draw_arc(m + Vector2(0, -_hr * 0.1).rotated(_hrot), _hr * 0.2, 0.3 + _hrot, PI - 0.3 + _hrot, 10, led, 2.0, true)
			_line(m + Vector2(-_hr * 0.17, 0).rotated(_hrot), m + Vector2(_hr * 0.17, 0).rotated(_hrot), led, 1.2)
		_:
			_ci.draw_arc(m + Vector2(0, -_hr * 0.1).rotated(_hrot), _hr * 0.17, 0.4 + _hrot, PI - 0.4 + _hrot, 10, led, 1.8, true)
