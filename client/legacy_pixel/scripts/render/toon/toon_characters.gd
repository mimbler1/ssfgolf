class_name ToonCharacters
extends RefCounted
## Character builders: each turns a solved pose into parts on a ToonCanvas. They share the
## skeleton and the part library (ToonParts) but own their silhouettes, so a robot can roll on a
## wheel and a dinosaur can lean over its tail without either being a person in a costume.
##
## Add a builder here, then an entry in CharacterDefs.ROSTER, then run tests/test_characters.gd.

const P := preload("res://scripts/render/toon/toon_parts.gd")

const BUILDERS := ["classic", "robot", "dino", "pirate", "wizard", "astronaut", "skeleton", "frost", "cowboy", "knight",
	"ace", "nana", "brick", "skipper"]


static func has_builder(id: String) -> bool:
	return id in BUILDERS


static func build(cv: ToonCanvas, id: String, def: Dictionary, p: Dictionary, app: Dictionary) -> void:
	match str(def.get("builder", "classic")):
		"robot":
			_robot(cv, p, def)
		"dino":
			_dino(cv, p, def)
		"pirate":
			ToonRoster.pirate(cv, p, def)
		"wizard":
			ToonRoster.wizard(cv, p, def)
		"astronaut":
			ToonRoster.astronaut(cv, p, def)
		"skeleton":
			ToonRoster.skeleton(cv, p, def)
		"frost":
			ToonRoster.frost(cv, p, def)
		"cowboy":
			ToonRoster.cowboy(cv, p, def)
		"knight":
			ToonRoster.knight(cv, p, def)
		"ace":
			ToonRoster.ace(cv, p, def)
		"nana":
			ToonRoster.nana(cv, p, def)
		"brick":
			ToonRoster.brick(cv, p, def)
		"skipper":
			ToonRoster.skipper(cv, p, def)
		_:
			_classic(cv, p, def, app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Transform at spine position t: local +x points to the golfer's front, +y down the spine.
static func spine_xf(p: Dictionary, t: float) -> Transform2D:
	var f := Golfer.spine_fwd(p, t)
	return Transform2D(f.angle(), Golfer.spine_at(p, t))


static func round_rect(half: Vector2, rad: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(half.x - rad, half.y - rad), Vector2(-half.x + rad, half.y - rad), Vector2(-half.x + rad, -half.y + rad), Vector2(half.x - rad, -half.y + rad)]
	for k in 4:
		for i in seg + 1:
			var a := PI * 0.5 * k + PI * 0.5 * float(i) / float(seg)
			pts.append((cs[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func c(def: Dictionary, key: String) -> Color:
	return CharacterDefs.color(def, key)


## Soft gloss on a round head (upper-left, mirrored with facing).
static func gloss(cv: ToonCanvas, at: Vector2, r: float, z: float, alpha: float = 0.35) -> void:
	var l := cv.light()
	cv.detail(z, func(k: ToonCanvas) -> void:
		k.fill_ellipse(at + l * r * 0.55, Vector2(r * 0.26, r * 0.13), l.angle() + PI * 0.5, Color(1, 1, 1, alpha)))


# ---------------------------------------------------------------------------
# Classic stickman (fully customisable)
# ---------------------------------------------------------------------------

static func _classic(cv: ToonCanvas, p: Dictionary, def: Dictionary, app: Dictionary) -> void:
	var body := Color(app.bodyColor)
	cv.ink = Color(app.outlineColor)
	var shirt: Variant = app.shirt
	var sc := Color(app.shirtColor)
	var r := float(p.head_r)
	var feature := Color("fdfdfd") if body.get_luminance() < 0.36 else Color("1d1a2b")

	P.shoes(cv, p, Color("f4f1de"), c(def, "shoe"))
	P.bean(cv, p, body, P.Z_BODY)
	var sleeve := 0.0
	if shirt != null:
		var kind := str(shirt)
		var t0 := 0.18 if kind == "hoodie" else 0.3
		P.band(cv, p, sc, P.Z_CLOTH, t0, 1.0, 0.7)
		sleeve = {"tee": 0.42, "polo": 0.42, "jersey": 0.5, "hoodie": 0.86, "vest": 0.0}.get(kind, 0.4)
		_classic_shirt(cv, p, kind, sc)
	P.arms_and_hands(cv, p, body, body.lightened(0.08), sc, sleeve)

	var at := P.head_xf(p)
	var shape := str(app.headShape)
	if shirt != null and str(shirt) == "hoodie":
		cv.circle(at * Vector2(-0.3 * r, 0.22 * r), r * 1.08, sc.darkened(0.15), P.Z_HEAD_BACK, {"shade": 0.15})
	cv.poly("head_%s_%.2f" % [shape, r], P.head_shape(shape, r), at, body, P.Z_HEAD, {"shade": 0.16})
	gloss(cv, p.head, r, P.Z_HEAD + 0.5, 0.22 if body.get_luminance() < 0.5 else 0.45)
	P.face(cv, p, {"eyes": str(app.eyes), "mouth": str(app.mouth), "col": feature, "x": 0.34, "glint": feature != Color("fdfdfd")})
	if app.hat != null:
		P.hat(cv, p, str(app.hat), Color(app.hatColor))
	P.club(cv, p)


static func _classic_shirt(cv: ToonCanvas, p: Dictionary, kind: String, sc: Color) -> void:
	var dark := sc.darkened(0.3)
	match kind:
		"jersey":
			P.band(cv, p, Color.WHITE.lerp(sc, 0.12), P.Z_CLOTH + 0.5, 0.56, 0.68, 0.75, {"rim": false})
			P.band(cv, p, dark, P.Z_CLOTH + 0.5, 0.47, 0.52, 0.75, {"rim": false})
		"polo":
			var xf := spine_xf(p, 0.97)
			for s: float in [-1.0, 1.0]:
				var pts := PackedVector2Array([Vector2(1.5, -1.0), Vector2(1.5 + 5.5 * s * 0.0 + 5.0, 2.5 + s * 0.0), Vector2(1.5, 4.5)])
				if s < 0.0:
					pts = PackedVector2Array([Vector2(-4.5, -0.5), Vector2(1.5, -1.0), Vector2(-1.0, 4.0)])
				cv.poly("polo_collar_%d" % int(s), pts, xf, sc.lightened(0.3), P.Z_CLOTH + 1.0, {"shade": 0.0})
			cv.detail(P.Z_CLOTH + 0.8, func(k: ToonCanvas) -> void:
				var a := Golfer.spine_at(p, 0.9) + Golfer.spine_fwd(p, 0.9) * 4.5
				var b := Golfer.spine_at(p, 0.72) + Golfer.spine_fwd(p, 0.72) * 5.5
				k.line(a, b, dark, maxf(0.5, k.in_w * 0.8))
				k.dot(a.lerp(b, 0.35), 0.75, Color.WHITE)
				k.dot(a.lerp(b, 0.75), 0.75, Color.WHITE))
		"vest":
			cv.detail(P.Z_CLOTH + 0.8, func(k: ToonCanvas) -> void:
				var top := Golfer.spine_at(p, 0.98) + Golfer.spine_fwd(p, 0.98) * 3.0
				var v := Golfer.spine_at(p, 0.68) + Golfer.spine_fwd(p, 0.68) * 6.5
				k.polyline(PackedVector2Array([top + Golfer.spine_fwd(p, 0.98) * 4.0, v, top - Golfer.spine_fwd(p, 0.98) * 2.0]), dark, maxf(0.6, k.in_w))
				for t: float in [0.58, 0.46]:
					k.dot(Golfer.spine_at(p, t) + Golfer.spine_fwd(p, t) * 7.5, 0.9, dark.darkened(0.2)))
		"hoodie":
			var xf2 := spine_xf(p, 0.42)
			cv.poly("hoodie_pocket", round_rect(Vector2(4.2, 3.0), 2.0), xf2.translated_local(Vector2(5.5, 0)), sc.darkened(0.1), P.Z_CLOTH + 0.6, {"shade": 0.0})
			cv.detail(P.Z_CLOTH + 0.9, func(k: ToonCanvas) -> void:
				for s: float in [0.0, 2.6]:
					var a := Golfer.spine_at(p, 0.98) + Golfer.spine_fwd(p, 0.98) * (2.5 + s)
					k.line(a, a + Golfer.spine_fwd(p, 0.98).rotated(PI * 0.5) * 6.0, Color.WHITE, maxf(0.5, k.in_w * 0.75)))
		_:
			cv.detail(P.Z_CLOTH + 0.8, func(k: ToonCanvas) -> void:
				var a := Golfer.spine_at(p, 0.98)
				var f := Golfer.spine_fwd(p, 0.98)
				k.arc(a + f * 2.0, 4.0, f.angle() - 1.2, f.angle() + 1.2, sc.darkened(0.25), maxf(0.5, k.in_w * 0.75), 8))


# ---------------------------------------------------------------------------
# Bolt — robot caddie on a single wheel
# ---------------------------------------------------------------------------

static func _robot(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var body := c(def, "body")
	var metal := c(def, "metal")
	var dark := c(def, "dark")
	var accent := c(def, "accent")
	var t := float(p.t)
	var root: Vector2 = p.root
	var wr := 6.2
	# Wheel + fork. It rolls when walking; otherwise it rocks a touch with the body.
	var wc := Vector2(root.x, minf(0.0, root.y) - wr)
	var spin: float = t * 9.0 if p.anim == "walk" else sin(t * Golfer.BREATH) * 0.15 + root.x * 0.15
	cv.capsule(wc, p.base, 2.6, 2.2, metal, P.Z_FEET - 1.0, {"shade": 0.2})
	cv.circle(wc, wr, c(def, "tyre"), P.Z_FEET, {"shade": 0.18})
	cv.circle(wc, wr * 0.48, accent, P.Z_FEET + 0.2, {"shade": 0.2})
	cv.detail(P.Z_FEET + 0.3, func(k: ToonCanvas) -> void:
		for i in 3:
			var a := spin + TAU * float(i) / 3.0
			k.line(wc + Vector2.from_angle(a) * wr * 0.15, wc + Vector2.from_angle(a) * wr * 0.42, accent.darkened(0.35), maxf(0.5, k.in_w * 0.7))
		k.dot(wc, wr * 0.13, dark))

	# Body: a rigid rounded box that leans but never bends.
	var base: Vector2 = p.base
	var top: Vector2 = p.top
	var axis := top - base
	var ang := atan2(axis.x, -axis.y)
	var r0 := float(p.rig.r[0])
	var bh := float(p.rig.body) + r0 * 1.6
	var bxf := Transform2D(ang, (base + top) * 0.5 + axis.normalized() * -r0 * 0.15).scaled_local(Vector2(float(p.wide), float(p.squash)))
	cv.poly("bolt_body", round_rect(Vector2(r0 + 0.5, bh * 0.5), 6.0), bxf, body, P.Z_BODY, {"shade": 0.2})
	cv.poly("bolt_panel", round_rect(Vector2(6.0, 6.2), 2.4), bxf.translated_local(Vector2(2.4, 1.0)), c(def, "panel"), P.Z_CLOTH, {"shade": 0.12})
	var blink := 0.5 + 0.5 * sin(t * TAU / 1.4)
	cv.detail(P.Z_CLOTH + 0.5, func(k: ToonCanvas) -> void:
		k.push(bxf.translated_local(Vector2(2.4, 1.0)))
		var lw := maxf(0.5, k.in_w * 0.7)
		k.dot(Vector2(-3.0, -3.0), 1.3, c(def, "light").lerp(accent, blink))
		k.dot(Vector2(0.4, -3.0), 1.3, Color("06d6a0"))
		k.dot(Vector2(3.6, -3.0), 1.3, accent)
		for i in 3:
			k.ci.draw_line(Vector2(-3.6, 0.6 + i * 1.8), Vector2(3.8, 0.6 + i * 1.8), dark.lightened(0.2), lw, false)
		k.pop()
		# Rivets along the seam.
		k.push(bxf)
		for i in 3:
			k.dot(Vector2(-r0 + 2.2, -bh * 0.3 + i * bh * 0.3), 0.8, body.darkened(0.35))
		k.pop())

	# Accordion arms with clamp hands.
	for back: bool in [true, false]:
		P.arm(cv, p, back, metal)
		var pts := P.arm_pts(p, back, 7)
		var z := P.arm_z(p, back) + 0.3
		var col := metal.darkened(0.35)
		cv.detail(z, func(k: ToonCanvas) -> void:
			for i in range(1, pts.size() - 1):
				var d := (pts[i + 1] - pts[i - 1]).normalized()
				var n := Vector2(-d.y, d.x) * float(p.rig.arm_w) * 0.95
				k.ci.draw_line(pts[i] - n, pts[i] + n, col, maxf(0.5, k.in_w * 0.7), false))
		P.hand(cv, p, back, dark, p.thumb and not back)
		cv.circle(P.shoulder(p, back), 3.3, accent if not back else accent.darkened(0.2), P.arm_z(p, back) + 0.4, {"shade": 0.15})

	# Head: a TV monitor with an LED face, ear bolts and a springy antenna.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	var sway := float(p.sway)
	var stem_top := at * Vector2(-0.35 * r + sway * 4.0, -1.55 * r)
	cv.capsule(at * Vector2(-0.35 * r, -0.8 * r), stem_top, 0.7, 0.6, metal, P.Z_HEAD_BACK, {"shade": 0.0})
	cv.circle(stem_top, 2.4, c(def, "light"), P.Z_HEAD_BACK + 0.1, {"shade": 0.2, "hl": 0.5})
	cv.poly("bolt_head_%.2f" % r, round_rect(Vector2(1.1 * r, 0.86 * r), 0.36 * r), at, body, P.Z_HEAD, {"shade": 0.2})
	cv.poly("bolt_screen_%.2f" % r, round_rect(Vector2(0.86 * r, 0.62 * r), 0.24 * r), at.translated_local(Vector2(0.1 * r, 0.02 * r)), c(def, "screen"), P.Z_HEAD + 0.5, {"shade": 0.0})
	_led_face(cv, p, def, at.translated_local(Vector2(0.18 * r, 0.02 * r)), r)
	gloss(cv, p.head, r * 1.2, P.Z_HEAD + 1.0, 0.18)
	P.club(cv, p)


static func _led_face(cv: ToonCanvas, p: Dictionary, def: Dictionary, at: Transform2D, r: float) -> void:
	var em := P.expression(p, "oval", "smile")
	var eyes: String = em[0]
	var mouth: String = em[1]
	var led := c(def, "led")
	var glow := Color(led, 0.22)
	cv.detail(P.Z_FACE, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.9, r * 0.11)
		for i in 2:
			var e := Vector2((-0.32 + i * 0.5) * r, -0.16 * r)
			var ex := eyes
			if ex == "wink":
				ex = "oval" if i == 0 else "happy"
			match ex:
				"happy":
					k.arc(e + Vector2(0, r * 0.08), r * 0.13, PI + 0.3, TAU - 0.3, glow, lw * 2.0)
					k.arc(e + Vector2(0, r * 0.08), r * 0.13, PI + 0.3, TAU - 0.3, led, lw)
				"closed", "sleepy":
					k.line(e + Vector2(-r * 0.12, r * 0.02), e + Vector2(r * 0.12, r * 0.02), led, lw)
				"big":
					k.fill_ellipse(e, Vector2(r * 0.19, r * 0.21), 0.0, glow)
					k.arc(e, r * 0.15, 0.0, TAU, led, lw * 0.8, 18)
					k.dot(e, r * 0.06, led)
				"angry":
					var s := 1.0 if i == 0 else -1.0
					k.fill_poly(PackedVector2Array([e + Vector2(-r * 0.13, -r * 0.08 * s), e + Vector2(r * 0.13, r * 0.08 * s),
						e + Vector2(r * 0.13, r * 0.14), e + Vector2(-r * 0.13, r * 0.14)]), led)
				"sad":
					k.arc(e + Vector2(0, -r * 0.02), r * 0.12, 0.25, PI - 0.25, led, lw)
				_:
					k.fill_ellipse(e, Vector2(r * 0.14, r * 0.18), 0.0, glow)
					k.fill_ellipse(e, Vector2(r * 0.085, r * 0.13), 0.0, led)
		var m := Vector2(-0.06 * r, 0.26 * r)
		match mouth:
			"open", "laugh", "o":
				var w := 0.1 if mouth == "o" else (0.24 if mouth == "laugh" else 0.18)
				k.fill_ellipse(m + Vector2(0, r * 0.02), Vector2(r * w, r * 0.11), 0.0, led)
			"frown":
				k.arc(m + Vector2(0, r * 0.14), r * 0.16, PI + 0.5, TAU - 0.5, led, lw)
			"flat":
				k.line(m + Vector2(-r * 0.15, 0), m + Vector2(r * 0.15, 0), led, lw)
			"grin":
				k.arc(m + Vector2(0, -r * 0.1), r * 0.2, 0.3, PI - 0.3, led, lw)
				k.line(m + Vector2(-r * 0.17, r * 0.0), m + Vector2(r * 0.17, r * 0.0), led, lw * 0.7)
			"smirk":
				k.arc(m + Vector2(r * 0.04, -r * 0.12), r * 0.17, 0.4, PI * 0.55, led, lw)
			_:
				k.arc(m + Vector2(0, -r * 0.1), r * 0.17, 0.4, PI - 0.4, led, lw)
		k.pop())


# ---------------------------------------------------------------------------
# Tee-Rex — a dinosaur: forward lean, counterweight tail, giant head, tiny arms
# ---------------------------------------------------------------------------

## Head in head radii: cranium at the back, long snout forward, upper jaw line along y = 0.3.
const DINO_HEAD := [Vector2(-0.95, 0.15), Vector2(-0.98, -0.45), Vector2(-0.6, -0.92), Vector2(-0.05, -1.05), Vector2(0.35, -0.9),
	Vector2(0.75, -0.72), Vector2(1.35, -0.6), Vector2(1.72, -0.42), Vector2(1.86, -0.1), Vector2(1.78, 0.2), Vector2(1.5, 0.32),
	Vector2(0.4, 0.34), Vector2(-0.3, 0.5), Vector2(-0.75, 0.48)]
const DINO_JAW := [Vector2(-0.35, 0.28), Vector2(1.35, 0.3), Vector2(1.42, 0.48), Vector2(1.1, 0.68), Vector2(0.3, 0.74), Vector2(-0.45, 0.6)]
const DINO_FOOT := [Vector2(-3.6, 0.0), Vector2(-4.2, -3.2), Vector2(-1.5, -5.4), Vector2(2.6, -5.0), Vector2(5.4, -3.4),
	Vector2(7.6, -2.2), Vector2(8.0, 0.0)]


static func _dino(cv: ToonCanvas, p: Dictionary, def: Dictionary) -> void:
	var skin := c(def, "skin")
	var stripe := c(def, "stripe")
	var belly := c(def, "belly")
	var plate := c(def, "plate")
	var claw := c(def, "claw")
	var t := float(p.t)
	var sway := float(p.sway)
	var base: Vector2 = p.base
	var r0 := float(p.rig.r[0]) * float(p.wide)
	var back := -(p.fwd as Vector2)

	# Tail: a thick tapering curve behind the hips that counter-swings.
	var swing := sin(t * Golfer.BREATH) * 1.6 + sway * 5.0 - (p.root as Vector2).y * 0.3
	var t0 := base + back * r0 * 0.4 + Vector2(0, 2.0)
	var t2 := base + Vector2(-27.0, 2.0 + swing)
	var t1 := (t0 + t2) * 0.5 + Vector2(0, 5.0)
	var tail := ToonCanvas.bezier(t0, t1, t2 + Vector2(0, -4.0 - swing * 0.4), 8)
	var trs := PackedFloat32Array()
	for i in tail.size():
		trs.append(lerpf(9.5, 1.6, pow(float(i) / float(tail.size() - 1), 0.85)))
	cv.tube(tail, trs, skin, P.Z_BODY - 1.0, {"shade": 0.2})
	# Back plates along the spine and tail.
	var plate_pts := PackedVector2Array([Vector2(-3.0, 0.5), Vector2(0.0, -6.0), Vector2(3.0, 0.5)])
	var spots: Array = []
	for tt: float in [0.95, 0.72, 0.48, 0.24]:
		var s := P.surface(p, tt, -1.0)
		spots.append([s, (-Golfer.spine_fwd(p, tt)).angle() + PI * 0.5, 1.0 - (1.0 - tt) * 0.25])
	for i: float in [1, 3, 5]:
		var a := tail[i]
		var d := (tail[i + 1] - tail[i - 1]).normalized()
		var n := Vector2(d.y, -d.x)
		if n.y > 0.0:
			n = -n
		spots.append([a + n * trs[i] * 0.85, n.angle() + PI * 0.5, lerpf(0.9, 0.5, float(i) / 5.0)])
	for i in spots.size():
		var sp: Array = spots[i]
		var xf := Transform2D(float(sp[1]), sp[0]).scaled_local(Vector2.ONE * float(sp[2]))
		cv.poly("dino_plate", plate_pts, xf, plate, P.Z_BODY - 2.0, {"shade": 0.15})

	# Legs: big haunches with three-toed feet.
	for i in 2:
		var f: Vector2 = p.feet[i]
		var hip := base + (p.fwd as Vector2) * (1.0 - i * 2.0) + Vector2(0, 1.0)
		var col := ToonCanvas.shadow_of(skin, 0.12) if i == 0 else skin
		var z := P.Z_FEET if i == 0 else P.Z_BODY + 1.0
		cv.capsule(hip, f + Vector2(0.5, -3.5), 7.0, 3.6, col, z, {"shade": 0.18})
		var lift := clampf(-(f.y - minf(0.0, (p.root as Vector2).y)) / 4.0, 0.0, 1.0)
		var fxf := Transform2D(lift * 0.35, f)
		cv.poly("dino_foot", PackedVector2Array(DINO_FOOT), fxf, col, z + 0.2, {"shade": 0.16})
		cv.detail(z + 0.3, func(k: ToonCanvas) -> void:
			k.push(fxf)
			for x: float in [3.4, 5.8, 8.0]:
				k.fill_poly(PackedVector2Array([Vector2(x - 1.2, -0.3), Vector2(x + 1.1, -0.2), Vector2(x, -1.9)]), claw)
			k.pop())

	# Body with belly patch and a few darker stripes on the back.
	P.bean(cv, p, skin, P.Z_BODY)
	var bt := 0.48
	var bxf := spine_xf(p, bt)
	var len := float(p.rig.body) * float(p.squash)
	cv.ellipse(bxf * Vector2(r0 * 0.5, 0), Vector2(r0 * 0.5, len * 0.5), bxf.get_rotation(), belly, P.Z_BODY + 0.5, {"shade": 0.12})
	cv.detail(P.Z_BODY + 0.4, func(k: ToonCanvas) -> void:
		var lw := maxf(0.6, k.in_w)
		for tt: float in [0.3, 0.55, 0.8]:
			var s := P.surface(p, tt, -0.95)
			var f := Golfer.spine_fwd(p, tt)
			k.line(s, s + f * 4.0 + (s - P.surface(p, tt + 0.1, -0.95)) * 0.3, stripe, lw * 1.6))
	cv.detail(P.Z_BODY + 0.6, func(k: ToonCanvas) -> void:
		var lw := maxf(0.5, k.in_w * 0.7)
		for i in 4:
			var tt := 0.25 + i * 0.15
			var a := bxf * Vector2(r0 * 0.35, (tt - bt) * len)
			k.arc(a + bxf.basis_xform(Vector2(-3.0, 0)), 3.0, bxf.get_rotation() - 0.5, bxf.get_rotation() + 0.5, belly.darkened(0.15), lw, 6))

	# Tiny arms.
	for b: bool in [true, false]:
		P.arm(cv, p, b, skin)
		P.hand(cv, p, b, skin, p.thumb and not b)

	# Head with an opening jaw.
	var r := float(p.head_r)
	var at := P.head_xf(p)
	var em := P.expression(p, "oval", "grin")
	var eyes: String = em[0]
	var mouth: String = em[1]
	var jaw_open := {"open": 0.32, "laugh": 0.42, "o": 0.2}.get(mouth, 0.0) as float
	var hinge := Vector2(-0.35, 0.36) * r
	var jxf := at * Transform2D(jaw_open, hinge) * Transform2D(0.0, -hinge)
	cv.poly("dino_jaw_%.2f" % r, P._hpts(DINO_JAW, r), jxf, skin, P.Z_HEAD - 0.5, {"shade": 0.15})
	cv.detail(P.Z_HEAD - 0.4, func(k: ToonCanvas) -> void:
		if jaw_open > 0.0:
			k.push(at)
			k.fill_poly(P._hpts([Vector2(-0.2, 0.34), Vector2(1.4, 0.32), Vector2(1.1, 0.5), Vector2(0.2, 0.6)], r), c(def, "mouth"))
			k.fill_ellipse(Vector2(0.5, 0.52) * r, Vector2(0.32, 0.1) * r, 0.0, P.TONGUE)
			k.pop())
	cv.poly("dino_head_%.2f" % r, P._hpts(DINO_HEAD, r), at, skin, P.Z_HEAD, {"shade": 0.16})
	cv.detail(P.Z_FACE, func(k: ToonCanvas) -> void:
		k.push(at)
		var lw := maxf(0.75, k.in_w * 0.95)
		# Teeth along the upper jaw.
		for i in 6:
			var x := lerpf(0.1, 1.35, float(i) / 5.0)
			var y := 0.33 - 0.01 * i
			k.fill_poly(P._hpts([Vector2(x - 0.07, y), Vector2(x + 0.08, y), Vector2(x, y + 0.13)], r), claw)
		# Spots, nostril, cheek.
		k.fill_ellipse(Vector2(-0.45, -0.55) * r, Vector2(0.14, 0.1) * r, 0.3, stripe)
		k.fill_ellipse(Vector2(-0.7, -0.15) * r, Vector2(0.09, 0.07) * r, 0.0, stripe)
		k.fill_ellipse(Vector2(1.62, -0.32) * r, Vector2(0.07, 0.045) * r, -0.3, k.ink)
		k.fill_ellipse(Vector2(0.7, 0.06) * r, Vector2(0.18, 0.09) * r, 0.0, Color(1.0, 0.45, 0.5, 0.3))
		# Eye: white with a big pupil, under a brow ridge.
		var e := Vector2(0.18, -0.42) * r
		var er := 0.2 * r
		match eyes:
			"closed", "sleepy":
				k.arc(e + Vector2(0, -er * 0.2), er * 0.8, 0.3, PI - 0.3, k.ink, lw)
			"happy":
				k.arc(e + Vector2(0, er * 0.5), er * 0.85, PI + 0.3, TAU - 0.3, k.ink, lw * 1.1)
			_:
				var big := 1.25 if eyes == "big" else 1.0
				k.fill_ellipse(e, Vector2(er * 0.95, er * 1.1) * big + Vector2(lw, lw) * 0.8, 0.0, k.ink)
				k.fill_ellipse(e, Vector2(er * 0.95, er * 1.1) * big, 0.0, Color.WHITE)
				var pup := Vector2(er * 0.3, er * 0.1)
				k.fill_ellipse(e + pup, Vector2(er * 0.48, er * 0.62) * big, 0.0, c(def, "eye"))
				k.dot(e + pup + Vector2(er * 0.15, -er * 0.25), er * 0.18, Color.WHITE)
		var tilt := {"angry": -0.25, "sad": 0.3}.get(eyes, 0.0) as float
		k.line(e + Vector2(-er * 1.1, -er * 1.25 - tilt * er), e + Vector2(er * 1.1, -er * 1.35 + tilt * er), k.ink, lw * 1.3)
		if mouth == "frown":
			k.arc(Vector2(1.0, 0.62) * r, 0.2 * r, PI + 0.6, TAU - 0.6, k.ink, lw)
		k.pop())
	P.club(cv, p, {"head": "#ffd166", "kind": "wood"})
