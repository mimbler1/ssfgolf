class_name SimBall
extends RefCounted
## Authoritative state of one golf ball.

var slot: int = 0
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var rot: float = 0.0
var ang_vel: float = 0.0
var radius: float = 9.0
var mass: float = 1.0

## Present in the world (false while holed or waiting for a hazard reset).
var active: bool = true
## Collides with other balls. Off until the ball has left the tee, so spawns never shove.
var collides_balls: bool = false

var at_rest: bool = true
var rest_timer: float = 0.0
var slow_timer: float = 0.0
var since_contact: float = 0.0
var contact_normal: Vector2 = Vector2.UP
var contact_mat: int = -1
## Glued in place by a sticky surface or the Sticky ability.
var stuck: bool = false
## Set when a contact this tick was deep enough to warrant a solid-interior check.
var deep: bool = false
## Bouncy pads give their launch boost once per shot (re-armed by other surfaces).
var pad_armed: bool = true
## While > 0 sticky surfaces won't capture the ball (set when shot off a sticky surface).
var unstick_grace: float = 0.0

# Ability-driven modifiers (reset on every shot).
var ability: String = "standard"
var gravity_scale: float = 1.0
var restitution_scale: float = 1.0
var roll_drag_scale: float = 1.0
var sticky_pending: bool = false
var grenade_pending: bool = false
var manual_available: bool = false
var flight_time: float = 0.0
var slow_gravity_timer: float = 0.0


func is_grounded(grace: float) -> bool:
	return at_rest or stuck or since_contact <= grace


func wake() -> void:
	at_rest = false
	rest_timer = 0.0
	slow_timer = 0.0


func reset_modifiers() -> void:
	ability = "standard"
	mass = 1.0
	gravity_scale = 1.0
	restitution_scale = 1.0
	roll_drag_scale = 1.0
	sticky_pending = false
	grenade_pending = false
	manual_available = false
	flight_time = 0.0
	slow_gravity_timer = 0.0
	pad_armed = true


func place(p: Vector2) -> void:
	pos = p
	vel = Vector2.ZERO
	ang_vel = 0.0
	at_rest = true
	stuck = false
	rest_timer = 0.0
	slow_timer = 0.0
	since_contact = 0.0
	contact_normal = Vector2.UP
