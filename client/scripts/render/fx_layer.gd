class_name FxLayer
extends Node2D
## Hand-drawn gameplay effects (docs/INK_ART_SPEC.md §11): outlined dust puffs, ink impact
## stars, speed streaks, droplets, sparkles, ice shards and shockwave arcs, all drawn in one
## InkCanvas pass per frame. Effects stay short and light so the ball always reads; the
## "reduced effects" setting halves particle counts.

const INK := InkCanvas.INK
const MAX := 700

enum K { PUFF, RING, CONFETTI, STREAK, SMOKE, DROP, STAR, SHARD, BURST, SHOCK }

class P:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var kind: int
	var gravity: float
	var drag: float
	var rot: float
	var spin: float
	var seed_v: float

var _ps: Array[P] = []
var _cv := InkCanvas.new()


func _amount(n: int) -> int:
	return maxi(1, n / 2) if bool(Settings.get_value("gameplay", "reduced_motion")) else n


func _process(delta: float) -> void:
	if _ps.is_empty():
		return
	var i := _ps.size() - 1
	while i >= 0:
		var p := _ps[i]
		p.life -= delta
		if p.life <= 0.0:
			_ps.remove_at(i)
		else:
			p.vel.y += p.gravity * delta
			p.vel *= maxf(0.0, 1.0 - p.drag * delta)
			p.pos += p.vel * delta
			p.rot += p.spin * delta
		i -= 1
	queue_redraw()


func _add(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: int, gravity: float = 0.0, drag: float = 0.0, spin: float = 0.0) -> void:
	if _ps.size() >= MAX:
		_ps.remove_at(0)
	var p := P.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.color = color
	p.kind = kind
	p.gravity = gravity
	p.drag = drag
	p.rot = randf() * TAU
	p.spin = spin
	p.seed_v = randf() * 100.0
	_ps.append(p)


func _draw() -> void:
	var cv := _cv
	for p in _ps:
		var k := p.life / p.max_life      ## 1 at birth -> 0 at death
		var c := p.color
		match p.kind:
			K.PUFF, K.SMOKE:
				var r := p.size * (0.55 + (1.0 - k) * 0.7)
				var a := minf(1.0, k * 2.2)
				cv.ellipse(p.pos, Vector2(r, r * 0.92), Color(c, c.a * a), p.rot)
				cv.ink_circle(p.pos, Vector2(r, r * 0.92), 1.4, Color(INK if p.kind == K.PUFF else c.darkened(0.45), 0.55 * a), p.seed_v, p.rot, 0.15, 0.08)
			K.RING:
				var rr := p.size * (1.0 - k * 0.85) + 4.0
				cv.ink_circle(p.pos, Vector2(rr, rr), 1.5 + 4.0 * k, Color(c, c.a * k), p.seed_v, 0.0, 0.0, 0.03)
			K.CONFETTI:
				var d := Vector2.from_angle(p.rot) * p.size
				var e := Vector2.from_angle(p.rot + PI * 0.5) * p.size * 0.45 * absf(sin(p.rot * 2.0))
				var a2 := minf(1.0, k * 3.0)
				cv.quad(p.pos - d - e, p.pos + d - e, p.pos + d + e, p.pos - d + e, Color(c, a2))
			K.STREAK:
				var tail := p.pos - p.vel * 0.045
				cv.stroke(PackedVector2Array([tail, p.pos]), p.size, Color(c, c.a * k), 0.7, 0.15)
			K.DROP:
				var dir := p.vel.normalized() if p.vel.length() > 1.0 else Vector2.DOWN
				var tear := PackedVector2Array([p.pos + dir * p.size * 1.6, p.pos + dir.rotated(1.8) * p.size, p.pos - dir * p.size, p.pos + dir.rotated(-1.8) * p.size])
				var drop := InkCanvas.spline(tear, 3, true)
				cv.fill(drop, Color(c, minf(1.0, k * 2.0)))
				cv.outline(drop, 1.1, Color(INK, 0.5 * k), p.seed_v)
			K.STAR:
				var s := p.size * (0.5 + k * 0.6)
				var star := PackedVector2Array()
				for q in 8:
					star.append(p.pos + Vector2.from_angle(p.rot + TAU * q / 8.0) * (s if q % 2 == 0 else s * 0.3))
				cv.fill(star, Color(c, k))
			K.SHARD:
				var sd := Vector2.from_angle(p.rot)
				var sn := Vector2(-sd.y, sd.x)
				var shard := PackedVector2Array([p.pos + sd * p.size, p.pos + sn * p.size * 0.4, p.pos - sd * p.size, p.pos - sn * p.size * 0.4])
				cv.fill(shard, Color(c, k))
				cv.outline(shard, 1.0, Color(INK, 0.6 * k), p.seed_v)
			K.BURST:
				# Ink impact star: radial tapered strokes that shoot out and thin away.
				var n := 7
				var grow := 1.0 - k
				for q in n:
					var a3 := p.rot + TAU * q / n
					var len := p.size * (0.55 + 0.45 * float((q * 5) % 3) / 2.0)
					var a0 := p.pos + Vector2.from_angle(a3) * len * (0.25 + grow * 0.7)
					var a1 := p.pos + Vector2.from_angle(a3) * len * (0.7 + grow * 0.7)
					cv.stroke(PackedVector2Array([a0, a1]), 3.2 * k + 0.6, Color(c, k), 0.1, 0.8)
			K.SHOCK:
				var rr2 := p.size * (1.0 - k) + 6.0
				var arc := InkCanvas.arc_pts(p.pos, rr2, p.rot, p.rot + PI * 1.4, 18)
				cv.stroke(arc, 6.0 * k + 1.0, Color(c, k), 0.4, 0.4, p.seed_v)
	cv.flush(get_canvas_item())


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

func dust(pos: Vector2, normal: Vector2, strength: float, color: Color = Color("e9dcc6")) -> void:
	var n := _amount(int(clampf(strength / 110.0, 2.0, 8.0)))
	var tang := Vector2(-normal.y, normal.x)
	for i in n:
		var side := tang * randf_range(-1.0, 1.0) * strength * 0.22
		_add(pos + normal * 3.0, side + normal * randf_range(20, 70), randf_range(0.35, 0.6), randf_range(4.0, 7.5), color, K.PUFF, 60.0, 3.0)
	if strength > 420.0:
		for i in _amount(4):
			var d := normal.rotated(randf_range(-1.0, 1.0))
			_add(pos, d * randf_range(160, 300), 0.22, 1.6, Color(INK, 0.7), K.STREAK, 0.0, 4.0)


func impact_ring(pos: Vector2, color: Color = Color(1, 1, 1, 0.8), size: float = 26.0) -> void:
	_add(pos, Vector2.ZERO, 0.3, size, color, K.RING)


func splash(pos: Vector2, color: Color = Color("bdeafe")) -> void:
	for i in _amount(14):
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_add(pos, Vector2.from_angle(a) * randf_range(160, 420), randf_range(0.5, 0.9), randf_range(2.6, 4.6), color, K.DROP, 900.0, 0.5)
	impact_ring(pos, Color(1, 1, 1, 0.95), 46.0)
	impact_ring(pos + Vector2(0, 2), Color(InkCanvas.INK, 0.45), 70.0)


func lava_splash(pos: Vector2) -> void:
	for i in _amount(20):
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_add(pos, Vector2.from_angle(a) * randf_range(120, 380), randf_range(0.5, 1.0), randf_range(2.6, 4.4), Color("ffb347").lerp(Color("ff3d00"), randf()), K.DROP, 800.0, 0.5)
	for i in _amount(7):
		_add(pos + Vector2(randf_range(-20, 20), -10), Vector2(randf_range(-20, 20), randf_range(-80, -40)), randf_range(0.8, 1.4), randf_range(8, 13), Color(0.5, 0.46, 0.48, 0.85), K.SMOKE, -20.0, 1.0)


## Grenade: curved ink burst, shockwave arcs, outlined smoke and flying debris.
func explosion(pos: Vector2, radius: float) -> void:
	_add(pos, Vector2.ZERO, 0.16, radius * 0.5, Color(1, 0.96, 0.78, 0.95), K.PUFF)
	_add(pos, Vector2.ZERO, 0.32, radius * 1.1, InkCanvas.INK, K.BURST)
	_add(pos, Vector2.ZERO, 0.45, radius * 1.2, Color("ffb03b"), K.SHOCK)
	_add(pos, Vector2.ZERO, 0.55, radius * 1.5, Color(InkCanvas.INK, 0.6), K.SHOCK)
	_ps[_ps.size() - 1].rot += PI
	for i in _amount(18):
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(250, 650), randf_range(0.2, 0.4), 2.4, Color("ff8a3d"), K.STREAK, 300.0, 2.0)
	for i in _amount(10):
		var a := randf() * TAU
		_add(pos + Vector2.from_angle(a) * randf_range(0, 18), Vector2.from_angle(a) * randf_range(40, 140), randf_range(0.7, 1.2), randf_range(11, 19), Color(0.88, 0.86, 0.84, 0.95), K.PUFF, -40.0, 2.5)


func confetti(pos: Vector2, amount: int = 60) -> void:
	var palette := [Color("f2b630"), Color("ef5a5a"), Color("3dbf7f"), Color("3fa3e8"), Color("9b6be8"), Color("fbf6ec")]
	for i in _amount(amount):
		var a := randf_range(-PI * 0.85, -PI * 0.15)
		_add(pos, Vector2.from_angle(a) * randf_range(250, 650), randf_range(1.4, 2.4), randf_range(4.0, 6.0), palette[i % palette.size()], K.CONFETTI, 700.0, 1.6, randf_range(-14, 14))
	for i in _amount(8):
		var a2 := randf_range(-PI, 0.0)
		_add(pos + Vector2(0, -20), Vector2.from_angle(a2) * randf_range(80, 220), randf_range(0.6, 1.0), randf_range(5, 8), Color("f2b630"), K.STAR, 200.0, 2.0, randf_range(-6, 6))
	_add(pos + Vector2(0, -18), Vector2.ZERO, 0.4, 44.0, InkCanvas.INK, K.BURST)


func sparkle(pos: Vector2, color: Color = Color("ffd166"), amount: int = 10) -> void:
	for i in _amount(amount):
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(60, 200), randf_range(0.3, 0.6), randf_range(3.0, 5.0), color, K.STAR, 0.0, 3.0, randf_range(-8, 8))


func nitro_burst(pos: Vector2, dir: Vector2) -> void:
	for i in _amount(14):
		var spread := dir.rotated(randf_range(-0.5, 0.5))
		_add(pos, -spread * randf_range(200, 460), randf_range(0.22, 0.42), randf_range(2.0, 3.4), Color("ff8a3d").lerp(Color("ffd166"), randf()), K.STREAK, 0.0, 4.0)
	for i in _amount(5):
		_add(pos - dir * 10.0, -dir * randf_range(30, 80) + Vector2(randf_range(-20, 20), randf_range(-20, 20)), randf_range(0.4, 0.6), randf_range(6, 10), Color(1, 1, 1, 0.9), K.PUFF, -30.0, 3.0)
	impact_ring(pos, Color("ff8a3d"), 38.0)


func brake_puff(pos: Vector2) -> void:
	for i in _amount(10):
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(40, 120), randf_range(0.4, 0.7), randf_range(6, 10), Color(1, 1, 1, 0.92), K.PUFF, 0.0, 3.0)
	impact_ring(pos, Color("4cc9f0"), 34.0)


func goo(pos: Vector2) -> void:
	for i in _amount(10):
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(60, 180), randf_range(0.3, 0.55), randf_range(2.4, 4.0), Color("b462e8"), K.DROP, 500.0, 1.0)


func ice(pos: Vector2) -> void:
	for i in _amount(10):
		var a := randf_range(-PI, 0.0)
		_add(pos, Vector2.from_angle(a) * randf_range(80, 220), randf_range(0.4, 0.7), randf_range(3.5, 6.0), Color("d6f3ff"), K.SHARD, 600.0, 1.0, randf_range(-8, 8))
	impact_ring(pos, Color("7fc8e8"), 40.0)


func poof(pos: Vector2) -> void:
	for i in _amount(9):
		var a := randf() * TAU
		_add(pos + Vector2.from_angle(a) * 8.0, Vector2.from_angle(a) * randf_range(30, 90), randf_range(0.35, 0.6), randf_range(6, 10), Color(1, 1, 1, 0.95), K.PUFF, -30.0, 3.0)


## Club meets ball: ink impact star, a couple of direction streaks and a dust kick.
func shot_burst(pos: Vector2, dir: Vector2, power: float) -> void:
	_add(pos, Vector2.ZERO, 0.22, 14.0 + power * 18.0, InkCanvas.INK, K.BURST)
	impact_ring(pos, Color(1, 1, 1, 0.9), 16.0 + power * 20.0)
	for i in _amount(int(3 + power * 5)):
		var d := dir.rotated(randf_range(-0.35, 0.35))
		_add(pos, d * randf_range(160, 360) * (0.5 + power), randf_range(0.16, 0.3), 2.0, Color(InkCanvas.INK, 0.8), K.STREAK, 0.0, 2.0)
	for i in _amount(3):
		_add(pos + Vector2(randf_range(-6, 6), 4), Vector2(randf_range(-60, 60), randf_range(-60, -20)), randf_range(0.3, 0.5), randf_range(4, 6), Color("e9dcc6"), K.PUFF, 80.0, 3.0)


## Kept for callers of the old flipbook API: maps names to drawn effects.
func flip(name: String, pos: Vector2, angle: float = 0.0, scale_mul: float = 1.0) -> void:
	match name:
		"impact":
			_add(pos, Vector2.ZERO, 0.22, 24.0 * scale_mul, InkCanvas.INK, K.BURST)
		"splash":
			splash(pos)
		"sparkle":
			sparkle(pos)
		"dust":
			dust(pos, Vector2.from_angle(angle - PI * 0.5), 500.0 * scale_mul)


## A frozen patch on a water surface (Ice Ball). Stays until clear_persistent().
func ice_patch(pos: Vector2) -> void:
	var patch := _IcePatch.new()
	patch.position = pos
	add_child(patch)
	sparkle(pos + Vector2(0, -6), Color("e6fbff"), 12)
	impact_ring(pos, Color("7fc8e8"), 34.0)


func clear_persistent() -> void:
	for c in get_children():
		if c is _IcePatch:
			c.queue_free()


## Hand-drawn ice sheet that grows out from where the Ice Ball landed: a pale slab with an inked
## rim, white glints and crack ticks.
class _IcePatch extends Node2D:
	var _t := 0.0
	var _cv := InkCanvas.new()

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.6:
			queue_redraw()

	func _draw() -> void:
		var grow := clampf(_t / 0.35, 0.0, 1.0)
		var w := 70.0 * grow
		if w < 2.0:
			return
		var slab := PackedVector2Array([Vector2(-w, -3), Vector2(-w * 0.5, -4.5), Vector2(w * 0.5, -4.0), Vector2(w, -3), Vector2(w - 4, 5), Vector2(-w + 4, 5)])
		_cv.fill(slab, Color("cdeefb"))
		_cv.stroke(PackedVector2Array([Vector2(-w + 6, -1.5), Vector2(w * 0.3, -2.5)]), 2.0, Color(1, 1, 1, 0.9), 0.3, 0.3)
		var x := -w + 14.0
		var k := 0
		while x < w - 10.0:
			_cv.stroke(PackedVector2Array([Vector2(x, 3), Vector2(x + 4, -1 if k % 2 == 0 else 0)]), 1.1, Color(InkCanvas.INK, 0.4), 0.2, 0.2)
			x += 20.0
			k += 1
		_cv.outline(slab, 2.2, Color("245e8e"), 3.0)
		_cv.flush(get_canvas_item())
