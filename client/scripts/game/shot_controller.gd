class_name ShotController
extends RefCounted
## Turns player input into shots for both control styles (docs/GAME_DESIGN.md, Controls).
## Both styles produce the same command (angle, power, ability, spin) for the same authoritative
## physics; only the input differs.
##
## Blitz (drag): press, drag away from or toward the target, release. Power follows drag distance.
## Classic (SSG3-style): rotate the arrow with the aim keys, press Swing to start the power meter,
##   press Swing again to lock the power and hit.
## Putting: near the cup on the ground, the full input range covers only PUTT_POWER of the
##   power scale, so small differences are precise.
## No mode shows the ball's flight path; the arrow shows direction, power and spin only.

const PUTT_POWER := 0.42
const PUTT_RANGE := 420.0           ## px from the cup (horizontal) for the putting profile
const METER_PERIOD := 1.9           ## s for the meter to rise 0 -> 1 -> 0
const AIM_RATE_SLOW := 0.7          ## rad/s for the first moments of a held aim key
const AIM_RATE_FAST := 1.9          ## rad/s once held
const AIM_TAP := 0.0175             ## one degree per tap
const SPIN_STEP := 0.25
const DEADZONE := 14.0

var style := "blitz"
## Blitz: a drag is in progress. Classic: the arrow is up (the ball is ready to be aimed).
var aiming := false
var angle := -PI * 0.25
## 0..1 position within the current profile (drag or meter); see shot_power().
var power := 0.0
## Launch spin, -1 full backspin .. +1 full topspin.
var spin := 0.0
var putting := false
var meter_on := false
var drag_start := Vector2.ZERO

var _meter_t := 0.0
var _hold := 0.0


## Power actually sent with the shot (0..1 of the full power scale).
func shot_power() -> float:
	return power * (PUTT_POWER if putting else 1.0)


func reset_for_hole(toward_cup: float) -> void:
	angle = -PI * 0.25 if toward_cup >= 0.0 else -PI * 0.75
	spin = 0.0
	cancel()


func cancel() -> void:
	if style == "blitz":
		aiming = false
	power = 0.0
	meter_on = false
	_meter_t = 0.0


func after_shot() -> void:
	spin = 0.0
	cancel()


func adjust_spin(dir: int) -> void:
	spin = clampf(snappedf(spin + SPIN_STEP * dir, SPIN_STEP), -1.0, 1.0)


# --- Blitz --------------------------------------------------------------------

func begin_drag(screen_pos: Vector2) -> void:
	aiming = true
	drag_start = screen_pos
	power = 0.0


## Returns true when angle or power changed noticeably.
func update_drag(mouse: Vector2, full_drag: float, pull: bool) -> bool:
	var drag := mouse - drag_start
	var dir := -drag if pull else drag
	var new_power := clampf((drag.length() - DEADZONE * 0.5) / full_drag, 0.0, 1.0)
	var new_angle := dir.angle() if drag.length() > 1.0 else angle
	var changed := absf(new_power - power) > 0.002 or absf(angle_difference(new_angle, angle)) > 0.002
	power = new_power
	angle = new_angle
	return changed


func drag_long_enough(mouse: Vector2) -> bool:
	return (mouse - drag_start).length() >= DEADZONE


# --- Classic ------------------------------------------------------------------

## Held aim keys rotate the arrow: a tap moves one degree, holding speeds up.
## Left turns the arrow toward the left (counter-clockwise on screen), right the other way.
func classic_aim(delta: float, left: bool, right: bool, left_tapped: bool, right_tapped: bool) -> bool:
	var dir := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	var before := angle
	if left_tapped:
		angle -= AIM_TAP
	if right_tapped:
		angle += AIM_TAP
	if dir != 0.0:
		_hold += delta
		if _hold > 0.18:
			var rate := AIM_RATE_SLOW if _hold < 0.6 else AIM_RATE_FAST
			angle += dir * rate * delta
	else:
		_hold = 0.0
	# Any direction above the ground line, plus a little below horizontal for chips off ledges.
	angle = clampf(angle, -PI - 0.3, 0.3)
	return not is_equal_approx(before, angle)


func start_meter() -> void:
	meter_on = true
	_meter_t = 0.0
	power = 0.0


## Advances the power meter: a triangle wave 0 -> 1 -> 0 with a fixed period, so timing is
## learnable and identical every swing.
func classic_meter(delta: float) -> void:
	if not meter_on:
		return
	_meter_t = fmod(_meter_t + delta, METER_PERIOD)
	var x := _meter_t / METER_PERIOD
	power = 1.0 - absf(1.0 - 2.0 * x)
