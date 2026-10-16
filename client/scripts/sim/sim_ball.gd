class_name SimBall
extends RefCounted
## Authoritative state of one golf ball (docs/PHYSICS_SPEC.md).

var slot: int = 0
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var rot: float = 0.0
## Angular velocity (rad/s, positive = clockwise on screen = rolling to the right on a floor).
## Real state: contact friction trades it against linear speed (spin, see PHYSICS_SPEC.md §4).
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
## "Up" for this ball right now: opposite of the local gravity (gravity fields can turn it).
var g_up: Vector2 = Vector2.UP
## Terrain contacts (cup excluded) since the shot: 0 when holed = swish.
var contacts_since_shot: int = 0
## In-flight spin input from the player: -1 backspin, 0 none, +1 topspin.
var spin_input: int = 0

# Ability-driven modifiers (reset on every shot, see reset_modifiers()).
var ability: String = "standard"
var gravity_scale: float = 1.0
var restitution_scale: float = 1.0
var roll_drag_scale: float = 1.0
var sticky_pending: bool = false
var grenade_pending: bool = false
var manual_available: bool = false
## Remaining manual activations for this shot (Zig Zag has several, most have one).
var activations_left: int = 0
var flight_time: float = 0.0
var slow_gravity_timer: float = 0.0
## Anti-Grav: seconds of altered gravity left (ends early on the first terrain contact).
var anti_grav_timer: float = 0.0
var anti_grav_scale: float = 0.0
## Air Brakes: seconds of braking left and the braking rate (1/s).
var brake_timer: float = 0.0
var brake_rate: float = 0.0
var brake_gravity: float = 1.0
## Nitro: seconds of thrust left and its acceleration (px/s^2) along the flight path.
var boost_timer: float = 0.0
var boost_accel: float = 0.0
var boost_cap: float = 0.0
## Magnet: pull toward the cup (px/s^2 at the cup, falling off with distance).
var magnet_strength: float = 0.0
var magnet_falloff: float = 300.0
var magnet_radius: float = 0.0
## Ice: water surfaces are solid ice for this ball.
var freezes_water: bool = false
## Shield: hazard-zone blocks left; while shielded the ball ignores knockback from blasts and balls.
var shield: int = 0
## Mulligan: the shot can be taken back until the next shot.
var mulligan_ready: bool = false


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
	activations_left = 0
	flight_time = 0.0
	slow_gravity_timer = 0.0
	anti_grav_timer = 0.0
	anti_grav_scale = 0.0
	brake_timer = 0.0
	brake_rate = 0.0
	brake_gravity = 1.0
	boost_timer = 0.0
	boost_accel = 0.0
	boost_cap = 0.0
	magnet_strength = 0.0
	magnet_radius = 0.0
	freezes_water = false
	shield = 0
	mulligan_ready = false
	spin_input = 0
	contacts_since_shot = 0
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
