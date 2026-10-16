class_name ToonParts
extends RefCounted
## Shared golfer parts in the house style: bean body, noodle arms, mitten hands, shoes, club,
## faces and expressions, plus the classic golfer's hats and shirts. Character builders
## (ToonCharacters) combine these with their own signature parts.
##
## All functions take the solved pose `p` from Golfer._solve (rig space, facing +x).

# Layer order (CHARACTER_ART_SPEC §4). Builders may use values in between.
const Z_REAR := 0.0
const Z_CLUB_PLANTED := 2.0
const Z_ARM_BACK_FREE := 8.0
const Z_FEET := 10.0
const Z_BODY := 20.0
const Z_CLOTH := 24.0
const Z_ARM_BACK := 30.0
const Z_SMEAR := 32.0
const Z_CLUB := 34.0
const Z_HAND_BACK := 36.0
const Z_CLUB_HELD := 38.0
const Z_ARM_FRONT := 40.0
const Z_HAND_FRONT := 42.0
const Z_HEAD_BACK := 46.0
const Z_HEAD := 50.0
const Z_FACE := 54.0
const Z_HAT := 58.0
const Z_OVER_FACE := 62.0
const Z_FRONT_FX := 70.0

const DARK := Color("1d1a2b")
const TONGUE := Color("ff7a8f")
const MOUTH := Color("5a1f33")

const CLUB_STYLE := {"shaft": "#e6ebf3", "grip": "#2d2f45", "head": "#c8d1df", "kind": "iron"}


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

## Body radius along the spine (t = 0 base, 1 neck) from a 3-value profile.
static func radius_at(p: Dictionary, prof: Array, t: float) -> float:
	var r0 := float(prof[0])
	var r1 := float(prof[1])
	var r2 := float(prof[2])
	var r := (1.0 - t) * (1.0 - t) * r0 + 2.0 * (1.0 - t) * t * (2.0 * r1 - 0.5 * (r0 + r2)) + t * t * r2
	return r * float(p.wide)


## The bean: a tube along the spine between t0 and t1, `extra` units fatter than the profile.
static func bean(cv: ToonCanvas, p: Dictionary, fill: Color, z: float, o: Dictionary = {},
		prof: Array = [], t0: float = 0.0, t1: float = 1.0, extra: float = 0.0, n: int = 9) -> void:
	if prof.is_empty():
		prof = p.rig.r
	var pts := PackedVector2Array()
	var rs := PackedFloat32Array()
	for i in n:
		var t := lerpf(t0, t1, float(i) / float(n - 1))
		pts.append(Golfer.spine_at(p, t))
		rs.append(radius_at(p, prof, t) + extra)
	cv.tube(pts, rs, fill, z, o)


## Outline of the body between cross-sections t0 and t1 (clothing bands, belts, stripes),
## `extra` units proud of the body. Includes the rounded cap when t0 = 0 or t1 = 1.
static func band_poly(p: Dictionary, t0: float, t1: float, extra: float = 0.0, prof: Array = [], n: int = 7) -> PackedVector2Array:
	if prof.is_empty():
		prof = p.rig.r
	var pts := PackedVector2Array()
	for i in n:
		var t := lerpf(t0, t1, float(i) / float(n - 1))
		pts.append(Golfer.spine_at(p, t) + Golfer.spine_fwd(p, t) * (radius_at(p, prof, t) + extra))
	if t1 >= 0.999:
		var c := Golfer.spine_at(p, 1.0)
		var f := Golfer.spine_fwd(p, 1.0)
		var rr := radius_at(p, prof, 1.0) + extra
		for i in range(1, 8):
			pts.append(c + f.rotated(-PI * float(i) / 8.0) * rr)
	for i in n:
		var t := lerpf(t1, t0, float(i) / float(n - 1))
		pts.append(Golfer.spine_at(p, t) - Golfer.spine_fwd(p, t) * (radius_at(p, prof, t) + extra))
	if t0 <= 0.001:
		var c2 := Golfer.spine_at(p, 0.0)
		var f2 := Golfer.spine_fwd(p, 0.0)
		var rr2 := radius_at(p, prof, 0.0) + extra
		for i in range(1, 8):
			pts.append(c2 - f2.rotated(-PI * float(i) / 8.0) * rr2)
	return pts


## Clothing band around the body between t0 and t1.
static func band(cv: ToonCanvas, p: Dictionary, col: Color, z: float, t0: float, t1: float, extra: float = 0.7, o: Dictionary = {}) -> void:
	var opts := o.duplicate()
	if not opts.has("shade"):
		opts.shade = 0.18 if t1 - t0 > 0.2 else 0.0
	cv.blob(band_poly(p, t0, t1, extra), col, z, opts)


## A point on the body surface: spine point at t pushed `side` radii toward the front (+1) or back (-1).
static func surface(p: Dictionary, t: float, side: float, prof: Array = []) -> Vector2:
	if prof.is_empty():
		prof = p.rig.r
	return Golfer.spine_at(p, t) + Golfer.spine_fwd(p, t) * radius_at(p, prof, t) * side


# ---------------------------------------------------------------------------
# Arms and hands
# ---------------------------------------------------------------------------

static func shoulder(p: Dictionary, back: bool) -> Vector2:
	var sh: Vector2 = p.shoulder
	if back:
		return sh - (p.fwd as Vector2) * 2.5 + (p.up as Vector2) * 0.5
	return sh + (p.fwd as Vector2) * 0.5


static func arm_z(p: Dictionary, back: bool) -> float:
	if not back:
		return Z_ARM_FRONT
	return Z_ARM_BACK if p.hands == "club" else Z_ARM_BACK_FREE


## Noodle arm control point: bows out with the slack, away from the head.
static func arm_ctrl(p: Dictionary, a: Vector2, h: Vector2, back: bool) -> Vector2:
	var reach := float(p.rig.reach)
	var mid := (a + h) * 0.5
	if float(p.flex) > 0.0:
		var side := -1.0 if back else 1.0
		var elbow := a + Vector2(side * reach * 0.62, reach * 0.12)
		return mid.lerp(elbow * 2.0 - mid, float(p.flex))
	var d := h - a
	var dist := d.length()
	var slack := maxf(0.0, reach - dist)
	var bulge := minf(slack * 0.6, reach * 0.42) + 1.0
	var n := Vector2(-d.y, d.x).normalized() if dist > 0.01 else Vector2.DOWN
	var away := mid - (p.head as Vector2)
	if n.dot(away) < 0.0:
		n = -n
	return mid + n * bulge


static func arm_pts(p: Dictionary, back: bool, n: int = 7) -> PackedVector2Array:
	var a := shoulder(p, back)
	var h: Vector2 = p.hb if back else p.hf
	return ToonCanvas.bezier(a, arm_ctrl(p, a, h, back), h, n)


## Noodle arm with an optional sleeve covering the first `sleeve_len` of it.
static func arm(cv: ToonCanvas, p: Dictionary, back: bool, fill: Color, sleeve: Color = Color(0, 0, 0, 0),
		sleeve_len: float = 0.0, w_mul: float = 1.0) -> void:
	var pts := arm_pts(p, back)
	var w := float(p.rig.arm_w) * w_mul
	var rs := PackedFloat32Array()
	for i in pts.size():
		rs.append(lerpf(w * 1.08, w * 0.88, float(i) / float(pts.size() - 1)))
	var z := arm_z(p, back)
	var col := ToonCanvas.shadow_of(fill, 0.12) if back else fill
	cv.tube(pts, rs, col, z, {"shade": 0.14})
	if sleeve.a > 0.0 and sleeve_len > 0.0:
		var m := maxi(2, roundi(sleeve_len * float(pts.size() - 1)) + 1)
		var sp := pts.slice(0, m)
		var srs := PackedFloat32Array()
		for i in sp.size():
			srs.append(rs[i] + 0.9 + (0.5 if i == sp.size() - 1 else 0.0))
		cv.tube(sp, srs, ToonCanvas.shadow_of(sleeve, 0.12) if back else sleeve, z + 0.5, {"shade": 0.14})


## Mitten hand. Faces along the forearm; `thumb` raises a thumbs-up.
static func hand(cv: ToonCanvas, p: Dictionary, back: bool, fill: Color, thumb: bool = false) -> void:
	var h: Vector2 = p.hb if back else p.hf
	var pts := arm_pts(p, back, 5)
	var dir := (pts[4] - pts[3]).normalized()
	var r := float(p.rig.hand_r)
	var z := (Z_HAND_BACK if p.hands == "club" else Z_ARM_BACK_FREE + 0.5) if back else Z_HAND_FRONT
	if not back and p.face_hand:
		z = Z_OVER_FACE
	var col := ToonCanvas.shadow_of(fill, 0.12) if back else fill
	cv.ellipse(h + dir * r * 0.15, Vector2(r * 1.08, r * 0.92), dir.angle(), col, z, {"shade": 0.15})
	if thumb:
		cv.capsule(h + Vector2(0.3, -r * 0.5), h + Vector2(0.6, -r * 1.75), r * 0.42, r * 0.36, col, z + 0.1, {"shade": 0.1})


static func arms_and_hands(cv: ToonCanvas, p: Dictionary, skin: Color, glove: Color, sleeve: Color = Color(0, 0, 0, 0), sleeve_len: float = 0.0) -> void:
	for back: bool in [true, false]:
		arm(cv, p, back, skin, sleeve, sleeve_len)
		hand(cv, p, back, glove, p.thumb and not back)


# ---------------------------------------------------------------------------
# Feet
# ---------------------------------------------------------------------------

const SHOE := [Vector2(-3.4, 0.0), Vector2(-3.9, -2.4), Vector2(-2.4, -4.3), Vector2(0.6, -4.6),
	Vector2(3.4, -3.9), Vector2(5.6, -2.4), Vector2(6.2, -0.6), Vector2(5.6, 0.0)]


## Rounded shoes under the body. `size` scales them; lifted feet tip their toes down.
## `which` picks feet (0 = back, 1 = front); `shape` overrides the shoe outline (sole at y = 0).
static func shoes(cv: ToonCanvas, p: Dictionary, fill: Color, sole: Color, size: float = 1.0, key: String = "shoe",
		which: Array = [0, 1], shape: Array = SHOE, sole_h: float = 1.3) -> void:
	var pts := PackedVector2Array()
	for v: Vector2 in shape:
		pts.append(v * size)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	for i: int in which:
		var at := foot_xf(p, i)
		var col := ToonCanvas.shadow_of(fill, 0.14) if i == 0 else fill
		cv.poly("%s_%.2f" % [key, size], pts, at, col, Z_FEET + i * 0.5, {"shade": 0.16})
		if sole_h > 0.0:
			var sole_pts := PackedVector2Array([Vector2(lo.x + 0.1, -sole_h * size), Vector2(hi.x - 0.2, -sole_h * size), Vector2(hi.x - 0.5, 0), Vector2(lo.x + 0.2, 0)])
			var sc := ToonCanvas.shadow_of(sole, 0.14) if i == 0 else sole
			cv.detail(Z_FEET + i * 0.5 + 0.1, func(c: ToonCanvas) -> void:
				c.push(at)
				c.fill_poly(sole_pts, sc)
				c.pop())


## Foot transform: at the foot's ground point, toes tipping down when lifted.
static func foot_xf(p: Dictionary, i: int) -> Transform2D:
	var f: Vector2 = p.feet[i]
	var lift := clampf(-(f.y - minf(0.0, (p.root as Vector2).y)) / 4.0, 0.0, 1.0)
	return Transform2D(lift * 0.35, f)


## Ear on the back half of a profile head.
static func ear(cv: ToonCanvas, p: Dictionary, skin: Color, x: float = -0.3, y: float = 0.06, s: float = 1.0) -> void:
	var r := float(p.head_r)
	var at := head_xf(p)
	cv.ellipse(at * Vector2(x * r, y * r), Vector2(0.17 * r, 0.22 * r) * s, float(p.head_rot), skin, Z_HEAD + 0.2, {"shade": 0.12})
	cv.detail(Z_HEAD + 0.25, func(c: ToonCanvas) -> void:
		c.push(at)
		c.arc(Vector2(x * r, y * r), 0.09 * r * s, -1.0, 2.0, skin.darkened(0.3), maxf(0.5, c.in_w * 0.7), 8)
		c.pop())


## Bumpy outline (beards, fur, plumes, clouds): each edge is split into bumps of about `step`
## units that bulge outward by `amp`.
static func scallop(pts: PackedVector2Array, amp: float, step: float) -> PackedVector2Array:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].x * pts[(i + 1) % n].y - pts[(i + 1) % n].x * pts[i].y
	var sgn := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		var len := d.length()
		if len < 0.001:
			continue
		var nrm := Vector2(d.y, -d.x).normalized() * -sgn
		var k := maxi(1, roundi(len / step))
		for j in k:
			var u0 := a + d * (float(j) / float(k))
			out.append(u0)
			for m: float in [0.25, 0.5, 0.75]:
				var u := a + d * ((float(j) + m) / float(k))
				out.append(u + nrm * amp * sin(m * PI))
	return out


## Head-space polygon (head radii) scaled to the head radius, optionally scalloped.
static func head_poly(arr: Array, r: float, amp: float = 0.0, step: float = 0.0) -> PackedVector2Array:
	var pts := _hpts(arr, r)
	if amp <= 0.0:
		return pts
	return clean(scallop(pts, amp * r, step * r))


## Removes self-touching spots (tight scallops) by keeping the largest outer ring of a hairline offset.
static func clean(pts: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		return pts
	var best := pts
	var best_a := -1.0
	for g: PackedVector2Array in Geometry2D.offset_polygon(pts, 0.02, Geometry2D.JOIN_ROUND):
		var a := 0.0
		for i in g.size():
			a += g[i].x * g[(i + 1) % g.size()].y - g[(i + 1) % g.size()].x * g[i].y
		if absf(a) > best_a:
			best_a = absf(a)
			best = g
	return best


# ---------------------------------------------------------------------------
# Club
# ---------------------------------------------------------------------------

## Iron head in its sole frame: hosel at the origin, blade forward along +x, sole at y = 4.6.
## Club heads are drawn this much larger than the shape tables (a bold, readable silhouette).
const HEAD_SCALE := 1.3
const IRON := [Vector2(-1.2, -1.6), Vector2(1.2, -1.4), Vector2(2.4, 0.7), Vector2(7.8, 0.4), Vector2(9.4, 1.0),
	Vector2(10.2, 2.6), Vector2(9.6, 4.3), Vector2(8.4, 4.8), Vector2(0.4, 4.8), Vector2(-1.6, 3.9), Vector2(-2.0, 1.4)]
const WOOD := [Vector2(-1.2, -1.6), Vector2(1.4, -1.2), Vector2(3.2, -0.4), Vector2(7.6, -0.6), Vector2(10.0, 0.6),
	Vector2(10.6, 2.8), Vector2(9.4, 4.6), Vector2(6.0, 5.2), Vector2(0.6, 5.0), Vector2(-1.6, 4.0), Vector2(-2.0, 1.4)]


static func club(cv: ToonCanvas, p: Dictionary, style: Dictionary = {}) -> void:
	if not p.club:
		return
	var st := CLUB_STYLE.duplicate()
	for k in style:
		st[k] = style[k]
	var z := Z_CLUB
	match str(p.club_mode):
		"planted":
			z = Z_CLUB_PLANTED
		"front", "back":
			z = Z_CLUB_HELD
	var grip: Vector2 = p.grip
	var dir: Vector2 = p.club_dir
	var hosel: Vector2 = p.hosel
	cv.capsule(grip, hosel, 1.0, 0.85, Color(str(st.shaft)), z, {"rim": false, "shade": 0.0})
	cv.capsule(grip, grip + dir * 6.5, 1.5, 1.35, Color(str(st.grip)), z + 0.1, {"rim": false, "shade": 0.0})
	# Head: sole frame rotated so the sole lies flat at address.
	var a: Vector2 = p.addr
	var addr_dir := Vector2(sin(a.x + a.y), cos(a.x + a.y))
	var at := Transform2D(dir.angle() - addr_dir.angle(), hosel)
	var kind := str(st.kind)
	var shape := PackedVector2Array()
	for v: Vector2 in (WOOD if kind == "wood" else IRON):
		shape.append(v * HEAD_SCALE)
	var head_col := Color(str(st.head))
	cv.poly("club_" + kind, shape, at, head_col, z + 0.2, {"shade": 0.22})
	cv.detail(z + 0.3, func(c: ToonCanvas) -> void:
		c.push(at.scaled_local(Vector2.ONE * HEAD_SCALE))
		var lw := maxf(0.5, c.in_w * 0.6) / HEAD_SCALE
		var g := head_col.darkened(0.3)
		if kind == "wood":
			c.ci.draw_circle(Vector2(6.4, 2.3), 1.1, Color(head_col.lightened(0.5), 0.9), true, -1.0, false)
		else:
			c.ci.draw_line(Vector2(3.0, 2.2), Vector2(8.6, 2.2), g, lw, false)
			c.ci.draw_line(Vector2(3.0, 3.5), Vector2(8.4, 3.5), g, lw, false)
		c.ci.draw_line(Vector2(2.4, 1.0), Vector2(8.0, 0.8), Color(1, 1, 1, 0.55), lw, false)
		c.pop())


## Motion smear behind the club head during the fast part of the swing.
static func _smear(cv: ToonCanvas, p: Dictionary) -> void:
	var at := float(p.smear)
	if at < Golfer.IMPACT * 0.6 or at > 0.17:
		return
	var fade := 1.0 - clampf((at - 0.07) / 0.1, 0.0, 1.0)
	var sh: Vector2 = p.shoulder
	var reach := float(p.rig.reach)
	var club_len := float(p.club_len)
	var top: Vector2 = p.swing_from
	var addr: Vector2 = p.addr
	var pts := PackedVector2Array()
	var widths := PackedFloat32Array()
	var n := 10
	for i in n:
		var s := maxf(Golfer.IMPACT * 0.75, at - 0.045 * (1.0 - float(i) / float(n - 1)))
		var c := _swing_ctrl(s, top, addr)
		var wrist := sh + Vector2(sin(c.x), cos(c.x)) * reach
		pts.append(wrist + Vector2(sin(c.x + c.y), cos(c.x + c.y)) * (club_len - 3.0))
		widths.append(lerpf(0.3, 5.5, pow(float(i) / float(n - 1), 0.7)))
	cv.detail(Z_SMEAR, func(c: ToonCanvas) -> void:
		var poly := PackedVector2Array()
		var back := PackedVector2Array()
		for i in pts.size():
			var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var nrm := Vector2(-d.y, d.x)
			poly.append(pts[i] + nrm * widths[i])
			back.append(pts[i] - nrm * widths[i])
		back.reverse()
		poly.append_array(back)
		c.fill_poly(poly, Color(1, 1, 1, 0.5 * fade)))


## Arm angle and hinge during the swing (mirrors Golfer._controls "swing").
static func _swing_ctrl(s: float, top: Vector2, addr: Vector2) -> Vector2:
	if s < Golfer.IMPACT:
		var k := pow(s / Golfer.IMPACT, 2.0)
		return Vector2(lerpf(top.x, addr.x, k), lerpf(top.y, addr.y, k))
	var k2 := clampf((s - Golfer.IMPACT) / 0.26, 0.0, 1.0)
	var e2 := 1.0 - pow(1.0 - k2, 3.0)
	return Vector2(lerpf(addr.x, 2.55, e2), lerpf(addr.y, 1.35, e2))


# ---------------------------------------------------------------------------
# Heads and faces
# ---------------------------------------------------------------------------

static func head_xf(p: Dictionary) -> Transform2D:
	return Transform2D(float(p.head_rot), p.head)


## Head-local point in head radii (x forward, y down) -> rig space.
static func hp(p: Dictionary, x: float, y: float) -> Vector2:
	var r := float(p.head_r)
	return (p.head as Vector2) + Vector2(x * r, y * r).rotated(float(p.head_rot))


## Maps an animation expression onto a character's resting eyes/mouth.
static func expression(p: Dictionary, eyes: String, mouth: String) -> Array:
	var ex: Dictionary = p.expr
	if ex.has("eyes") and eyes not in ["shades", "visor"]:
		eyes = {"joy": "happy", "wide": "big", "fierce": "angry", "focus": "angry"}.get(ex.eyes, ex.eyes)
	if ex.has("mouth") and mouth != "none":
		mouth = str(ex.mouth)
	if p.blink and eyes in ["dot", "oval", "big", "angry", "sad"]:
		eyes = "closed"
	return [eyes, mouth]


## Cartoon face drawn in head space. Style keys (all optional):
##   x (0.36)      face centre, forward offset in head radii
##   y (0.0)       vertical offset
##   eyes ("oval") resting eye style; mouth ("smile") resting mouth
##   col           line/eye colour (dark ink)
##   size (1.0)    eye size multiplier; spacing (0.46)
##   brows         brow colour (omit for none)
##   nose          "" | "button" | "long"; skin (nose colour)
##   cheeks        blush; glint (true) eye highlights
static func face(cv: ToonCanvas, p: Dictionary, style: Dictionary, z: float = Z_FACE) -> void:
	var em := expression(p, str(style.get("eyes", "oval")), str(style.get("mouth", "smile")))
	var eyes: String = em[0]
	var mouth: String = em[1]
	var r := float(p.head_r)
	var col: Color = style.get("col", DARK)
	var cx := float(style.get("x", 0.36))
	var cy := float(style.get("y", 0.0))
	var size := float(style.get("size", 1.0))
	var sp := float(style.get("spacing", 0.46))
	var brows: Variant = style.get("brows", null)
	var nose := str(style.get("nose", ""))
	var skin: Color = style.get("skin", Color.WHITE)
	var cheeks := bool(style.get("cheeks", false))
	var glint := bool(style.get("glint", true))
	var tilt_brow := {"angry": -0.13, "sad": 0.14, "big": 0.0}.get(eyes, 0.0) as float
	var at := head_xf(p)
	cv.detail(z, func(c: ToonCanvas) -> void:
		c.push(at)
		var lw := maxf(0.75, c.in_w * 0.95)
		var e1 := Vector2((cx - sp * 0.5) * r, (cy - 0.1) * r)
		var e2 := Vector2((cx + sp * 0.5) * r, (cy - 0.12) * r)
		var er := r * 0.115 * size
		if cheeks:
			c.fill_ellipse(Vector2((cx + 0.32) * r, (cy + 0.22) * r), Vector2(r * 0.17, r * 0.1), 0.0, Color(1.0, 0.42, 0.5, 0.35))
		for i in 2:
			var e: Vector2 = e1 if i == 0 else e2
			var s := 0.88 if i == 0 else 1.0     # far eye slightly smaller
			_eye(c, eyes, e, er * s, col, lw, glint, i)
			if brows != null:
				var inner := 1.0 if i == 0 else -1.0
				var by := e.y - er * 2.1 - (er * 0.4 if eyes == "big" else 0.0)
				var tw := er * 1.15
				c.line(Vector2(e.x - tw, by + tilt_brow * r * inner), Vector2(e.x + tw, by - tilt_brow * r * inner), brows, lw * 1.25)
		if nose == "button":
			c.fill_ellipse(Vector2((cx + sp * 0.5 + 0.2) * r, (cy + 0.1) * r), Vector2(r * 0.11, r * 0.09), 0.0, skin.darkened(0.12))
		elif nose == "long":
			var n0 := Vector2((cx + sp * 0.5 + 0.08) * r, (cy - 0.02) * r)
			var npts := PackedVector2Array([n0, n0 + Vector2(r * 0.3, r * 0.18), n0 + Vector2(r * 0.22, r * 0.26), n0 + Vector2(0, r * 0.22)])
			c.fill_poly(npts, skin.darkened(0.08))
			c.polyline(PackedVector2Array([n0, n0 + Vector2(r * 0.3, r * 0.18), n0 + Vector2(r * 0.22, r * 0.26), n0 + Vector2(0, r * 0.22)]), col, lw * 0.8)
		_mouth(c, mouth, Vector2((cx + 0.12) * r, (cy + 0.38) * r), r, col, lw)
		c.pop())


static func _eye(c: ToonCanvas, kind: String, e: Vector2, er: float, col: Color, lw: float, glint: bool, idx: int) -> void:
	match kind:
		"closed":
			c.arc(e + Vector2(0, -er * 0.3), er * 1.05, 0.35, PI - 0.35, col, lw)
		"happy":
			c.arc(e + Vector2(0, er * 0.6), er * 1.1, PI + 0.35, TAU - 0.35, col, lw * 1.1)
		"sleepy":
			c.arc(e + Vector2(0, -er * 0.2), er * 1.05, 0.2, PI - 0.2, col, lw)
			c.line(e + Vector2(-er, -er * 0.2), e + Vector2(er, -er * 0.2), col, lw * 0.8)
		"wink":
			if idx == 0:
				c.fill_ellipse(e, Vector2(er * 0.85, er * 1.25), 0.0, col)
				if glint:
					c.dot(e + Vector2(er * 0.3, -er * 0.45), er * 0.36, Color.WHITE)
			else:
				c.arc(e + Vector2(0, er * 0.6), er * 1.1, PI + 0.35, TAU - 0.35, col, lw * 1.1)
		"big":
			c.fill_ellipse(e, Vector2(er * 1.55, er * 1.8), 0.0, col)
			c.fill_ellipse(e, Vector2(er * 1.55 - lw * 0.8, er * 1.8 - lw * 0.8), 0.0, Color.WHITE)
			c.fill_ellipse(e + Vector2(er * 0.35, er * 0.15), Vector2(er * 0.75, er * 0.95), 0.0, col)
			c.dot(e + Vector2(er * 0.55, -er * 0.25), er * 0.3, Color.WHITE)
		"dot":
			c.dot(e, er * 0.95, col)
		"angry":
			c.fill_ellipse(e + Vector2(0, er * 0.2), Vector2(er * 0.85, er * 1.0), 0.0, col)
			c.line(e + Vector2(-er * 1.2, -er * (1.5 if idx == 0 else 0.6)), e + Vector2(er * 1.2, -er * (0.6 if idx == 0 else 1.5)), col, lw * 1.2)
		"sad":
			c.fill_ellipse(e + Vector2(0, er * 0.2), Vector2(er * 0.8, er * 1.0), 0.0, col)
			if glint:
				c.dot(e + Vector2(er * 0.25, -er * 0.2), er * 0.32, Color.WHITE)
		"shades":
			if idx == 1:
				var a := e + Vector2(-er * 4.6, -er * 0.4)
				c.line(a, e + Vector2(er * 1.6, -er * 0.4), Color("11121c"), lw * 1.2)
			c.fill_poly(_lens(e, er), Color("11121c"))
			c.line(e + Vector2(-er * 0.7, -er * 0.3), e + Vector2(-er * 0.1, er * 0.35), Color(1, 1, 1, 0.6), lw * 0.8)
		"visor":
			if idx == 1:
				var v := PackedVector2Array([e + Vector2(-er * 5.0, -er * 1.3), e + Vector2(er * 2.2, -er * 1.5), e + Vector2(er * 2.0, er * 1.3), e + Vector2(-er * 4.8, er * 1.2)])
				c.fill_poly(v, Color("11121c"))
				c.line(e + Vector2(-er * 4.2, 0), e + Vector2(er * 1.4, -er * 0.1), Color("4cc9f0"), lw * 1.3)
		_:   # "oval"
			c.fill_ellipse(e, Vector2(er * 0.82, er * 1.22), 0.0, col)
			if glint:
				c.dot(e + Vector2(er * 0.28, -er * 0.45), er * 0.34, Color.WHITE)


static func _lens(e: Vector2, er: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := PI * float(i) / 11.0
		pts.append(e + Vector2(cos(a) * er * 1.7, -er * 0.55 + sin(a) * er * 1.45))
	return pts


static func _mouth(c: ToonCanvas, kind: String, m: Vector2, r: float, col: Color, lw: float) -> void:
	match kind:
		"smile":
			c.arc(m + Vector2(0, -r * 0.12), r * 0.2, 0.45, PI - 0.45, col, lw)
		"grin":
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(0.0, PI, float(i) / 12.0)
				pts.append(m + Vector2(cos(a) * r * 0.25, -r * 0.07 + sin(a) * r * 0.19))
			c.fill_poly(pts, col)
			c.fill_poly(PackedVector2Array([pts[0] + Vector2(-lw * 0.3, lw * 0.5), pts[12] + Vector2(lw * 0.3, lw * 0.5),
				pts[11] + Vector2(0, -lw * 0.1), pts[1] + Vector2(0, -lw * 0.1)]), Color.WHITE)
		"open", "laugh":
			var big := 1.3 if kind == "laugh" else 1.0
			var pts2 := PackedVector2Array()
			for i in 15:
				var a := lerpf(0.0, PI, float(i) / 14.0)
				pts2.append(m + Vector2(cos(a) * r * 0.2 * big, -r * 0.07 + sin(a) * r * 0.25 * big))
			c.fill_poly(pts2, col)
			c.fill_ellipse(m + Vector2(0, r * 0.11 * big), Vector2(r * 0.12 * big, r * 0.065 * big), 0.0, TONGUE)
		"o":
			c.fill_ellipse(m + Vector2(0, -r * 0.01), Vector2(r * 0.09, r * 0.13), 0.0, col)
		"frown":
			c.arc(m + Vector2(0, r * 0.13), r * 0.17, PI + 0.5, TAU - 0.5, col, lw)
		"flat":
			c.line(m + Vector2(-r * 0.13, 0), m + Vector2(r * 0.13, 0), col, lw)
		"smirk":
			c.arc(m + Vector2(r * 0.04, -r * 0.14), r * 0.18, 0.4, PI * 0.55, col, lw)
		"tongue":
			c.arc(m + Vector2(0, -r * 0.12), r * 0.2, 0.45, PI - 0.45, col, lw)
			c.fill_ellipse(m + Vector2(r * 0.05, r * 0.1), Vector2(r * 0.08, r * 0.1), 0.0, TONGUE)
			c.line(m + Vector2(r * 0.05, r * 0.06), m + Vector2(r * 0.05, r * 0.14), TONGUE.darkened(0.3), lw * 0.6)
		_:
			pass


# ---------------------------------------------------------------------------
# Head shapes (classic) — head-local polygons in head radii, cached per radius.
# ---------------------------------------------------------------------------

static func head_shape(kind: String, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * float(i) / float(n)
		var v := Vector2(cos(a), sin(a))
		var rr := Vector2(r, r)
		match kind:
			"oval":
				rr = Vector2(r * 0.88, r * 1.1)
			"square":
				var e := 4.0
				v = Vector2(signf(v.x) * pow(absf(v.x), 2.0 / e), signf(v.y) * pow(absf(v.y), 2.0 / e))
				rr = Vector2(r * 0.97, r * 0.95)
			"bean":
				rr = Vector2(r * (1.0 + 0.1 * maxf(0.0, v.y)), r * 1.02)
		pts.append(v * rr)
	return pts


# ---------------------------------------------------------------------------
# Classic hats — head-local, coordinates in head radii (x forward, y down).
# ---------------------------------------------------------------------------

static func _hpts(arr: Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in arr:
		out.append(v * r)
	return out


static func _dome(r: float, rx: float, ry: float, cy: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := PI + PI * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry + cy) * r)
	return pts


static func hat(cv: ToonCanvas, p: Dictionary, kind: String, col: Color) -> void:
	var r := float(p.head_r)
	var at := head_xf(p)
	var dark := col.darkened(0.28)
	var key := "hat_%s_%.2f" % [kind, r]
	var t := float(p.t)
	var sway := float(p.sway)
	match kind:
		"cap":
			cv.poly(key, _dome(r, 1.04, 0.98, -0.1), at, col, Z_HAT, {"shade": 0.18})
			cv.poly(key + "b", _hpts([Vector2(0.55, -0.22), Vector2(1.72, -0.2), Vector2(1.78, -0.02), Vector2(0.5, 0.02)], r), at, dark, Z_HAT + 0.2, {"shade": 0.0})
			cv.circle(at * Vector2(0.0, -1.06 * r), r * 0.12, dark, Z_HAT + 0.3, {"shade": 0.0, "rim": false})
			cv.detail(Z_HAT + 0.4, func(c: ToonCanvas) -> void:
				c.push(at)
				c.arc(Vector2(0, -0.1 * r), r * 0.98, PI * 1.25, PI * 1.62, Color(1, 1, 1, 0.35), maxf(0.6, c.in_w))
				c.pop())
		"beanie":
			cv.poly(key, _dome(r, 1.06, 1.08, -0.18), at, col, Z_HAT, {"shade": 0.18})
			cv.poly(key + "b", _hpts([Vector2(-1.12, -0.42), Vector2(1.12, -0.42), Vector2(1.12, -0.04), Vector2(-1.12, -0.04)], r), at, dark, Z_HAT + 0.2, {"shade": 0.1})
			cv.circle(at * Vector2(sway * 0.15 * r, -1.38 * r), r * 0.3, Color.WHITE.lerp(col, 0.12), Z_HAT + 0.3, {"shade": 0.15})
			cv.detail(Z_HAT + 0.25, func(c: ToonCanvas) -> void:
				c.push(at)
				for i in 6:
					var x := lerpf(-0.85, 0.85, float(i) / 5.0) * r
					c.ci.draw_line(Vector2(x, -0.38 * r), Vector2(x, -0.08 * r), dark.darkened(0.3), maxf(0.5, c.in_w * 0.7), false)
				c.pop())
		"tophat":
			cv.poly(key, _hpts([Vector2(-0.72, -0.5), Vector2(0.72, -0.5), Vector2(0.66, -2.0), Vector2(-0.66, -2.0)], r), at, col, Z_HAT, {"shade": 0.2})
			cv.poly(key + "b", _hpts([Vector2(-1.25, -0.42), Vector2(1.25, -0.42), Vector2(1.2, -0.66), Vector2(-1.2, -0.66)], r), at, dark, Z_HAT + 0.2, {"shade": 0.0})
			var band := Color("e63946") if col.get_luminance() < 0.5 else Color("1b2040")
			cv.poly(key + "s", _hpts([Vector2(-0.71, -0.66), Vector2(0.71, -0.66), Vector2(0.7, -0.95), Vector2(-0.7, -0.95)], r), at, band, Z_HAT + 0.3, {"shade": 0.0})
		"cowboy":
			var brim := PackedVector2Array()
			for i in 17:
				var x := lerpf(-1.8, 1.8, float(i) / 16.0)
				brim.append(Vector2(x, -0.4 - 0.16 * x * x + 0.2) * r)
			for i in 17:
				var x := lerpf(1.8, -1.8, float(i) / 16.0)
				brim.append(Vector2(x, -0.4 - 0.16 * x * x + 0.02) * r)
			cv.poly(key + "b", brim, at, dark, Z_HAT, {"shade": 0.1})
			cv.poly(key, _hpts([Vector2(-0.78, -0.45), Vector2(0.78, -0.45), Vector2(0.7, -1.5), Vector2(0.2, -1.32), Vector2(-0.2, -1.32), Vector2(-0.7, -1.5)], r), at, col, Z_HAT + 0.2, {"shade": 0.2})
			cv.poly(key + "s", _hpts([Vector2(-0.77, -0.5), Vector2(0.77, -0.5), Vector2(0.75, -0.72), Vector2(-0.75, -0.72)], r), at, Color("ffd166"), Z_HAT + 0.3, {"shade": 0.0, "rim": false})
		"crown":
			var base := -0.6
			cv.poly(key, _hpts([Vector2(-0.82, base), Vector2(0.82, base), Vector2(0.92, base - 0.95), Vector2(0.46, base - 0.5),
				Vector2(0.0, base - 1.08), Vector2(-0.46, base - 0.5), Vector2(-0.92, base - 0.95)], r), at, col, Z_HAT, {"shade": 0.2})
			for g in [[Vector2(0, base - 0.28), Color("e63946"), 0.14], [Vector2(0.5, base - 0.26), Color("4cc9f0"), 0.1], [Vector2(-0.5, base - 0.26), Color("06d6a0"), 0.1]]:
				cv.circle(at * ((g[0] as Vector2) * r), float(g[2]) * r, g[1], Z_HAT + 0.3, {"shade": 0.0})
			var gl := absf(sin(t * 2.0))
			cv.detail(Z_HAT + 0.5, func(c: ToonCanvas) -> void:
				c.push(at)
				c.dot(Vector2(0.92 * r, (base - 0.95) * r), 1.0 + gl * 1.3, Color(1, 1, 1, 0.85 * gl))
				c.pop())
		"headband":
			cv.poly(key, _hpts([Vector2(-1.04, -0.55), Vector2(1.04, -0.55), Vector2(1.02, -0.24), Vector2(-1.02, -0.24)], r), at, col, Z_HAT, {"shade": 0.1})
			var flap := sin(t * 8.0) * 0.12 + sway * 0.2
			for k in 2:
				var a0 := Vector2(-1.0, -0.4) * r
				var a1 := Vector2(-1.7, -0.3 + (0.25 + flap) * (1.0 if k == 0 else -1.2)) * r
				cv.capsule(at * a0, at * a1, r * 0.13, r * 0.09, col, Z_HAT - 5.0 - k, {"shade": 0.1})
		"wizard":
			var bend := sin(t * 1.5) * 0.08 + sway * 0.25
			var tip := (Vector2(-0.7, -2.6)).rotated(bend)
			cv.poly(key + "%.2f" % snappedf(bend, 0.04), _hpts([Vector2(-0.95, -0.45), Vector2(0.95, -0.45), Vector2(0.32, -1.5), tip, Vector2(-0.36, -1.3)], r), at, col, Z_HAT, {"shade": 0.2})
			cv.poly(key + "b", _hpts([Vector2(-1.45, -0.3), Vector2(1.45, -0.3), Vector2(1.4, -0.56), Vector2(-1.4, -0.56)], r), at, dark, Z_HAT + 0.2, {"shade": 0.0})
			cv.detail(Z_HAT + 0.4, func(c: ToonCanvas) -> void:
				c.push(at)
				_star(c, Vector2(0.05, -1.05) * r, r * 0.22, Color("ffd166"))
				_star(c, Vector2(-0.4, -1.65) * r, r * 0.13, Color.WHITE)
				c.pop())
		"bucket":
			cv.poly(key, _hpts([Vector2(-1.0, -0.3), Vector2(1.0, -0.3), Vector2(0.74, -1.28), Vector2(-0.74, -1.28)], r), at, col, Z_HAT, {"shade": 0.2})
			cv.poly(key + "b", _hpts([Vector2(-1.0, -0.36), Vector2(1.0, -0.36), Vector2(1.5, 0.02), Vector2(-1.5, 0.02)], r), at, dark, Z_HAT + 0.2, {"shade": 0.0})
		"halo":
			var hy := -1.35 + sin(t * 2.4) * 0.06
			cv.detail(Z_HAT, func(c: ToonCanvas) -> void:
				c.push(at)
				var ring := ToonCanvas.ellipse_pts(Vector2(0, hy * r), Vector2(r * 0.95, r * 0.28), 0.0, 30)
				ring.append(ring[0])
				c.ci.draw_polyline(ring, c.ink, c.in_w * 2.0 + r * 0.16, false)
				c.ci.draw_polyline(ring, col, r * 0.16, false)
				c.ci.draw_polyline(ring, Color(col.lightened(0.5), 0.6), r * 0.05, false)
				c.pop())


static func _star(c: ToonCanvas, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * float(i) / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.fill_poly(pts, col)
