class_name InkHead
extends RefCounted
## Head, face, hair, headwear, eyewear and the floating companion of the ink golfer
## (docs/INK_ART_SPEC.md §4, §6). Shapes are authored in head-local units: the head circle has
## radius 1, x points the way the golfer faces, y points down. `st.sway` (radians) is the hair
## spring; hanging hair also counter-rotates against the head tilt so it falls with gravity.

const INK := InkCanvas.INK
const PAPER := InkCanvas.PAPER


class Frame:
	var c: Vector2
	var rot: float
	var r: float

	func p(v: Vector2) -> Vector2:
		return c + v.rotated(rot) * r

	func pts(vs: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(vs.size())
		for i in vs.size():
			out[i] = c + vs[i].rotated(rot) * r
		return out


static func frame(s: Dictionary) -> Frame:
	var f := Frame.new()
	f.c = s.head
	f.rot = float(s.head_rot)
	f.r = InkRig.HEAD_R
	return f


static func polar(deg: float, rad: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg)) * rad


static func draw(cv: InkCanvas, s: Dictionary, look: Dictionary, st: Dictionary) -> void:
	var f := frame(s)
	var lw := float(st.lw)
	var hat := str(look.hat)
	var covered := hat in InkLook.HATS_COVER_CROWN
	_hair(cv, f, look, st, lw, covered, true)
	if hat == "helmet":
		_hat(cv, f, look, st, lw, true)
	# Head: one pen loop. Hollow by default (background shows through), or paper-filled.
	if str(look.headFill) == "paper":
		cv.ellipse(f.c, Vector2(f.r, f.r), PAPER)
	cv.ink_circle(f.c, Vector2(f.r, f.r * 1.02), lw * 1.02, INK, float(st.seed) + 40.0, f.rot)
	_face(cv, f, s, look, st, lw)
	_hair(cv, f, look, st, lw, covered, false)
	if hat != "" and hat != "helmet":
		_hat(cv, f, look, st, lw, false)
	_eyewear(cv, f, look, lw)
	if hat == "helmet":
		_hat(cv, f, look, st, lw, false)


# ---------------------------------------------------------------------------
# Face
# ---------------------------------------------------------------------------

static func _face(cv: InkCanvas, f: Frame, s: Dictionary, look: Dictionary, st: Dictionary, lw: float) -> void:
	var expr: Dictionary = s.get("expr", {})
	var eyes := str(expr.get("eyes", look.eyes))
	var mouth := str(expr.get("mouth", look.mouth))
	var blink: bool = st.get("blink", false)
	var ew := lw * 0.8
	var e1 := Vector2(0.2, -0.12)
	var e2 := Vector2(0.62, -0.16)
	var mark := str(look.mark)
	if mark == "blush":
		for e in [e1, e2]:
			cv.ellipse(f.p((e as Vector2) + Vector2(0.02, 0.32)), Vector2(f.r * 0.17, f.r * 0.09), Color(0.94, 0.45, 0.55, 0.45), f.rot)
	elif mark == "freckles":
		for v: Vector2 in [Vector2(0.18, 0.18), Vector2(0.3, 0.24), Vector2(0.24, 0.12), Vector2(0.6, 0.12), Vector2(0.7, 0.2)]:
			cv.dot(f.p(v), lw * 0.24, Color("b0683f"))
	elif mark == "paint":
		cv.stroke(f.pts(PackedVector2Array([Vector2(0.05, 0.12), Vector2(0.4, 0.1)])), lw * 0.9, Color("d6304a"), 0.2, 0.3)
		cv.stroke(f.pts(PackedVector2Array([Vector2(0.08, 0.26), Vector2(0.38, 0.24)])), lw * 0.9, Color("3c6fe0"), 0.2, 0.3)
	if blink and eyes not in ["none", "joy", "closed"]:
		eyes = "closed"
	for i in 2:
		var e: Vector2 = e1 if i == 0 else e2
		var sc := 0.85 if i == 0 else 1.0     ## the far eye is a little smaller (3/4 view)
		match eyes:
			"dots":
				cv.dot(f.p(e), lw * 0.62 * sc, INK)
			"ovals":
				cv.ellipse(f.p(e), Vector2(f.r * 0.1, f.r * 0.17) * sc, INK, f.rot)
			"lines", "focus":
				cv.stroke(f.pts(PackedVector2Array([e + Vector2(-0.09, 0), e + Vector2(0.09, -0.01)])), ew, INK, 0.2, 0.2)
			"happy", "joy":
				cv.stroke(f.pts(InkCanvas.arc_pts(e + Vector2(0, 0.06), 0.11 * sc, PI * 1.1, PI * 1.9, 6)), ew, INK, 0.2, 0.2)
			"sleepy":
				cv.stroke(f.pts(InkCanvas.arc_pts(e + Vector2(0, -0.04), 0.1 * sc, PI * 0.1, PI * 0.9, 6)), ew, INK, 0.2, 0.2)
				cv.dot(f.p(e + Vector2(0, 0.02)), lw * 0.4 * sc, INK)
			"wide":
				cv.ink_circle(f.p(e), Vector2(f.r * 0.15, f.r * 0.17) * sc, ew * 0.85, INK, float(i), f.rot, 0.1, 0.0)
				cv.dot(f.p(e + Vector2(0.03, 0.02)), lw * 0.45 * sc, INK)
			"wink":
				if i == 1:
					cv.stroke(f.pts(InkCanvas.arc_pts(e + Vector2(0, 0.06), 0.11, PI * 1.1, PI * 1.9, 6)), ew, INK, 0.2, 0.2)
				else:
					cv.dot(f.p(e), lw * 0.62 * sc, INK)
			"angry", "fierce":
				cv.dot(f.p(e + Vector2(0, 0.02)), lw * 0.58 * sc, INK)
				cv.stroke(f.pts(PackedVector2Array([e + Vector2(-0.13, -0.17), e + Vector2(0.12, -0.08)])), ew, INK, 0.2, 0.2)
			"sad":
				cv.dot(f.p(e + Vector2(0, 0.03)), lw * 0.52 * sc, INK)
				cv.stroke(f.pts(PackedVector2Array([e + Vector2(-0.12, -0.08), e + Vector2(0.12, -0.17)])), ew, INK, 0.2, 0.2)
			"closed":
				cv.stroke(f.pts(InkCanvas.arc_pts(e + Vector2(0, -0.06), 0.1 * sc, PI * 0.15, PI * 0.85, 6)), ew, INK, 0.2, 0.2)
	# Brows (skipped when the expression already drew angled ones).
	var brows := str(look.brows)
	if brows != "none" and eyes not in ["angry", "fierce", "sad"]:
		for i in 2:
			var e: Vector2 = e1 if i == 0 else e2
			var b := PackedVector2Array()
			match brows:
				"flat":
					b = PackedVector2Array([e + Vector2(-0.11, -0.25), e + Vector2(0.11, -0.26)])
				"arched":
					b = InkCanvas.arc_pts(e + Vector2(0, -0.12), 0.14, PI * 1.15, PI * 1.85, 5)
				"angry":
					b = PackedVector2Array([e + Vector2(-0.12, -0.3), e + Vector2(0.12, -0.2)])
				"worried":
					b = PackedVector2Array([e + Vector2(-0.12, -0.2), e + Vector2(0.12, -0.3)])
				"thick":
					b = PackedVector2Array([e + Vector2(-0.13, -0.24), e + Vector2(0.13, -0.27)])
			cv.stroke(f.pts(b), ew * (1.7 if brows == "thick" else 1.0), INK, 0.25, 0.25)
	# Mouth.
	var m := Vector2(0.45, 0.42)
	match mouth:
		"smile":
			cv.stroke(f.pts(InkCanvas.arc_pts(m + Vector2(0, -0.14), 0.2, PI * 0.25, PI * 0.75, 7)), ew, INK, 0.25, 0.25)
		"grin":
			var g := InkCanvas.arc_pts(m + Vector2(0, -0.2), 0.27, PI * 0.18, PI * 0.82, 9)
			cv.fill(f.pts(g), PAPER)
			cv.outline(f.pts(g), ew * 0.9, INK)
		"flat":
			cv.stroke(f.pts(PackedVector2Array([m + Vector2(-0.14, 0.0), m + Vector2(0.14, -0.02)])), ew, INK, 0.25, 0.25)
		"open", "laugh":
			var big := 1.35 if mouth == "laugh" else 1.0
			var o := InkCanvas.arc_pts(m + Vector2(0, -0.1), 0.22 * big, 0.0, PI, 9)
			cv.fill(f.pts(o), Color("5a1f22"))
			cv.outline(f.pts(o), ew * 0.9, INK)
		"smirk":
			cv.stroke(f.pts(PackedVector2Array([m + Vector2(-0.14, 0.02), m + Vector2(0.08, 0.02), m + Vector2(0.18, -0.06)])), ew, INK, 0.25, 0.25)
		"tongue":
			cv.stroke(f.pts(InkCanvas.arc_pts(m + Vector2(0, -0.14), 0.2, PI * 0.25, PI * 0.75, 7)), ew, INK, 0.25, 0.25)
			cv.ellipse(f.p(m + Vector2(0.04, 0.09)), Vector2(f.r * 0.08, f.r * 0.09), Color("ef7aa0"), f.rot)
		"frown":
			cv.stroke(f.pts(InkCanvas.arc_pts(m + Vector2(0, 0.14), 0.18, PI * 1.25, PI * 1.75, 7)), ew, INK, 0.25, 0.25)
		"o":
			cv.ink_circle(f.p(m + Vector2(0, 0.02)), Vector2(f.r * 0.09, f.r * 0.11), ew * 0.9, INK, 3.0, f.rot, 0.1, 0.0)
	var hc := Color(str(look.hairColor)) if str(look.hairColor) != "" else Color("4a3428")
	if mark == "beard":
		var bd := PackedVector2Array([polar(-5, 1.0), polar(20, 1.04), Vector2(0.7, 0.86), Vector2(0.42, 1.18), Vector2(0.05, 1.06),
			polar(105, 1.02), polar(80, 0.98), Vector2(0.35, 0.68), Vector2(0.6, 0.62), polar(35, 0.98)])
		var bp := f.pts(InkCanvas.spline(bd, 3, true))
		cv.fill(bp, hc)
		cv.outline(bp, ew, INK)
	elif mark == "mustache":
		var mu := PackedVector2Array([Vector2(0.22, 0.3), Vector2(0.45, 0.2), Vector2(0.72, 0.3), Vector2(0.78, 0.4), Vector2(0.45, 0.31), Vector2(0.16, 0.4)])
		var mp := f.pts(InkCanvas.spline(mu, 3, true))
		cv.fill(mp, hc)
		cv.outline(mp, ew * 0.8, INK)
	elif mark == "scar":
		cv.stroke(f.pts(PackedVector2Array([Vector2(0.48, -0.42), Vector2(0.72, 0.08)])), ew * 0.7, Color("8a3a3a"), 0.2, 0.2)
		for k in 3:
			var a := Vector2(0.48, -0.42).lerp(Vector2(0.72, 0.08), 0.25 + k * 0.25)
			cv.stroke(f.pts(PackedVector2Array([a + Vector2(-0.07, 0.03), a + Vector2(0.07, -0.03)])), ew * 0.5, Color("8a3a3a"), 0.1, 0.1)


# ---------------------------------------------------------------------------
# Hair
# ---------------------------------------------------------------------------

## Hair shapes: each strand is head-local points from the head edge, out, and back to the edge.
## "hang" strands fall with gravity. Back strands draw behind the head circle.
static func _strands(style: String) -> Array:
	match style:
		"spikes":
			return [{"p": [polar(-52, 1.0), Vector2(-0.25, -1.82), polar(-112, 1.12), Vector2(-1.38, -1.55), polar(-146, 1.1),
				Vector2(-2.0, -0.72), polar(-188, 1.0)]},
				{"p": [polar(-28, 1.0), Vector2(0.55, -1.48), polar(-62, 1.03)]}]
		"swept":
			return [{"p": [polar(-30, 1.0), polar(-48, 1.3), Vector2(-0.3, -1.6), Vector2(-1.35, -1.25), Vector2(-1.9, -0.75),
				polar(-178, 1.25), polar(-190, 1.0)]},
				{"p": [polar(-60, 1.02), Vector2(-0.4, -1.3), Vector2(-1.4, -0.95)], "line": true}]
		"messy":
			var pts: Array = []
			var r := [1.0, 1.42, 1.08, 1.5, 1.05, 1.36, 1.1, 1.55, 1.04, 1.4, 1.08, 1.32, 0.98]
			for i in r.size():
				pts.append(polar(-25.0 - i * 15.0 + (5.0 if i % 3 == 0 else 0.0), r[i]))
			return [{"p": pts}]
		"mohawk":
			return [{"p": [polar(-62, 1.0), polar(-70, 1.55), polar(-82, 2.0), polar(-100, 1.95), polar(-118, 1.85), polar(-135, 1.5), polar(-145, 1.0)]}]
		"curly":
			var out: Array = []
			for i in 7:
				var a := -20.0 - i * 27.0
				out.append({"loop": polar(a, 1.12), "lr": 0.28})
			return out
		"afro":
			var pts2: Array = []
			for i in 15:
				var a := -22.0 - i * 15.5
				pts2.append(polar(a, 1.55 + (0.12 if i % 2 == 0 else 0.0)) + Vector2(-0.12, -0.12))
			return [{"p": [polar(-15, 1.0)] + pts2 + [polar(140, 1.0)], "fill": true}]
		"bob":
			return [{"p": [polar(-15, 1.02), polar(-40, 1.25), polar(-90, 1.28), polar(-150, 1.3), polar(-200, 1.28), polar(150, 1.25), Vector2(-0.55, 1.18), polar(118, 1.0)], "fill": true},
				{"p": [polar(-25, 0.98), Vector2(0.38, -0.55), Vector2(0.1, -0.8), Vector2(-0.3, -0.92)], "fringe": true}]
		"long":
			return [{"p": [polar(-20, 1.0), polar(-50, 1.24), polar(-110, 1.3), polar(-170, 1.3), Vector2(-1.35, 0.8), Vector2(-1.2, 2.3), Vector2(-0.55, 2.55), Vector2(-0.6, 1.2), polar(115, 1.0)],
				"fill": true, "hang": [0, 0, 0, 0, 0.4, 0.9, 1.0, 0.6, 0]}]
		"ponytail":
			return [{"p": [polar(-20, 1.0), polar(-55, 1.14), polar(-120, 1.17), polar(-170, 1.12), polar(170, 1.0)], "fill": true},
				{"p": [polar(-158, 1.05), Vector2(-1.5, -0.95), Vector2(-2.05, 0.1), Vector2(-1.9, 1.15), Vector2(-1.55, 0.25), Vector2(-1.25, -0.45), polar(-175, 1.04)],
					"fill": true, "hang": [0, 0.2, 0.6, 1.0, 0.8, 0.3, 0], "back": true},
				{"tie": Vector2(-1.32, -0.82)}]
		"pigtails":
			return [{"p": [polar(-20, 1.0), polar(-60, 1.12), polar(-120, 1.15), polar(-175, 1.1), polar(170, 1.0)], "fill": true},
				{"p": [polar(-150, 1.05), Vector2(-1.65, -0.55), Vector2(-2.0, 0.55), Vector2(-1.5, 0.15), polar(-185, 1.04)], "fill": true, "hang": [0, 0.4, 1.0, 0.6, 0], "back": true},
				{"p": [polar(-40, 1.05), Vector2(0.95, -1.2), Vector2(1.45, -0.3), Vector2(1.0, -0.6), polar(-25, 1.04)], "fill": true, "hang": [0, 0.4, 1.0, 0.6, 0], "back": true}]
		"bun":
			return [{"p": [polar(-20, 1.0), polar(-60, 1.1), polar(-130, 1.12), polar(-180, 1.08), polar(165, 1.0)], "fill": true},
				{"bun": Vector2(-0.7, -1.2), "br": 0.5}]
		"braid":
			return [{"p": [polar(-20, 1.0), polar(-60, 1.12), polar(-130, 1.14), polar(-180, 1.1), polar(160, 1.0)], "fill": true},
				{"braid": [Vector2(-1.0, 0.0), Vector2(-1.25, 0.8), Vector2(-1.2, 1.6), Vector2(-1.0, 2.35)]}]
		"buzz":
			return [{"p": [polar(-25, 1.0), polar(-50, 1.1), polar(-100, 1.12), polar(-160, 1.1), polar(-195, 1.0)], "fill": true, "stipple": true}]
		"quiff":
			return [{"p": [polar(-5, 1.0), Vector2(0.95, -1.25), Vector2(0.55, -1.75), Vector2(-0.2, -1.55), polar(-125, 1.25), polar(-175, 1.15), polar(-195, 1.0)], "fill": true},
				{"p": [Vector2(0.75, -1.3), Vector2(0.2, -1.4), Vector2(-0.4, -1.3)], "line": true}]
		"fringe":
			return [{"p": [polar(-10, 1.0), polar(-50, 1.2), polar(-120, 1.22), polar(-175, 1.15), polar(-200, 1.0)], "fill": true},
				{"p": [polar(-15, 1.0), Vector2(0.75, -0.25), Vector2(0.6, -0.45), Vector2(0.4, -0.2), Vector2(0.2, -0.5), Vector2(-0.1, -0.35), polar(-120, 1.0)], "fringe": true}]
	return []


static func _sway_point(v: Vector2, sway: float, hang: float, head_rot: float) -> Vector2:
	var out := v.rotated(sway * clampf(v.length() - 0.95, 0.0, 1.2))
	if hang > 0.0:
		var anchor := v.normalized()
		out = anchor + (out - anchor).rotated(-head_rot * hang * 0.85)
	return out


static func _hair(cv: InkCanvas, f: Frame, look: Dictionary, st: Dictionary, lw: float, covered: bool, back_pass: bool) -> void:
	var style := str(look.hair)
	if style == "none":
		return
	var hc_s := str(look.hairColor)
	var filled := hc_s != ""
	var hc := Color(hc_s) if filled else Color.TRANSPARENT
	var sway := float(st.get("sway", 0.0))
	var strands := _strands(style)
	var seed_v := float(st.seed) + 70.0
	for sd: Dictionary in strands:
		var is_back := bool(sd.get("back", false)) or sd.has("bun") or sd.has("braid")
		if is_back != back_pass:
			continue
		if sd.has("loop"):
			if covered:
				continue
			var c := _sway_point(sd.loop, sway, 0.0, f.rot)
			var lr := float(sd.lr)
			if filled:
				cv.ellipse(f.p(c), Vector2(lr, lr) * f.r, hc)
			cv.ink_circle(f.p(c), Vector2(lr, lr) * f.r, lw * 0.85, INK, seed_v + c.x * 10.0, 0.0, 0.5, 0.06)
			continue
		if sd.has("bun"):
			if covered:
				continue
			var bc: Vector2 = sd.bun
			var br := float(sd.br) * f.r
			cv.ellipse(f.p(bc), Vector2(br, br), hc if filled else PAPER)
			cv.ink_circle(f.p(bc), Vector2(br, br), lw * 0.9, INK, seed_v)
			cv.stroke(f.pts(InkCanvas.arc_pts(bc, float(sd.br) * 0.55, -2.5, -0.5, 6)), lw * 0.5, INK, 0.3, 0.3)
			continue
		if sd.has("braid"):
			var path: Array = sd.braid
			var prev := Vector2.ZERO
			for i in path.size():
				var bp := _sway_point(path[i], sway, 1.0 if i > 0 else 0.3, f.rot)
				var rr := 0.34 - i * 0.04
				cv.ellipse(f.p(bp), Vector2(rr, rr * 1.2) * f.r, hc if filled else PAPER, f.rot)
				cv.ink_circle(f.p(bp), Vector2(rr, rr * 1.2) * f.r, lw * 0.75, INK, seed_v + i, f.rot)
				prev = bp
			cv.stroke(f.pts(PackedVector2Array([prev + Vector2(0, 0.3), prev + Vector2(0, 0.6)])), lw * 0.7, INK, 0.1, 0.4)
			continue
		if sd.has("tie"):
			cv.dot(f.p(sd.tie), lw * 0.9, Color(look.hatColor) if str(look.hat) == "" else INK)
			continue
		var raw: Array = sd.p
		var hang: Array = sd.get("hang", [])
		var local := PackedVector2Array()
		for i in raw.size():
			var hv := float(hang[i]) if i < hang.size() else 0.0
			local.append(_sway_point(raw[i], sway, hv, f.rot))
		if covered and not bool(sd.get("fringe", false)) and not is_back:
			# Under a hat only the hair below the brim shows: keep points low on the head.
			var kept := PackedVector2Array()
			for v in local:
				if v.y > -0.25:
					kept.append(v)
			if kept.size() < 2:
				continue
			local = kept
		var line := InkCanvas.spline(local, 4)
		var world := f.pts(line)
		if bool(sd.get("line", false)):
			cv.stroke(world, lw * 0.5, Color(INK, 0.75), 0.3, 0.4, seed_v)
			continue
		if filled or bool(sd.get("fill", false)):
			# Close the shape along the inside of the head so the fill never covers the face.
			var shape := line.duplicate()
			if not bool(sd.get("fringe", false)):
				# Close along the arc of the head that lies *under* the hair (nearest the strand's
				# mean direction), never across the face.
				var a0 := line[line.size() - 1].angle()
				var a1 := line[0].angle()
				# The face sits around +30° (front, slightly below centre): pick the arc that
				# avoids it.
				var up_arc := fposmod(a1 - a0, TAU)          ## increasing-angle arc length
				var face_in_inc := fposmod(deg_to_rad(30.0) - a0, TAU) < up_arc
				var a_end := a0 - (TAU - up_arc) if face_in_inc else a0 + up_arc
				for k in range(1, 10):
					shape.append(Vector2.from_angle(lerpf(a0, a_end, k / 10.0)) * 0.96)
			cv.fill(f.pts(shape), hc if filled else PAPER)
			if bool(sd.get("stipple", false)):
				for k in 14:
					var a := deg_to_rad(-30.0 - k * 11.0)
					cv.dot(f.p(Vector2.from_angle(a) * (1.05 + 0.05 * (k % 2))), lw * 0.18, Color(INK, 0.6))
		cv.stroke(world, lw * 0.95, INK, 0.12, 0.22, seed_v, 0.14, 0.0, 0.4)


# ---------------------------------------------------------------------------
# Headwear
# ---------------------------------------------------------------------------

static func _hat(cv: InkCanvas, f: Frame, look: Dictionary, st: Dictionary, lw: float, back_pass: bool) -> void:
	var kind := str(look.hat)
	var col := Color(str(look.hatColor))
	var dark := col.darkened(0.2)
	var t := float(st.t)
	var sway := float(st.get("sway", 0.0))
	var lw2 := lw * 0.9
	match kind:
		"cap", "cap_back":
			var dir := 1.0 if kind == "cap" else -1.0
			var dome := InkCanvas.arc_pts(Vector2(0, -0.05), 1.07, deg_to_rad(-200 if dir > 0 else -165), deg_to_rad(-15 if dir > 0 else 20), 12)
			cv.shape(f.pts(dome), col, lw2)
			var brim := PackedVector2Array([Vector2(0.55 * dir, -0.5), Vector2(1.65 * dir, -0.38), Vector2(1.7 * dir, -0.26), Vector2(0.6 * dir, -0.28)])
			cv.shape(f.pts(InkCanvas.spline(brim, 3, true)), dark, lw2)
			cv.dot(f.p(Vector2(-0.1, -1.1)), lw * 0.6, dark)
			cv.stroke(f.pts(PackedVector2Array([Vector2(-0.15, -1.08), Vector2(-0.4, -0.35)])), lw * 0.4, Color(INK, 0.5), 0.2, 0.2)
		"beanie":
			var dome2 := InkCanvas.arc_pts(Vector2(0, -0.1), 1.1, deg_to_rad(-190), deg_to_rad(-12), 12)
			dome2.append(Vector2(1.05, -0.32))
			dome2.append(Vector2(-1.05, -0.36))
			cv.shape(f.pts(dome2), col, lw2)
			var band := PackedVector2Array([Vector2(-1.1, -0.62), Vector2(1.08, -0.5), Vector2(1.08, -0.22), Vector2(-1.12, -0.32)])
			cv.shape(f.pts(band), dark, lw2)
			for k in 5:
				var x := -0.8 + k * 0.4
				cv.stroke(f.pts(PackedVector2Array([Vector2(x, -0.55), Vector2(x, -0.3)])), lw * 0.35, Color(INK, 0.45), 0.2, 0.2)
			var pom := Vector2(-0.35, -1.38).rotated(sway * 0.6)
			cv.ellipse(f.p(pom), Vector2(0.32, 0.3) * f.r, Color(look.hatColor).lightened(0.35))
			cv.ink_circle(f.p(pom), Vector2(0.32, 0.3) * f.r, lw * 0.75, INK, 5.0, 0.0, 0.4, 0.12)
		"bucket":
			var crown := PackedVector2Array([Vector2(-0.95, -0.45), Vector2(-0.8, -1.2), Vector2(0.75, -1.25), Vector2(0.95, -0.45)])
			cv.shape(f.pts(InkCanvas.spline(crown, 3)), col, lw2)
			var brim2 := PackedVector2Array([Vector2(-1.55, -0.12), Vector2(-0.95, -0.55), Vector2(0.95, -0.55), Vector2(1.6, -0.1), Vector2(0.9, -0.32), Vector2(-0.9, -0.34)])
			cv.shape(f.pts(InkCanvas.spline(brim2, 3, true)), dark, lw2)
		"tophat":
			var brim3 := PackedVector2Array([Vector2(-1.45, -0.62), Vector2(1.45, -0.58), Vector2(1.4, -0.42), Vector2(-1.4, -0.46)])
			var tube := PackedVector2Array([Vector2(-0.82, -0.6), Vector2(-0.9, -2.3), Vector2(0.85, -2.35), Vector2(0.8, -0.6)])
			cv.shape(f.pts(tube), col, lw2)
			cv.fill(f.pts(PackedVector2Array([Vector2(-0.84, -0.95), Vector2(0.81, -0.95), Vector2(0.81, -0.72), Vector2(-0.84, -0.72)])), Color("d6304a"))
			cv.shape(f.pts(brim3), col, lw2)
		"cowboy":
			var crown2 := PackedVector2Array([Vector2(-0.9, -0.55), Vector2(-0.85, -1.45), Vector2(-0.3, -1.25), Vector2(0.0, -1.5), Vector2(0.4, -1.3), Vector2(0.88, -1.45), Vector2(0.9, -0.55)])
			cv.shape(f.pts(InkCanvas.spline(crown2, 3)), col, lw2)
			var brim4 := PackedVector2Array([Vector2(-2.0, -0.95), Vector2(-1.2, -0.5), Vector2(1.2, -0.48), Vector2(2.05, -0.92), Vector2(1.5, -0.3), Vector2(-1.5, -0.3)])
			cv.shape(f.pts(InkCanvas.spline(brim4, 3, true)), dark, lw2)
			cv.stroke(f.pts(PackedVector2Array([Vector2(-0.9, -0.7), Vector2(0.9, -0.68)])), lw * 1.1, Color("4a2c1d"), 0.0, 0.0)
		"crown":
			var cr := PackedVector2Array([Vector2(-0.85, -0.68), Vector2(-0.95, -1.55), Vector2(-0.48, -1.05), Vector2(0.0, -1.75), Vector2(0.48, -1.05),
				Vector2(0.95, -1.55), Vector2(0.85, -0.68)])
			cv.shape(f.pts(cr), col, lw2)
			for v: Vector2 in [Vector2(-0.45, -0.88), Vector2(0.0, -0.9), Vector2(0.45, -0.88)]:
				cv.dot(f.p(v), lw * 0.75, Color("d6304a") if v.x == 0.0 else Color("3fa3e8"))
		"headband":
			var hb := PackedVector2Array([polar(-160, 1.03), Vector2(-0.2, -1.0), polar(-15, 1.03)])
			cv.stroke(f.pts(InkCanvas.spline(hb, 4)), lw * 2.6, col, 0.02, 0.02)
			cv.stroke(f.pts(InkCanvas.offset_line(InkCanvas.spline(hb, 4), 0.15)), lw * 0.4, INK, 0.05, 0.05)
			for k in 2:
				var tip := Vector2(-1.9 - k * 0.2, -0.3 + k * 0.55).rotated(sway * 1.2)
				var tail := PackedVector2Array([polar(-165, 1.0), Vector2(-1.4, -0.55 + k * 0.2), tip])
				cv.stroke(f.pts(InkCanvas.spline(tail, 3)), lw * 1.5, dark, 0.05, 0.6, k)
		"wizard":
			var tip2 := Vector2(-1.4, -2.85).rotated(sway * 0.5 + sin(t * 1.3) * 0.04)
			var cone := PackedVector2Array([Vector2(-1.05, -0.6), Vector2(-0.6, -1.6), tip2, Vector2(0.15, -1.75), Vector2(0.95, -0.55)])
			cv.shape(f.pts(InkCanvas.spline(cone, 4)), col, lw2)
			cv.shape(f.pts(PackedVector2Array([Vector2(-1.6, -0.62), Vector2(1.5, -0.5), Vector2(1.5, -0.32), Vector2(-1.55, -0.42)])), dark, lw2)
			for v: Vector2 in [Vector2(-0.3, -1.3), Vector2(0.3, -0.95), Vector2(-0.7, -0.9)]:
				_tiny_star(cv, f.p(v), f.r * 0.17, Color("ffd166"))
		"viking":
			var dome3 := InkCanvas.arc_pts(Vector2(0, -0.12), 1.08, deg_to_rad(-195), deg_to_rad(-15), 12)
			cv.shape(f.pts(dome3), col, lw2)
			cv.stroke(f.pts(PackedVector2Array([Vector2(-1.05, -0.38), Vector2(1.05, -0.34)])), lw * 1.6, dark, 0.0, 0.0)
			for side: float in [-1.0, 1.0]:
				var horn := PackedVector2Array([Vector2(0.75 * side, -0.85), Vector2(1.45 * side, -1.05), Vector2(1.7 * side, -1.75), Vector2(1.25 * side, -1.15), Vector2(0.65 * side, -1.1)])
				cv.shape(f.pts(InkCanvas.spline(horn, 3, true)), Color("f1ead8"), lw * 0.8)
		"halo":
			if back_pass:
				return
			var bob := sin(t * 2.0) * 0.06
			cv.ink_circle(f.c + Vector2(0, -f.r * (1.75 + bob)), Vector2(f.r * 0.85, f.r * 0.24), lw * 1.3, Color("f2b630"), 9.0, 0.0, 0.3, 0.0)
		"bandana":
			var dome4 := InkCanvas.arc_pts(Vector2(0, 0.0), 1.06, deg_to_rad(-200), deg_to_rad(-18), 12)
			cv.shape(f.pts(dome4), col, lw2)
			for k in 2:
				var tail2 := PackedVector2Array([polar(-195, 1.05), Vector2(-1.55, -0.1 + k * 0.4).rotated(sway), Vector2(-1.95, 0.2 + k * 0.5).rotated(sway * 1.3)])
				cv.stroke(f.pts(tail2), lw * 1.4, dark, 0.05, 0.5)
			for v: Vector2 in [Vector2(-0.3, -0.75), Vector2(0.3, -0.85), Vector2(0.0, -0.45)]:
				cv.dot(f.p(v), lw * 0.3, Color(1, 1, 1, 0.8))
		"pirate":
			var tri := PackedVector2Array([Vector2(-1.7, -0.55), Vector2(-0.6, -1.85), Vector2(0.2, -1.35), Vector2(1.2, -1.75), Vector2(1.75, -0.5), Vector2(0.0, -0.75)])
			cv.shape(f.pts(InkCanvas.spline(tri, 3, true)), col, lw2)
			cv.stroke(f.pts(PackedVector2Array([Vector2(-1.5, -0.62), Vector2(0.0, -0.8), Vector2(1.55, -0.6)])), lw * 0.7, Color("f2b630"), 0.05, 0.05)
			_tiny_skull(cv, f.p(Vector2(0.15, -1.2)), f.r * 0.22, lw)
		"dino":
			if back_pass:
				return
			var hood := InkCanvas.arc_pts(Vector2(-0.05, 0.0), 1.25, deg_to_rad(-210), deg_to_rad(-20), 14)
			hood.append(Vector2(0.95, 0.15))
			hood.append(polar(-20, 0.98))
			var inner := InkCanvas.arc_pts(Vector2.ZERO, 0.98, deg_to_rad(-20), deg_to_rad(-210), 10)
			cv.fill(f.pts(hood + inner), col)
			cv.outline(f.pts(hood), lw2, INK)
			for k in 4:
				var a := deg_to_rad(-60.0 - k * 34.0)
				var b := Vector2.from_angle(a) * 1.24
				var spike := PackedVector2Array([Vector2.from_angle(a + 0.17) * 1.22, Vector2.from_angle(a) * 1.75, Vector2.from_angle(a - 0.17) * 1.22])
				cv.shape(f.pts(spike), Color("f2b630"), lw * 0.7)
				b = b
			for k in 4:
				var x := 0.2 + k * 0.2
				cv.shape(f.pts(PackedVector2Array([Vector2(x, -0.62 - k * 0.05), Vector2(x + 0.1, -0.42), Vector2(x + 0.2, -0.65 - k * 0.05)])), PAPER, lw * 0.4)
		"antenna":
			var tip3 := Vector2(0.2, -2.2).rotated(sway * 1.4 + sin(t * 3.0) * 0.05)
			cv.stroke(f.pts(InkCanvas.quad_bez(Vector2(0.0, -1.0), Vector2(0.0, -1.7), tip3, 6)), lw * 0.8, INK, 0.05, 0.05)
			cv.ellipse(f.p(Vector2(0, -1.02)), Vector2(0.38, 0.16) * f.r, Color("8d99ae"))
			cv.dot(f.p(tip3), f.r * 0.24, col)
			cv.ink_circle(f.p(tip3), Vector2(0.24, 0.24) * f.r, lw * 0.7, INK, 4.0)
			var glow := Color(col, 0.25 + 0.2 * sin(t * 5.0))
			cv.dot(f.p(tip3), f.r * 0.42, glow)
		"helmet":
			if back_pass:
				cv.ellipse(f.c + Vector2(0, -f.r * 0.1), Vector2(f.r * 1.55, f.r * 1.55), Color(col, 0.22))
			else:
				cv.ink_circle(f.c + Vector2(0, -f.r * 0.1), Vector2(f.r * 1.55, f.r * 1.55), lw * 0.9, INK, 2.0, 0.0, 0.2, 0.01)
				cv.stroke(f.pts(InkCanvas.arc_pts(Vector2(0, -0.1), 1.25, deg_to_rad(-80), deg_to_rad(-30), 6)), lw * 0.9, Color(1, 1, 1, 0.85), 0.3, 0.3)
				cv.stroke(f.pts(PackedVector2Array([Vector2(-1.1, 1.1), Vector2(1.1, 1.1)])), lw * 2.2, Color("d9d9d9"), 0.0, 0.0)
		"helm":
			var helm := InkCanvas.arc_pts(Vector2(0, 0.05), 1.16, deg_to_rad(-210), deg_to_rad(30), 16)
			helm.append(Vector2(0.92, 0.75))
			helm.append(Vector2(-0.6, 1.0))
			cv.shape(f.pts(helm), col, lw2)
			cv.fill(f.pts(PackedVector2Array([Vector2(0.15, -0.28), Vector2(1.08, -0.3), Vector2(1.06, -0.12), Vector2(0.15, -0.1)])), INK)
			cv.stroke(f.pts(PackedVector2Array([Vector2(0.0, -1.15), Vector2(0.0, 0.9)])), lw * 0.5, Color(INK, 0.5), 0.1, 0.1)
			var plume := PackedVector2Array([Vector2(-0.1, -1.1), Vector2(-0.6, -1.85).rotated(sway), Vector2(-1.6, -1.5).rotated(sway * 1.3), Vector2(-0.6, -1.25)])
			cv.shape(f.pts(InkCanvas.spline(plume, 3, true)), Color("d6304a"), lw * 0.7)


static func _tiny_star(cv: InkCanvas, c: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for k in 8:
		p.append(c + Vector2.from_angle(TAU * k / 8.0) * (r if k % 2 == 0 else r * 0.38))
	cv.fill(p, col)


static func _tiny_skull(cv: InkCanvas, c: Vector2, r: float, lw: float) -> void:
	cv.ellipse(c, Vector2(r, r * 0.9), PAPER)
	cv.dot(c + Vector2(-r * 0.35, 0), r * 0.25, INK)
	cv.dot(c + Vector2(r * 0.35, 0), r * 0.25, INK)


static func _eyewear(cv: InkCanvas, f: Frame, look: Dictionary, lw: float) -> void:
	var kind := str(look.eyewear)
	if kind == "":
		return
	var col := Color(str(look.eyewearColor))
	var e1 := Vector2(0.2, -0.12)
	var e2 := Vector2(0.62, -0.16)
	var w := lw * 0.75
	match kind:
		"round":
			for e in [e1, e2]:
				cv.ink_circle(f.p(e), Vector2(0.19, 0.19) * f.r, w, col, (e as Vector2).x * 10.0, 0.0, 0.15, 0.01)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(0.18, -0.03), e2 + Vector2(-0.18, 0.0)])), w, col, 0.0, 0.0)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(-0.19, 0.0), Vector2(-0.6, -0.2)])), w, col, 0.0, 0.3)
		"square":
			for e in [e1, e2]:
				var q := PackedVector2Array([(e as Vector2) + Vector2(-0.19, -0.13), (e as Vector2) + Vector2(0.19, -0.14), (e as Vector2) + Vector2(0.18, 0.13), (e as Vector2) + Vector2(-0.18, 0.13)])
				cv.outline(f.pts(q), w, col)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(0.19, -0.04), e2 + Vector2(-0.19, -0.04)])), w, col, 0.0, 0.0)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(-0.19, -0.05), Vector2(-0.6, -0.2)])), w, col, 0.0, 0.3)
		"shades":
			for e in [e1, e2]:
				var q2 := PackedVector2Array([(e as Vector2) + Vector2(-0.21, -0.12), (e as Vector2) + Vector2(0.21, -0.14), (e as Vector2) + Vector2(0.16, 0.13), (e as Vector2) + Vector2(-0.14, 0.14)])
				cv.shape(f.pts(q2), col, w)
				cv.stroke(f.pts(PackedVector2Array([(e as Vector2) + Vector2(-0.1, -0.06), (e as Vector2) + Vector2(0.0, -0.08)])), w * 0.7, Color(1, 1, 1, 0.7), 0.1, 0.1)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(0.2, -0.08), e2 + Vector2(-0.2, -0.09)])), w * 1.2, col, 0.0, 0.0)
			cv.stroke(f.pts(PackedVector2Array([e1 + Vector2(-0.21, -0.08), Vector2(-0.6, -0.22)])), w, col, 0.0, 0.3)
		"visor":
			var band := PackedVector2Array([Vector2(-0.05, -0.32), Vector2(1.02, -0.36), Vector2(1.0, 0.02), Vector2(-0.05, 0.06)])
			cv.fill(f.pts(band), Color(col, 0.75))
			cv.outline(f.pts(band), w, INK)
			cv.stroke(f.pts(PackedVector2Array([Vector2(0.1, -0.22), Vector2(0.55, -0.24)])), w * 0.8, Color(1, 1, 1, 0.8), 0.2, 0.2)
		"monocle":
			cv.ink_circle(f.p(e2), Vector2(0.22, 0.22) * f.r, w, Color("c9a46b"), 3.0)
			cv.stroke(f.pts(InkCanvas.quad_bez(e2 + Vector2(-0.05, 0.22), Vector2(0.3, 0.9), Vector2(-0.2, 1.3), 6)), w * 0.5, Color("c9a46b"), 0.0, 0.3)
		"goggles":
			cv.stroke(f.pts(InkCanvas.arc_pts(Vector2.ZERO, 1.02, deg_to_rad(-170), deg_to_rad(-15), 10)), lw * 1.4, Color("6d4c41"), 0.0, 0.0)
			for e in [e1, e2]:
				cv.ellipse(f.p((e as Vector2) + Vector2(0, -0.05)), Vector2(0.24, 0.21) * f.r, Color(col, 0.6))
				cv.ink_circle(f.p((e as Vector2) + Vector2(0, -0.05)), Vector2(0.24, 0.21) * f.r, w * 1.2, INK, (e as Vector2).x * 7.0)
		"patch":
			cv.ellipse(f.p(e2), Vector2(0.22, 0.2) * f.r, INK, f.rot)
			cv.stroke(f.pts(PackedVector2Array([e2 + Vector2(0.15, -0.15), polar(-60, 1.0), polar(-150, 1.0)])), w * 0.7, INK, 0.0, 0.2)


# ---------------------------------------------------------------------------
# Companion
# ---------------------------------------------------------------------------

static func draw_companion(cv: InkCanvas, pos: Vector2, look: Dictionary, st: Dictionary) -> void:
	var kind := str(look.companion)
	if kind == "":
		return
	var lw := float(st.lw) * 0.85
	var t := float(st.t)
	var c := pos + Vector2(0, sin(t * 2.4) * 1.6)
	match kind:
		"bird":
			cv.ellipse(c, Vector2(4.2, 3.4), Color("3dbf7f"))
			cv.ink_circle(c, Vector2(4.2, 3.4), lw, INK, 1.0)
			var flap := sin(t * 14.0) * 2.2
			cv.shape(PackedVector2Array([c + Vector2(-1.5, -1.0), c + Vector2(-5.5, -3.0 - flap), c + Vector2(-3.0, 1.0)]), Color("2a8a5a"), lw * 0.8)
			cv.shape(PackedVector2Array([c + Vector2(3.6, -0.6), c + Vector2(6.2, 0.2), c + Vector2(3.6, 1.0)]), Color("f2b630"), lw * 0.6)
			cv.dot(c + Vector2(1.8, -1.0), lw * 0.6, INK)
			cv.shape(PackedVector2Array([c + Vector2(-0.5, -3.2), c + Vector2(0.5, -5.6), c + Vector2(1.6, -3.2)]), Color("d6304a"), lw * 0.6)
		"ghost":
			var body := PackedVector2Array()
			for k in 9:
				body.append(c + Vector2.from_angle(PI + PI * k / 8.0) * 4.6)
			for k in 5:
				body.append(c + Vector2(4.6 - k * 2.3, 4.0 + (1.2 if k % 2 == 0 else -0.2) + sin(t * 6.0 + k) * 0.5))
			cv.shape(body, Color(1, 1, 1, 0.9), lw)
			cv.dot(c + Vector2(-1.2, -0.5), lw * 0.7, INK)
			cv.dot(c + Vector2(1.4, -0.5), lw * 0.7, INK)
			cv.ink_circle(c + Vector2(0.2, 1.6), Vector2(0.9, 1.1), lw * 0.6, INK, 2.0)
		"drone":
			var body2 := PackedVector2Array([c + Vector2(-4.5, -1.2), c + Vector2(4.5, -1.2), c + Vector2(3.4, 2.4), c + Vector2(-3.4, 2.4)])
			cv.shape(body2, Color("adb5bd"), lw)
			cv.dot(c + Vector2(0, 0.6), 1.3, Color("4cc9f0"))
			for side: float in [-1.0, 1.0]:
				var arm := c + Vector2(side * 4.5, -1.2)
				cv.stroke(PackedVector2Array([arm, arm + Vector2(side * 1.5, -2.0)]), lw * 0.7, INK)
				var spin := absf(sin(t * 30.0 + side)) * 3.6 + 0.6
				cv.stroke(PackedVector2Array([arm + Vector2(side * 1.5 - spin, -2.3), arm + Vector2(side * 1.5 + spin, -2.3)]), lw * 0.7, Color(INK, 0.7), 0.2, 0.2)
		"star":
			var p := PackedVector2Array()
			var rot := t * 1.4
			for k in 10:
				p.append(c + Vector2.from_angle(rot - PI * 0.5 + TAU * k / 10.0) * (5.0 if k % 2 == 0 else 2.2))
			cv.shape(p, Color("ffd166"), lw)
			cv.dot(c + Vector2(-0.9, -0.4), lw * 0.45, INK)
			cv.dot(c + Vector2(0.9, -0.4), lw * 0.45, INK)
		"dino":
			var body3 := PackedVector2Array([c + Vector2(-4.0, 2.0), c + Vector2(-3.5, -1.5), c + Vector2(0.0, -2.8), c + Vector2(2.5, -4.5), c + Vector2(5.5, -3.8),
				c + Vector2(5.0, -2.0), c + Vector2(2.6, -1.6), c + Vector2(3.0, 2.0), c + Vector2(1.5, 3.6), c + Vector2(-2.0, 3.4), c + Vector2(-6.0, 3.0)])
			cv.shape(InkCanvas.spline(body3, 3, true), Color("7bd17f"), lw)
			cv.dot(c + Vector2(3.4, -3.3), lw * 0.55, INK)
