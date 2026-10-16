class_name InkRig
extends RefCounted
## Skeleton of the ink stick figure (docs/INK_ART_SPEC.md §4, §7). Turns authored key poses
## (InkAnims) into a solved sample: positions of hip, neck, head, shoulder, hands, feet and club,
## in rig units with the origin on the ground between the feet, facing +x, y down.

const HEAD_R := 8.2
const NECK_GAP := 0.4
const TORSO := 22.5
const THIGH := 17.4
const SHIN := 17.6
const UPPER := 13.0
const FORE := 13.6
const CLUB := 31.0
const HIP_H := 34.3
const SHOULDER_T := 0.84
const HIP_SPREAD := 1.3
## Distance from the shoulder to the hands while gripping the club.
const REACH := 22.4
## Ball centre at address, from the golfer origin (rig units).
const BALL_OFFSET := 34.0
## Where the hosel (shaft end) sits at address: the club face just behind the ball.
const HOSEL_TARGET := Vector2(23.4, -2.8)

const DEFAULTS := {
	"hip": Vector2.ZERO, "lean": 0.06, "bend": 1.0, "tilt": 0.0, "sq": 1.0,
	"arm": 0.0, "hinge": 0.0, "da": 0.0, "dh": 0.0,
	"hb": Vector2(-3, 22), "hf": Vector2(3, 22),
	"fb": Vector2(-5.5, 0), "ff": Vector2(5.5, 0), "tb": 0.0, "tf": 0.0,
	"crot": 0.4, "thumb": 0.0, "face_hand": 0.0, "elbow_up": 0.0,
}

static var _addr := Vector2.INF


static func up_of(lean: float) -> Vector2:
	return Vector2(sin(lean), -cos(lean))


static func bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


static func bez_tan(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return ((c - a) * (1.0 - t) + (b - c) * t).normalized()


## Two-bone IK: the middle joint for a chain a -> ? -> b. `side` picks the bend (+1 / -1).
static func ik(a: Vector2, b: Vector2, l1: float, l2: float, side: float) -> Vector2:
	var d := b - a
	var dist := clampf(d.length(), 0.001, l1 + l2 - 0.001)
	var cos_a := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)
	var ang := acos(clampf(cos_a, -1.0, 1.0))
	return a + Vector2.from_angle(d.angle() + ang * side) * l1


## (arm angle, wrist hinge) that grounds the club behind the ball at address.
static func address() -> Vector2:
	if _addr != Vector2.INF:
		return _addr
	var p: Dictionary = InkAnims.ADDRESS
	var hip := Vector2(0, -HIP_H) + (p.hip as Vector2)
	var t := _torso(hip, float(p.lean), float(p.bend), 1.0)
	var sh := bez(hip, t[1], t[0], SHOULDER_T)
	var best := Vector2.ZERO
	for side: float in [-1.0, 1.0]:
		var w := ik(sh, HOSEL_TARGET, REACH, CLUB - 3.0, side)
		var arm := atan2(w.x - sh.x, w.y - sh.y)
		var cl := atan2(HOSEL_TARGET.x - w.x, HOSEL_TARGET.y - w.y)
		if cl - arm > best.y or best == Vector2.ZERO:
			best = Vector2(arm, cl - arm)
	_addr = best
	return _addr


static func _torso(hip: Vector2, lean: float, bend: float, sq: float) -> Array:
	var up := up_of(lean)
	var fwd := Vector2(-up.y, up.x)
	var neck := hip + up * TORSO * sq
	var ctrl := (hip + neck) * 0.5 + fwd * bend
	return [neck, ctrl]


static func is_grip(p: Dictionary) -> bool:
	return bool(p.get("addr", false)) or bool(p.get("grip", false))


## Grip-mode arm angles for a pose (address-relative poses resolved).
static func grip_angles(p: Dictionary) -> Vector2:
	if bool(p.get("addr", false)):
		var a := address()
		return Vector2(a.x + float(p.get("da", 0.0)), a.y + float(p.get("dh", 0.0)))
	return Vector2(float(p.get("arm", 0.0)), float(p.get("hinge", 0.0)))


## Interpolates two raw poses (both gripping: swing arcs stay arcs).
static func lerp_params(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	var ga := grip_angles(a)
	var gb := grip_angles(b)
	out.grip = true
	out.arm = lerpf(ga.x, gb.x, k)
	out.hinge = lerpf(ga.y, gb.y, k)
	for key: String in DEFAULTS:
		if key in ["arm", "hinge", "da", "dh"]:
			continue
		var va = a.get(key, DEFAULTS[key])
		var vb = b.get(key, DEFAULTS[key])
		if va is Vector2:
			out[key] = (va as Vector2).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	out.expr = b.get("expr", {}) if k > 0.5 else a.get("expr", {})
	out.club = "hands"
	return out


## Solves a raw pose into positions.
static func solve(p: Dictionary) -> Dictionary:
	var g := func(key: String) -> Variant: return p.get(key, DEFAULTS.get(key))
	var sq := float(g.call("sq"))
	var hip := Vector2(0, -HIP_H) + (g.call("hip") as Vector2)
	var lean := float(g.call("lean"))
	var t := _torso(hip, lean, float(g.call("bend")), sq)
	var neck: Vector2 = t[0]
	var ctrl: Vector2 = t[1]
	var tangent := bez_tan(hip, ctrl, neck, 1.0)
	var head_dir := tangent.rotated(float(g.call("tilt")))
	var head := neck + head_dir * (NECK_GAP + HEAD_R)
	var head_rot := atan2(head_dir.x, -head_dir.y)
	var sh := bez(hip, ctrl, neck, SHOULDER_T)
	var s := {
		"hip": hip, "neck": neck, "ctrl": ctrl, "head": head, "head_rot": head_rot, "shoulder": sh,
		"fb": g.call("fb"), "ff": g.call("ff"), "tb": float(g.call("tb")), "tf": float(g.call("tf")),
		"sq": sq, "lean": lean, "expr": p.get("expr", {}), "thumb": float(g.call("thumb")),
		"elbow_up": float(g.call("elbow_up")), "club": "hands", "grip_mode": false,
	}
	if is_grip(p):
		var ga := grip_angles(p)
		var hands := sh + Vector2(sin(ga.x), cos(ga.x)) * REACH
		var cdir := Vector2(sin(ga.x + ga.y), cos(ga.x + ga.y))
		s.hf = hands + cdir * 1.4
		s.hb = hands - cdir * 2.0
		s.grip = hands - cdir * 4.4
		s.hosel = hands + cdir * (CLUB - 3.0)
		s.grip_mode = true
		s.arm = ga.x
	else:
		var hb: Vector2 = sh + _reach(g.call("hb"))
		var hf: Vector2 = sh + _reach(g.call("hf"))
		if float(g.call("face_hand")) > 0.5:
			hf = head + Vector2(HEAD_R * 0.55, HEAD_R * 0.15).rotated(head_rot)
		s.hb = hb
		s.hf = hf
		var mode := str(p.get("club", "planted"))
		s.club = mode
		var crot := float(g.call("crot"))
		var cdir := Vector2(sin(crot), cos(crot))
		match mode:
			"planted":
				s.grip = Vector2(-15.5, -27.0)
				s.hosel = Vector2(-12.6, -2.2)
			"none":
				s.grip = hf
				s.hosel = hf
			_:
				s.grip = hf - cdir * 4.0
				s.hosel = hf + cdir * (CLUB - 3.0)
		s.arm = 0.0
	return s


static func _reach(v: Vector2) -> Vector2:
	var m := (UPPER + FORE) * 0.98
	return v if v.length() <= m else v.normalized() * m


## Blends two solved samples (cross-fades between clips).
static func lerp_sample(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := b.duplicate()
	for key: String in ["hip", "neck", "ctrl", "head", "shoulder", "hb", "hf", "fb", "ff", "grip", "hosel"]:
		out[key] = (a[key] as Vector2).lerp(b[key], k)
	for key: String in ["tb", "tf", "sq", "lean", "thumb", "elbow_up"]:
		out[key] = lerpf(float(a[key]), float(b[key]), k)
	out.head_rot = lerp_angle(float(a.head_rot), float(b.head_rot), k)
	if k < 0.5:
		out.expr = a.expr
		out.club = a.club
		out.grip_mode = a.grip_mode
	return out


## Evaluates clip `name` at time `t`. `top` replaces the swing's first key (backswing top).
static func evaluate(name: String, t: float, top: Dictionary = {}) -> Dictionary:
	var c := InkAnims.clip(name)
	var keys: Array = c.keys
	var length := float(c.len)
	t = fposmod(t, length) if bool(c.loop) else clampf(t, 0.0, length)
	var i := 0
	while i < keys.size() - 2 and t >= float(keys[i + 1][0]):
		i += 1
	var k0: Array = keys[i]
	var k1: Array = keys[mini(i + 1, keys.size() - 1)]
	var pa: Dictionary = top if (i == 0 and not top.is_empty() and name == "swing") else k0[1]
	var pb: Dictionary = k1[1]
	var span := maxf(0.0001, float(k1[0]) - float(k0[0]))
	var k := InkAnims.ease((t - float(k0[0])) / span, str(k1[2]))
	if is_grip(pa) and is_grip(pb):
		return solve(lerp_params(pa, pb, k))
	return lerp_sample(solve(pa), solve(pb), k)


## Aiming: address blended toward the top of the backswing by shot power (0..1).
static func aim_params(power: float) -> Dictionary:
	var e := ease(clampf(power, 0.0, 1.0), 0.8)
	return lerp_params(InkAnims.ADDRESS, InkAnims.TOP, e)
