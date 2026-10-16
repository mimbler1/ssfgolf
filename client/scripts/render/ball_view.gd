class_name BallView
extends Node2D
## Hand-drawn golf ball (docs/INK_ART_SPEC.md §11): ink outline, rotating dimple marks, a
## tapered trail, ability skins and state overlays (shield, frost, anti-grav, magnet), ground
## shadow, name tag and (for the local player) the cooldown ring. Purely visual; positions come
## from the simulation every frame.

const TRAIL_LEN := 26
const INK := InkCanvas.INK

var slot: int = 0
var radius: float = 9.0
var ball_color: Color = Color.WHITE
var trail_color: Color = Color("ffd166")
var slot_color: Color = Color.WHITE
var display_name: String = ""
var is_local: bool = false
var terrain: SimTerrain

# Render state, set by the game scene every frame.
var rot: float = 0.0
var ability: String = "standard"
var boosted: float = 0.0        ## >0 while nitro flames should show
var braked: float = 0.0         ## >0 while the air-brake chute shows
var moving: bool = false
var visible_ball: bool = true
var cooldown_frac: float = 0.0  ## 0 = ready, 1 = just shot
var ready_to_shoot: bool = false
var finished: bool = false
var disconnected: bool = false
## Name tag shown (the scene hides it while balls are bunched together, e.g. on the tee).
var show_name: bool = true
## Ability states mirrored from the authoritative ball (snapshot flags).
var shield: bool = false
var iced: bool = false
var anti_grav: bool = false
var magnet: bool = false

var _trail: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0
var _ready_pulse: float = 0.0
var _was_ready: bool = false
var _shadow_y: float = 0.0
var _shadow_dist: float = 999.0
var _cv := InkCanvas.new()


func _process(delta: float) -> void:
	_t += delta
	boosted = maxf(0.0, boosted - delta)
	braked = maxf(0.0, braked - delta)
	if moving and visible_ball:
		_trail.append(global_position)
		if _trail.size() > TRAIL_LEN:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)
		if _trail.size() > 0:
			_trail.remove_at(0)
	if ready_to_shoot and not _was_ready:
		_ready_pulse = 1.0
	_was_ready = ready_to_shoot
	_ready_pulse = maxf(0.0, _ready_pulse - delta * 2.5)
	if terrain and visible_ball:
		var hit := terrain.raycast(global_position, Vector2.DOWN, 500.0)
		if hit.hit:
			_shadow_y = hit.pos.y - global_position.y
			_shadow_dist = hit.dist
		else:
			_shadow_dist = 999.0
	queue_redraw()


func clear_trail() -> void:
	_trail.clear()


func _trail_dir() -> Vector2:
	if _trail.size() >= 2:
		var d := _trail[_trail.size() - 1] - _trail[_trail.size() - 2]
		if d.length_squared() > 0.01:
			return d.normalized()
	return Vector2.RIGHT


## Ball fill for an ability (the same rules the old renderer used, so balls stay recognisable).
static func ability_fill(base: Color, ability_id: String) -> Color:
	match ability_id:
		"heavy":
			return Color("8d96a6")
		"sticky":
			return Color("b462e8")
		"grenade":
			return Color("5cbf6c")
		"nitro":
			return base.lerp(Color("ff8a3d"), 0.55)
		"air_brake":
			return base.lerp(Color("4cc9f0"), 0.5)
		"standard", "laser", "mulligan", "free_shot":
			return base
	return base.lerp(Color(GameData.ability(ability_id).get("color", "#ffffff")), 0.5)


func _draw() -> void:
	if not visible_ball:
		return
	var cv := _cv
	var r := radius
	if _trail.size() > 3:
		var local := PackedVector2Array()
		for p in _trail:
			local.append(to_local(p))
		var smooth := InkCanvas.spline(local, 2)
		cv.stroke(smooth, r * 1.7, Color(trail_color, 0.62), 0.95, 0.02, 1.0, 0.0, 0.0, 0.0)
		cv.stroke(InkCanvas.offset_line(smooth, r * 0.55), 1.3, Color(INK, 0.35), 0.9, 0.05, 2.0, 0.0, 0.0, 0.0)
	if _shadow_dist < 480.0:
		var s := clampf(1.0 - _shadow_dist / 480.0, 0.0, 1.0)
		cv.ellipse(Vector2(0, _shadow_y), Vector2(r * (0.6 + s * 0.6), r * 0.25 * (0.5 + s * 0.5)), Color(0.1, 0.07, 0.05, 0.2 * s))
	if boosted > 0.0:
		_flames(cv, r)
	if braked > 0.0:
		_chute(cv, r)
	var fill := ability_fill(ball_color, ability)
	if iced:
		fill = fill.lerp(Color("cdf3ff"), 0.6)
	var alpha := 0.5 if finished or disconnected else 1.0
	cv.ellipse(Vector2.ZERO, Vector2(r, r), Color(fill, alpha))
	cv.crescent(Vector2.ZERO, r * 0.98, Vector2(-r * 0.26, -r * 0.24), Color(fill.darkened(0.16), alpha))
	var mark := fill.darkened(0.32)
	for k in 3:
		var a := rot + TAU * float(k) / 3.0
		var p := Vector2(cos(a), sin(a)) * r * 0.52
		cv.stroke(InkCanvas.arc_pts(p, r * 0.16, a + 1.2, a + 2.6, 4), 1.1, Color(mark, alpha * 0.9), 0.2, 0.2)
	match ability:
		"heavy":
			cv.stroke(PackedVector2Array([Vector2.from_angle(rot) * -r * 0.85, Vector2.from_angle(rot) * r * 0.85]), 2.2, Color("4f5868"), 0.1, 0.1)
		"grenade":
			cv.shape(PackedVector2Array([Vector2(-2.5, -r - 3.5), Vector2(2.5, -r - 3.5), Vector2(2.5, -r + 1.0), Vector2(-2.5, -r + 1.0)]), Color("8d96a6"), 1.4)
			cv.ink_circle(Vector2(4.0, -r - 3.0), Vector2(2.0, 2.0), 1.2, INK, 3.0)
			cv.dot(Vector2(0, -1.5), 2.2, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(_t * 18.0)))
		"sticky":
			cv.stroke(PackedVector2Array([Vector2(r * 0.3, r * 0.75), Vector2(r * 0.34, r * 1.35)]), 2.6, Color("7a35b8"), 0.1, 0.3)
			cv.dot(Vector2(r * 0.34, r * 1.35), 1.8, Color("7a35b8"))
		"laser":
			cv.stroke(PackedVector2Array([Vector2(-r * 0.6, 0), Vector2(r * 0.6, 0)]), 1.6, Color("ef3b3b"), 0.2, 0.2)
		"super":
			InkIcons._spark(cv, Vector2.ZERO, r * 0.55, Color(1, 1, 1, 0.75))
		"zig_zag":
			cv.stroke(PackedVector2Array([Vector2(-r * 0.6, -r * 0.2), Vector2(-r * 0.2, r * 0.25), Vector2(r * 0.2, -r * 0.25), Vector2(r * 0.6, r * 0.2)]), 1.4, Color(INK, 0.6), 0.1, 0.1)
	_states(cv, r)
	cv.ink_circle(Vector2.ZERO, Vector2(r, r), 2.4, Color(INK, alpha), float(slot) * 3.0 + 1.0, 0.0, 0.25, 0.025)
	if is_local and not finished:
		_local_marker(cv)
	cv.flush(get_canvas_item())
	if not is_local and display_name != "" and not finished and show_name:
		_draw_name()


## Ability state overlays: shield bubble, frost, anti-grav rings, magnet pulse.
func _states(cv: InkCanvas, r: float) -> void:
	if shield:
		var p := 0.6 + 0.4 * sin(_t * 5.0)
		var sr := r + 7.0
		cv.ellipse(Vector2.ZERO, Vector2(sr, sr), Color(0.4, 0.68, 1.0, 0.16 * p))
		cv.ink_circle(Vector2.ZERO, Vector2(sr, sr), 2.2, Color("3f7fd8"), 4.0, _t, 0.2, 0.03)
		cv.stroke(InkCanvas.arc_pts(Vector2.ZERO, sr - 2.5, -2.4, -1.5, 6), 1.8, Color(1, 1, 1, 0.85), 0.2, 0.2)
	if iced:
		for k in 4:
			var a := rot + TAU * float(k) / 4.0
			cv.stroke(PackedVector2Array([Vector2.from_angle(a) * 2.0, Vector2.from_angle(a) * (r - 1.5)]), 1.0, Color(1, 1, 1, 0.8), 0.1, 0.1)
	if anti_grav:
		for k in 2:
			var ph := fmod(_t * 1.4 + k * 0.5, 1.0)
			var y := r + 6.0 + ph * 18.0
			var w := r * (1.2 - ph * 0.5)
			cv.stroke(InkCanvas.quad_bez(Vector2(-w, y), Vector2(0, y + 3.0), Vector2(w, y), 5), 1.8, Color(0.25, 0.75, 0.6, 1.0 - ph), 0.2, 0.2)
	if magnet:
		var ph2 := fmod(_t * 2.0, 1.0)
		var mr := r + 4.0 + ph2 * 16.0
		cv.ink_circle(Vector2.ZERO, Vector2(mr, mr), 1.8, Color(0.85, 0.2, 0.22, 1.0 - ph2), 6.0, 0.0, 0.0, 0.02)


func _flames(cv: InkCanvas, r: float) -> void:
	var dir := _trail_dir()
	var n := Vector2(-dir.y, dir.x)
	for k in 3:
		var flick := sin(_t * 30.0 + k * 2.0) * 2.0
		var len := r * (2.6 - k * 0.5) + flick
		var w := r * (0.85 - k * 0.18)
		var base := -dir * r * 0.4
		var tongue := PackedVector2Array([base + n * w, base - dir * len * 0.55 + n * w * 0.6, base - dir * len, base - dir * len * 0.55 - n * w * 0.6, base - n * w])
		var col: Color = [Color("ffb03b"), Color("ff7a2e"), Color("ffe08a")][k]
		cv.fill(InkCanvas.spline(tongue, 3), col)
		if k == 0:
			cv.outline(InkCanvas.spline(tongue, 3), 1.6, INK, 2.0)
	for k in 2:
		var o := n * (k * 2.0 - 1.0) * r * 1.2
		cv.stroke(PackedVector2Array([o - dir * r * 1.6, o - dir * r * 3.4]), 1.4, Color(INK, 0.5), 0.3, 0.6)


func _chute(cv: InkCanvas, r: float) -> void:
	var top := Vector2(0, -r - 30)
	var canopy := InkCanvas.arc_pts(top, 22.0, PI, TAU, 12)
	var hem := PackedVector2Array()
	for k in 5:
		hem.append(top + Vector2(22.0 - k * 11.0, 3.0 if k % 2 == 1 else 0.0))
	var shape := canopy + hem
	cv.fill(shape, Color("4cc9f0"))
	for k in 3:
		cv.stroke(PackedVector2Array([top + Vector2(-11 + k * 11, 0), top + Vector2(-6 + k * 6, -20)]), 1.0, Color(INK, 0.4), 0.2, 0.2)
	cv.outline(shape, 2.0, INK, 7.0)
	for x: float in [-20.0, 0.0, 20.0]:
		cv.stroke(PackedVector2Array([top + Vector2(x, 2), Vector2(0, -r)]), 1.1, INK, 0.0, 0.0)


func _local_marker(cv: InkCanvas) -> void:
	var ring_r := radius + 9.0
	if cooldown_frac > 0.001:
		cv.ink_circle(Vector2.ZERO, Vector2(ring_r, ring_r), 3.6, Color(INK, 0.25), 9.0, 0.0, 0.0, 0.0)
		var a0 := -PI * 0.5
		cv.stroke(InkCanvas.arc_pts(Vector2.ZERO, ring_r, a0, a0 + TAU * (1.0 - cooldown_frac), 28), 3.6, slot_color, 0.05, 0.05)
	elif ready_to_shoot:
		var pulse := _ready_pulse
		var rr := ring_r + pulse * 10.0
		cv.ink_circle(Vector2.ZERO, Vector2(rr, rr), 2.4 + pulse * 2.0, Color(slot_color, 0.4 + pulse * 0.6), 5.0, 0.0, 0.2, 0.02)
	var bob := sin(_t * 4.0) * 3.0
	var tip := Vector2(0, -radius - 15 + bob)
	cv.shape(PackedVector2Array([tip, tip + Vector2(-8, -11), tip + Vector2(0, -8.5), tip + Vector2(8, -11)]), slot_color, 2.2)


func _draw_name() -> void:
	var font := UITheme.body_bold_font()
	var size := 18
	var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, -radius - 14)
	draw_string_outline(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, InkCanvas.PAPER)
	draw_string(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, slot_color.darkened(0.35))
