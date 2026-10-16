class_name InkBody
extends RefCounted
## Draws the ink golfer's body from a solved InkRig sample (docs/INK_ART_SPEC.md §4–6):
## limbs, pants, tops, shoes, gloves, club and back accessories. The head and everything worn on
## it is InkHead. `st` carries per-frame state from the Golfer node:
##   lw: body line width (rig units), t: clock, cuff: [Vector2, Vector2] cuff lag offsets,
##   cuff_v: [float, float] cuff speeds, cape: PackedVector2Array chain, scarf: PackedVector2Array,
##   trail: PackedVector2Array of recent club-head positions (swing smear), seed: per-golfer seed,
##   show_club: bool, drawings: bool (render player drawings)

const INK := InkCanvas.INK

const SLEEVES := {"tee": 0.5, "polo": 0.45, "jersey": 0.55, "hoodie": 1.0, "jacket": 1.0, "sweater": 1.0, "coat": 1.0, "robe": 1.0}
## Torso tube half-widths (neck, chest, waist) and how far below the hip the top reaches (rig units).
const TOP_SHAPES := {
	"tee": [2.4, 4.3, 4.1, 2.6], "polo": [2.6, 4.3, 4.1, 2.6], "tank": [1.8, 3.8, 3.9, 2.2], "hoodie": [2.8, 5.0, 4.8, 3.4],
	"jacket": [2.8, 4.9, 4.7, 4.0], "sweater": [2.6, 4.8, 4.6, 3.4], "vest": [2.0, 4.4, 4.3, 3.0], "coat": [2.9, 5.0, 5.6, 15.0],
	"robe": [2.8, 5.0, 6.6, 22.0], "jersey": [2.6, 4.6, 4.4, 3.2],
}


static func draw(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary) -> void:
	var lw := float(st.lw)
	# Joints.
	var hip: Vector2 = s.hip
	var hip_b := hip + Vector2(-InkRig.HIP_SPREAD, 0.3)
	var hip_f := hip + Vector2(InkRig.HIP_SPREAD, -0.3)
	var ank_b: Vector2 = (s.fb as Vector2) + Vector2(0, -2.2)
	var ank_f: Vector2 = (s.ff as Vector2) + Vector2(0, -2.2)
	var knee_b := _knee(hip_b, ank_b)
	var knee_f := _knee(hip_f, ank_f)
	var sh: Vector2 = s.shoulder
	var elb_b := _elbow(sh, s.hb, -1.0, float(s.elbow_up))
	var elb_f := _elbow(sh, s.hf, 1.0, float(s.elbow_up))
	var club_mode := str(s.club)
	var show_club: bool = st.get("show_club", true) and club_mode != "none"
	var arm := float(s.get("arm", 0.0))
	var club_behind: bool = bool(s.grip_mode) and (arm > 1.95 or arm < -1.7)
	if club_mode == "planted" or club_mode == "shoulder":
		club_behind = true
	var top := str(look.top)
	var sleeve := float(SLEEVES.get(top, 0.0))

	_back_accessory(cv, s, look, st, true)
	if show_club and club_behind:
		draw_club(cv, s, look, st)
	# Back arm.
	_arm(cv, sh, elb_b, s.hb, lw, look, sleeve, true)
	_glove(cv, s.hb, elb_b, look, lw, true)
	# Back leg.
	var shape := InkLook.cut_shape(look)
	var c_back := Color(str(look.pantsColor2 if str(look.pantsPattern) == "split" else look.pantsColor))
	_leg(cv, hip_b, knee_b, ank_b, lw)
	_shoe(cv, s.fb, float(s.tb), look, lw, true)
	var waist := hip + InkRig.up_of(float(s.lean)) * (1.4 + float(look.pantsWaist))
	_pant_leg(cv, waist, hip_b, knee_b, ank_b, shape, look, c_back.darkened(0.17), st, 0, lw, s)
	# Front leg.
	_leg(cv, hip_f, knee_f, ank_f, lw)
	_shoe(cv, s.ff, float(s.tf), look, lw, false)
	_pant_leg(cv, waist, hip_f, knee_f, ank_f, shape, look, Color(str(look.pantsColor)), st, 1, lw, s)
	# Torso.
	var spine := InkCanvas.quad_bez(s.neck, s.ctrl, hip, 10)
	cv.stroke(spine, lw, INK, 0.08, 0.1, float(st.seed) + 1.0, 0.1, 0.0, 0.7)
	if top != "none":
		_top(cv, s, look, st, lw)
	_neck_accessory(cv, s, look, st)
	_back_accessory(cv, s, look, st, false)
	if show_club and not club_behind:
		draw_club(cv, s, look, st)
	# Front arm over everything on the body.
	_arm(cv, sh, elb_f, s.hf, lw, look, sleeve, false)
	_glove(cv, s.hf, elb_f, look, lw, false)
	if float(s.thumb) > 0.5:
		var d := ((s.hf as Vector2) - elb_f).normalized()
		cv.stroke(PackedVector2Array([s.hf, (s.hf as Vector2) + d * 1.2 + Vector2(0, -3.6)]), lw * 0.9, INK, 0.1, 0.4)


static func _knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var a := InkRig.ik(hip, ankle, InkRig.THIGH, InkRig.SHIN, 1.0)
	var b := InkRig.ik(hip, ankle, InkRig.THIGH, InkRig.SHIN, -1.0)
	return a if a.x > b.x else b


static func _elbow(sh: Vector2, hand: Vector2, side: float, up: float) -> Vector2:
	var a := InkRig.ik(sh, hand, InkRig.UPPER, InkRig.FORE, 1.0)
	var b := InkRig.ik(sh, hand, InkRig.UPPER, InkRig.FORE, -1.0)
	if up > 0.5:
		return a if a.x * side > b.x * side else b
	return a if a.y > b.y else b


static func _leg(cv: InkCanvas, hip: Vector2, knee: Vector2, ankle: Vector2, lw: float) -> void:
	var line := InkCanvas.spline(PackedVector2Array([hip, knee, ankle]), 5)
	cv.stroke(line, lw * 0.95, INK, 0.05, 0.08, hip.x, 0.08, 0.0, 0.8)


static func _arm(cv: InkCanvas, sh: Vector2, elb: Vector2, hand: Vector2, lw: float, look: Dictionary, sleeve: float, back: bool) -> void:
	var line := InkCanvas.spline(PackedVector2Array([sh, elb, hand]), 5)
	cv.stroke(line, lw * 0.92, INK, 0.05, 0.3, 3.0 if back else 4.0, 0.1, 0.0, 0.5)
	if sleeve <= 0.0:
		return
	# Sleeve: a tube over the arm from the shoulder, sleeve fraction of the whole arm length.
	var robe := str(look.top) == "robe"
	var path := InkCanvas.resample(line, 1.4)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	var end_len := total * sleeve * (0.9 if sleeve >= 1.0 else 1.0)
	var side_a := PackedVector2Array()
	var side_b := PackedVector2Array()
	var acc := 0.0
	for i in path.size():
		if i > 0:
			acc += path[i].distance_to(path[i - 1])
		if acc > end_len:
			break
		var u := acc / maxf(end_len, 0.01)
		var d := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-d.y, d.x)
		var w := lerpf(2.5, 2.0, u) if not robe else lerpf(2.4, 4.6, u * u)
		side_a.append(path[i] + n * w)
		side_b.append(path[i] - n * w)
	if side_a.size() < 2:
		return
	side_b.reverse()
	var poly := side_a + side_b
	var col := Color(str(look.topColor))
	if back:
		col = col.darkened(0.17)
	cv.fill(poly, col)
	cv.outline(poly, lw * 0.7, INK, 7.0)
	if str(look.top) == "sweater" and sleeve >= 1.0:
		var e := side_a.size() - 1
		cv.stroke(PackedVector2Array([side_a[e].lerp(side_b[0], 0.0), side_b[0]]), lw * 0.5, Color(INK, 0.6))


static func _glove(cv: InkCanvas, hand: Vector2, elb: Vector2, look: Dictionary, lw: float, back: bool) -> void:
	var g := str(look.gloves)
	if g == "":
		return
	var col := Color(str(look.glovesColor))
	if back:
		col = col.darkened(0.15)
	var d := (hand - elb).normalized()
	match g:
		"golf":
			cv.ellipse(hand + d * 0.6, Vector2(2.0, 1.7), col, d.angle())
			cv.ink_circle(hand + d * 0.6, Vector2(2.0, 1.7), lw * 0.55, INK, hand.x, d.angle(), 0.1, 0.0)
		"mitten":
			cv.ellipse(hand + d * 0.8, Vector2(2.7, 2.3), col, d.angle())
			cv.ink_circle(hand + d * 0.8, Vector2(2.7, 2.3), lw * 0.6, INK, hand.y, d.angle(), 0.1, 0.0)
			cv.stroke(PackedVector2Array([hand - d * 1.8 + Vector2(-d.y, d.x) * 2.4, hand - d * 1.8 - Vector2(-d.y, d.x) * 2.4]), lw * 1.4, col.darkened(0.2), 0.0, 0.0)
		"wristband":
			var a := hand - d * 2.6
			cv.stroke(PackedVector2Array([a - d * 1.0, a + d * 1.0]), lw * 2.4, col, 0.0, 0.0)


static func _shoe(cv: InkCanvas, foot: Vector2, toe: float, look: Dictionary, lw: float, back: bool) -> void:
	var style := str(look.shoes)
	var col := Color(str(look.shoesColor))
	if back:
		col = col.darkened(0.2)
	var rot := Transform2D(toe * 0.55, foot)
	var poly: PackedVector2Array
	match style:
		"boot":
			poly = PackedVector2Array([Vector2(-2.6, -5.2), Vector2(1.4, -5.2), Vector2(1.8, -2.2), Vector2(5.4, -1.6), Vector2(6.0, 0.2), Vector2(-2.8, 0.4)])
		"loafer":
			poly = PackedVector2Array([Vector2(-2.6, -2.2), Vector2(2.0, -2.0), Vector2(5.6, -0.6), Vector2(5.8, 0.3), Vector2(-2.8, 0.3)])
		_:
			poly = PackedVector2Array([Vector2(-2.6, -2.6), Vector2(1.2, -2.8), Vector2(5.2, -1.2), Vector2(5.9, 0.3), Vector2(-2.9, 0.4)])
	var world := rot * poly
	if style == "classic":
		cv.fill(world, INK if not back else INK.lightened(0.08))
		cv.outline(world, lw * 0.45, INK, foot.x)
		return
	cv.fill(world, col)
	if style == "sneaker" or style == "spike":
		cv.stroke(PackedVector2Array([rot * Vector2(-2.7, -0.5), rot * Vector2(5.6, -0.4)]), lw * 0.75, Color("fbf6ec") if col.get_luminance() < 0.7 else Color("c9c1b3"), 0.05, 0.05)
	if style == "spike":
		for x: float in [-1.5, 1.2, 3.8]:
			cv.dot(rot * Vector2(x, 1.0), 0.7, INK)
	cv.outline(world, lw * 0.6, INK, foot.y)


## One pant leg: a tube from the waist through hip, knee and ankle (u = 0 at the waist, 1 at the
## cuff; v = -1..1 across). Patterns and drawings are drawn in (u, v) so they follow the cloth.
static func _pant_leg(cv: InkCanvas, waist: Vector2, hip: Vector2, knee: Vector2, ankle: Vector2, shape: Dictionary,
		look: Dictionary, col: Color, st: Dictionary, leg: int, lw: float, s: Dictionary) -> void:
	# Cloth hangs over the knee rather than tracing it: soften the bend.
	var drape := knee.lerp((hip + ankle) * 0.5, 0.55)
	var spine := InkCanvas.spline(PackedVector2Array([waist, hip, drape, ankle]), 6)
	var acc := PackedFloat32Array([0.0])
	for i in range(1, spine.size()):
		acc.append(acc[i - 1] + spine[i].distance_to(spine[i - 1]))
	var leg_len := acc[acc.size() - 1]
	var waist_len := waist.distance_to(hip)
	var full := float(shape.len) >= 0.99
	var length := waist_len + (leg_len - waist_len) * float(shape.len) - (1.6 if full else 0.0)
	var cuff_off: Vector2 = (st.cuff as Array)[leg]
	var speed := float((st.cuff_v as Array)[leg])
	var t := float(st.t)
	var flutter := clampf(speed * 0.004, 0.0, 1.0)
	var waist_w := float(shape.waist)
	var cuff_w := float(shape.cuff) * (1.0 + flutter * 0.22)
	var power := float(shape.pow)
	var bag := float(shape.bag)
	var cuff_style := str(look.pantsCuff)
	var seed_v := float(st.seed) + float(leg) * 3.1
	const N := 15
	var cs := PackedVector2Array()
	var ns := PackedVector2Array()
	var ws := PackedFloat32Array()
	cs.resize(N + 1)
	ns.resize(N + 1)
	ws.resize(N + 1)
	var j := 0
	for k in N + 1:
		var u := float(k) / float(N)
		var dist := u * length
		while j < acc.size() - 2 and acc[j + 1] < dist:
			j += 1
		var seg := maxf(acc[j + 1] - acc[j], 0.0001)
		var f := clampf((dist - acc[j]) / seg, 0.0, 1.0)
		var c := spine[j].lerp(spine[j + 1], f)
		var d := (spine[j + 1] - spine[j]).normalized()
		# Lag and billow: the lower leg trails the motion, the hem ripples with speed.
		var lag := pow(u, 2.2)
		var billow := sin(t * 11.0 + u * 4.0 + seed_v) * (0.25 + flutter * 2.2) * u * u
		var n := Vector2(-d.y, d.x)
		c += cuff_off * lag + n * billow
		var w := lerpf(waist_w, cuff_w, pow(u, power)) + bag * sin(PI * u) * (1.0 - u * 0.25)
		if cuff_style == "narrow" and u > 0.86:
			w = lerpf(w, minf(w, 3.2), smoothstep(0.86, 1.0, u))
		cs[k] = c
		ns[k] = n
		ws[k] = w
	# Normals: smooth them so the tube does not kink at the knee.
	for k in range(1, N):
		ns[k] = (ns[k - 1] + ns[k] * 2.0 + ns[k + 1]).normalized()
	var mapper := func(u: float, v: float) -> Vector2:
		var x := clampf(u, 0.0, 1.0) * N
		var i0 := mini(int(x), N - 1)
		var fr := x - i0
		var c := cs[i0].lerp(cs[i0 + 1], fr)
		var n := ns[i0].lerp(ns[i0 + 1], fr).normalized()
		return c + n * lerpf(ws[i0], ws[i0 + 1], fr) * v
	# Outline polygon: one side down, wavy hem, other side up.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in N + 1:
		left.append(cs[k] + ns[k] * ws[k])
		right.append(cs[k] - ns[k] * ws[k])
	var hem := PackedVector2Array()
	var hd := (cs[N] - cs[N - 1]).normalized()
	var hem_steps := 8
	for k in range(1, hem_steps):
		var v := 1.0 - 2.0 * float(k) / float(hem_steps)
		var p: Vector2 = mapper.call(1.0, v)
		var wave := sin(float(k) * 1.9 + t * 9.0 + seed_v) * (0.3 + flutter * 1.6)
		if cuff_style == "frayed":
			wave += 1.4 if k % 2 == 0 else -0.4
		p += hd * (wave + (1.0 - v * v) * ws[N] * 0.12)
		hem.append(p)
	right.reverse()
	var poly := left + hem + right
	cv.fill(poly, col)
	_pattern(cv, mapper, look, col, leg, lw, ws)
	if bool(st.get("drawings", true)):
		var dr: Dictionary = (look.drawings as Dictionary).get("pants", {})
		if not dr.is_empty() and (leg == 1 or str(dr.get("legs", "both")) == "both"):
			var avg := (ws[0] + ws[N / 2] + ws[N]) / 3.0
			InkDrawing.draw(cv, dr, mapper, avg / 5.0, 0.17 if leg == 0 else 0.0)
	if cuff_style == "rolled":
		var band := PackedVector2Array()
		for k in 5:
			band.append(mapper.call(0.9, -1.0 + 0.5 * k))
		for k in 5:
			band.append(mapper.call(1.0, 1.0 - 0.5 * k))
		cv.fill(band, col.lightened(0.12))
		cv.stroke(PackedVector2Array([mapper.call(0.9, -1.0), mapper.call(0.9, 0.0), mapper.call(0.9, 1.0)]), lw * 0.5, INK, 0.1, 0.1)
	# Fold creases near the cuff and at the knee.
	var crease := INK
	crease.a = 0.55
	cv.stroke(PackedVector2Array([mapper.call(0.72, 0.38), mapper.call(0.86, 0.45), mapper.call(0.97, 0.4)]), lw * 0.42, crease, 0.4, 0.4, seed_v)
	if bag > 1.5 or float(shape.cuff) > 9.0:
		cv.stroke(PackedVector2Array([mapper.call(0.8, -0.5), mapper.call(0.92, -0.62)]), lw * 0.4, crease, 0.4, 0.4, seed_v + 1.0)
	cv.stroke(PackedVector2Array([mapper.call(0.42, -0.2), mapper.call(0.5, 0.05), mapper.call(0.56, 0.18)]), lw * 0.36, Color(INK, 0.35), 0.4, 0.4, seed_v + 2.0)
	var o := left + hem + right
	cv.outline(o, lw * 0.86, INK, seed_v, 0.12)


static func _pattern(cv: InkCanvas, mapper: Callable, look: Dictionary, col: Color, leg: int, lw: float, ws: PackedFloat32Array) -> void:
	var pat := str(look.pantsPattern)
	var c2 := Color(str(look.pantsColor2))
	if leg == 0:
		c2 = c2.darkened(0.17)
	match pat:
		"stripes":
			_band(cv, mapper, 0.0, 1.0, 0.22, 0.56, c2)
		"pinstripe":
			for v: float in [-0.55, 0.0, 0.55]:
				var line := PackedVector2Array()
				for k in 9:
					line.append(mapper.call(0.03 + 0.96 * k / 8.0, v))
				cv.stroke(line, lw * 0.32, c2, 0.02, 0.02)
		"hoops":
			for u0: float in [0.18, 0.46, 0.74]:
				_band(cv, mapper, u0, u0 + 0.12, -1.0, 1.0, c2)
		"twotone":
			_band(cv, mapper, 0.55, 1.0, -1.0, 1.0, c2)
		"dots":
			var row := 0
			var u := 0.1
			while u < 0.98:
				var off := 0.5 if row % 2 == 1 else 0.0
				var v := -0.75 + off
				while v <= 0.8:
					var r := lerpf(ws[0], ws[ws.size() - 1], u) * 0.17
					cv.dot(mapper.call(u, v), r, c2)
					v += 1.0
				u += 0.13
				row += 1
		"checks":
			for iu in 7:
				for iv in 4:
					if (iu + iv) % 2 == 0:
						_band(cv, mapper, iu / 7.0, (iu + 1) / 7.0, -1.0 + iv * 0.5, -0.5 + iv * 0.5, Color(c2, 0.85))
		"zigzag":
			var z := PackedVector2Array()
			for k in 9:
				z.append(mapper.call(0.6 + 0.04 * float(k % 2), -0.92 + 1.84 * k / 8.0))
			cv.stroke(z, lw * 1.2, c2, 0.02, 0.02)
			var z2 := PackedVector2Array()
			for k in 9:
				z2.append(mapper.call(0.76 + 0.04 * float(k % 2), -0.92 + 1.84 * k / 8.0))
			cv.stroke(z2, lw * 1.2, c2, 0.02, 0.02)
		"stars":
			for uv: Vector2 in [Vector2(0.25, -0.3), Vector2(0.48, 0.4), Vector2(0.7, -0.35), Vector2(0.88, 0.35), Vector2(0.12, 0.45)]:
				_star(cv, mapper.call(uv.x, uv.y), lerpf(ws[0], ws[ws.size() - 1], uv.x) * 0.3, c2)
		"flames":
			var tongues := 4
			for k in tongues:
				var v0 := -1.0 + 2.0 * k / tongues
				var v1 := -1.0 + 2.0 * (k + 1) / tongues
				var tip := 0.5 + 0.12 * float((k * 7) % 3)
				var poly := PackedVector2Array([mapper.call(1.0, v0), mapper.call(0.82, v0 + 0.05), mapper.call(tip, (v0 + v1) * 0.5 + 0.15),
					mapper.call(0.84, v1 - 0.05), mapper.call(1.0, v1)])
				cv.fill(poly, c2)
				cv.outline(poly, lw * 0.35, Color(INK, 0.5))
		_:
			pass


static func _band(cv: InkCanvas, mapper: Callable, u0: float, u1: float, v0: float, v1: float, c: Color) -> void:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var steps := maxi(2, int((u1 - u0) * 10.0) + 1)
	for k in steps + 1:
		var u := lerpf(u0, u1, float(k) / steps)
		a.append(mapper.call(u, v0))
		b.append(mapper.call(u, v1))
	b.reverse()
	cv.fill(a + b, c)


static func _star(cv: InkCanvas, c: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + TAU * k / 10.0
		p.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
	cv.fill(p, col)


# ---------------------------------------------------------------------------
# Tops
# ---------------------------------------------------------------------------

static func _top(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary, lw: float) -> void:
	var top := str(look.top)
	var dims: Array = TOP_SHAPES.get(top, TOP_SHAPES.tee)
	var hip: Vector2 = s.hip
	var neck: Vector2 = s.neck
	var ctrl: Vector2 = s.ctrl
	var down := (hip - ctrl).normalized()
	var ext := float(dims[3])
	var col := Color(str(look.topColor))
	var col2 := Color(str(look.topColor2))
	const N := 12
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cs := PackedVector2Array()
	var ns := PackedVector2Array()
	var ws := PackedFloat32Array()
	var total := 1.0 + ext / InkRig.TORSO
	for k in N + 1:
		var u := float(k) / float(N) * total     ## 0 neck .. 1 hip .. > 1 below the hip
		var c: Vector2
		var d: Vector2
		if u <= 1.0:
			c = InkRig.bez(neck, ctrl, hip, u)
			d = InkRig.bez_tan(neck, ctrl, hip, u)
		else:
			c = hip + down * (u - 1.0) * InkRig.TORSO
			d = down
			# Long coats and robes swing with the cuffs of the pants.
			var lag: Vector2 = ((st.cuff as Array)[0] + (st.cuff as Array)[1]) * 0.25
			c += lag * (u - 1.0) / maxf(total - 1.0, 0.01)
		var n := Vector2(-d.y, d.x)
		var w: float
		if u < 0.3:
			w = lerpf(float(dims[0]), float(dims[1]), smoothstep(0.0, 0.3, u))
		elif u <= 1.0:
			w = lerpf(float(dims[1]), float(dims[2]), (u - 0.3) / 0.7)
		else:
			w = float(dims[2]) + (u - 1.0) * InkRig.TORSO * (0.32 if top == "robe" else 0.18)
		cs.append(c)
		ns.append(n)
		ws.append(w)
		left.append(c + n * w)
		right.append(c - n * w)
	right.reverse()
	var poly := left + right
	cv.fill(poly, col)
	var mapper := func(u: float, v: float) -> Vector2:
		var x := clampf(u, 0.0, 1.0) * N
		var i0 := mini(int(x), N - 1)
		var fr := x - i0
		return cs[i0].lerp(cs[i0 + 1], fr) + ns[i0].lerp(ns[i0 + 1], fr).normalized() * lerpf(ws[i0], ws[i0 + 1], fr) * v
	var m := func(u_body: float, v: float) -> Vector2: return mapper.call(u_body / total, v)
	match top:
		"jersey":
			cv.fill(PackedVector2Array([m.call(0.32, -1.0), m.call(0.32, 1.0), m.call(0.46, 1.0), m.call(0.46, -1.0)]), col2)
		"jacket", "coat":
			cv.stroke(PackedVector2Array([m.call(0.06, 0.25), m.call(0.5, 0.42), m.call(total, 0.4)]), lw * 0.55, INK, 0.05, 0.05)
			for b: float in [0.35, 0.6, 0.85]:
				if b < total:
					cv.dot(m.call(b, 0.62), lw * 0.45, col2)
			cv.fill(PackedVector2Array([m.call(0.0, 0.1), m.call(0.0, 1.0), m.call(0.22, 0.4)]), col.darkened(0.15))
		"hoodie":
			var head: Vector2 = s.head
			var back := (neck - head).normalized().rotated(-0.9) * InkRig.HEAD_R * 0.95
			var hood := PackedVector2Array([m.call(0.0, -1.0), neck + back * 1.25 + Vector2(-2.0, -1.0), m.call(0.12, -1.2)])
			cv.fill(InkCanvas.spline(hood, 4), col.darkened(0.08))
			cv.stroke(InkCanvas.spline(hood, 4), lw * 0.6, INK, 0.1, 0.1)
			cv.stroke(PackedVector2Array([m.call(0.05, 0.3), m.call(0.25, 0.42)]), lw * 0.4, INK, 0.2, 0.3)
			_band_m(cv, m, 0.78, 0.92, -0.2, 0.75, col.darkened(0.12))
		"sweater":
			for u: float in [0.86, 0.92]:
				cv.stroke(PackedVector2Array([m.call(u, -0.9), m.call(u, 0.0), m.call(u, 0.9)]), lw * 0.4, Color(INK, 0.5), 0.05, 0.05)
			cv.stroke(PackedVector2Array([m.call(0.38, -0.9), m.call(0.38, 0.9)]), lw * 0.9, col2, 0.05, 0.05)
		"polo":
			cv.fill(PackedVector2Array([m.call(0.0, 0.2), m.call(0.02, 1.25), m.call(0.16, 0.75)]), col.lightened(0.15))
			cv.stroke(PackedVector2Array([m.call(0.0, 0.2), m.call(0.02, 1.25), m.call(0.16, 0.75)]), lw * 0.45, INK, 0.1, 0.1)
		"vest":
			cv.stroke(PackedVector2Array([m.call(0.0, 0.6), m.call(0.4, 0.2), m.call(1.0, 0.3)]), lw * 0.5, INK, 0.05, 0.05)
			for b: float in [0.5, 0.75]:
				cv.dot(m.call(b, 0.45), lw * 0.4, col2)
		"robe":
			_band_m(cv, m, 0.92, 1.0, -1.0, 1.0, col2)
			cv.stroke(PackedVector2Array([m.call(0.05, 0.5), m.call(1.0, 0.25), m.call(total, 0.1)]), lw * 0.45, Color(col2, 0.9), 0.05, 0.05)
		"tank":
			pass
	if bool(st.get("drawings", true)):
		var dr: Dictionary = (look.drawings as Dictionary).get("top", {})
		if not dr.is_empty():
			InkDrawing.draw(cv, dr, func(u: float, v: float) -> Vector2: return m.call(u, v), 0.9)
	cv.outline(poly, lw * 0.8, INK, float(st.seed) + 9.0)


static func _band_m(cv: InkCanvas, m: Callable, u0: float, u1: float, v0: float, v1: float, c: Color) -> void:
	cv.fill(PackedVector2Array([m.call(u0, v0), m.call(u0, v1), m.call(u1, v1), m.call(u1, v0)]), c)


# ---------------------------------------------------------------------------
# Neck and back accessories
# ---------------------------------------------------------------------------

static func _neck_accessory(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary) -> void:
	var kind := str(look.neck)
	if kind == "":
		return
	var lw := float(st.lw)
	var col := Color(str(look.neckColor))
	var neck: Vector2 = s.neck
	var d := ((s.hip as Vector2) - neck).normalized()
	var n := Vector2(-d.y, d.x)
	var c := neck + d * 1.2
	match kind:
		"scarf":
			var chain: PackedVector2Array = st.get("scarf", PackedVector2Array())
			if chain.size() >= 3:
				for side: float in [0.0, 1.6]:
					var line := PackedVector2Array([c + Vector2(-2.0, 0.6)])
					for p in chain:
						line.append(p + Vector2(0, side))
					var smooth := InkCanvas.spline(line, 3)
					cv.stroke(smooth, lw * 2.3, col.darkened(0.12 if side > 0 else 0.0), 0.05, 0.5, side)
					cv.stroke(InkCanvas.offset_line(smooth, lw * 1.15), lw * 0.4, Color(INK, 0.8), 0.1, 0.6)
			var wrap := PackedVector2Array([c - n * 4.0, c + n * 4.2])
			cv.stroke(wrap, lw * 2.6, col, 0.05, 0.05)
			cv.stroke(InkCanvas.offset_line(wrap, lw * 1.3), lw * 0.45, INK, 0.05, 0.05)
			cv.stroke(InkCanvas.offset_line(wrap, -lw * 1.3), lw * 0.45, INK, 0.05, 0.05)
		"bandana":
			var poly := PackedVector2Array([c - n * 3.8, c + n * 3.8, c + d * 4.8 + n * 0.6])
			cv.shape(poly, col, lw * 0.6)
			cv.dot(c + d * 1.6 + n * 0.8, lw * 0.35, col.lightened(0.5))
		"bowtie":
			var f := c + n * 2.0
			var a := PackedVector2Array([f, f + d * 2.2 + Vector2(-0.4, 0), f - d * 2.2 + Vector2(-0.4, 0)])
			var b := PackedVector2Array([f, f + d * 2.2 + Vector2(3.0, 0.4), f - d * 2.2 + Vector2(3.0, -0.4)])
			cv.shape(a, col, lw * 0.5)
			cv.shape(b, col, lw * 0.5)
			cv.dot(f, lw * 0.6, col.darkened(0.25))


static func _back_accessory(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary, behind: bool) -> void:
	var kind := str(look.back)
	if kind == "":
		return
	var lw := float(st.lw)
	var col := Color(str(look.backColor))
	var neck: Vector2 = s.neck
	var hip: Vector2 = s.hip
	var up := (neck - hip).normalized()
	var back := Vector2(up.y, -up.x)       ## points behind the golfer (-x when upright)
	if back.x > 0.0:
		back = -back
	match kind:
		"cape":
			if not behind:
				return
			var chain: PackedVector2Array = st.get("cape", PackedVector2Array())
			if chain.size() < 3:
				return
			var top_a := neck + back * 1.0 + up * -1.0
			var left := PackedVector2Array([top_a])
			var right := PackedVector2Array([top_a + Vector2(3.0, 0.5)])
			for i in chain.size():
				var k := float(i + 1) / chain.size()
				var p := chain[i]
				var w := lerpf(2.0, 7.5, k)
				var d := (p - (chain[i - 1] if i > 0 else top_a)).normalized()
				var n := Vector2(-d.y, d.x)
				left.append(p - n * w)
				right.append(p + n * w)
			right.reverse()
			var poly := InkCanvas.spline(left, 3) + InkCanvas.spline(right, 3)
			cv.fill(poly, col.darkened(0.12))
			cv.outline(poly, lw * 0.75, INK, 31.0)
		"backpack":
			if behind:
				var c := InkRig.bez(hip, s.ctrl, neck, 0.62) + back * 4.6
				var poly := _rrect(c, Vector2(4.0, 6.5), 1.8, up)
				cv.shape(poly, col, lw * 0.7)
				cv.stroke(PackedVector2Array([c + back * -4.0 + up * 1.0, c + back * -4.0 + up * -3.5]), lw * 0.5, Color(INK, 0.6))
				cv.shape(_rrect(c + up * -3.0 + back * 0.5, Vector2(3.0, 2.2), 1.0, up), col.darkened(0.15), lw * 0.5)
			else:
				var a := InkRig.bez(hip, s.ctrl, neck, 0.95)
				var b := InkRig.bez(hip, s.ctrl, neck, 0.45) + back * -1.5
				cv.stroke(PackedVector2Array([a, a.lerp(b, 0.5) + back * -1.6, b]), lw * 0.9, col.darkened(0.25), 0.05, 0.05)
		"golfbag":
			if not behind:
				return
			var base := InkRig.bez(hip, s.ctrl, neck, 0.15) + back * 5.0
			var top := InkRig.bez(hip, s.ctrl, neck, 1.1) + back * 9.5
			var axis := (top - base).normalized()
			var n := Vector2(-axis.y, axis.x)
			var poly := PackedVector2Array([base - n * 3.4, base + n * 3.4, top + n * 3.8, top - n * 3.8])
			for k in 3:
				var club_top := top + axis * (4.0 + k * 1.2) + n * (-2.4 + k * 2.4)
				cv.stroke(PackedVector2Array([top + n * (-2.4 + k * 2.4), club_top]), lw * 0.5, INK)
				cv.ellipse(club_top, Vector2(1.6, 1.0), Color("c9c1b3"), axis.angle())
			cv.shape(poly, col, lw * 0.7)
			cv.stroke(PackedVector2Array([base.lerp(top, 0.3) - n * 3.4, base.lerp(top, 0.3) + n * 3.4]), lw * 0.9, col.darkened(0.25), 0.0, 0.0)
		"wings":
			if not behind:
				return
			var root := InkRig.bez(hip, s.ctrl, neck, 0.8) + back * 1.5
			var flap := sin(float(st.t) * 7.0) * 0.25
			for side: float in [1.0, 0.6]:
				var dirw := back.rotated(-0.5 - flap * side) * side
				var tip := root + dirw * 13.0 + up * 4.0 * side
				var poly := PackedVector2Array([root, root + up * 3.0, tip + up * 1.0, tip, tip - up * 3.0 + dirw * -3.0,
					root - up * 3.5 + dirw * 4.0])
				cv.shape(InkCanvas.spline(poly, 3, true), col if side > 0.7 else col.darkened(0.15), lw * 0.6)
				for f in 3:
					var a := root.lerp(tip, 0.45 + f * 0.17)
					cv.stroke(PackedVector2Array([a, a - up * 2.6 + dirw * -1.0]), lw * 0.35, Color(INK, 0.6))


static func _rrect(c: Vector2, half: Vector2, r: float, up: Vector2) -> PackedVector2Array:
	var x := Vector2(-up.y, up.x)
	var y := -up
	var out := PackedVector2Array()
	var corners := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	var start := [0.0, PI * 0.5, PI, PI * 1.5]
	for i in 4:
		for k in 4:
			var a: float = start[i] + PI * 0.5 * k / 3.0
			var p: Vector2 = corners[i] + Vector2(cos(a), sin(a)) * r
			out.append(c + x * p.x + y * p.y)
	return out


# ---------------------------------------------------------------------------
# Club
# ---------------------------------------------------------------------------

static func draw_club(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary) -> void:
	var lw := float(st.lw)
	var grip: Vector2 = s.grip
	var hosel: Vector2 = s.hosel
	if grip.distance_to(hosel) < 1.0:
		return
	var style := str(look.club)
	var d := (hosel - grip).normalized()
	var face := Vector2(d.y, -d.x)
	if face.x < 0.0 and bool(s.grip_mode) and absf(float(s.get("arm", 0.0))) < 1.0:
		face = -face
	# Swing smear: fading ink arcs along the club-head path just after impact.
	var trail: PackedVector2Array = st.get("trail", PackedVector2Array())
	if trail.size() >= 3:
		var smooth := InkCanvas.spline(trail, 3)
		cv.stroke(smooth, lw * 2.6, Color(1, 1, 1, 0.55), 0.85, 0.05, 2.0, 0.0, 0.0, 0.05)
		cv.stroke(InkCanvas.offset_line(smooth, lw * 1.8), lw * 0.5, Color(INK, 0.5), 0.8, 0.1, 3.0, 0.0, 0.0, 0.05)
	var shaft_col := Color("d8dde6")
	match style:
		"golden":
			shaft_col = Color("e8c25a")
		"candy":
			shaft_col = Color("fbf6ec")
		"laser":
			shaft_col = Color("8ff3ff")
		"bone":
			shaft_col = Color("f1ead8")
		"wood":
			shaft_col = Color("b98a5a")
	var shaft := PackedVector2Array([grip, hosel])
	var shaft_w := lw * (1.25 if style == "bone" else 0.95)
	if style == "laser":
		cv.stroke(shaft, lw * 2.6, Color(0.5, 0.95, 1.0, 0.3), 0.1, 0.1)
	cv.stroke(shaft, shaft_w + lw * 0.55, INK, 0.0, 0.0, 5.0, 0.0)
	cv.stroke(shaft, shaft_w, shaft_col, 0.0, 0.0, 6.0, 0.0)
	if style == "candy":
		var steps := 7
		for k in steps:
			var a := grip.lerp(hosel, (k + 0.3) / steps)
			cv.stroke(PackedVector2Array([a - d * 0.8 + face * 0.5, a + d * 0.8 - face * 0.5]), lw * 0.9, Color("d6304a"), 0.0, 0.0)
	# Grip wrap.
	cv.stroke(PackedVector2Array([grip, grip + d * 5.5]), lw * 1.55, INK, 0.0, 0.0)
	# Head.
	var hx := Transform2D(face, d, hosel)       ## x = club face direction, y = along the shaft
	var head: PackedVector2Array
	var head_col := Color("c9cfd8")
	match style:
		"driver":
			head = PackedVector2Array([Vector2(-1.2, -1.0), Vector2(1.6, -0.8), Vector2(3.4, 1.0), Vector2(3.2, 3.6), Vector2(-0.6, 4.4), Vector2(-4.2, 3.2), Vector2(-3.6, 0.6)])
			head_col = Color("2b3a55")
		"wood":
			head = PackedVector2Array([Vector2(-1.0, -0.8), Vector2(1.8, -0.4), Vector2(3.0, 1.6), Vector2(2.6, 3.6), Vector2(-1.4, 4.0), Vector2(-3.6, 2.4), Vector2(-3.0, 0.4)])
			head_col = Color("8a5a32")
		"putter":
			head = PackedVector2Array([Vector2(-1.0, -0.5), Vector2(1.6, -0.5), Vector2(1.6, 3.6), Vector2(-5.0, 3.6), Vector2(-5.0, 1.6), Vector2(-1.0, 1.6)])
			head_col = Color("9aa3b0")
		"bone":
			cv.dot(hosel + d * 1.2 + face * 1.4, 2.0, Color("f1ead8"))
			cv.dot(hosel + d * 1.6 - face * 1.4, 2.0, Color("f1ead8"))
			cv.ink_circle(hosel + d * 1.2 + face * 1.4, Vector2(2.0, 2.0), lw * 0.5, INK, 1.0)
			cv.ink_circle(hosel + d * 1.6 - face * 1.4, Vector2(2.0, 2.0), lw * 0.5, INK, 2.0)
			return
		_:
			head = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(1.4, -0.4), Vector2(2.0, 3.8), Vector2(-3.4, 3.8), Vector2(-3.0, 1.8)])
			if style == "golden":
				head_col = Color("f2c84b")
			elif style == "laser":
				head_col = Color("4cc9f0")
	var hp := hx * head
	cv.fill(hp, head_col)
	cv.stroke(PackedVector2Array([hx * Vector2(1.0, 0.0), hx * Vector2(1.4, 3.2)]), lw * 0.35, Color(1, 1, 1, 0.7), 0.1, 0.1)
	cv.outline(hp, lw * 0.6, INK, 12.0)
