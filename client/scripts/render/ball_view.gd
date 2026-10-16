class_name BallView
extends Node2D
## Visual for one golf ball: shading, spin marks, trail, ability skin, ground shadow,
## name tag, and (for the local player) the cooldown ring.

const TRAIL_LEN := 26

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


func _draw() -> void:
	if not visible_ball:
		return
	# Trail (in world space -> local).
	if _trail.size() > 2:
		var n := _trail.size()
		for i in range(1, n):
			var k := float(i) / float(n)
			var a := to_local(_trail[i - 1])
			var b := to_local(_trail[i])
			var col := trail_color
			col.a = k * 0.75
			draw_line(a, b, col, radius * 1.5 * k + 1.0, true)
	# Ground shadow, shrinking with height.
	if _shadow_dist < 480.0:
		var s := clampf(1.0 - _shadow_dist / 480.0, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 16:
			var ang := TAU * float(i) / 16.0
			pts.append(Vector2(cos(ang) * radius * (0.6 + s * 0.6), _shadow_y + sin(ang) * radius * 0.25 * (0.5 + s * 0.5)))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.22 * s))

	# Nitro flames behind the ball.
	if boosted > 0.0:
		var dir := _trail_dir()
		for i in 5:
			var off := -dir * (radius + 4.0 + i * 5.0) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			draw_circle(off, radius * (0.95 - i * 0.15), Color("ffd166").lerp(Color("ff4d1d"), float(i) / 4.0), true, -1.0, true)

	# Air brake chute.
	if braked > 0.0:
		var top := Vector2(0, -radius - 30)
		var chute := PackedVector2Array()
		for i in 11:
			var ang := PI + PI * float(i) / 10.0
			chute.append(top + Vector2(cos(ang) * 22.0, sin(ang) * 12.0))
		draw_colored_polygon(chute, Color("4cc9f0"))
		draw_polyline(chute, Color("1b2040"), 2.0, true)
		for x in [-20.0, 0.0, 20.0]:
			draw_line(top + Vector2(x, 0), Vector2(0, -radius), Color("1b2040"), 1.2, true)

	var outline := Color("1b2040")
	var fill := ball_color
	match ability:
		"heavy":
			fill = Color("8d99ae")
		"sticky":
			fill = Color("b65cff")
		"grenade":
			fill = Color("56c271")
		"nitro":
			fill = fill.lerp(Color("ff7b2e"), 0.55)
		"air_brake":
			fill = fill.lerp(Color("4cc9f0"), 0.55)
		"standard", "laser", "mulligan", "free_shot":
			pass
		_:
			fill = fill.lerp(Color(GameData.ability(ability).get("color", "#ffffff")), 0.5)
	if iced:
		fill = fill.lerp(Color("cdf3ff"), 0.6)
	if finished or disconnected:
		fill.a = 0.5

	draw_circle(Vector2.ZERO, radius + 2.2, outline, true, -1.0, true)
	draw_circle(Vector2.ZERO, radius, fill, true, -1.0, true)
	# Shading crescent (fixed light direction).
	draw_arc(Vector2(1.2, 1.4), radius - 2.2, -0.2, PI * 0.85, 12, fill.darkened(0.22), 3.0, true)
	# Spin marks rotate with the ball.
	var r := radius * 0.55
	for k in 3:
		var a := rot + TAU * float(k) / 3.0
		draw_circle(Vector2(cos(a), sin(a)) * r, 1.3, fill.darkened(0.3), true, -1.0, true)
	if ability == "heavy":
		draw_line(Vector2.from_angle(rot) * -radius * 0.8, Vector2.from_angle(rot) * radius * 0.8, Color("5c677d"), 2.0, true)
	elif ability == "grenade":
		draw_rect(Rect2(-2, -radius - 4, 4, 4), Color("2b2d42"))
		var blink := 0.5 + 0.5 * sin(_t * 18.0)
		draw_circle(Vector2(0, -2), 2.2, Color(1, 0.25, 0.2, blink), true, -1.0, true)
	elif ability == "sticky":
		draw_circle(Vector2(-radius * 0.5, radius * 0.6), 3.0, Color("7b2cbf"), true, -1.0, true)
	# Highlight.
	draw_circle(Vector2(-radius * 0.35, -radius * 0.38), radius * 0.28, Color(1, 1, 1, 0.75), true, -1.0, true)
	_draw_states()

	if is_local and not finished:
		_draw_local_marker()
	elif display_name != "" and not finished:
		_draw_name()


## Ability state overlays: shield bubble, frost, anti-grav rings, magnet pulse.
func _draw_states() -> void:
	if shield:
		var p := 0.6 + 0.4 * sin(_t * 5.0)
		draw_arc(Vector2.ZERO, radius + 7.0, 0, TAU, 28, Color("1b2040"), 5.0)
		draw_arc(Vector2.ZERO, radius + 7.0, 0, TAU, 28, Color(0.36, 0.66, 1.0, p), 3.0)
		draw_arc(Vector2.ZERO, radius + 7.0, -2.4, -1.5, 8, Color(1, 1, 1, 0.8), 2.0)
	if iced:
		for k in 4:
			var a := rot + TAU * float(k) / 4.0
			draw_line(Vector2.from_angle(a) * 2.0, Vector2.from_angle(a) * (radius - 1.5), Color(1, 1, 1, 0.7), 1.0)
	if anti_grav:
		for k in 2:
			var ph := fmod(_t * 1.4 + k * 0.5, 1.0)
			var y := radius + 6.0 + ph * 18.0
			var w := radius * (1.2 - ph * 0.5)
			draw_line(Vector2(-w, y), Vector2(w, y), Color(0.49, 0.95, 0.79, 1.0 - ph), 2.0)
	if magnet:
		var ph2 := fmod(_t * 2.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 4.0 + ph2 * 16.0, 0, TAU, 24, Color(0.9, 0.22, 0.23, 1.0 - ph2), 2.0)


func _trail_dir() -> Vector2:
	if _trail.size() >= 2:
		var d := _trail[_trail.size() - 1] - _trail[_trail.size() - 2]
		if d.length_squared() > 0.01:
			return d.normalized()
	return Vector2.RIGHT


func _draw_local_marker() -> void:
	var ring_r := radius + 9.0
	if cooldown_frac > 0.001:
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 40, Color(0, 0, 0, 0.25), 4.0, true)
		draw_arc(Vector2.ZERO, ring_r, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cooldown_frac), 40, Color("ffd166"), 4.0, true)
	elif ready_to_shoot:
		var pulse := _ready_pulse
		draw_arc(Vector2.ZERO, ring_r + pulse * 10.0, 0, TAU, 40, Color(0.5, 1.0, 0.6, 0.35 + pulse * 0.6), 3.0, true)
	# Bobbing arrow above the ball.
	var bob := sin(_t * 4.0) * 3.0
	var tip := Vector2(0, -radius - 16 + bob)
	var arrow := PackedVector2Array([tip, tip + Vector2(-8, -11), tip + Vector2(8, -11)])
	draw_colored_polygon(arrow, slot_color)
	var o := arrow.duplicate()
	o.append(arrow[0])
	draw_polyline(o, Color("1b2040"), 2.5, true)


func _draw_name() -> void:
	var font := UITheme.body_bold_font()
	var size := 16
	var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, -radius - 14)
	draw_string_outline(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color("1b2040"))
	draw_string(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, slot_color)
