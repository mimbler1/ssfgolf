class_name Golfer
extends Node2D
## The hand-drawn stick-figure golfer (docs/INK_ART_SPEC.md §4–7). One master rig for every
## player; individuality comes from the Appearance `ink` look. The origin is the ground point
## between the feet; the golfer faces +x when facing = 1.
##
## Every frame: the current clip (InkAnims key poses) is evaluated and cross-faded into an
## InkRig sample, procedural layers (breathing, look-at, blink) and springs (hair, pants cuffs,
## scarf, cape, companion, swing smear) are applied, then InkBody / InkHead emit the drawing into
## one InkCanvas that is submitted as a single draw command.

## Horizontal distance from the golfer origin to the ball at address (rig units).
const BALL_OFFSET := InkRig.BALL_OFFSET
## Height of the golfer, feet to head top (rig units); used to size line weight for display.
const STANDARD_HEIGHT := 74.0
const IMPACT := 0.045             ## downswing time: the ball leaves on this frame
const SWING_LEN := 0.75

var appearance: Dictionary = Appearance.DEFAULT.duplicate(true)
var facing: float = 1.0
var anim: String = "idle"         ## idle | aim | swing | watch | celebrate | sad | walk | run | jump | land | dance | victory | disappointed | lookaround | any Emotes id
var aim_power: float = 0.0        ## 0..1 backswing amount while aiming
var show_club: bool = true
## Draw the player's custom clothing drawings (off for opponents unless the viewer opts in).
var show_drawings: bool = true
var look_target: Vector2 = Vector2.ZERO  ## Local-space point to look at (watch anim)
## When true, time only moves via set_time() (thumbnails, emote wheel, tests).
var frozen_time := false
## Throttles redraws (cards in a big grid): 0 = every frame.
var redraw_interval := 0.0
## Drop shadow under the feet (off when standing on a UI platform that draws its own).
var shadow := true

var _look: Dictionary = InkLook.DEFAULT.duplicate(true)
var _t: float = 0.0
var _anim_t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0
var _after_swing: String = "watch"
var _one_shot := 0.0
var _redraw_wait := 0.0
var _idle_glance := 7.0
var _top: Dictionary = {}
var _fade_from: Dictionary = {}
var _fade_t := 0.0
var _fade_len := 0.0
var _p: Dictionary = {}
var _cv := InkCanvas.new()
var _seed := 0.0

# Springs (rig space).
var _sway := 0.0
var _sway_v := 0.0
var _last_head := Vector2.INF
var _cuff: Array = [Vector2.ZERO, Vector2.ZERO]
var _cuff_vel: Array = [Vector2.ZERO, Vector2.ZERO]
var _cuff_speed: Array = [0.0, 0.0]
var _last_ank: Array = [Vector2.INF, Vector2.INF]
var _cape := PackedVector2Array()
var _scarf := PackedVector2Array()
var _comp := Vector2.INF
var _comp_v := Vector2.ZERO
var _trail := PackedVector2Array()

static var _bounds_cache: Dictionary = {}


func _ready() -> void:
	set_appearance(appearance)


func set_appearance(a: Dictionary) -> void:
	appearance = Appearance.normalize(a)
	_look = appearance.ink
	_seed = float(hash(str(appearance.get("character", ""))) % 997) * 0.37
	_cape.clear()
	_scarf.clear()
	_comp = Vector2.INF
	_p = _sample()
	queue_redraw()


func character_def() -> Dictionary:
	return InkLook.outfit(str(appearance.get("character", "stickman")))


## Rig units from the golfer origin to the ball at address.
func ball_offset() -> float:
	return BALL_OFFSET


## Rig units from the ground to the top of the head and hat (for name tags and emote bubbles).
func head_height() -> float:
	return -Golfer.head_bounds(appearance).position.y


func play(name: String) -> void:
	if name == anim:
		return
	_begin_fade(0.0 if name == "swing" else (0.1 if name == "aim" else 0.2))
	if name == "swing":
		_top = InkRig.aim_params(aim_power)
	anim = name
	_anim_t = 0.0
	_one_shot = 0.0


## Performs an emote once (see Emotes.LIST), then returns to idle.
func emote(name: String) -> void:
	_begin_fade(0.14)
	anim = name
	_anim_t = 0.0
	_one_shot = Emotes.duration(name)


## True while an emote or celebration should not be interrupted by idle/aim updates.
func is_performing() -> bool:
	return _one_shot > 0.0 or anim in ["celebrate", "sad", "dance", "victory", "disappointed"]


## Sets the animation clock directly. `t` drives loops, `anim_t` one-shots.
func set_time(t: float, anim_t: float) -> void:
	_t = t
	_anim_t = anim_t
	_blink = 0.0
	_fade_len = 0.0
	_p = _sample()
	queue_redraw()


## Swing then transition to another animation. The club meets the ball IMPACT seconds in.
func swing(power: float, then_anim: String = "watch") -> void:
	aim_power = power
	_top = InkRig.aim_params(power)
	_fade_len = 0.0
	anim = "swing"
	_anim_t = 0.0
	_after_swing = then_anim
	_trail.clear()


func _begin_fade(length: float) -> void:
	if _p.is_empty() or length <= 0.0:
		_fade_len = 0.0
		return
	_fade_from = _p
	_fade_t = 0.0
	_fade_len = length


func _process(delta: float) -> void:
	if frozen_time:
		return
	_t += delta
	_anim_t += delta
	_fade_t += delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	if anim == "swing" and _anim_t > SWING_LEN and _after_swing != "swing":
		_begin_fade(0.25)
		anim = _after_swing
		_anim_t = 0.0
	if _one_shot > 0.0 and _anim_t > _one_shot:
		play("idle")
	elif anim in InkAnims.ONE_SHOTS and _anim_t > float(InkAnims.clip(anim).len):
		play("land" if anim == "jump" else "idle")
	if anim == "idle":
		_idle_glance -= delta
		if _idle_glance <= 0.0:
			_idle_glance = randf_range(7.0, 12.0)
			play("lookaround")
	_p = _sample()
	_springs(delta)
	if redraw_interval > 0.0:
		_redraw_wait -= delta
		if _redraw_wait > 0.0:
			return
		_redraw_wait = redraw_interval
	queue_redraw()


# ---------------------------------------------------------------------------
# Pose
# ---------------------------------------------------------------------------

func _sample() -> Dictionary:
	var s: Dictionary
	match anim:
		"aim":
			var q := InkRig.aim_params(aim_power)
			var pw := clampf(aim_power, 0.0, 1.0)
			q.arm = float(q.arm) + sin(_t * 31.0) * 0.012 * pw * pw
			if pw > 0.7:
				q.expr = {"eyes": "focus"}
			s = InkRig.solve(q)
		"swing":
			s = InkRig.evaluate("swing", _anim_t, _top)
		"idle":
			s = InkRig.evaluate("idle", _t)
		_:
			var c := InkAnims.clip(anim)
			s = InkRig.evaluate(anim, _anim_t if not bool(c.loop) or _one_shot > 0.0 else _t)
	# Breathing: the chest and head rise a little; hands stay on the club.
	var breath := sin(_t * TAU / 3.2) * 0.32
	var up := InkRig.up_of(float(s.lean))
	s.neck = (s.neck as Vector2) + up * breath
	s.head = (s.head as Vector2) + up * breath * 1.1
	s.shoulder = (s.shoulder as Vector2) + up * breath * 0.7
	if anim == "watch" and look_target != Vector2.ZERO:
		var want := clampf(atan2(look_target.y, absf(look_target.x)) * 0.5, -0.6, 0.3)
		var extra := want - (-0.36)
		var nk: Vector2 = s.neck
		s.head = nk + ((s.head as Vector2) - nk).rotated(extra)
		s.head_rot = float(s.head_rot) + extra
	if _fade_len > 0.0 and _fade_t < _fade_len and not _fade_from.is_empty():
		s = InkRig.lerp_sample(_fade_from, s, InkAnims.ease(_fade_t / _fade_len, "s"))
	return s


func _springs(delta: float) -> void:
	if delta <= 0.0:
		return
	var p := _p
	# Hair: lags the head.
	var h: Vector2 = p.head
	if _last_head != Vector2.INF:
		var v := clampf((h.x - _last_head.x) / delta, -400.0, 400.0)
		_sway_v += (-v * 0.006 - _sway) * 90.0 * delta - _sway_v * 9.0 * delta
	_last_head = h
	_sway = clampf(_sway + _sway_v * delta, -0.7, 0.7)
	# Pants cuffs trail the ankles, then spring back with a little overshoot.
	for leg in 2:
		var a: Vector2 = (p.fb if leg == 0 else p.ff)
		if _last_ank[leg] != Vector2.INF:
			var moved: Vector2 = a - _last_ank[leg]
			_cuff[leg] = ((_cuff[leg] as Vector2) - moved * 0.75).limit_length(7.0)
			_cuff_speed[leg] = lerpf(float(_cuff_speed[leg]), moved.length() / delta, 0.25)
		_last_ank[leg] = a
		var o: Vector2 = _cuff[leg]
		var ov: Vector2 = _cuff_vel[leg]
		ov += (-o * 240.0 - ov * 15.0) * delta
		o += ov * delta
		_cuff[leg] = o
		_cuff_vel[leg] = ov
	# Cape and scarf chains: each link drifts toward hanging behind its parent.
	if str(_look.back) == "cape":
		_cape = _chain(_cape, (p.neck as Vector2) + Vector2(-1.5, 1.0), 5, 5.6, Vector2(-0.45, 1.0), delta, 1.0)
	if str(_look.neck) == "scarf":
		_scarf = _chain(_scarf, (p.neck as Vector2) + Vector2(-2.6, 1.6), 3, 4.2, Vector2(-1.0, 0.55), delta, 1.6)
	# Companion floats behind the head.
	if str(_look.companion) != "":
		var anchor := h + Vector2(-17.0, -9.0)
		if _comp == Vector2.INF:
			_comp = anchor
		_comp_v += ((anchor - _comp) * 30.0 - _comp_v * 6.0) * delta
		_comp += _comp_v * delta
	# Swing smear: record the club head for a short window after impact.
	if anim == "swing" and _anim_t > IMPACT * 0.4 and _anim_t < 0.24:
		var cdir := ((p.hosel as Vector2) - (p.grip as Vector2)).normalized()
		_trail.append((p.hosel as Vector2) + cdir * 2.5)
		if _trail.size() > 9:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)


func _chain(chain: PackedVector2Array, anchor: Vector2, count: int, link: float, hang: Vector2, delta: float, flutter: float) -> PackedVector2Array:
	var hd := hang.normalized()
	if chain.size() != count:
		chain = PackedVector2Array()
		for i in count:
			chain.append(anchor + hd * link * (i + 1))
	var prev := anchor
	for i in count:
		var wave := Vector2(0, sin(_t * 6.0 + i * 1.3) * 0.5 * flutter * (i + 1) / count)
		var target := prev + hd * link + wave
		var p := chain[i].lerp(target, clampf(delta * (16.0 - i * 2.0), 0.0, 1.0))
		p = prev + (p - prev).normalized() * link
		chain[i] = p
		prev = p
	return chain


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

## Body line width in rig units for the current on-screen size (3% of height, clamped in px).
func _line_units() -> float:
	var s := absf(get_global_transform_with_canvas().get_scale().y)
	if s <= 0.0001:
		return 2.3
	var px := clampf(0.031 * STANDARD_HEIGHT * s, 1.6, 9.0)
	return px / s


func _state(lw: float) -> Dictionary:
	return {
		"lw": lw, "t": _t, "seed": _seed, "sway": _sway, "blink": _blink > 0.0,
		"cuff": _cuff, "cuff_v": _cuff_speed, "cape": _cape, "scarf": _scarf, "trail": _trail,
		"show_club": show_club, "drawings": show_drawings,
	}


func _draw() -> void:
	if _p.is_empty():
		_p = _sample()
	render_into(_cv, _p, _line_units(), true)
	_cv.flush(get_canvas_item())


## Emits the full golfer (pose `p`) into `cv` in this node's local space.
func render_into(cv: InkCanvas, p: Dictionary, lw: float, with_shadow: bool) -> void:
	cv.xf = Transform2D(Vector2(facing, 0), Vector2(0, 1), Vector2.ZERO)
	var st := _state(lw)
	if with_shadow and shadow:
		var lift := clampf(-((p.fb as Vector2).y + (p.ff as Vector2).y) * 0.5 / 14.0, 0.0, 1.0)
		cv.ellipse(Vector2(0, 0.6), Vector2(15.0 * (1.0 - lift * 0.35), 2.6), Color(0.1, 0.08, 0.06, 0.16 * (1.0 - lift * 0.5)))
	if _comp != Vector2.INF:
		InkHead.draw_companion(cv, _comp, _look, st)
	InkBody.draw(cv, p, _look, st)
	InkHead.draw(cv, p, _look, st)


## Inked bounds of the golfer (node space, facing right) for the given animation frame.
## Used to frame cards and previews from the actual artwork.
func visual_bounds(anim_name: String = "idle", t: float = 0.0, outline: float = 2.4, min_z: float = -INF) -> Rect2:
	var saved := [anim, _t, _anim_t, _one_shot, _fade_len, facing]
	anim = anim_name
	_t = t
	_anim_t = t
	_one_shot = 0.0
	_fade_len = 0.0
	facing = 1.0
	var p := _sample()
	var cv := InkCanvas.new()
	cv.xf = Transform2D.IDENTITY
	var st := _state(outline)
	if min_z > -INF:
		InkHead.draw(cv, p, _look, st)
	else:
		if _comp != Vector2.INF:
			InkHead.draw_companion(cv, (p.head as Vector2) + Vector2(-17.0, -9.0), _look, st)
		InkBody.draw(cv, p, _look, st)
		InkHead.draw(cv, p, _look, st)
	anim = saved[0]
	_t = saved[1]
	_anim_t = saved[2]
	_one_shot = saved[3]
	_fade_len = saved[4]
	facing = saved[5]
	return cv.bounds


## Idle bounds per look, cached (appearance changes like hats change the bounds).
static func idle_bounds(app: Dictionary) -> Rect2:
	var key := JSON.stringify(Appearance.normalize(app))
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var g := Golfer.new()
	g.set_appearance(app)
	var r := Rect2()
	for i in 4:
		var b := g.visual_bounds("idle", float(i) * 0.85)
		r = b if i == 0 else r.merge(b)
	if str(g._look.companion) != "":
		r = r.merge(Rect2(Vector2(-30, -82), Vector2(10, 10)))
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
	var r := g.visual_bounds("idle", 0.0, 2.4, 0.0)
	g.free()
	_bounds_cache[key] = r
	return r


## Debug/test access to the solved skeleton.
func solved_pose() -> Dictionary:
	return _sample()


## Poses used for still renders (thumbnails, portraits): standing tall, no club in hand.
const STILL_POSES := {
	"stand": {"club": "none", "lean": 0.02, "tilt": -0.04, "hb": Vector2(-5, 21), "hf": Vector2(6, 21)},
	"stride": {"club": "none", "lean": 0.04, "tilt": 0.0, "hb": Vector2(-8, 19), "hf": Vector2(9, 18), "fb": Vector2(-8, 0), "ff": Vector2(8, 0)},
}


## Draws a still golfer (no node, no springs) into `cv`. `pose` is an InkAnims clip name or a
## STILL_POSES key; `part` limits the drawing to "head" or "club" for focused thumbnails.
static func draw_still(cv: InkCanvas, app: Dictionary, pose: String = "idle", lw: float = 2.3, part: String = "") -> Dictionary:
	var look: Dictionary = Appearance.normalize(app).ink
	var s: Dictionary
	if STILL_POSES.has(pose):
		s = InkRig.solve(STILL_POSES[pose])
	else:
		s = InkRig.evaluate(pose, 0.0)
	var st := {"lw": lw, "t": 0.0, "seed": 1.0, "sway": 0.0, "blink": false, "cuff": [Vector2.ZERO, Vector2.ZERO],
		"cuff_v": [0.0, 0.0], "cape": _still_chain(s, look, "back"), "scarf": _still_chain(s, look, "neck"),
		"trail": PackedVector2Array(), "show_club": pose not in STILL_POSES, "drawings": true}
	match part:
		"head":
			InkHead.draw(cv, s, look, st)
		"club":
			InkBody.draw_club(cv, s, look, st)
		_:
			if str(look.companion) != "":
				InkHead.draw_companion(cv, (s.head as Vector2) + Vector2(-17.0, -9.0), look, st)
			InkBody.draw(cv, s, look, st)
			InkHead.draw(cv, s, look, st)
	return s


static func _still_chain(s: Dictionary, look: Dictionary, which: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	if which == "back" and str(look.back) == "cape":
		for i in 5:
			out.append((s.neck as Vector2) + Vector2(-1.5 - i * 2.2, 1.0 + (i + 1) * 5.2))
	elif which == "neck" and str(look.neck) == "scarf":
		for i in 3:
			out.append((s.neck as Vector2) + Vector2(-2.6 - (i + 1) * 3.8, 1.6 + (i + 1) * 2.2))
	return out
