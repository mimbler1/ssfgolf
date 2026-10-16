class_name InkIcons
extends RefCounted
## Hand-drawn icon library (docs/INK_ART_SPEC.md §10, §15): ball abilities and UI glyphs, all
## drawn with InkCanvas so they share one line language. `s` is the icon box size in pixels;
## `t` animates the few icons that move (nitro flame, grenade fuse, energy spark).

const INK := InkCanvas.INK


static func draw(cv: InkCanvas, kind: String, c: Vector2, s: float, t: float = 0.0, dim: bool = false, tint: Color = Color.WHITE) -> void:
	var lw := clampf(s * 0.055, 1.6, 4.0)
	var r := s * 0.34
	var a := 0.45 if dim else 1.0
	var ink := Color(INK, 0.55 if dim else 1.0)
	var k := func(col: Color) -> Color: return Color(col.lerp(Color("d8cfc0"), 0.55) if dim else col, a)
	match kind:
		# --- Ball abilities -------------------------------------------------------------
		"standard":
			_ball(cv, c, r, k.call(Color("fbfbf7")), ink, lw)
			for q in 4:
				var p := c + Vector2.from_angle(0.5 + q * 1.6) * r * 0.5
				cv.stroke(InkCanvas.arc_pts(p, r * 0.13, 0.4 + q * 1.6, 2.0 + q * 1.6, 4), lw * 0.45, Color(ink, 0.6), 0.2, 0.2)
		"nitro":
			var flick := sin(t * 14.0) * r * 0.05
			var flame := PackedVector2Array([c + Vector2(-r * 0.75, r * 0.45), c + Vector2(-r * 0.6, -r * 0.35), c + Vector2(-r * 0.2, -r * 0.05),
				c + Vector2(-r * 0.05, -r * 1.05 + flick), c + Vector2(r * 0.35, -r * 0.3), c + Vector2(r * 0.6, -r * 0.7 - flick), c + Vector2(r * 0.8, r * 0.45)])
			var fs := InkCanvas.spline(flame, 3)
			cv.fill(fs, k.call(Color("ff8a3d")))
			var inner := PackedVector2Array()
			for v in fs:
				inner.append(c + (v - c) * 0.58 + Vector2(0, r * 0.18))
			cv.fill(inner, k.call(Color("ffd166")))
			cv.outline(fs, lw, ink, 3.0)
			_ball(cv, c + Vector2(0, r * 0.45), r * 0.42, k.call(Color("fbfbf7")), ink, lw * 0.9)
			for q in 2:
				cv.stroke(PackedVector2Array([c + Vector2(-r * 1.15, r * (0.2 + q * 0.4)), c + Vector2(-r * 0.75, r * (0.2 + q * 0.4))]), lw * 0.6, Color(ink, 0.6), 0.3, 0.3)
		"sticky":
			_ball(cv, c + Vector2(0, -r * 0.1), r * 0.92, k.call(Color("b462e8")), ink, lw)
			for x: float in [-0.45, 0.05, 0.48]:
				var top := c + Vector2(r * x, r * 0.62)
				var l := r * (0.32 + absf(x) * 0.35)
				cv.stroke(PackedVector2Array([top, top + Vector2(0, l)]), lw * 1.6, k.call(Color("7a35b8")), 0.05, 0.2)
				cv.dot(top + Vector2(0, l), lw * 1.0, k.call(Color("7a35b8")))
			cv.stroke(InkCanvas.arc_pts(c + Vector2(-r * 0.3, -r * 0.4), r * 0.3, PI * 1.05, PI * 1.6, 5), lw * 0.8, Color(1, 1, 1, 0.75 * a), 0.2, 0.2)
		"grenade":
			_ball(cv, c + Vector2(0, r * 0.12), r * 0.88, k.call(Color("5cbf6c")), ink, lw)
			cv.stroke(PackedVector2Array([c + Vector2(-r * 0.75, r * 0.12), c + Vector2(r * 0.75, r * 0.12)]), lw * 0.6, Color(ink, 0.55), 0.1, 0.1)
			cv.stroke(PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.95)]), lw * 0.6, Color(ink, 0.55), 0.1, 0.1)
			var cap := PackedVector2Array([c + Vector2(-r * 0.24, -r * 0.98), c + Vector2(r * 0.24, -r * 0.98), c + Vector2(r * 0.24, -r * 0.7), c + Vector2(-r * 0.24, -r * 0.7)])
			cv.shape(cap, k.call(Color("9aa3b0")), lw * 0.8)
			cv.ink_circle(c + Vector2(r * 0.42, -r * 0.92), Vector2(r * 0.2, r * 0.2), lw * 0.8, ink, 2.0)
			var spark := 0.5 + 0.5 * sin(t * 16.0)
			cv.stroke(InkCanvas.quad_bez(c + Vector2(-r * 0.05, -r * 0.98), c + Vector2(-r * 0.25, -r * 1.25), c + Vector2(-r * 0.1, -r * 1.4), 4), lw * 0.7, ink, 0.1, 0.4)
			if not dim:
				InkIcons._spark(cv, c + Vector2(-r * 0.1, -r * 1.45), r * (0.22 + spark * 0.12), Color("ffd166"))
		"heavy":
			var w := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.45), c + Vector2(r * 0.55, -r * 0.45), c + Vector2(r * 0.95, r * 0.85), c + Vector2(-r * 0.95, r * 0.85)])
			cv.shape(w, k.call(Color("8d96a6")), lw)
			cv.stroke(InkCanvas.arc_pts(c + Vector2(0, -r * 0.55), r * 0.36, PI, TAU, 8), lw * 1.5, ink, 0.05, 0.05)
			cv.stroke(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.55), c + Vector2(r * 0.6, r * 0.55)]), lw * 0.6, Color(1, 1, 1, 0.4 * a), 0.2, 0.2)
		"air_brake":
			var top := c + Vector2(0, -r * 0.2)
			var canopy := InkCanvas.arc_pts(top, r, PI, TAU, 12)
			canopy.append(top + Vector2(r * 0.5, r * 0.12))
			canopy.append(top + Vector2(0, 0))
			canopy.append(top + Vector2(-r * 0.5, r * 0.12))
			cv.shape(canopy, k.call(Color("4cc9f0")), lw)
			for x: float in [-1.0, 0.0, 1.0]:
				cv.stroke(PackedVector2Array([top + Vector2(x * r * 0.95, 0), c + Vector2(0, r * 0.62)]), lw * 0.55, ink, 0.0, 0.0)
			_ball(cv, c + Vector2(0, r * 0.78), r * 0.3, k.call(Color("fbfbf7")), ink, lw * 0.8)
		"ice":
			_ball(cv, c, r * 0.95, k.call(Color("d6f3ff")), ink, lw)
			for q in 3:
				var ang := -PI * 0.5 + q * TAU / 3.0
				var p0 := c + Vector2.from_angle(ang) * r * 0.62
				cv.stroke(PackedVector2Array([c + Vector2.from_angle(ang + PI) * r * 0.62, p0]), lw * 0.7, k.call(Color("5fb3dc")), 0.1, 0.1)
				for side: float in [-1.0, 1.0]:
					cv.stroke(PackedVector2Array([c + Vector2.from_angle(ang) * r * 0.38, c + Vector2.from_angle(ang) * r * 0.38 + Vector2.from_angle(ang + side * 0.8) * r * 0.24]), lw * 0.6, k.call(Color("5fb3dc")), 0.1, 0.1)
		"antigrav", "anti_grav":
			_ball(cv, c + Vector2(0, r * 0.05), r * 0.62, k.call(Color("b6a8ff")), ink, lw)
			cv.ink_circle(c + Vector2(0, r * 0.05), Vector2(r * 1.05, r * 0.38), lw * 0.85, k.call(Color("6a5ae0")), 3.0, -0.3, 0.1, 0.0)
			var up := PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(-r * 0.32, -r * 0.72), c + Vector2(r * 0.32, -r * 0.72)])
			cv.shape(up, k.call(Color("f2b630")), lw * 0.7)
		"free_shot":
			_ball(cv, c, r * 0.92, k.call(Color("fff3b0")), ink, lw)
			var tag := PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.2), c + Vector2(r * 0.95, -r * 0.42), c + Vector2(r * 1.0, r * 0.18), c + Vector2(-r * 0.9, r * 0.38)])
			cv.shape(tag, k.call(Color("ffe066")), lw * 0.8)
			cv.stroke(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.02), c + Vector2(r * 0.55, -r * 0.18)]), lw * 0.7, ink, 0.2, 0.2)
			cv.stroke(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.16), c + Vector2(r * 0.3, r * 0.04)]), lw * 0.7, ink, 0.2, 0.2)
		"laser":
			_ball(cv, c + Vector2(-r * 0.45, r * 0.35), r * 0.55, k.call(Color("fbfbf7")), ink, lw * 0.9)
			var beam := PackedVector2Array([c + Vector2(-r * 0.05, r * 0.05), c + Vector2(r * 1.1, -r * 0.95)])
			cv.stroke(beam, lw * 3.0, Color(Color("ef3b5e"), 0.25 * a), 0.05, 0.05)
			cv.stroke(beam, lw * 1.2, k.call(Color("ef3b5e")), 0.05, 0.05)
			for q in 3:
				var p := c + Vector2(r * (0.15 + q * 0.33), -r * (0.12 + q * 0.3))
				InkIcons._spark(cv, p, r * 0.16, Color(1, 1, 1, a))
		"magnet":
			var arc := InkCanvas.arc_pts(c + Vector2(0, -r * 0.05), r * 0.68, PI * 0.0, PI * 1.0, 12)
			cv.stroke(arc, lw * 4.2, ink, 0.02, 0.02)
			cv.stroke(arc, lw * 2.6, k.call(Color("e5383b")), 0.02, 0.02)
			for side: float in [-1.0, 1.0]:
				var p := c + Vector2(side * r * 0.68, -r * 0.05)
				cv.shape(PackedVector2Array([p + Vector2(-r * 0.2, 0), p + Vector2(r * 0.2, 0), p + Vector2(r * 0.2, -r * 0.42), p + Vector2(-r * 0.2, -r * 0.42)]), k.call(Color("dfe6ee")), lw * 0.8)
			for q in 2:
				cv.stroke(InkCanvas.arc_pts(c + Vector2(0, -r * 0.6), r * (0.25 + q * 0.2), PI * 1.15, PI * 1.85, 6), lw * 0.6, Color(ink, 0.5), 0.2, 0.2)
		"mulligan":
			_ball(cv, c + Vector2(r * 0.2, r * 0.15), r * 0.6, k.call(Color("fbfbf7")), ink, lw * 0.9)
			var loop := InkCanvas.arc_pts(c, r * 0.95, -PI * 0.15, PI * 1.25, 16)
			cv.stroke(loop, lw * 1.5, k.call(Color("c9a227")), 0.05, 0.05)
			var e := loop[0]
			cv.shape(PackedVector2Array([e + Vector2(r * 0.28, -r * 0.05), e + Vector2(-r * 0.12, -r * 0.32), e + Vector2(-r * 0.15, r * 0.18)]), k.call(Color("c9a227")), lw * 0.7)
		"shield":
			_ball(cv, c, r * 0.55, k.call(Color("fbfbf7")), ink, lw * 0.9)
			var sh := PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 0.9, -r * 0.65), c + Vector2(r * 0.75, r * 0.35), c + Vector2(0, r * 1.05), c + Vector2(-r * 0.75, r * 0.35), c + Vector2(-r * 0.9, -r * 0.65)])
			var shs := InkCanvas.spline(sh, 3, true)
			cv.fill(shs, Color(Color("5aa9ff"), 0.3 * a))
			cv.outline(shs, lw * 1.2, k.call(Color("3f7fd8")), 3.0)
			cv.stroke(InkCanvas.arc_pts(c, r * 0.8, -2.5, -1.7, 5), lw * 0.8, Color(1, 1, 1, 0.85 * a), 0.2, 0.2)
		"super":
			_ball(cv, c, r * 0.9, k.call(Color("ffd60a")), ink, lw)
			var st := PackedVector2Array()
			for q in 10:
				st.append(c + Vector2.from_angle(-PI * 0.5 + TAU * q / 10.0) * r * (0.5 if q % 2 == 0 else 0.22))
			cv.fill(st, Color(1, 1, 1, 0.85 * a))
			for q in 3:
				cv.stroke(PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.35 + q * r * 0.35), c + Vector2(-r * 1.5, -r * 0.35 + q * r * 0.35)]), lw * 0.7, Color(ink, 0.6), 0.2, 0.2)
		"zig_zag", "zigzag":
			var z := PackedVector2Array([c + Vector2(-r * 1.0, r * 0.7), c + Vector2(-r * 0.4, -r * 0.5), c + Vector2(r * 0.1, r * 0.45), c + Vector2(r * 0.6, -r * 0.6)])
			cv.stroke(z, lw * 1.6, k.call(Color("c77dff")), 0.05, 0.05)
			_ball(cv, c + Vector2(r * 0.75, -r * 0.7), r * 0.38, k.call(Color("fbfbf7")), ink, lw * 0.8)
			for q in 2:
				cv.stroke(PackedVector2Array([z[q + 1] + Vector2(-r * 0.15, 0), z[q + 1] + Vector2(r * 0.15, 0)]), lw * 0.6, Color(ink, 0.6), 0.2, 0.2)
		# --- UI glyphs --------------------------------------------------------------------
		"trophy":
			var gold := k.call(tint if tint != Color.WHITE else Color("f2b630"))
			for side: float in [-1.0, 1.0]:
				cv.stroke(InkCanvas.arc_pts(c + Vector2(side * s * 0.28, -s * 0.2), s * 0.13, PI * 0.5 if side < 0 else -PI * 0.5, PI * 1.5 if side < 0 else PI * 0.5, 8), lw * 1.2, ink, 0.1, 0.1)
			var cup := InkCanvas.spline(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.38), c + Vector2(s * 0.3, -s * 0.38), c + Vector2(s * 0.22, -s * 0.04), c + Vector2(0, s * 0.12), c + Vector2(-s * 0.22, -s * 0.04)]), 3, true)
			cv.shape(cup, gold, lw)
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.07, s * 0.1), c + Vector2(s * 0.07, s * 0.1), c + Vector2(s * 0.09, s * 0.27), c + Vector2(-s * 0.09, s * 0.27)]), gold.darkened(0.15), lw * 0.8)
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.24, s * 0.27), c + Vector2(s * 0.24, s * 0.27), c + Vector2(s * 0.24, s * 0.41), c + Vector2(-s * 0.24, s * 0.41)]), gold.darkened(0.3), lw * 0.8)
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.3), c + Vector2(-s * 0.12, -s * 0.12)]), lw * 0.7, Color(1, 1, 1, 0.7 * a), 0.2, 0.2)
		"coin":
			cv.ellipse(c, Vector2(s * 0.38, s * 0.38), k.call(Color("f2b630")))
			cv.ink_circle(c, Vector2(s * 0.38, s * 0.38), lw, ink, 2.0)
			cv.ink_circle(c, Vector2(s * 0.26, s * 0.26), lw * 0.6, Color(ink, 0.6), 3.0, 0.0, 0.1, 0.0)
			cv.stroke(PackedVector2Array([c + Vector2(0, -s * 0.14), c + Vector2(0, s * 0.14)]), lw * 0.9, Color(ink, 0.7), 0.1, 0.1)
		"crown":
			var cr := PackedVector2Array([c + Vector2(-s * 0.38, s * 0.28), c + Vector2(-s * 0.4, -s * 0.22), c + Vector2(-s * 0.17, s * 0.0), c + Vector2(0, -s * 0.34),
				c + Vector2(s * 0.17, 0.0), c + Vector2(s * 0.4, -s * 0.22), c + Vector2(s * 0.38, s * 0.28)])
			cv.shape(cr, k.call(tint if tint != Color.WHITE else Color("f2b630")), lw)
		"check":
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.08, s * 0.24), c + Vector2(s * 0.34, -s * 0.28)]), lw * 1.8, k.call(tint if tint != Color.WHITE else UITheme.GRASS_DARK), 0.1, 0.2)
		"flag":
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.22, s * 0.4), c + Vector2(-s * 0.2, -s * 0.38)]), lw, ink, 0.05, 0.05)
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.38), c + Vector2(s * 0.36, -s * 0.22), c + Vector2(-s * 0.2, -s * 0.04)]), k.call(Color("e8543a")), lw * 0.8)
		"gear", "settings":
			var g := PackedVector2Array()
			for q in 32:
				var ang := TAU * q / 32.0
				g.append(c + Vector2.from_angle(ang) * s * (0.4 if (q / 2) % 2 == 0 else 0.3))
			cv.shape(g, k.call(Color("c9c1b3")), lw * 0.8)
			cv.ellipse(c, Vector2(s * 0.13, s * 0.13), k.call(UITheme.PAPER))
			cv.ink_circle(c, Vector2(s * 0.13, s * 0.13), lw * 0.8, ink, 4.0)
		"user", "friends":
			var col: Color = k.call(tint if tint != Color.WHITE else UITheme.SKY)
			var off := 0.0 if kind == "user" else s * 0.13
			if kind == "friends":
				cv.ink_circle(c + Vector2(s * 0.18, -s * 0.12), Vector2(s * 0.13, s * 0.13), lw * 0.85, Color(ink, 0.7), 5.0)
				cv.stroke(InkCanvas.arc_pts(c + Vector2(s * 0.18, s * 0.34), s * 0.24, PI * 1.1, PI * 1.9, 8), lw * 0.85, Color(ink, 0.7), 0.1, 0.1)
			cv.ink_circle(c + Vector2(-off, -s * 0.14), Vector2(s * 0.16, s * 0.16), lw, ink, 6.0)
			var body := InkCanvas.arc_pts(c + Vector2(-off, s * 0.42), s * 0.3, PI, TAU, 10)
			cv.shape(body, col, lw)
		"copy":
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.36), c + Vector2(s * 0.3, -s * 0.36), c + Vector2(s * 0.3, s * 0.2), c + Vector2(-s * 0.18, s * 0.2)]), k.call(UITheme.PAPER_DEEP), lw * 0.8)
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.34, -s * 0.2), c + Vector2(s * 0.14, -s * 0.2), c + Vector2(s * 0.14, s * 0.38), c + Vector2(-s * 0.34, s * 0.38)]), k.call(UITheme.PAPER), lw * 0.8)
		"wifi_off":
			for q in 3:
				cv.stroke(InkCanvas.arc_pts(c + Vector2(0, s * 0.25), s * (0.14 + q * 0.13), PI * 1.25, PI * 1.75, 8), lw, Color(ink, 0.7), 0.1, 0.1)
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.36), c + Vector2(s * 0.36, s * 0.36)]), lw * 1.3, k.call(UITheme.CORAL), 0.1, 0.1)
		"play":
			var tri := PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.32), c + Vector2(s * 0.34, 0), c + Vector2(-s * 0.22, s * 0.32)])
			cv.shape(InkCanvas.spline(tri, 2, true), k.call(tint if tint != Color.WHITE else UITheme.GRASS), lw)
		"star":
			var st := PackedVector2Array()
			for q in 10:
				st.append(c + Vector2.from_angle(-PI * 0.5 + TAU * q / 10.0) * s * (0.4 if q % 2 == 0 else 0.17))
			cv.shape(st, k.call(tint if tint != Color.WHITE else UITheme.SUN), lw)
		"cards", "collection":
			for q in 3:
				var o := Vector2((q - 1) * s * 0.14, (1 - q) * s * 0.03)
				var rot := (q - 1) * 0.22
				var card := PackedVector2Array()
				for v: Vector2 in [Vector2(-0.2, -0.3), Vector2(0.2, -0.3), Vector2(0.2, 0.3), Vector2(-0.2, 0.3)]:
					card.append(c + o + (v * s).rotated(rot))
				cv.shape(card, k.call([UITheme.SKY, UITheme.PAPER, UITheme.SUN][q]), lw * 0.8)
			InkIcons._spark(cv, c + Vector2(s * 0.14, -s * 0.02), s * 0.1, Color(ink, 0.8))
		"pack":
			var pk := PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.36), c + Vector2(s * 0.3, -s * 0.36), c + Vector2(s * 0.34, s * 0.38), c + Vector2(-s * 0.34, s * 0.38)])
			cv.shape(pk, k.call(UITheme.CORAL), lw)
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.24), c + Vector2(s * 0.3, -s * 0.24)]), lw * 0.7, ink, 0.0, 0.0)
			InkIcons._spark(cv, c + Vector2(0, s * 0.06), s * 0.16, Color(UITheme.SUN, a))
		"studio", "brush":
			cv.stroke(PackedVector2Array([c + Vector2(s * 0.34, -s * 0.36), c + Vector2(-s * 0.08, s * 0.12)]), lw * 1.6, k.call(Color("c48a55")), 0.05, 0.05)
			cv.stroke(PackedVector2Array([c + Vector2(s * 0.34, -s * 0.36), c + Vector2(-s * 0.08, s * 0.12)]), lw * 0.5, Color(ink, 0.5), 0.0, 0.0)
			var tip := PackedVector2Array([c + Vector2(-s * 0.06, s * 0.06), c + Vector2(-s * 0.34, s * 0.38), c + Vector2(-s * 0.14, s * 0.12)])
			cv.shape(tip, k.call(tint if tint != Color.WHITE else UITheme.CORAL), lw * 0.8)
		"leaderboard":
			for q in 3:
				var h: float = [0.5, 0.75, 0.35][q] * s
				var x := c.x + (q - 1) * s * 0.26
				cv.shape(PackedVector2Array([Vector2(x - s * 0.11, c.y + s * 0.4), Vector2(x - s * 0.11, c.y + s * 0.4 - h), Vector2(x + s * 0.11, c.y + s * 0.4 - h), Vector2(x + s * 0.11, c.y + s * 0.4)]),
					k.call([UITheme.SKY, UITheme.SUN, UITheme.CORAL][q]), lw * 0.8)
		"challenge", "target":
			for q in 3:
				var rr := s * (0.38 - q * 0.12)
				cv.ellipse(c, Vector2(rr, rr), k.call(UITheme.CORAL if q % 2 == 0 else UITheme.PAPER))
				cv.ink_circle(c, Vector2(rr, rr), lw * 0.7, ink, q)
		"lock":
			cv.stroke(InkCanvas.arc_pts(c + Vector2(0, -s * 0.05), s * 0.18, PI, TAU, 8), lw * 1.3, ink, 0.05, 0.05)
			cv.shape(PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.05), c + Vector2(s * 0.28, -s * 0.05), c + Vector2(s * 0.28, s * 0.38), c + Vector2(-s * 0.28, s * 0.38)]), k.call(UITheme.SUN), lw)
		"energy":
			var bolt := PackedVector2Array([c + Vector2(s * 0.05, -s * 0.42), c + Vector2(-s * 0.22, s * 0.06), c + Vector2(-s * 0.02, s * 0.06), c + Vector2(-s * 0.08, s * 0.42), c + Vector2(s * 0.24, -s * 0.08), c + Vector2(s * 0.03, -s * 0.08)])
			cv.shape(bolt, k.call(UITheme.ENERGY.lightened(0.25)), lw * 0.8)
		"back":
			cv.stroke(PackedVector2Array([c + Vector2(s * 0.3, 0), c + Vector2(-s * 0.3, 0)]), lw * 1.5, ink, 0.1, 0.1)
			cv.stroke(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.24), c + Vector2(-s * 0.32, 0), c + Vector2(-s * 0.08, s * 0.24)]), lw * 1.5, ink, 0.1, 0.1)
		"menu":
			for q in 3:
				var y := c.y + (q - 1) * s * 0.22
				cv.stroke(PackedVector2Array([Vector2(c.x - s * 0.3, y), Vector2(c.x + s * 0.3, y + (q - 1) * 0.6)]), lw * 1.3, ink, 0.2, 0.2)
		_:
			_ball(cv, c, r, k.call(Color.WHITE), ink, lw)


static func _ball(cv: InkCanvas, c: Vector2, r: float, fill: Color, ink: Color, lw: float) -> void:
	cv.ellipse(c, Vector2(r, r), fill)
	cv.crescent(c, r * 0.97, Vector2(-r * 0.24, -r * 0.24), Color(fill.darkened(0.14), fill.a))
	cv.ink_circle(c, Vector2(r, r), lw, ink, r, 0.0, 0.25, 0.025)


static func _spark(cv: InkCanvas, c: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for q in 8:
		p.append(c + Vector2.from_angle(TAU * q / 8.0) * (r if q % 2 == 0 else r * 0.3))
	cv.fill(p, col)
