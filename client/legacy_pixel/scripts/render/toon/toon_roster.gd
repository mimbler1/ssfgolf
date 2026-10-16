class_name ToonRoster
extends RefCounted
## Builders for the costumed and creature golfers (see ToonCharacters for the dispatcher and the
## classic / robot / dinosaur builders). Each design is built around one strong visual idea:
##   pirate     tricorn, red beard, eye patch, peg leg, long coat
##   wizard     towering floppy hat, beard down to the belly, bell robe
##   astronaut  bubble helmet with a face inside, backpack, chunky suit
##   skeleton   skull with glowing pupils, argyle sweater vest, flat cap
##   frost      round fur ball of a yeti, horns, flapping scarf
##   cowboy     ten-gallon hat, handlebar moustache, lanky frame, spurs
##   knight     bucket helm with plume, cape, tabard with a golf-ball crest
##   ace, nana, brick, skipper: the original roster, redrawn in the toon style

const P := preload("res://scripts/render/toon/toon_parts.gd")


static func c(def: Dictionary, key: String) -> Color:
	return CharacterDefs.color(def, key)


static func spine_xf(p: Dictionary, t: float) -> Transform2D:
	var f := Golfer.spine_fwd(p, t)
	return Transform2D(f.angle(), Golfer.spine_at(p, t))


static func _r(p: Dictionary, t: float) -> float:
	return P.radius_at(p, p.rig.r, t)


## Thin band of colour around the body between t0 and t1 (belts, hems, stripes).
static func band(cv: ToonCanvas, p: Dictionary, col: Color, z: float, t0: float, t1: float, extra: float = 0.8, rim: bool = true) -> void:
	P.band(cv, p, col, z, t0, t1, extra, {"rim": rim})


## Cuff ring near the wrist of an arm.
static func cuff(cv: ToonCanvas, p: Dictionary, back: bool, col: Color, at: float = 0.8, w_extra: float = 1.1) -> void:
	var pts := P.arm_pts(p, back, 11)
	var i := clampi(roundi(at * 10.0), 1, 9)
	var w := float(p.rig.arm_w) + w_extra
	var cc := ToonCanvas.shadow_of(col, 0.12) if back else col
	cv.capsule(pts[i - 1], pts[i], w, w, cc, P.arm_z(p, back) + 0.6, {"shade": 0.1})


## Full-length sleeve that widens toward the wrist (robes, coats).
static func sleeve(cv: ToonCanvas, p: Dictionary, back: bool, col: Color, w0: float, w1: float, upto: float = 0.85) -> void:
	var pts := P.arm_pts(p, back, 9)
	var m := clampi(roundi(upto * 8.0) + 1, 2, 9)
	var sp := pts.slice(0, m)
	var rs := PackedFloat32Array()
	for i in sp.size():
		rs.append(lerpf(w0, w1, float(i) / float(sp.size() - 1)))
	var cc := ToonCanvas.shadow_of(col, 0.12) if back else col
	cv.tube(sp, rs, cc, P.arm_z(p, back) + 0.5, {"shade": 0.15})


static func arms(cv: ToonCanvas, p: Dictionary, skin: Color, hand: Color, thumb_hand: Color = Color(0, 0, 0, 0)) -> void:
	for back: bool in [true, false]:
		P.arm(cv, p, back, skin)
		P.hand(cv, p, back, thumb_hand if (thumb_hand.a > 0.0 and not back) else hand, p.thumb and not back)


static func round_head(cv: ToonCanvas, p: Dictionary, skin: Color, shape: String = "round") -> void:
	var r := float(p.head_r)
	cv.poly("head_%s_%.2f" % [shape, r], P.head_shape(shape, r), P.head_xf(p), skin, P.Z_HEAD, {"shade": 0.15})


## A local-space polygon in the body frame at spine t (x forward, y down the spine).
static func body_poly(cv: ToonCanvas, p: Dictionary, key: String, pts: Array, t: float, col: Color, z: float, o: Dictionary = {}) -> void:
	cv.poly(key, PackedVector2Array(pts), spine_xf(p, t), col, z, o)


# ---------------------------------------------------------------------------
# Cap'n Slice — pirate
# ---------------------------------------------------------------------------

static func pirate(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var coat := c(def, "coat")
	var trim := c(def, "trim")
	var skin := c(def, "skin")
	var beard := c(def, "beard")
	var wood := c(def, "wood")
	var r0 := _r(p, 0.0)
	# Peg leg (back) and buckled boot (front).
	var fb: Vector2 = p.feet[0]
	cv.capsule(fb + Vector2(0.4, -7.0), fb + Vector2(0, -1.0), 2.3, 1.5, wood.darkened(0.12), P.Z_FEET, {"shade": 0.18})
	cv.circle(fb + Vector2(0, -0.9), 1.5, wood.darkened(0.4), P.Z_FEET + 0.1, {"shade": 0.0})
	P.shoes(cv, p, c(def, "boot"), c(def, "boot").darkened(0.4), 1.05, "boot", [1])
	cv.detail(P.Z_FEET + 0.7, func(k: ToonCanvas) -> void:
		k.push(P.foot_xf(p, 1))
		k.fill_poly(PackedVector2Array([Vector2(1.0, -3.6), Vector2(3.2, -3.6), Vector2(3.2, -1.9), Vector2(1.0, -1.9)]), trim)
		k.pop())
	# Coat tails flaring behind the hips.
	var sw := float(p.sway) * 1.5
	body_poly(cv, p, "pirate_tails_%.1f" % snappedf(sw, 0.5), [Vector2(-1.0, -5.0), Vector2(-r0 - 0.5, -3.0), Vector2(-r0 - 4.0 - sw, r0 + 0.5),
		Vector2(-r0 + 2.0 - sw, r0 + 3.2), Vector2(-1.0, r0 + 1.0)], 0.0, coat.darkened(0.12), P.Z_BODY - 1.0, {"shade": 0.12})
	P.bean(cv, p, coat, P.Z_BODY)
	# Striped shirt in the V of the coat.
	var vx := spine_xf(p, 0.82)
	var rv := _r(p, 0.82)
	cv.poly("pirate_v_%.1f" % rv, PackedVector2Array([Vector2(rv * 0.05, -6.0), Vector2(rv - 0.6, -6.5), Vector2(rv * 0.62, 5.0)]), vx, Color.WHITE, P.Z_CLOTH, {"shade": 0.0})
	cv.detail(P.Z_CLOTH + 0.1, func(k: ToonCanvas) -> void:
		k.push(vx)
		for i in 3:
			var y := -3.4 + i * 2.8
			var f := (y + 6.0) / 11.0
			k.ci.draw_line(Vector2(lerpf(rv * 0.05, rv * 0.62, f) + 0.6, y), Vector2(lerpf(rv - 0.6, rv * 0.62, f) - 0.6, y), c(def, "stripe"), 1.3, false)
		k.pop())
	band(cv, p, c(def, "sash"), P.Z_CLOTH + 0.5, 0.24, 0.34)
	var bx := spine_xf(p, 0.29)
	cv.poly("pirate_buckle", ToonCharacters.round_rect(Vector2(2.4, 2.2), 0.8), bx.translated_local(Vector2(_r(p, 0.29) - 1.5, 0)), trim, P.Z_CLOTH + 0.8, {"shade": 0.15})
	cv.detail(P.Z_CLOTH + 0.9, func(k: ToonCanvas) -> void:
		for t: float in [0.48, 0.62]:
			k.dot(Golfer.spine_at(p, t) + Golfer.spine_fwd(p, t) * (_r(p, t) - 2.2), 1.0, trim))
	# Coat sleeves with gold cuffs.
	for back: bool in [true, false]:
		P.arm(cv, p, back, coat, Color(0, 0, 0, 0), 0.0, 1.15)
		cuff(cv, p, back, trim, 0.82, 1.0)
		P.hand(cv, p, back, skin, p.thumb and not back)
	# Head: big red beard, eye patch, tricorn.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	round_head(cv, p, skin)
	cv.poly("pirate_beard_%.2f" % r, P.head_poly([Vector2(-0.42, 0.0), Vector2(-0.1, 0.3), Vector2(0.4, 0.42), Vector2(0.86, 0.28), Vector2(1.04, 0.52),
		Vector2(0.86, 0.98), Vector2(0.35, 1.22), Vector2(-0.18, 1.02), Vector2(-0.5, 0.55)], r, 0.07, 0.24), at, beard, P.Z_HEAD + 0.4, {"shade": 0.15})
	P.face(cv, p, {"x": 0.36, "brows": beard.darkened(0.25), "nose": "button", "skin": skin, "mouth": "grin"})
	cv.detail(P.Z_FACE + 0.5, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_ellipse(Vector2(0.13, -0.1) * r, Vector2(0.17, 0.16) * r, 0.0, k.ink)
		k.line(Vector2(0.2, -0.22) * r, Vector2(-0.75, -0.6) * r, k.ink, maxf(0.7, k.in_w))
		# Moustache over the mouth.
		k.fill_poly(P._hpts([Vector2(0.28, 0.36), Vector2(0.62, 0.28), Vector2(0.98, 0.36), Vector2(0.9, 0.46), Vector2(0.62, 0.38), Vector2(0.34, 0.47)], r), beard.darkened(0.12))
		k.dot(Vector2(-0.36, 0.3) * r, 0.09 * r, c(def, "trim"))
		k.pop())
	cv.poly("pirate_hat_%.2f" % r, P.head_poly([Vector2(-1.3, -0.4), Vector2(-1.12, -0.95), Vector2(-0.55, -1.25), Vector2(0.2, -1.32), Vector2(0.88, -1.12),
		Vector2(1.42, -0.72), Vector2(1.52, -0.36), Vector2(1.05, -0.48), Vector2(0.3, -0.6), Vector2(-0.62, -0.58)], r), at, c(def, "hat"), P.Z_HAT, {"shade": 0.2})
	cv.detail(P.Z_HAT + 0.3, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.7, k.in_w)
		k.polyline(P._hpts([Vector2(-1.26, -0.44), Vector2(-0.62, -0.62), Vector2(0.3, -0.64), Vector2(1.05, -0.52), Vector2(1.46, -0.4)], r), trim, lw * 1.2)
		# Emblem: a golf ball over crossed clubs.
		var e := Vector2(0.18, -0.95) * r
		k.line(e + Vector2(-0.28, -0.2) * r, e + Vector2(0.28, 0.2) * r, Color.WHITE, lw)
		k.line(e + Vector2(0.28, -0.2) * r, e + Vector2(-0.28, 0.2) * r, Color.WHITE, lw)
		k.dot(e, 0.17 * r, k.ink)
		k.dot(e, 0.17 * r - lw * 0.7, Color.WHITE)
		k.pop())
	P.club(cv, p, {"shaft": "#c08a5a", "head": "#ffd166"})


# ---------------------------------------------------------------------------
# Fizzwick — wizard
# ---------------------------------------------------------------------------

static func wizard(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var robe := c(def, "robe")
	var gold := c(def, "gold")
	var skin := c(def, "skin")
	var beard := c(def, "beard")
	var t := float(p.t)
	var sway := float(p.sway)
	# Curly slipper tips peek out under the robe.
	P.shoes(cv, p, gold, gold.darkened(0.35), 0.95, "slipper", [0, 1],
		[Vector2(-3.0, 0.0), Vector2(-3.2, -2.6), Vector2(0.4, -3.8), Vector2(4.0, -3.0), Vector2(6.6, -3.6), Vector2(7.4, -2.2), Vector2(5.6, 0.0)], 1.0)
	# Bell robe: the bean plus a flared skirt down to the ankles.
	P.bean(cv, p, robe, P.Z_BODY)
	var base: Vector2 = p.base
	var r0 := _r(p, 0.0)
	var up: Vector2 = p.up
	var fwd: Vector2 = p.fwd
	var hem_y := -2.2
	var sw := sway * 1.8 + sin(t * Golfer.BREATH) * 0.4
	var top_l := base + up * 6.0 - fwd * (r0 - 0.4)
	var top_r := base + up * 6.0 + fwd * (r0 - 0.4)
	var skirt := PackedVector2Array([top_l, top_r])
	for i in 9:
		var u := float(i) / 8.0
		var x := lerpf(r0 * 1.38, -r0 * 1.5, u) + sw
		skirt.append(Vector2(base.x + x, hem_y + sin(u * PI * 4.0 + t * 2.0) * 0.5 + ((p.root as Vector2).y * 0.6)))
	cv.blob(skirt, robe, P.Z_BODY + 0.5, {"shade": 0.18})
	cv.detail(P.Z_BODY + 0.6, func(k: ToonCanvas) -> void:
		var hem := PackedVector2Array()
		for i in range(2, skirt.size()):
			hem.append(skirt[i] + Vector2(0, -1.1))
		k.polyline(hem, gold, maxf(0.8, k.in_w * 1.3))
		for sp: Vector2 in [Vector2(3.0, 4.0), Vector2(-5.0, 9.0), Vector2(6.0, 12.0), Vector2(-2.0, 16.0)]:
			ToonParts._star(k, base + up * (6.0 - sp.y * 0.5) + fwd * sp.x * 0.9 + Vector2(0, sp.y * 0.4), 1.5, Color(gold, 0.85)))
	band(cv, p, gold, P.Z_CLOTH, 0.3, 0.37, 0.6)
	# Bell sleeves.
	for back: bool in [true, false]:
		P.arm(cv, p, back, skin)
		sleeve(cv, p, back, robe, float(p.rig.arm_w) + 1.2, float(p.rig.arm_w) + 3.0, 0.82)
		cuff(cv, p, back, gold, 0.82, 2.3)
		P.hand(cv, p, back, skin, p.thumb and not back)
	# Head, beard to the belly, brows, towering hat.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	round_head(cv, p, skin)
	var bs := snappedf(sway * 0.25, 0.05)
	cv.poly("wizard_beard_%.2f_%.2f" % [r, bs], P.head_poly([Vector2(-0.4, 0.05), Vector2(0.1, 0.32), Vector2(0.6, 0.3), Vector2(0.98, 0.18), Vector2(1.05, 0.55),
		Vector2(0.85, 1.2), Vector2(0.6 + bs, 1.9), Vector2(0.38 + bs, 2.2), Vector2(0.15, 1.7), Vector2(-0.25, 1.1), Vector2(-0.5, 0.5)], r, 0.06, 0.22),
		at, beard, P.Z_HEAD + 0.4, {"shade": 0.12})
	P.face(cv, p, {"x": 0.34, "brows": beard, "nose": "long", "skin": skin, "mouth": "smile", "size": 0.95})
	cv.detail(P.Z_FACE + 0.4, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_poly(P.head_poly([Vector2(0.2, 0.42), Vector2(0.55, 0.3), Vector2(0.95, 0.38), Vector2(1.1, 0.55), Vector2(0.75, 0.5), Vector2(0.5, 0.48), Vector2(0.3, 0.58)], r, 0.03, 0.15), beard.darkened(0.06))
		k.pop())
	var bend := snappedf(sin(t * 1.4) * 0.07 + sway * 0.3, 0.04)
	var tip := Vector2(-0.95, -3.1).rotated(bend)
	cv.poly("wizard_hat_%.2f_%.2f" % [r, bend], P._hpts([Vector2(-0.95, -0.5), Vector2(0.95, -0.5), Vector2(0.42, -1.55), Vector2(-0.05, -2.3),
		tip, Vector2(-0.5, -2.05), Vector2(-0.5, -1.3)], r), at, robe.darkened(0.1), P.Z_HAT, {"shade": 0.2})
	cv.poly("wizard_brim_%.2f" % r, P._hpts([Vector2(-1.55, -0.32), Vector2(1.6, -0.32), Vector2(1.45, -0.62), Vector2(-1.4, -0.62)], r), at, robe.darkened(0.25), P.Z_HAT + 0.2, {"shade": 0.0})
	cv.poly("wizard_band_%.2f" % r, P._hpts([Vector2(-0.88, -0.62), Vector2(0.88, -0.62), Vector2(0.8, -0.85), Vector2(-0.82, -0.85)], r), at, gold, P.Z_HAT + 0.3, {"shade": 0.0})
	var tw := 0.5 + 0.5 * sin(t * 4.0)
	cv.detail(P.Z_HAT + 0.5, func(k: ToonCanvas) -> void:
		k.push(at)
		ToonParts._star(k, Vector2(0.05, -1.2) * r, 0.24 * r, gold)
		k.arc(Vector2(-0.3, -1.75) * r, 0.14 * r, 0.6, 4.4, Color("fff3b0"), maxf(0.8, k.in_w * 1.2), 10)
		# Sparkles drifting off the hat tip.
		var tp := tip * r
		for i in 3:
			var ph := fmod(t * 0.7 + i * 0.33, 1.0)
			var sp := tp + Vector2(-2.0 - ph * 8.0 + i * 3.0, -ph * 9.0 + i * 2.0)
			_sparkle(k, sp, 1.6 * (1.0 - ph) * (0.6 + tw * 0.4), Color(c(def, "spark"), 1.0 - ph))
		k.pop())
	P.club(cv, p, {"shaft": "#9b6b43", "grip": "#4b2e83", "head": "#7df9ff", "kind": "wood"})


static func _sparkle(k: ToonCanvas, at: Vector2, s: float, col: Color) -> void:
	if s <= 0.05:
		return
	k.fill_poly(PackedVector2Array([at + Vector2(0, -s * 2.0), at + Vector2(s * 0.45, -s * 0.45), at + Vector2(s * 2.0, 0), at + Vector2(s * 0.45, s * 0.45),
		at + Vector2(0, s * 2.0), at + Vector2(-s * 0.45, s * 0.45), at + Vector2(-s * 2.0, 0), at + Vector2(-s * 0.45, -s * 0.45)]), col)


# ---------------------------------------------------------------------------
# Nova — astronaut
# ---------------------------------------------------------------------------

static func astronaut(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var suit := c(def, "suit")
	var accent := c(def, "accent")
	var grey := c(def, "grey")
	var t := float(p.t)
	P.shoes(cv, p, suit, grey.darkened(0.2), 1.2, "moonboot", [0, 1],
		[Vector2(-3.6, 0.0), Vector2(-3.9, -4.4), Vector2(-1.0, -5.4), Vector2(3.0, -5.0), Vector2(5.4, -3.2), Vector2(5.8, 0.0)], 1.6)
	# Backpack.
	var r55 := _r(p, 0.55)
	body_poly(cv, p, "nova_pack", ToonCharacters.round_rect(Vector2(4.6, 9.5), 2.6), 0.58, grey, P.Z_BODY - 1.0, {"shade": 0.2})
	var pxf := spine_xf(p, 0.58).translated_local(Vector2(-r55 - 2.5, 0))
	cv.poly("nova_pack2", ToonCharacters.round_rect(Vector2(3.4, 8.5), 2.2), pxf, grey, P.Z_BODY - 1.0, {"shade": 0.2})
	P.bean(cv, p, suit, P.Z_BODY)
	band(cv, p, grey, P.Z_CLOTH, 0.22, 0.29, 0.6)
	band(cv, p, accent, P.Z_CLOTH, 0.05, 0.1, 0.6)
	var cxf := spine_xf(p, 0.62).translated_local(Vector2(_r(p, 0.62) * 0.42, 0))
	cv.poly("nova_panel", ToonCharacters.round_rect(Vector2(3.9, 3.2), 1.2), cxf, c(def, "panel"), P.Z_CLOTH + 0.5, {"shade": 0.0})
	var blink := fmod(t, 1.2) < 0.6
	cv.detail(P.Z_CLOTH + 0.6, func(k: ToonCanvas) -> void:
		k.push(cxf)
		k.dot(Vector2(-1.8, -1.0), 0.9, Color("ef476f") if blink else Color("7a2a3a"))
		k.dot(Vector2(0.4, -1.0), 0.9, Color("ffd166"))
		k.dot(Vector2(2.4, -1.0), 0.9, Color("06d6a0"))
		k.ci.draw_line(Vector2(-2.4, 1.3), Vector2(2.6, 1.3), Color("6ff7ff"), 0.8, false)
		k.pop()
		# Flag patch on the shoulder.
		var sp := Golfer.spine_at(p, 0.86) + Golfer.spine_fwd(p, 0.86) * (_r(p, 0.86) * 0.1)
		k.fill_poly(PackedVector2Array([sp + Vector2(-1.5, -1.2), sp + Vector2(1.6, -1.2), sp + Vector2(1.6, 1.0), sp + Vector2(-1.5, 1.0)]), accent))
	for back: bool in [true, false]:
		P.arm(cv, p, back, suit, Color(0, 0, 0, 0), 0.0, 1.2)
		cuff(cv, p, back, accent, 0.78, 1.0)
		P.hand(cv, p, back, suit.darkened(0.04), p.thumb and not back)
	# Bubble helmet with the face inside.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	cv.ellipse(at * Vector2(-0.05 * r, 0.82 * r), Vector2(0.9 * r, 0.3 * r), float(p.head_rot), grey, P.Z_HEAD - 0.5, {"shade": 0.1})
	var ant := at * Vector2(-0.55 * r + float(p.sway) * 2.0, -1.45 * r)
	cv.capsule(at * Vector2(-0.45 * r, -0.85 * r), ant, 0.6, 0.5, grey, P.Z_HEAD_BACK, {"shade": 0.0})
	cv.circle(ant, 1.5, Color("ef476f") if blink else Color("ffd166"), P.Z_HEAD_BACK + 0.1, {"shade": 0.0})
	cv.circle(p.head, r * 1.06, suit, P.Z_HEAD, {"shade": 0.14, "hl": 0.3})
	cv.ellipse(at * Vector2(0.24 * r, 0.04 * r), Vector2(0.78 * r, 0.74 * r), float(p.head_rot), c(def, "visor"), P.Z_HEAD + 0.2, {"shade": 0.0})
	cv.ellipse(at * Vector2(0.28 * r, 0.08 * r), Vector2(0.64 * r, 0.6 * r), float(p.head_rot), c(def, "skin"), P.Z_HEAD + 0.3, {"shade": 0.12, "rim": false})
	cv.detail(P.Z_HEAD + 0.35, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_poly(P.head_poly([Vector2(-0.3, -0.38), Vector2(0.1, -0.56), Vector2(0.6, -0.52), Vector2(0.86, -0.3), Vector2(0.4, -0.3), Vector2(0.0, -0.22)], r, 0.04, 0.16), c(def, "hair"))
		k.pop())
	P.face(cv, p, {"x": 0.32, "y": 0.06, "size": 0.85, "brows": c(def, "hair"), "cheeks": true, "spacing": 0.42})
	cv.detail(P.Z_FACE + 1.0, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_ellipse(Vector2(0.24, 0.04) * r, Vector2(0.78, 0.74) * r, 0.0, Color(0.62, 0.86, 1.0, 0.16))
		k.arc(Vector2(0.24, 0.04) * r, 0.62 * r, PI * 1.08, PI * 1.42, Color(1, 1, 1, 0.75), maxf(1.0, r * 0.1), 10)
		k.dot(Vector2(0.62, -0.48) * r, 0.07 * r, Color(1, 1, 1, 0.8))
		k.pop())
	P.club(cv, p, {"head": "#ff8c42"})


# ---------------------------------------------------------------------------
# Rattles — skeleton
# ---------------------------------------------------------------------------

static func skeleton(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var bone := c(def, "bone")
	var vest := c(def, "vest")
	var vest2 := c(def, "vest2")
	var glow := c(def, "glow")
	var base: Vector2 = p.base
	var r0 := _r(p, 0.0)
	# Bony legs with knee knobs.
	for i in 2:
		var f: Vector2 = p.feet[i]
		var hip := base + Vector2((-1.5 if i == 0 else 1.5), r0 * 0.5)
		var col := ToonCanvas.shadow_of(bone, 0.14) if i == 0 else bone
		var knee := hip.lerp(f + Vector2(0, -2.5), 0.5) + Vector2(0.8, 0)
		cv.capsule(hip, f + Vector2(0.3, -2.5), 1.25, 1.1, col, P.Z_FEET - 0.5 + i * 0.5, {"shade": 0.1})
		cv.circle(knee, 1.9, col, P.Z_FEET - 0.4 + i * 0.5, {"shade": 0.12})
	P.shoes(cv, p, bone, bone.darkened(0.25), 0.82, "bonefoot", [0, 1],
		[Vector2(-2.8, 0.0), Vector2(-3.0, -2.6), Vector2(-0.8, -3.6), Vector2(3.4, -2.6), Vector2(6.0, -1.4), Vector2(6.2, 0.0)], 0.0)
	# Argyle sweater vest is the body.
	P.bean(cv, p, vest, P.Z_BODY)
	band(cv, p, c(def, "pants"), P.Z_CLOTH - 0.5, 0.0, 0.16, 0.4)
	band(cv, p, vest2, P.Z_CLOTH, 0.15, 0.21, 0.6)
	cv.detail(P.Z_CLOTH + 0.2, func(k: ToonCanvas) -> void:
		for row in 3:
			var tt := 0.28 + row * 0.2
			var rr := _r(p, tt)
			var n := 3
			for j in n:
				var x := lerpf(-0.55, 0.6, float(j) / float(n - 1)) + (0.18 if row % 2 == 1 else 0.0)
				if absf(x) * rr > rr - 3.2:
					continue
				var cc := Golfer.spine_at(p, tt) + Golfer.spine_fwd(p, tt) * x * rr
				var u := (p.up as Vector2) * 2.6
				var s := (p.fwd as Vector2) * 1.9
				k.fill_poly(PackedVector2Array([cc + u, cc + s, cc - u, cc - s]), vest2 if (row + j) % 2 == 0 else c(def, "vest3")))
	# Ribs peeking from the V neck.
	var vx := spine_xf(p, 0.86)
	var rv := _r(p, 0.86)
	cv.poly("skel_v_%.1f" % rv, PackedVector2Array([Vector2(rv * 0.1, -5.0), Vector2(rv - 0.8, -5.5), Vector2(rv * 0.55, 3.0)]), vx, c(def, "dark"), P.Z_CLOTH + 0.4, {"shade": 0.0})
	cv.detail(P.Z_CLOTH + 0.5, func(k: ToonCanvas) -> void:
		k.push(vx)
		for i in 2:
			var y := -3.0 + i * 2.4
			k.line(Vector2(rv * 0.25, y), Vector2(rv * 0.85 - i * 1.2, y + 0.4), bone, 1.1)
		k.pop())
	# Bone arms with elbow knobs.
	for back: bool in [true, false]:
		P.arm(cv, p, back, bone, Color(0, 0, 0, 0), 0.0, 0.75)
		var pts := P.arm_pts(p, back, 5)
		var col := ToonCanvas.shadow_of(bone, 0.12) if back else bone
		cv.circle(pts[2], float(p.rig.arm_w) * 1.25, col, P.arm_z(p, back) + 0.3, {"shade": 0.1})
		P.hand(cv, p, back, bone, p.thumb and not back)
	# Skull with a chattering jaw.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	var em := P.expression(p, "oval", "grin")
	var eyes: String = em[0]
	var mouth: String = em[1]
	var open := {"open": 0.22, "laugh": 0.32, "o": 0.16}.get(mouth, 0.0) as float
	if mouth == "laugh":
		open += absf(sin(float(p.t) * 22.0)) * 0.12
	var hinge := Vector2(-0.3, 0.45) * r
	var jxf := at * Transform2D(open, hinge) * Transform2D(0.0, -hinge)
	cv.poly("skel_jaw_%.2f" % r, P._hpts([Vector2(-0.3, 0.42), Vector2(0.86, 0.38), Vector2(0.96, 0.66), Vector2(0.62, 0.92), Vector2(0.02, 0.9), Vector2(-0.34, 0.68)], r), jxf, bone, P.Z_HEAD + 0.5, {"shade": 0.15})
	cv.poly("skel_skull_%.2f" % r, P._hpts([Vector2(-0.95, 0.2), Vector2(-1.0, -0.35), Vector2(-0.7, -0.88), Vector2(-0.1, -1.06), Vector2(0.55, -0.9),
		Vector2(0.95, -0.45), Vector2(1.02, 0.05), Vector2(0.92, 0.42), Vector2(0.3, 0.48), Vector2(-0.4, 0.5), Vector2(-0.8, 0.45)], r), at, bone, P.Z_HEAD, {"shade": 0.15})
	var dark := c(def, "dark")
	cv.detail(P.Z_FACE, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.7, k.in_w)
		for i in 2:
			var e := Vector2(0.12 + i * 0.46, -0.14) * r
			var s := 0.85 if i == 0 else 1.0
			k.fill_ellipse(e, Vector2(0.19, 0.23) * r * s, 0.0, dark)
			match eyes:
				"closed", "sleepy":
					k.line(e + Vector2(-0.12, 0.02) * r, e + Vector2(0.12, 0.02) * r, glow, lw)
				"happy":
					k.arc(e + Vector2(0, 0.06) * r, 0.1 * r, PI + 0.3, TAU - 0.3, glow, lw)
				"big":
					k.dot(e, 0.1 * r * s, glow)
				"angry":
					k.dot(e + Vector2(0, 0.04) * r, 0.065 * r * s, glow)
					k.line(e + Vector2(-0.2, -0.24 + (0.06 if i == 0 else -0.06)) * r, e + Vector2(0.2, -0.24 - (0.06 if i == 0 else -0.06)) * r, k.ink, lw * 1.3)
				_:
					k.dot(e + Vector2(0.03, 0.02) * r, 0.065 * r * s, glow)
		k.fill_poly(P._hpts([Vector2(0.86, 0.12), Vector2(0.98, 0.3), Vector2(0.82, 0.32)], r), dark)
		for i in 5:
			var x := lerpf(0.05, 0.8, float(i) / 4.0)
			k.ci.draw_line(Vector2(x, 0.4) * r, Vector2(x, 0.5) * r, dark, lw * 0.7, false)
		k.ci.draw_line(Vector2(-0.6, -0.62) * r, Vector2(-0.45, -0.42) * r, bone.darkened(0.3), lw * 0.7, false)
		k.pop())
	# Tweed flat cap.
	cv.poly("skel_cap_%.2f" % r, P._hpts([Vector2(-1.05, -0.35), Vector2(-0.98, -0.85), Vector2(-0.45, -1.15), Vector2(0.35, -1.12), Vector2(0.92, -0.78), Vector2(1.08, -0.5)], r), at, c(def, "cap"), P.Z_HAT, {"shade": 0.2})
	cv.poly("skel_brim_%.2f" % r, P._hpts([Vector2(0.55, -0.6), Vector2(1.58, -0.46), Vector2(1.5, -0.3), Vector2(0.5, -0.38)], r), at, c(def, "cap").darkened(0.2), P.Z_HAT + 0.2, {"shade": 0.0})
	cv.detail(P.Z_HAT + 0.3, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.5, k.in_w * 0.6)
		for i in 3:
			k.ci.draw_line(Vector2(-0.8 + i * 0.5, -0.95 + absf(i - 1) * 0.08) * r, Vector2(-0.6 + i * 0.5, -0.45) * r, c(def, "cap").darkened(0.25), lw, false)
		k.pop())
	P.club(cv, p, {"shaft": "#f3ecd8", "head": "#c8d1df"})


# ---------------------------------------------------------------------------
# Frost — yeti
# ---------------------------------------------------------------------------

static func frost(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var fur := c(def, "fur")
	var skin := c(def, "skin")
	var scarf := c(def, "scarf")
	var t := float(p.t)
	P.shoes(cv, p, skin, skin.darkened(0.25), 1.35, "yetifoot", [0, 1],
		[Vector2(-3.2, 0.0), Vector2(-3.4, -2.8), Vector2(-1.0, -3.8), Vector2(3.8, -3.4), Vector2(6.0, -2.4), Vector2(6.4, 0.0)], 0.0)
	# Fur body: dense spine with alternating radii gives a scalloped edge.
	var pts := PackedVector2Array()
	var rs := PackedFloat32Array()
	var n := 15
	for i in n:
		var tt := float(i) / float(n - 1)
		pts.append(Golfer.spine_at(p, tt))
		rs.append(_r(p, tt) + (0.9 if i % 2 == 0 else -0.2))
	cv.tube(pts, rs, fur, P.Z_BODY, {"shade": 0.2})
	cv.ellipse(spine_xf(p, 0.42) * Vector2(_r(p, 0.42) * 0.42, 0), Vector2(_r(p, 0.42) * 0.55, float(p.rig.body) * 0.36), spine_xf(p, 0.42).get_rotation(), c(def, "belly"), P.Z_BODY + 0.5, {"shade": 0.0, "rim": false})
	# Thick furry arms and big paws.
	for back: bool in [true, false]:
		var ap := P.arm_pts(p, back, 9)
		var ars := PackedFloat32Array()
		for i in ap.size():
			ars.append(float(p.rig.arm_w) * lerpf(1.15, 0.95, float(i) / 8.0) + (0.45 if i % 2 == 0 else 0.0))
		var col := ToonCanvas.shadow_of(fur, 0.12) if back else fur
		cv.tube(ap, ars, col, P.arm_z(p, back), {"shade": 0.14})
		P.hand(cv, p, back, skin, p.thumb and not back)
	# Head: fur dome with horns and a pale face patch.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	for side: float in [-1.0, 1.0]:
		var hx := -0.5 if side < 0.0 else 0.18
		var horn := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			horn.append(Vector2(hx - 0.2 + u * 0.1 - u * u * 0.5, -0.7 - u * 0.62) * r + Vector2(0.15, 0) * r * (1.0 - u) * 1.0)
		for i in 7:
			var u := 1.0 - float(i) / 6.0
			horn.append(Vector2(hx - 0.2 + u * 0.1 - u * u * 0.5, -0.7 - u * 0.62) * r + Vector2(-0.15, 0) * r * (1.0 - u) * 1.0 + Vector2(0.0, 0.0))
		cv.poly("frost_horn_%.2f_%d" % [r, int(side)], horn, at, c(def, "horn").darkened(0.12 if side < 0.0 else 0.0), P.Z_HEAD - 0.5, {"shade": 0.15})
	cv.poly("frost_head_%.2f" % r, P.scallop(P.head_shape("round", r * 1.04), 0.07 * r, 0.26 * r), at, fur, P.Z_HEAD, {"shade": 0.15})
	cv.ellipse(at * Vector2(0.38 * r, 0.1 * r), Vector2(0.58 * r, 0.6 * r), float(p.head_rot), skin, P.Z_HEAD + 0.3, {"shade": 0.12})
	P.face(cv, p, {"x": 0.38, "y": 0.06, "size": 0.95, "brows": skin.darkened(0.35), "cheeks": true, "mouth": "smile", "spacing": 0.44})
	var em := P.expression(p, "oval", "smile")
	cv.detail(P.Z_FACE + 0.2, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_ellipse(Vector2(0.66, 0.16) * r, Vector2(0.11, 0.07) * r, 0.0, skin.darkened(0.45))
		if em[1] in ["smile", "grin", "open", "laugh"]:
			for x: float in [0.4, 0.66]:
				k.fill_poly(P._hpts([Vector2(x - 0.06, 0.34), Vector2(x + 0.06, 0.34), Vector2(x, 0.46)], r), Color.WHITE)
		k.pop())
	# Scarf wrapped at the neck, tails flapping behind.
	var neck := Golfer.spine_at(p, 0.86)
	var nf := Golfer.spine_fwd(p, 0.86)
	var nr := _r(p, 0.86)
	var flap := sin(t * TAU / 0.8) * 1.2 + float(p.sway) * 4.0
	var back_dir := -nf
	for k2 in 2:
		var tail0 := neck + back_dir * (nr - 1.0)
		var tail1 := tail0 + back_dir * (7.0 - k2 * 1.5) + Vector2(0, 6.0 + k2 * 3.5 + flap * (1.0 - k2 * 0.5))
		cv.capsule(tail0, tail1, 2.4, 2.1, scarf.darkened(0.08 * k2), P.Z_BODY - 1.0 - k2, {"shade": 0.12})
	var wrap0 := neck - nf * (nr + 0.5)
	var wrap1 := neck + nf * (nr + 0.5)
	cv.capsule(wrap0, wrap1, 3.2, 3.2, scarf, P.Z_CLOTH + 2.0, {"shade": 0.15})
	cv.detail(P.Z_CLOTH + 2.1, func(k: ToonCanvas) -> void:
		var lw := maxf(0.8, k.in_w * 1.2)
		for u: float in [0.3, 0.55, 0.8]:
			var m := wrap0.lerp(wrap1, u)
			k.line(m + Vector2(0, -2.2), m + Vector2(0, 2.2), c(def, "scarf2"), lw))
	P.club(cv, p, {"shaft": "#9fe3ff", "head": "#e6f7ff"})


# ---------------------------------------------------------------------------
# Dusty — cowboy
# ---------------------------------------------------------------------------

static func cowboy(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var hat := c(def, "hat")
	var leather := c(def, "leather")
	var gold := c(def, "gold")
	P.shoes(cv, p, c(def, "boot"), c(def, "boot").darkened(0.45), 1.05, "cowboot", [0, 1],
		[Vector2(-3.4, 0.0), Vector2(-3.6, -6.4), Vector2(0.2, -6.6), Vector2(0.8, -3.4), Vector2(4.4, -3.0), Vector2(6.6, -1.4), Vector2(6.4, 0.0), Vector2(-1.4, 0.0), Vector2(-1.8, 1.0), Vector2(-3.4, 1.0)], 0.9)
	cv.detail(P.Z_FEET + 0.9, func(k: ToonCanvas) -> void:
		for i in 2:
			k.push(P.foot_xf(p, i))
			ToonParts._star(k, Vector2(-4.6, -1.6), 1.5, gold)
			k.pop())
	P.bean(cv, p, c(def, "shirt"), P.Z_BODY)
	band(cv, p, c(def, "jeans"), P.Z_CLOTH - 1.0, 0.0, 0.3, 0.6)
	# Leather vest open at the front, showing the shirt.
	band(cv, p, leather, P.Z_CLOTH, 0.32, 0.98, 0.7)
	var vx := spine_xf(p, 0.66)
	var rv := _r(p, 0.66)
	var len := float(p.rig.body) * float(p.squash)
	cv.poly("cowboy_shirt_%.1f_%.1f" % [rv, len], PackedVector2Array([Vector2(rv * 0.3, -len * 0.33), Vector2(rv + 0.6, -len * 0.33), Vector2(rv + 0.6, len * 0.3), Vector2(rv * 0.55, len * 0.3)]),
		vx, c(def, "shirt"), P.Z_CLOTH + 0.3, {"shade": 0.12})
	cv.detail(P.Z_CLOTH + 0.4, func(k: ToonCanvas) -> void:
		var bp := Golfer.spine_at(p, 0.62) + Golfer.spine_fwd(p, 0.62) * _r(p, 0.62) * 0.05
		ToonParts._star(k, bp, 2.4, k.ink)
		ToonParts._star(k, bp, 1.8, gold))
	band(cv, p, leather.darkened(0.3), P.Z_CLOTH + 0.6, 0.27, 0.32, 0.8)
	cv.poly("cowboy_buckle", ToonCharacters.round_rect(Vector2(2.6, 2.0), 0.8), spine_xf(p, 0.295).translated_local(Vector2(_r(p, 0.295) - 1.0, 0)), gold, P.Z_CLOTH + 0.8, {"shade": 0.15})
	for back: bool in [true, false]:
		P.arm(cv, p, back, c(def, "shirt"), Color(0, 0, 0, 0), 0.0, 1.05)
		cuff(cv, p, back, c(def, "shirt").darkened(0.12), 0.84, 0.6)
		P.hand(cv, p, back, skin, p.thumb and not back)
	# Head: bandana, handlebar moustache, ten-gallon hat.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	var bandana := c(def, "bandana")
	var nk := Golfer.spine_at(p, 0.93)
	var nkf := Golfer.spine_fwd(p, 0.93)
	var nkr := _r(p, 0.93)
	cv.capsule(nk - nkf * (nkr + 0.3), nk + nkf * (nkr + 0.3), 2.3, 2.3, bandana, P.Z_CLOTH + 2.0, {"shade": 0.15})
	var tri := spine_xf(p, 0.84)
	cv.poly("cowboy_bandana", PackedVector2Array([Vector2(0.5, -3.0), Vector2(nkr + 0.6, -3.0), Vector2(nkr * 0.62, 4.6)]), tri, bandana, P.Z_CLOTH + 2.1, {"shade": 0.12})
	cv.detail(P.Z_CLOTH + 2.2, func(k: ToonCanvas) -> void:
		k.push(tri)
		for d: Vector2 in [Vector2(2.6, -1.6), Vector2(5.6, -1.8), Vector2(4.6, 1.0)]:
			k.dot(d, 0.55, Color.WHITE)
		k.pop())
	round_head(cv, p, skin, "oval")
	P.face(cv, p, {"x": 0.34, "eyes": "oval", "size": 0.9, "brows": c(def, "stache").darkened(0.1), "nose": "button", "skin": skin, "mouth": "smirk"})
	cv.detail(P.Z_FACE + 0.4, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_poly(P._hpts([Vector2(0.18, 0.4), Vector2(0.42, 0.26), Vector2(0.7, 0.24), Vector2(0.98, 0.3), Vector2(1.2, 0.2), Vector2(1.28, 0.02), Vector2(1.36, 0.16),
			Vector2(1.24, 0.42), Vector2(0.98, 0.46), Vector2(0.66, 0.38), Vector2(0.36, 0.48), Vector2(0.08, 0.58), Vector2(-0.08, 0.42), Vector2(-0.02, 0.56)], r), c(def, "stache"))
		k.pop())
	var brim := PackedVector2Array()
	for i in 17:
		var x := lerpf(-2.0, 2.1, float(i) / 16.0)
		brim.append(Vector2(x, -0.5 - 0.1 * x * x + 0.24) * r)
	for i in 17:
		var x := lerpf(2.1, -2.0, float(i) / 16.0)
		brim.append(Vector2(x, -0.5 - 0.1 * x * x) * r)
	cv.poly("cowboy_brim_%.2f" % r, brim, at, hat.darkened(0.12), P.Z_HAT, {"shade": 0.1})
	cv.poly("cowboy_crown_%.2f" % r, P._hpts([Vector2(-0.84, -0.55), Vector2(0.84, -0.55), Vector2(0.8, -1.3), Vector2(0.6, -1.56), Vector2(0.28, -1.62), Vector2(0.0, -1.48),
		Vector2(-0.28, -1.62), Vector2(-0.6, -1.56), Vector2(-0.8, -1.3)], r), at, hat, P.Z_HAT + 0.2, {"shade": 0.2})
	cv.poly("cowboy_band_%.2f" % r, P._hpts([Vector2(-0.82, -0.58), Vector2(0.82, -0.58), Vector2(0.83, -0.8), Vector2(-0.82, -0.8)], r), at, leather.darkened(0.4), P.Z_HAT + 0.3, {"shade": 0.0, "rim": false})
	P.club(cv, p, {"shaft": "#d9c8a2", "head": "#c8d1df"})


# ---------------------------------------------------------------------------
# Sir Putts — knight
# ---------------------------------------------------------------------------

static func knight(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var steel := c(def, "steel")
	var gold := c(def, "gold")
	var tabard := c(def, "tabard")
	var cape := c(def, "cape")
	var t := float(p.t)
	var sway := float(p.sway)
	# Cape from the shoulders to the heels, swinging with motion.
	var sh := P.shoulder(p, true)
	var neck: Vector2 = p.top
	var back := -(p.fwd as Vector2)
	var flutter := sin(t * Golfer.BREATH * 1.5) * 0.8 + sway * 4.0
	var cpts := PackedVector2Array([neck + back * 3.0 + Vector2(0, -1.0), sh + back * 2.5])
	for i in 6:
		var u := float(i) / 5.0
		cpts.append(Vector2(lerpf(sh.x + back.x * 9.0 + flutter, (p.base as Vector2).x + back.x * 2.0, u), -2.5 + sin(u * PI * 2.0 + t * 3.0) * 0.6))
	cv.blob(cpts, cape, P.Z_REAR, {"shade": 0.2})
	P.shoes(cv, p, steel, steel.darkened(0.35), 1.1, "sabaton", [0, 1],
		[Vector2(-3.4, 0.0), Vector2(-3.6, -3.8), Vector2(-0.8, -5.0), Vector2(3.0, -3.8), Vector2(7.4, -1.0), Vector2(7.0, 0.0)], 1.0)
	P.bean(cv, p, steel, P.Z_BODY, {"shade": 0.22})
	band(cv, p, tabard, P.Z_CLOTH, 0.08, 0.88, 0.5)
	band(cv, p, gold, P.Z_CLOTH + 0.3, 0.08, 0.13, 0.7)
	band(cv, p, steel.darkened(0.2), P.Z_CLOTH + 0.4, 0.3, 0.36, 0.8)
	var crest := spine_xf(p, 0.6).translated_local(Vector2(_r(p, 0.6) * 0.38, 0))
	cv.circle(crest.origin, 3.6, gold, P.Z_CLOTH + 0.5, {"shade": 0.15, "hl": 0.3})
	cv.detail(P.Z_CLOTH + 0.6, func(k: ToonCanvas) -> void:
		for d: Vector2 in [Vector2(-1.2, -1.0), Vector2(0.8, -1.4), Vector2(1.4, 0.6), Vector2(-0.6, 1.2), Vector2(0.3, -0.1)]:
			k.dot(crest.origin + d, 0.42, gold.darkened(0.3)))
	# Plated arms, pauldrons and gauntlets.
	for b: bool in [true, false]:
		P.arm(cv, p, b, steel, Color(0, 0, 0, 0), 0.0, 1.1)
		cuff(cv, p, b, steel.darkened(0.12), 0.45, 0.8)
		P.hand(cv, p, b, steel.darkened(0.06), p.thumb and not b)
		var pc := ToonCanvas.shadow_of(steel, 0.12) if b else steel
		cv.ellipse(P.shoulder(p, b) + Vector2(0, -0.5), Vector2(4.4, 3.6), (p.fwd as Vector2).angle(), pc, P.arm_z(p, b) + 0.8, {"shade": 0.18, "hl": 0.25})
	# Bucket helm with a visor slit, plume on top.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	var pl := PackedVector2Array()
	var prs := PackedFloat32Array()
	var bend := sway * 0.35 + sin(t * 2.0) * 0.05
	for i in 9:
		var u := float(i) / 8.0
		pl.append(at * (Vector2(-0.1 - u * 1.25, -1.0 - sin(u * 2.4) * 0.75 + u * u * 0.6).rotated(bend * u) * r))
		prs.append(lerpf(0.26, 0.12, u) * r + (0.06 * r if i % 2 == 0 else 0.0))
	cv.tube(pl, prs, c(def, "plume"), P.Z_HEAD_BACK, {"shade": 0.18})
	cv.poly("knight_helm_%.2f" % r, ToonCharacters.round_rect(Vector2(1.0, 1.08) * r, 0.42 * r), at.translated_local(Vector2(0.06 * r, -0.04 * r)), steel, P.Z_HEAD, {"shade": 0.2})
	cv.poly("knight_slit_%.2f" % r, ToonCharacters.round_rect(Vector2(0.6, 0.14) * r, 0.1 * r), at.translated_local(Vector2(0.48 * r, -0.12 * r)), c(def, "dark"), P.Z_HEAD + 0.4, {"shade": 0.0})
	var em := P.expression(p, "oval", "smile")
	cv.detail(P.Z_FACE, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.8, k.in_w * 1.1)
		var eyes: String = em[0]
		for i in 2:
			var e := Vector2(0.26 + i * 0.42, -0.12) * r
			match eyes:
				"closed", "sleepy":
					k.line(e + Vector2(-0.08, 0) * r, e + Vector2(0.08, 0) * r, c(def, "eye"), lw)
				"happy":
					k.arc(e + Vector2(0, 0.06) * r, 0.08 * r, PI + 0.3, TAU - 0.3, c(def, "eye"), lw)
				"big":
					k.dot(e, 0.1 * r, c(def, "eye"))
				_:
					k.dot(e, 0.065 * r, c(def, "eye"))
		k.ci.draw_line(Vector2(-0.6, -1.0) * r, Vector2(-0.6, 0.9) * r, steel.darkened(0.25), lw * 0.7, false)
		for i in 3:
			for j in 2:
				k.dot(Vector2(0.55 + i * 0.16, 0.36 + j * 0.18) * r, 0.04 * r, c(def, "dark"))
		k.pop())
	P.club(cv, p, {"shaft": "#c3cbd9", "grip": "#3a5bd9", "head": "#ffd166"})


# ---------------------------------------------------------------------------
# Original roster, redrawn: Ace, Nana Birdie, Brick, Skipper
# ---------------------------------------------------------------------------

static func ace(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var polo := c(def, "shirt")
	P.shoes(cv, p, Color.WHITE, c(def, "shoe2"), 1.0, "saddle")
	cv.detail(P.Z_FEET + 0.9, func(k: ToonCanvas) -> void:
		for i in 2:
			k.push(P.foot_xf(p, i))
			k.fill_ellipse(Vector2(1.2, -2.6), Vector2(2.2, 1.4), 0.0, c(def, "shoe2"))
			k.pop())
	P.bean(cv, p, c(def, "pants"), P.Z_BODY)
	band(cv, p, polo, P.Z_CLOTH, 0.32, 1.0, 0.7)
	band(cv, p, Color("2b2d42"), P.Z_CLOTH - 0.5, 0.27, 0.33, 0.7)
	var cx := spine_xf(p, 0.97)
	cv.poly("ace_collar_a", PackedVector2Array([Vector2(1.0, -1.5), Vector2(7.5, -0.5), Vector2(3.0, 4.0)]), cx, Color.WHITE, P.Z_CLOTH + 1.0, {"shade": 0.0})
	cv.poly("ace_collar_b", PackedVector2Array([Vector2(-5.0, -1.0), Vector2(1.5, -1.5), Vector2(-1.0, 3.5)]), cx, Color.WHITE.darkened(0.08), P.Z_CLOTH + 0.9, {"shade": 0.0})
	cv.detail(P.Z_CLOTH + 0.8, func(k: ToonCanvas) -> void:
		var a := Golfer.spine_at(p, 0.9) + Golfer.spine_fwd(p, 0.9) * (_r(p, 0.9) - 3.5)
		var b := Golfer.spine_at(p, 0.72) + Golfer.spine_fwd(p, 0.72) * (_r(p, 0.72) - 3.0)
		k.line(a, b, polo.darkened(0.35), maxf(0.5, k.in_w * 0.8))
		k.dot(a.lerp(b, 0.5), 0.75, Color.WHITE))
	for back: bool in [true, false]:
		P.arm(cv, p, back, skin, polo, 0.42)
		P.hand(cv, p, back, skin if back else Color.WHITE, p.thumb and not back)
	var r := float(p.head_r)
	var at := P.head_xf(p)
	round_head(cv, p, skin)
	cv.poly("ace_hair_%.2f" % r, P.head_poly([Vector2(-1.0, 0.1), Vector2(-1.02, -0.5), Vector2(-0.6, -0.95), Vector2(0.1, -1.06), Vector2(0.72, -0.86),
		Vector2(0.95, -0.55), Vector2(0.5, -0.62), Vector2(-0.2, -0.5), Vector2(-0.62, -0.08)], r, 0.04, 0.2), at, c(def, "hair"), P.Z_HEAD + 0.3, {"shade": 0.15})
	P.face(cv, p, {"x": 0.36, "brows": c(def, "hair").darkened(0.2), "nose": "button", "skin": skin, "mouth": "smirk"})
	cv.poly("ace_visor_%.2f" % r, P._hpts([Vector2(-1.0, -0.66), Vector2(0.8, -0.76), Vector2(0.86, -0.5), Vector2(-0.98, -0.42)], r), at, Color.WHITE, P.Z_HAT, {"shade": 0.12})
	cv.poly("ace_brim_%.2f" % r, P._hpts([Vector2(0.55, -0.72), Vector2(1.62, -0.6), Vector2(1.56, -0.42), Vector2(0.6, -0.48)], r), at, c(def, "hat2"), P.Z_HAT + 0.2, {"shade": 0.15})
	P.club(cv, p, {"head": "#c8d1df", "kind": "wood", "shaft": "#2b2d42"})


static func nana(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var card := c(def, "shirt")
	var skirt := c(def, "pants")
	var t := float(p.t)
	P.shoes(cv, p, c(def, "shoe"), c(def, "shoe").darkened(0.4), 0.9, "nanashoe")
	# Stocking legs under a pleated skirt.
	for i in 2:
		var f: Vector2 = p.feet[i]
		var col := Color("e9d8cf").darkened(0.1 if i == 0 else 0.0)
		cv.capsule((p.base as Vector2) + Vector2(-1.5 + i * 3.0, 4.0), f + Vector2(0.3, -3.0), 1.7, 1.5, col, P.Z_FEET - 0.5 + i * 0.5, {"shade": 0.1})
	P.bean(cv, p, card, P.Z_BODY)
	var base: Vector2 = p.base
	var r0 := _r(p, 0.0)
	var up: Vector2 = p.up
	var fwd: Vector2 = p.fwd
	var top_t := 0.36
	var tc := Golfer.spine_at(p, top_t)
	var tf := Golfer.spine_fwd(p, top_t)
	var tr := _r(p, top_t)
	var sk := PackedVector2Array([tc - tf * (tr + 0.4), tc + tf * (tr + 0.4)])
	var sw := float(p.sway) * 1.2
	for i in 7:
		var u := float(i) / 6.0
		sk.append(base + up * -(r0 + 1.0) + fwd * lerpf(r0 * 1.18 + sw, -r0 * 1.22 + sw, u) + Vector2(0, sin(u * PI * 3.0) * 0.4))
	cv.blob(sk, skirt, P.Z_BODY + 0.5, {"shade": 0.18})
	cv.detail(P.Z_BODY + 0.6, func(k: ToonCanvas) -> void:
		for i in 4:
			var u := lerpf(0.2, 0.8, float(i) / 3.0)
			k.line(sk[0].lerp(sk[1], u), sk[sk.size() - 1].lerp(sk[2], u), skirt.darkened(0.22), maxf(0.5, k.in_w * 0.7)))
	# Blouse front, buttons, pearls.
	var vx := spine_xf(p, 0.7)
	var rv := _r(p, 0.7)
	cv.poly("nana_blouse_%.1f" % rv, PackedVector2Array([Vector2(rv * 0.35, -9.0), Vector2(rv, -9.0), Vector2(rv, 6.0), Vector2(rv * 0.55, 6.0)]), vx, c(def, "shirt2"), P.Z_CLOTH, {"shade": 0.0})
	cv.detail(P.Z_CLOTH + 0.2, func(k: ToonCanvas) -> void:
		for i in 3:
			var tt := 0.5 + i * 0.13
			k.dot(Golfer.spine_at(p, tt) + Golfer.spine_fwd(p, tt) * (_r(p, tt) * 0.5), 0.8, Color("ffd166"))
		for i in 7:
			var u := lerpf(-0.9, 0.9, float(i) / 6.0)
			var cc := Golfer.spine_at(p, 0.95) + Golfer.spine_fwd(p, 0.95) * (2.5 + u * 4.5) + (p.up as Vector2) * -(1.2 - absf(u) * 1.0)
			k.dot(cc, 0.9, Color("fffaf0")))
	for back: bool in [true, false]:
		P.arm(cv, p, back, card, Color(0, 0, 0, 0), 0.0, 1.1)
		cuff(cv, p, back, c(def, "shirt2"), 0.84, 0.7)
		P.hand(cv, p, back, skin, p.thumb and not back)
	var r := float(p.head_r)
	var at := P.head_xf(p)
	cv.circle(at * Vector2(-0.88 * r, -0.35 * r), 0.42 * r, c(def, "hair"), P.Z_HEAD - 0.5, {"shade": 0.12})
	round_head(cv, p, skin)
	cv.poly("nana_curls_%.2f" % r, P.head_poly([Vector2(-1.02, 0.25), Vector2(-1.05, -0.4), Vector2(-0.7, -0.9), Vector2(-0.1, -1.05), Vector2(0.55, -0.9),
		Vector2(0.88, -0.55), Vector2(0.4, -0.55), Vector2(-0.2, -0.5), Vector2(-0.6, -0.25), Vector2(-0.72, 0.18)], r, 0.09, 0.26), at, c(def, "hair"), P.Z_HEAD + 0.3, {"shade": 0.12})
	P.face(cv, p, {"x": 0.36, "brows": c(def, "brow"), "nose": "button", "skin": skin, "cheeks": true, "mouth": "smile"})
	cv.detail(P.Z_FACE + 0.4, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.7, k.in_w * 0.9)
		var gc := c(def, "glasses")
		for ex: float in [0.13, 0.59]:
			k.arc(Vector2(ex, -0.11) * r, 0.2 * r, 0.0, TAU, gc, lw, 20)
		k.line(Vector2(0.33, -0.13) * r, Vector2(0.39, -0.13) * r, gc, lw)
		k.line(Vector2(-0.07, -0.13) * r, Vector2(-0.4, -0.2) * r, gc, lw)
		k.pop())
	# Straw sun hat with a ribbon and flower.
	var brim := PackedVector2Array()
	for i in 15:
		var x := lerpf(-1.7, 1.75, float(i) / 14.0)
		brim.append(Vector2(x, -0.62 + 0.08 * x * x) * r)
	for i in 15:
		var x := lerpf(1.75, -1.7, float(i) / 14.0)
		brim.append(Vector2(x, -0.78 + 0.05 * x * x) * r)
	cv.poly("nana_brim_%.2f" % r, brim, at, c(def, "hat"), P.Z_HAT, {"shade": 0.1})
	cv.poly("nana_crown_%.2f" % r, P._hpts([Vector2(-0.8, -0.72), Vector2(0.82, -0.72), Vector2(0.68, -1.25), Vector2(0.2, -1.38), Vector2(-0.4, -1.32), Vector2(-0.74, -1.18)], r), at, c(def, "hat"), P.Z_HAT + 0.2, {"shade": 0.18})
	cv.poly("nana_ribbon_%.2f" % r, P._hpts([Vector2(-0.8, -0.74), Vector2(0.82, -0.74), Vector2(0.79, -0.92), Vector2(-0.78, -0.92)], r), at, c(def, "hat2"), P.Z_HAT + 0.3, {"shade": 0.0, "rim": false})
	var fl := at * (Vector2(-0.62, -0.88) * r)
	cv.detail(P.Z_HAT + 0.4, func(k: ToonCanvas) -> void:
		for i in 5:
			var a := TAU * float(i) / 5.0 + t * 0.2
			k.dot(fl + Vector2.from_angle(a) * 0.15 * r, 0.12 * r, Color.WHITE)
		k.dot(fl, 0.1 * r, Color("ffd166")))
	P.club(cv, p, {"shaft": "#ff8fab", "head": "#c8d1df"})


static func brick(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var shirt := c(def, "shirt")
	var plaid := c(def, "shirt2")
	P.shoes(cv, p, c(def, "shoe"), c(def, "shoe2"), 1.25, "brickboot", [0, 1],
		[Vector2(-3.4, 0.0), Vector2(-3.8, -4.6), Vector2(-1.0, -5.6), Vector2(3.4, -4.8), Vector2(5.8, -3.0), Vector2(6.2, 0.0)], 1.5)
	P.bean(cv, p, shirt, P.Z_BODY)
	band(cv, p, c(def, "pants"), P.Z_CLOTH - 1.0, 0.0, 0.28, 0.6)
	cv.detail(P.Z_CLOTH - 0.5, func(k: ToonCanvas) -> void:
		var lw := maxf(1.0, k.in_w * 1.7)
		var col := Color(plaid, 0.4)
		for tt: float in [0.42, 0.58, 0.74, 0.9]:
			var rr := _r(p, tt) - 0.6
			k.line(Golfer.spine_at(p, tt) - Golfer.spine_fwd(p, tt) * rr, Golfer.spine_at(p, tt) + Golfer.spine_fwd(p, tt) * rr, col, lw)
		for x: float in [-0.5, 0.0, 0.5]:
			var line := PackedVector2Array()
			for i in 6:
				var tt := lerpf(0.31, 0.98, float(i) / 5.0)
				line.append(Golfer.spine_at(p, tt) + Golfer.spine_fwd(p, tt) * x * _r(p, tt))
			k.polyline(line, col, lw * 0.8))
	band(cv, p, c(def, "belt"), P.Z_CLOTH, 0.26, 0.32, 0.7)
	cv.poly("brick_buckle", ToonCharacters.round_rect(Vector2(2.6, 2.1), 0.7), spine_xf(p, 0.29).translated_local(Vector2(_r(p, 0.29) - 1.2, 0)), Color("c9cdd6"), P.Z_CLOTH + 0.4, {"shade": 0.15})
	for back: bool in [true, false]:
		P.arm(cv, p, back, skin, shirt, 0.48)
		cuff(cv, p, back, shirt.lightened(0.1), 0.42, 1.4)
		P.hand(cv, p, back, skin, p.thumb and not back)
	var r := float(p.head_r)
	var at := P.head_xf(p)
	round_head(cv, p, skin)
	var hair := c(def, "hair")
	cv.poly("brick_beard_%.2f" % r, P.head_poly([Vector2(-0.6, -0.05), Vector2(-0.3, 0.2), Vector2(0.3, 0.32), Vector2(0.92, 0.22), Vector2(1.06, 0.5),
		Vector2(0.86, 1.0), Vector2(0.25, 1.3), Vector2(-0.38, 1.0), Vector2(-0.72, 0.42)], r, 0.08, 0.22), at, hair, P.Z_HEAD + 0.4, {"shade": 0.15})
	P.face(cv, p, {"x": 0.36, "brows": hair.darkened(0.2), "nose": "button", "skin": skin, "mouth": "grin"})
	cv.detail(P.Z_FACE + 0.4, func(k: ToonCanvas) -> void:
		k.push(at)
		k.fill_poly(P.head_poly([Vector2(0.24, 0.38), Vector2(0.6, 0.26), Vector2(1.02, 0.36), Vector2(0.94, 0.5), Vector2(0.62, 0.42), Vector2(0.3, 0.52)], r, 0.03, 0.12), hair.darkened(0.1))
		k.pop())
	cv.poly("brick_beanie_%.2f" % r, P._hpts([Vector2(-1.1, -0.45), Vector2(-1.0, -0.95), Vector2(-0.5, -1.3), Vector2(0.2, -1.34), Vector2(0.78, -1.1), Vector2(1.0, -0.62), Vector2(0.98, -0.45)], r), at, c(def, "hat"), P.Z_HAT, {"shade": 0.18})
	cv.poly("brick_cuff_%.2f" % r, P._hpts([Vector2(-1.14, -0.32), Vector2(1.02, -0.38), Vector2(1.04, -0.66), Vector2(-1.12, -0.64)], r), at, c(def, "hat2"), P.Z_HAT + 0.2, {"shade": 0.1})
	cv.detail(P.Z_HAT + 0.3, func(k: ToonCanvas) -> void:
		k.push(at)
		for i in 6:
			var x := lerpf(-0.92, 0.84, float(i) / 5.0)
			k.ci.draw_line(Vector2(x, -0.4) * r, Vector2(x, -0.62) * r, c(def, "hat2").darkened(0.3), maxf(0.5, k.in_w * 0.7), false)
		k.pop())
	P.club(cv, p, {"shaft": "#8a5a3c", "head": "#c8d1df"})


static func skipper(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var tee := c(def, "shirt")
	var t := float(p.t)
	P.shoes(cv, p, c(def, "shoe"), Color.WHITE, 0.95, "kidshoe")
	cv.detail(P.Z_FEET + 0.9, func(k: ToonCanvas) -> void:
		for i in 2:
			k.push(P.foot_xf(p, i))
			k.ci.draw_line(Vector2(-0.6, -3.6), Vector2(1.8, -2.6), Color.WHITE, 0.8, false)
			k.ci.draw_line(Vector2(0.6, -4.0), Vector2(3.0, -3.0), Color.WHITE, 0.8, false)
			k.pop())
	for i in 2:
		var f: Vector2 = p.feet[i]
		var col := ToonCanvas.shadow_of(skin, 0.12) if i == 0 else skin
		cv.capsule((p.base as Vector2) + Vector2(-2.0 + i * 4.0, 4.0), f + Vector2(0.4, -3.6), 2.0, 1.8, col, P.Z_FEET - 0.5 + i * 0.5, {"shade": 0.1})
	P.bean(cv, p, tee, P.Z_BODY)
	band(cv, p, c(def, "pants"), P.Z_CLOTH - 1.0, 0.0, 0.3, 0.6)
	band(cv, p, c(def, "shirt2"), P.Z_CLOTH, 0.48, 0.58, 0.5, false)
	band(cv, p, c(def, "shirt2"), P.Z_CLOTH, 0.7, 0.8, 0.5, false)
	for back: bool in [true, false]:
		P.arm(cv, p, back, skin, tee, 0.4)
		P.hand(cv, p, back, skin, p.thumb and not back)
	var r := float(p.head_r)
	var at := P.head_xf(p)
	round_head(cv, p, skin)
	cv.poly("skip_hair_%.2f" % r, P.head_poly([Vector2(-1.0, -0.05), Vector2(-0.92, -0.62), Vector2(-0.4, -0.86), Vector2(0.5, -0.8), Vector2(0.86, -0.52),
		Vector2(0.62, -0.38), Vector2(0.4, -0.5), Vector2(0.15, -0.36), Vector2(-0.3, -0.46), Vector2(-0.62, -0.16)], r, 0.05, 0.18), at, c(def, "hair"), P.Z_HEAD + 0.3, {"shade": 0.12})
	P.face(cv, p, {"x": 0.36, "size": 1.12, "brows": c(def, "hair"), "nose": "button", "skin": skin, "mouth": "grin", "spacing": 0.48})
	cv.detail(P.Z_FACE + 0.3, func(k: ToonCanvas) -> void:
		k.push(at)
		for f: Vector2 in [Vector2(0.42, 0.14), Vector2(0.52, 0.2), Vector2(0.36, 0.22), Vector2(0.78, 0.14), Vector2(0.88, 0.2)]:
			k.dot(f * r, 0.035 * r, skin.darkened(0.35))
		k.pop())
	cv.poly("skip_cap_%.2f" % r, P._hpts([Vector2(-1.0, -0.42), Vector2(-0.86, -0.9), Vector2(-0.3, -1.12), Vector2(0.3, -1.1), Vector2(0.82, -0.8), Vector2(0.96, -0.42)], r), at, c(def, "hat"), P.Z_HAT, {"shade": 0.15})
	cv.poly("skip_seg_%.2f" % r, P._hpts([Vector2(-0.28, -1.11), Vector2(0.3, -1.09), Vector2(0.36, -0.46), Vector2(-0.22, -0.44)], r), at, c(def, "hat2"), P.Z_HAT + 0.1, {"shade": 0.1, "rim": false})
	cv.poly("skip_brim_%.2f" % r, P._hpts([Vector2(0.62, -0.52), Vector2(1.6, -0.44), Vector2(1.54, -0.28), Vector2(0.6, -0.34)], r), at, c(def, "hat"), P.Z_HAT + 0.2, {"shade": 0.18})
	var spin := cos(t * TAU * 3.0)
	cv.detail(P.Z_HAT + 0.4, func(k: ToonCanvas) -> void:
		k.push(at)
		var hub := Vector2(0.0, -1.22) * r
		k.line(hub, Vector2(0.0, -1.42) * r, k.ink, maxf(1.0, k.in_w * 1.4))
		var top := Vector2(0.0, -1.46) * r
		var w := 0.78 * r * spin
		k.line(top - Vector2(w, 0), top + Vector2(w, 0), k.ink, 0.36 * r)
		k.line(top - Vector2(w, 0), top + Vector2(w, 0), Color("ffd166"), 0.36 * r - k.in_w * 1.6)
		k.dot(top, 0.12 * r, c(def, "hat2"))
		k.pop())
	P.club(cv, p, {"shaft": "#ffd166", "head": "#c8d1df"})
