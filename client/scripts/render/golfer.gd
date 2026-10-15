class_name Golfer
extends Node2D
## An animated toon golfer (docs/CHARACTER_ART_SPEC.md). The origin is the ground point between
## the feet; the golfer faces +x when facing = 1.
##
## Every frame: the current animation produces pose controls, `_solve` turns them into a skeleton
## shared by all characters (spine curve, head, shoulders, hands, club, feet), and the character's
## builder (ToonCharacters) emits parts into a ToonCanvas that draws them with one merged ink
## outline. Clothing, hats and accessories attach to skeleton spaces, so they follow every
## animation; the same node renders gameplay, cards and the big studio preview.

## Horizontal distance from the golfer origin to the ball at address (rig units).
const BALL_OFFSET := 34.0
## Height of the standard golfer (rig units); used to size the outline for the display scale.
const STANDARD_HEIGHT := 66.0

var appearance: Dictionary = Appearance.DEFAULT.duplicate(true)
var facing: float = 1.0
var anim: String = "idle"         ## idle | aim | swing | watch | celebrate | sad | walk | dance | victory | any Emotes id
var aim_power: float = 0.0        ## 0..1 backswing amount while aiming
var show_club: bool = true
var look_target: Vector2 = Vector2.ZERO  ## Local-space point to look at (watch anim)
## When true, time only moves via set_time() (thumbnails, emote wheel, tests).
var frozen_time := false
## Throttles redraws (cards in a big grid): 0 = every frame.
var redraw_interval := 0.0

var _t: float = 0.0
var _anim_t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0
var _swing_from := Vector2.ZERO   ## (arm angle, wrist hinge) at the moment of release
var _after_swing: String = "watch"
var _one_shot := 0.0               ## > 0: current anim is an emote that returns to idle after this many seconds
var _redraw_wait := 0.0

var _id := "stickman"
var _def: Dictionary = {}
var _rig: Dictionary = {}
var _scale := 1.0
var _addr := Vector2.ZERO          ## (arm angle, wrist hinge) at address, solved by IK per rig
var _cv := ToonCanvas.new()
## Hand-authored sprite art for this character, when it has any (res://assets/characters/<id>/).
## Sprite characters draw frames from their sheets; the skeleton below is still solved so
## anchors, tests and effects keep one source of pose timing.
var _sprite: SpriteCharacter = null
## Secondary motion: spring that lags behind the head (drives plumes, tails, antennae).
var _sway := 0.0
var _sway_v := 0.0
var _last_head := Vector2.INF

## Solved skeleton for this frame (rig space, facing +x).
var _p: Dictionary = {}

## Base angular speed of looping animations (whole 3 s cycles).
const BREATH := TAU / 3.0
const IMPACT := 0.045             ## downswing time: the ball leaves on this frame
const SWING_LEN := 0.75

static var _bounds_cache: Dictionary = {}


func _ready() -> void:
	set_appearance(appearance)


func set_appearance(a: Dictionary) -> void:
	appearance = Appearance.normalize(a)
	_id = str(appearance.character)
	_def = CharacterDefs.get_def(_id)
	_rig = CharacterDefs.rig(_id)
	_scale = float(_def.scale)
	_sprite = SpriteCharacter.load_for(_id)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _sprite else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	if CharacterDefs.accepts(_id, "proportions"):
		_rig.head_r = float(_rig.head_r) * float(appearance.headScale)
		var lt := float(appearance.limbThickness)
		_rig.arm_w = float(_rig.arm_w) * lt
		_rig.hand_r = float(_rig.hand_r) * lerpf(1.0, lt, 0.5)
		var w := lerpf(1.0, lt, 0.45)
		_rig.r = [float(_rig.r[0]) * w, float(_rig.r[1]) * w, float(_rig.r[2]) * w]
	_addr = _solve_address()
	queue_redraw()


func character_def() -> Dictionary:
	return _def


func play(name: String) -> void:
	if name == anim:
		return
	if name == "swing":
		_swing_from = _aim_controls(aim_power)
	anim = name
	_anim_t = 0.0
	_one_shot = 0.0


## Performs an emote once (see Emotes.LIST), then returns to idle.
func emote(name: String) -> void:
	anim = name
	_anim_t = 0.0
	_one_shot = Emotes.duration(name)


## True while an emote or celebration should not be interrupted by idle/aim updates.
func is_performing() -> bool:
	return _one_shot > 0.0 or anim in ["celebrate", "sad", "dance", "victory"]


## Sets the animation clock directly. `t` drives loops, `anim_t` one-shots.
func set_time(t: float, anim_t: float) -> void:
	_t = t
	_anim_t = anim_t
	_blink = 0.0
	queue_redraw()


## Swing then transition to another animation. The club meets the ball IMPACT seconds in.
func swing(power: float, then_anim: String = "watch") -> void:
	aim_power = power
	_swing_from = _aim_controls(power)
	anim = "swing"
	_anim_t = 0.0
	_after_swing = then_anim


func _process(delta: float) -> void:
	if frozen_time:
		return
	_t += delta
	_anim_t += delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.13
		_next_blink = randf_range(2.2, 5.0)
	_blink = maxf(0.0, _blink - delta)
	if anim == "swing" and _anim_t > SWING_LEN and _after_swing != "swing":
		anim = _after_swing
		_anim_t = 0.0
	if _one_shot > 0.0 and _anim_t > _one_shot:
		play("idle")
	# Secondary motion spring, driven by how fast the head moves.
	if _p.has("head"):
		var h: Vector2 = _p.head
		if _last_head != Vector2.INF and delta > 0.0:
			var v := (h.x - _last_head.x) / delta
			_sway_v += (-v * 0.012 - _sway) * 60.0 * delta - _sway_v * 7.0 * delta
		_last_head = h
	_sway = clampf(_sway + _sway_v * delta, -1.0, 1.0)
	if redraw_interval > 0.0:
		_redraw_wait -= delta
		if _redraw_wait > 0.0:
			return
		_redraw_wait = redraw_interval
	queue_redraw()


# ---------------------------------------------------------------------------
# Pose controls
# ---------------------------------------------------------------------------

## Club controls while aiming: (arm angle, wrist hinge). Arm angle 0 = hands straight down,
## negative = up behind the golfer. The hinge is the club's angle relative to the arms.
func _aim_controls(power: float) -> Vector2:
	var pw := clampf(power, 0.0, 1.0)
	var e := ease(pw, 0.8)
	# Hands rise up behind the head while the wrists cock the club toward the target.
	return Vector2(lerpf(_addr.x, -2.35, e), lerpf(_addr.y, -1.75, pow(pw, 1.15)))


## Two-bone IK (arm + club) that grounds the club head behind the ball at address.
func _solve_address() -> Vector2:
	var sh := _rest_shoulder()
	# Hosel above the sole, blade toe just behind the ball (ball radius ~7 rig units in game).
	var target := Vector2(BALL_OFFSET / _scale - 21.0, -6.2)
	var reach := float(_rig.reach)
	var club := float(_rig.club)
	var wrist := _ik(sh, target, reach, club, -1.0)
	var arm := atan2(wrist.x - sh.x, wrist.y - sh.y)
	var cl := atan2(target.x - wrist.x, target.y - wrist.y)
	return Vector2(arm, cl - arm)


func _rest_shoulder() -> Vector2:
	var r: Array = _rig.r
	var base := Vector2(0, -float(_rig.leg) - float(r[0]))
	var lean := float(_rig.lean)
	var top := base + Vector2(sin(lean), -cos(lean)) * float(_rig.body)
	var t := float(_rig.shoulder_t)
	return base.lerp(top, t) + Vector2(cos(lean), sin(lean)) * 2.0


static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := b - a
	var dist := clampf(d.length(), 0.001, l1 + l2 - 0.001)
	var cos_a := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)
	var ang := acos(clampf(cos_a, -1.0, 1.0))
	return a + Vector2.from_angle(d.angle() + ang * bend) * l1


## Smooth keyframe track: keys = [[time, value], ...] (sorted), eased in-out between keys.
static func kf(t: float, keys: Array) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var k0: Array = keys[i - 1]
		var k1: Array = keys[i]
		if t <= float(k1[0]):
			var u := (t - float(k0[0])) / maxf(0.0001, float(k1[0]) - float(k0[0]))
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(float(k0[1]), float(k1[1]), u)
	return float(keys[keys.size() - 1][1])


## Pose controls for the current animation. Hand targets (hb = back hand, hf = front hand) are
## relative to the shoulder, in standard-rig units (scaled by the character's reach).
func _controls() -> Dictionary:
	var t := _t
	var at := _anim_t
	var fs := float(_rig.feet)
	var breathe := sin(t * BREATH)
	var q := {
		"root": Vector2.ZERO, "lean": 0.0, "bend": 0.0, "squash": 1.0 + breathe * 0.015, "tilt": 0.0,
		"feet": [Vector2(-fs, 0), Vector2(fs, 0)], "hands": "club", "arm": _addr.x, "hinge": _addr.y,
		"hb": Vector2(-4, 15), "hf": Vector2(4, 15), "club": "hands", "club_rot": 0.0,
		"expr": {}, "thumb": false, "smear": -1.0, "flex": 0.0, "face_hand": false,
	}
	match anim:
		"idle":
			q.lean = breathe * 0.012
			q.tilt = sin(t * BREATH * 0.5) * 0.04
			# A little club waggle once per breath cycle.
			var w := maxf(0.0, sin(t * BREATH * 2.0 - 1.0))
			q.hinge = _addr.y + pow(w, 3.0) * 0.16
			q.arm = _addr.x - pow(w, 3.0) * 0.05
		"aim":
			var pw := clampf(aim_power, 0.0, 1.0)
			var e := ease(pw, 0.8)
			var c := _aim_controls(pw)
			q.arm = c.x + sin(t * 31.0) * 0.012 * pw * pw
			q.hinge = c.y
			q.lean = -0.1 * e
			q.bend = -3.0 * e
			q.squash = 1.0 - 0.05 * e + breathe * 0.008
			q.root = Vector2(-1.2 * e, 0)
			q.tilt = 0.18 * e
			q.feet = [Vector2(-fs - 0.6 * e, 0), Vector2(fs + 0.4 * e, 0)]
			if pw > 0.7:
				q.expr = {"eyes": "focus"}
		"swing":
			q.smear = at
			var top := _swing_from
			if at < IMPACT:
				var k := pow(at / IMPACT, 2.0)
				var pe := ease(clampf(aim_power, 0.0, 1.0), 0.8)
				q.arm = lerpf(top.x, _addr.x, k)
				q.hinge = lerpf(top.y, _addr.y, k)
				q.lean = lerpf(-0.1 * pe, 0.05, k)
				q.bend = lerpf(-3.0 * pe, 1.0, k)
				q.squash = lerpf(1.0 - 0.05 * pe, 0.96, k)
				q.root = Vector2(lerpf(-1.2 * pe, 0.5, k), 0)
				q.tilt = 0.18
			else:
				var k2 := clampf((at - IMPACT) / 0.26, 0.0, 1.0)
				var e2 := 1.0 - pow(1.0 - k2, 3.0)
				var settle := clampf((at - 0.3) / 0.25, 0.0, 1.0)
				q.arm = lerpf(_addr.x, 2.55, e2)
				q.hinge = lerpf(_addr.y, 1.35, e2)
				q.lean = lerpf(0.05, -0.26, e2) + sin(settle * PI) * 0.05
				q.bend = lerpf(1.0, 4.0, e2)
				q.squash = lerpf(0.96, 1.05, e2) - settle * 0.03
				q.root = Vector2(lerpf(0.5, 2.0, e2), 0)
				q.tilt = lerpf(0.18, -0.42, e2)
				q.feet = [Vector2(lerpf(-fs, -fs * 0.35, e2), -1.8 * e2), Vector2(fs, 0)]
		"watch":
			# Finish held loosely, club resting on the shoulder, eyes following the ball.
			q.arm = 2.15 + breathe * 0.03
			q.hinge = 1.65
			q.lean = -0.14 + breathe * 0.01
			q.bend = 2.5
			q.root = Vector2(1.5, 0)
			q.feet = [Vector2(-fs * 0.45, -1.2), Vector2(fs, 0)]
			var look := -0.3
			if look_target != Vector2.ZERO:
				look = clampf(-atan2(-look_target.y, absf(look_target.x)) * 0.5, -0.6, 0.25)
			q.tilt = look + breathe * 0.02
		"celebrate":
			var ph := fmod(at, 0.9) / 0.9
			var hop := absf(sin(ph * PI))
			q.root = Vector2(0, -hop * 10.0)
			q.squash = lerpf(0.88, 1.07, smoothstep(0.0, 0.45, hop))
			q.feet = [Vector2(-fs * 0.8, 0), Vector2(fs * 0.8, 0)]
			q.hands = "free"
			q.club = "planted"
			var wave := sin(at * TAU * 2.0 / 0.9) * 3.0
			q.hb = Vector2(-9, -21 + wave)
			q.hf = Vector2(10, -22 - wave)
			q.lean = -0.06
			q.tilt = -0.2
			q.expr = {"eyes": "joy", "mouth": "open"}
		"victory":
			var pump := absf(sin(t * BREATH * 2.0))
			q.hands = "free"
			q.club = "front"
			q.club_rot = PI + sin(t * BREATH * 2.0) * 0.12
			q.hf = Vector2(5, -25 - pump * 3.0)
			q.hb = Vector2(-7, 9)
			q.lean = -0.1
			q.bend = 3.0
			q.squash = 1.0 + pump * 0.03
			q.tilt = -0.18
			q.expr = {"mouth": "grin"}
		"sad":
			q.lean = 0.26 + breathe * 0.02
			q.bend = -4.5
			q.squash = 0.93 + breathe * 0.01
			q.tilt = 0.5 + sin(t * TAU * 0.66) * 0.09
			q.hands = "free"
			q.club = "front"
			q.club_rot = 0.35
			q.hf = Vector2(5, 15)
			q.hb = Vector2(-2, 16)
			q.feet = [Vector2(-fs * 0.7, 0), Vector2(fs * 0.7, 0)]
			q.expr = {"eyes": "sad", "mouth": "frown"}
		"walk":
			var ph2 := t * TAU / 0.7
			match str((_def.get("motion", {}) as Dictionary).get("walk", "step")):
				"roll":
					# Rolls on a wheel: no steps, a forward lean and a little bounce.
					q.root = Vector2(0, -absf(sin(ph2 * 2.0)) * 0.8)
					q.lean = 0.16 + sin(ph2) * 0.03
					q.tilt = -0.05
				"waddle":
					# Short steps and a side-to-side rock.
					q.feet = [Vector2(-fs + sin(ph2) * 3.5, minf(0.0, cos(ph2) * 3.0)),
							Vector2(fs - sin(ph2) * 3.5, minf(0.0, -cos(ph2) * 3.0))]
					q.root = Vector2(0, -absf(sin(ph2)) * 1.4)
					q.lean = sin(ph2) * 0.09
					q.bend = sin(ph2) * 1.5
					q.tilt = -sin(ph2) * 0.06
				_:
					q.feet = [Vector2(-1.5 + sin(ph2) * 6.5, minf(0.0, cos(ph2) * 4.0)),
							Vector2(1.5 - sin(ph2) * 6.5, minf(0.0, -cos(ph2) * 4.0))]
					q.root = Vector2(0, -absf(sin(ph2)) * 1.8)
					q.lean = 0.1
					q.tilt = sin(ph2) * 0.05
			q.squash = 1.0 + cos(ph2 * 2.0) * 0.025
			q.hands = "free"
			q.club = "front"
			q.club_rot = 3.7
			q.hf = Vector2(7, 3)
			q.hb = Vector2(-sin(ph2) * 7.0 - 2.0, 13)
		"dance":
			var ph3 := (at if _one_shot > 0.0 else t) * TAU
			q.root = Vector2(sin(ph3) * 3.0, -absf(cos(ph3)) * 3.0)
			q.lean = sin(ph3) * 0.16
			q.bend = sin(ph3) * 3.0
			q.squash = 1.0 - absf(sin(ph3)) * 0.05
			q.hands = "free"
			q.club = "planted"
			var up := sin(ph3) > 0.0
			q.hb = Vector2(-10, -22) if up else Vector2(-8, 4)
			q.hf = Vector2(8, 4) if up else Vector2(10, -22)
			q.feet = [Vector2(-fs, -maxf(0.0, sin(ph3)) * 3.0), Vector2(fs, -maxf(0.0, -sin(ph3)) * 3.0)]
			q.tilt = sin(ph3) * 0.2
			q.expr = {"eyes": "joy", "mouth": "open"}
		"wave":
			q.hands = "free"
			q.club = "planted"
			q.hb = Vector2(-7, 9)
			q.hf = Vector2(11 + sin(at * 12.0) * 4.0, -21)
			q.tilt = -0.06
			q.lean = -0.03
			q.expr = {"mouth": "open"}
		"laugh":
			var shake := sin(at * 28.0)
			var bob := absf(sin(at * 14.0))
			q.lean = -0.22 + shake * 0.03
			q.squash = 1.0 - bob * 0.05
			q.root = Vector2(-1.0, 0)
			q.tilt = -0.3 + shake * 0.05
			q.hands = "free"
			q.club = "planted"
			q.hf = Vector2(5, 11 - bob)
			q.hb = Vector2(0, 12 - bob)
			q.expr = {"eyes": "joy", "mouth": "laugh"}
		"wow":
			var k3 := clampf(at / 0.16, 0.0, 1.0)
			var jump := sin(k3 * PI) * 7.0
			q.lean = lerpf(0.05, -0.16, ease(k3, 0.5))
			q.root = Vector2(-3.0 * ease(k3, 0.5), -jump)
			q.squash = 1.0 + sin(k3 * PI) * 0.08
			q.feet = [Vector2(-fs - 3.0 * k3, 0), Vector2(fs - 3.0 * k3, 0)]
			q.tilt = -0.1 + sin(at * 9.0) * 0.03 * (1.0 - clampf(at - 0.6, 0.0, 1.0))
			q.hands = "free"
			q.club = "planted"
			q.hf = Vector2(8, -12)
			q.hb = Vector2(-4, -13)
			q.expr = {"eyes": "wide", "mouth": "o"}
		"thumbs_up":
			var pump2 := maxf(0.0, sin(clampf(at / 0.35, 0.0, 1.0) * PI)) * 4.0
			q.hands = "free"
			q.club = "planted"
			q.hf = Vector2(13, -4 - pump2)
			q.hb = Vector2(-7, 9)
			q.thumb = true
			q.tilt = -0.05
			q.expr = {"eyes": "wink", "mouth": "grin"}
		"clap":
			var cp := sin(at * TAU * 2.4)
			var hop2 := absf(sin(at * TAU * 1.2)) * 2.0
			q.root = Vector2(0, -hop2)
			q.squash = 1.0 + hop2 * 0.01
			q.hands = "free"
			q.club = "planted"
			q.hf = Vector2(12, 0)
			q.hb = Vector2(12 - 7.0 * maxf(0.0, cp), -1.0 - 2.0 * maxf(0.0, cp))
			q.expr = {"eyes": "joy", "mouth": "open"}
		"facepalm":
			var k4 := clampf(at / 0.3, 0.0, 1.0)
			q.lean = lerpf(0.05, 0.2, ease(k4, 0.5))
			q.bend = -2.0 * k4
			q.tilt = lerpf(0.0, 0.35, ease(k4, 0.5)) + sin(at * 6.0) * 0.07 * k4
			q.hands = "free"
			q.club = "planted"
			q.face_hand = true
			q.hb = Vector2(-1, 15)
			q.expr = {"eyes": "closed", "mouth": "flat"}
		"flex":
			var k5 := clampf(at / 0.2, 0.0, 1.0)
			var pulse := sin(at * TAU * 1.6) * 1.2 * k5
			q.squash = 1.0 - 0.06 * k5
			q.lean = -0.05
			q.bend = 2.0 * k5
			q.feet = [Vector2(-fs - 2.5, 0), Vector2(fs + 2.5, 0)]
			q.hands = "free"
			q.club = "planted"
			q.flex = k5
			q.hb = Vector2(-13, -8 + pulse).lerp(Vector2(-4, 15), 1.0 - k5)
			q.hf = Vector2(13, -9 - pulse).lerp(Vector2(4, 15), 1.0 - k5)
			q.tilt = -0.12
			q.expr = {"eyes": "fierce", "mouth": "smirk"}
	return q


# ---------------------------------------------------------------------------
# Skeleton
# ---------------------------------------------------------------------------

func _solve() -> void:
	var q := _controls()
	var r: Array = _rig.r
	var sq := float(q.squash)
	var wide := 1.0 / sqrt(sq)
	var root: Vector2 = q.root
	var r0 := float(r[0]) * wide
	var base := root + Vector2(0, -float(_rig.leg) - r0)
	var lean := float(_rig.lean) + float(q.lean)
	var up := Vector2(sin(lean), -cos(lean))
	var fwd := Vector2(cos(lean), sin(lean))
	var top := base + up * float(_rig.body) * sq
	var ctrl := (base + top) * 0.5 + fwd * float(q.bend)
	var tan_top := (top - ctrl).normalized()
	var tilt := float(q.tilt)
	var head_dir := tan_top.rotated(tilt)
	var head_r := float(_rig.head_r)
	var head := top + head_dir * (head_r - float(_rig.head_sink))
	var head_rot := atan2(head_dir.x, -head_dir.y)
	var st := float(_rig.shoulder_t)
	var sh := _bez(base, ctrl, top, st) + _bez_fwd(base, ctrl, top, st) * 2.0
	var reach := float(_rig.reach)
	var k := reach / 17.0

	var hb: Vector2
	var hf: Vector2
	var grip := Vector2.ZERO           ## butt end of the club
	var club_dir := Vector2.DOWN
	var club_mode: String = q.club
	var club_len := float(_rig.club)
	if q.hands == "club":
		var a := float(q.arm)
		var hinge := float(q.hinge)
		var wrist := sh + Vector2(sin(a), cos(a)) * reach
		club_dir = Vector2(sin(a + hinge), cos(a + hinge))
		hf = wrist + club_dir * 0.6
		hb = wrist - club_dir * 2.4
		grip = wrist - club_dir * 4.6
		club_len += 4.6
	else:
		hb = sh + _clamp_reach((q.hb as Vector2) * k, reach)
		hf = sh + _clamp_reach((q.hf as Vector2) * k, reach)
		if q.face_hand:
			hf = head + Vector2(head_r * 0.62, head_r * 0.25).rotated(head_rot)
		if club_mode == "front" or club_mode == "back":
			var holder := hf if club_mode == "front" else hb
			club_dir = Vector2(sin(q.club_rot), cos(q.club_rot))
			grip = holder - club_dir * 3.5
			club_len += 3.5
		elif club_mode == "planted":
			# Stood upright in the turf behind the golfer while the hands are busy.
			grip = Vector2(-16.0, -25.0)
			club_dir = (Vector2(-13.0, -3.0) - grip).normalized()
			club_len = (Vector2(-13.0, -3.0) - grip).length()

	var feet: Array = q.feet
	var fb: Vector2 = feet[0] + Vector2(0, minf(0.0, root.y))
	var ff: Vector2 = feet[1] + Vector2(0, minf(0.0, root.y))

	_p = {
		"t": _t, "at": _anim_t, "anim": anim, "blink": _blink > 0.0, "sway": _sway,
		"root": root, "squash": sq, "wide": wide, "lean": lean,
		"base": base, "ctrl": ctrl, "top": top, "up": up, "fwd": fwd,
		"head": head, "head_r": head_r, "head_rot": head_rot,
		"shoulder": sh, "hb": hb, "hf": hf, "hands": q.hands,
		"grip": grip, "club_dir": club_dir, "club_len": club_len,
		"hosel": grip + club_dir * club_len,
		"club": show_club and club_mode != "none", "club_mode": club_mode,
		"feet": [fb, ff], "expr": q.expr, "thumb": q.thumb, "flex": q.flex,
		"face_hand": q.face_hand, "smear": q.smear, "swing_from": _swing_from, "addr": _addr,
		"rig": _rig,
	}


static func _clamp_reach(v: Vector2, reach: float) -> Vector2:
	var m := reach * 1.2
	return v if v.length() <= m else v.normalized() * m


static func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


## Unit vector pointing to the golfer's front, perpendicular to the spine at t.
static func _bez_fwd(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var d := ((c - a) * (1.0 - t) + (b - c) * t).normalized()
	return Vector2(-d.y, d.x)


## Spine point at t (0 = base, 1 = neck) for a solved pose.
static func spine_at(p: Dictionary, t: float) -> Vector2:
	return _bez(p.base, p.ctrl, p.top, t)


static func spine_fwd(p: Dictionary, t: float) -> Vector2:
	return _bez_fwd(p.base, p.ctrl, p.top, t)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

## Screen-space outline width for this display size (CHARACTER_ART_SPEC §3), in rig units.
func _outline_units() -> float:
	var s := absf(get_global_transform_with_canvas().get_scale().y) * _scale
	if s <= 0.0001:
		return 2.4
	var px := clampf(0.034 * STANDARD_HEIGHT * s, 2.6, 7.0)
	return px / s


func _draw() -> void:
	if _sprite:
		_draw_sprite()
		return
	_solve()
	var p := _p
	# Soft contact shadow that shrinks as the golfer leaves the ground.
	var lift := clampf(-(p.root as Vector2).y / 14.0, 0.0, 1.0)
	var sw := (float(_rig.r[0]) + 6.0) * _scale * (1.0 - lift * 0.35)
	draw_colored_polygon(ToonCanvas.ellipse_pts(Vector2(0, 0.5), Vector2(sw, 3.0 * _scale * (1.0 - lift * 0.4)), 0.0, 28), Color(0.05, 0.06, 0.2, 0.2 * (1.0 - lift * 0.5)))
	_cv.begin(self, Transform2D(0.0, Vector2(facing * _scale, _scale), 0.0, Vector2.ZERO), facing, _outline_units())
	ToonCharacters.build(_cv, _id, _def, p, appearance)
	_cv.flush()


## Current sprite frame: (sprite anim, frame index) for the game animation and clock.
func sprite_frame() -> Array:
	if anim == "aim" and _sprite.anims.has("swing") and not _sprite.anims.has("prepare"):
		# Wind-up follows shot power: address .. top of backswing (frames before the downswing).
		var top := maxi(int(_sprite.anims.swing.contact) - 2, 0)
		return ["swing", clampi(roundi(clampf(aim_power, 0.0, 1.0) * top), 0, top)]
	var sa := _sprite.resolve(anim if not Emotes.is_emote(anim) else "idle")
	var t := _anim_t
	if sa == "swing":
		# Line the art's club-contact frame up with the moment the ball leaves (IMPACT).
		t += _sprite.contact_time(sa) - IMPACT
	elif bool(_sprite.anims[sa].loop):
		t = _t
	return [sa, _sprite.frame_at(sa, maxf(t, 0.0))]


func _draw_sprite() -> void:
	var u := _sprite.units_per_px
	draw_colored_polygon(ToonCanvas.ellipse_pts(Vector2(0, 0.5), Vector2(17.0, 2.6), 0.0, 20), Color(0.05, 0.06, 0.2, 0.22))
	var f := sprite_frame()
	var fr := _sprite.frame(f[0], f[1])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing * u, u))
	draw_texture(fr.tex, -_sprite.pivot)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Inked bounds of the golfer (node space, facing right) for the given animation frame.
## Used to frame cards and previews from the actual artwork.
func visual_bounds(anim_name: String = "idle", t: float = 0.0, outline: float = 2.4, min_z: float = -INF) -> Rect2:
	if _sprite:
		return _sprite.idle_bounds()
	var saved := [anim, _t, _anim_t, _one_shot]
	anim = anim_name
	_t = t
	_anim_t = t
	_one_shot = 0.0
	_solve()
	var cv := ToonCanvas.new()
	cv.begin(null, Transform2D.IDENTITY, 1.0, outline)
	cv.measure_min_z = min_z
	ToonCharacters.build(cv, _id, _def, _p, appearance)
	cv.flush()
	anim = saved[0]
	_t = saved[1]
	_anim_t = saved[2]
	_one_shot = saved[3]
	var b := cv.bounds
	return Rect2(b.position * _scale, b.size * _scale)


## Idle bounds per look, cached (appearance changes like hats change the bounds).
static func idle_bounds(app: Dictionary) -> Rect2:
	var key := JSON.stringify(Appearance.normalize(app))
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var g := Golfer.new()
	g.set_appearance(app)
	var r := Rect2()
	# Union over a breathing cycle so the idle motion never pokes out of the frame.
	for i in 4:
		var b := g.visual_bounds("idle", float(i) * 0.75)
		r = b if i == 0 else r.merge(b)
	g.free()
	if _bounds_cache.size() > 256:
		_bounds_cache.clear()
	_bounds_cache[key] = r
	return r


## Bounds of the head and everything worn on it (idle pose), for face/hat thumbnails.
static func head_bounds(app: Dictionary) -> Rect2:
	var key := "head|" + JSON.stringify(Appearance.normalize(app))
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var g := Golfer.new()
	g.set_appearance(app)
	var r := g.visual_bounds("idle", 0.0, 2.4, ToonParts.Z_HEAD_BACK - 1.0)
	g.free()
	_bounds_cache[key] = r
	return r


## Debug/test access to the solved skeleton.
func solved_pose() -> Dictionary:
	_solve()
	return _p
