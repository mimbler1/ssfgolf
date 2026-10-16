class_name FxLayer
extends Node2D
## Gameplay feedback: authored sprite flipbooks (res://assets/effects, see effects.json) layered
## with a light particle system (sparks, confetti, droplets) drawn in one pass.

class P:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var kind: int       # 0 circle, 1 ring, 2 confetti rect, 3 spark line, 4 smoke
	var gravity: float
	var drag: float
	var rot: float
	var spin: float

var _ps: Array[P] = []
const MAX := 900

const FX_DIR := "res://assets/effects/"
static var _fx_lib: Dictionary = {}
static var _fx_loaded := false


## Plays an authored flipbook effect once at `pos` (no-op when the effect has no art).
func flip(name: String, pos: Vector2, angle: float = 0.0, scale_mul: float = 1.0) -> void:
	if not _fx_loaded:
		_fx_loaded = true
		var path := FX_DIR + "effects.json"
		if FileAccess.file_exists(path):
			_fx_lib = JSON.parse_string(FileAccess.get_file_as_string(path))
	var d: Dictionary = _fx_lib.get(name, {})
	if d.is_empty():
		return
	var sp := _Flip.new()
	sp.texture = load(FX_DIR + str(d.sheet))
	sp.hframes = int(d.frames)
	sp.fps = float(d.get("fps", 20))
	sp.position = pos
	sp.rotation = angle
	var k := float(d.get("scale", 2.0)) * scale_mul
	sp.scale = Vector2(k, k)
	sp.offset = Vector2(0, float(d.get("offset_y", 0)))
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if bool(d.get("additive", false)):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sp.material = m
	add_child(sp)


class _Flip extends Sprite2D:
	var fps := 20.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var f := int(_t * fps)
		if f >= hframes:
			queue_free()
		else:
			frame = f


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
	_ps.append(p)


func _draw() -> void:
	for p in _ps:
		var k := p.life / p.max_life
		var c := p.color
		match p.kind:
			0:
				c.a *= minf(1.0, k * 2.0)
				draw_circle(p.pos, p.size * (0.4 + 0.6 * k), c, true, -1.0, true)
			1:
				c.a *= k
				draw_arc(p.pos, p.size * (1.0 - k) + 4.0, 0, TAU, 40, c, 3.0 + 5.0 * k, true)
			2:
				c.a *= minf(1.0, k * 3.0)
				var d := Vector2.from_angle(p.rot) * p.size
				var e := Vector2.from_angle(p.rot + PI * 0.5) * p.size * 0.5 * absf(sin(p.rot * 2.0))
				draw_colored_polygon(PackedVector2Array([p.pos - d - e, p.pos + d - e, p.pos + d + e, p.pos - d + e]), c)
			3:
				c.a *= k
				draw_line(p.pos, p.pos - p.vel * 0.035, c, p.size, true)
			4:
				c.a *= k * 0.6
				draw_circle(p.pos, p.size * (1.6 - k * 0.6), c, true, -1.0, true)


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

func dust(pos: Vector2, normal: Vector2, strength: float, color: Color = Color("e9dcc6")) -> void:
	var n := int(clampf(strength / 90.0, 2.0, 10.0))
	var tang := Vector2(-normal.y, normal.x)
	if strength > 380.0:
		flip("dust", pos, normal.angle() + PI * 0.5, clampf(strength / 700.0, 0.6, 1.0))
	for i in n:
		var side := tang * randf_range(-1.0, 1.0) * strength * 0.25
		_add(pos, side + normal * randf_range(20, 70), randf_range(0.35, 0.6), randf_range(3.0, 6.0), color, 4, 60.0, 3.0)


func impact_ring(pos: Vector2, color: Color = Color(1, 1, 1, 0.8), size: float = 26.0) -> void:
	_add(pos, Vector2.ZERO, 0.28, size, color, 1)


func splash(pos: Vector2, color: Color = Color("bdeafe")) -> void:
	flip("splash", pos)
	for i in 14:
		var a := randf_range(-PI * 0.92, -PI * 0.08)
		_add(pos, Vector2.from_angle(a) * randf_range(140, 420), randf_range(0.5, 0.9), randf_range(2.5, 5.0), color, 0, 900.0, 0.5)
	impact_ring(pos, Color(1, 1, 1, 0.9), 50.0)
	impact_ring(pos + Vector2(0, 2), Color(color, 0.7), 80.0)


func lava_splash(pos: Vector2) -> void:
	for i in 22:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_add(pos, Vector2.from_angle(a) * randf_range(120, 380), randf_range(0.5, 1.0), randf_range(2.5, 5.0), Color("ffb347").lerp(Color("ff3d00"), randf()), 0, 800.0, 0.5)
	for i in 8:
		_add(pos + Vector2(randf_range(-20, 20), -10), Vector2(randf_range(-20, 20), randf_range(-80, -40)), randf_range(0.8, 1.4), randf_range(8, 14), Color(0.25, 0.22, 0.25, 0.8), 4, -20.0, 1.0)


func explosion(pos: Vector2, radius: float) -> void:
	_add(pos, Vector2.ZERO, 0.14, radius * 0.55, Color(1, 0.97, 0.8, 0.95), 0)
	_add(pos, Vector2.ZERO, 0.45, radius, Color("ffd166"), 1)
	_add(pos, Vector2.ZERO, 0.6, radius * 1.3, Color(1, 1, 1, 0.5), 1)
	for i in 34:
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(250, 700), randf_range(0.25, 0.5), randf_range(2.0, 4.0), Color("ffb703").lerp(Color("ff4d1d"), randf()), 3, 300.0, 2.0)
	for i in 14:
		var a := randf() * TAU
		_add(pos + Vector2.from_angle(a) * randf_range(0, 20), Vector2.from_angle(a) * randf_range(40, 140), randf_range(0.7, 1.2), randf_range(12, 22), Color(0.35, 0.33, 0.38, 0.9), 4, -40.0, 2.5)


func confetti(pos: Vector2, amount: int = 60) -> void:
	flip("sparkle", pos + Vector2(0, -24), 0.0, 1.4)
	var palette := [Color("ffd166"), Color("ef476f"), Color("06d6a0"), Color("4cc9f0"), Color("b65cff"), Color("ffffff")]
	for i in amount:
		var a := randf_range(-PI * 0.85, -PI * 0.15)
		_add(pos, Vector2.from_angle(a) * randf_range(250, 650), randf_range(1.4, 2.4), randf_range(4.0, 6.5), palette[i % palette.size()], 2, 700.0, 1.6, randf_range(-14, 14))


func sparkle(pos: Vector2, color: Color = Color("ffd166"), amount: int = 10) -> void:
	for i in amount:
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(60, 200), randf_range(0.3, 0.6), randf_range(1.6, 2.6), color, 3, 0.0, 3.0)


func nitro_burst(pos: Vector2, dir: Vector2) -> void:
	flip("flame", pos, (-dir).angle() + PI * 0.5)
	for i in 18:
		var spread := dir.rotated(randf_range(-0.6, 0.6))
		_add(pos, -spread * randf_range(150, 420), randf_range(0.25, 0.5), randf_range(3, 6), Color("ffd166").lerp(Color("ff4d1d"), randf()), 0, 0.0, 4.0)
	impact_ring(pos, Color("ff7b2e"), 40.0)


func brake_puff(pos: Vector2) -> void:
	for i in 12:
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(40, 120), randf_range(0.4, 0.7), randf_range(6, 11), Color(1, 1, 1, 0.8), 4, 0.0, 3.0)
	impact_ring(pos, Color("4cc9f0"), 34.0)


## A frozen patch on a water surface (Ice Ball). Stays until clear_persistent().
func ice_patch(pos: Vector2) -> void:
	var patch := _IcePatch.new()
	patch.position = pos
	add_child(patch)
	sparkle(pos + Vector2(0, -6), Color("e6fbff"), 14)
	impact_ring(pos, Color("a5e8ff"), 34.0)


func clear_persistent() -> void:
	for c in get_children():
		if c is _IcePatch:
			c.queue_free()


class _IcePatch extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.6:
			queue_redraw()

	func _draw() -> void:
		var grow := clampf(_t / 0.35, 0.0, 1.0)
		var w := 70.0 * grow
		draw_rect(Rect2(-w - 3, -5, w * 2 + 6, 12), Color("1b2040"))
		draw_rect(Rect2(-w, -3, w * 2, 8), Color("bfefff"))
		draw_rect(Rect2(-w, -3, w * 2, 2), Color("ffffff"))
		var x := -w + 10.0
		while x < w - 8.0:
			draw_rect(Rect2(x, 1, 6, 2), Color("8fd8f5"))
			x += 22.0


func goo(pos: Vector2) -> void:
	for i in 12:
		var a := randf() * TAU
		_add(pos, Vector2.from_angle(a) * randf_range(60, 180), randf_range(0.3, 0.55), randf_range(2.5, 4.5), Color("b65cff"), 0, 500.0, 1.0)


func poof(pos: Vector2) -> void:
	for i in 10:
		var a := randf() * TAU
		_add(pos + Vector2.from_angle(a) * 8.0, Vector2.from_angle(a) * randf_range(30, 90), randf_range(0.35, 0.6), randf_range(7, 12), Color(1, 1, 1, 0.9), 4, -30.0, 3.0)


func shot_burst(pos: Vector2, dir: Vector2, power: float) -> void:
	flip("impact", pos, 0.0, 0.7 + power * 0.5)
	impact_ring(pos, Color(1, 1, 1, 0.9), 18.0 + power * 22.0)
	for i in int(4 + power * 8):
		var d := dir.rotated(randf_range(-0.5, 0.5))
		_add(pos, d * randf_range(120, 320) * (0.5 + power), randf_range(0.18, 0.35), 2.2, Color(1, 1, 1, 0.9), 3, 0.0, 2.0)
