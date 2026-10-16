class_name SimPhysics
extends RefCounted
## Fixed-timestep arcade golf physics shared by the server, practice, stroke play and the
## Laser Ball guide. Balls are circles; terrain is static segments. Spec: docs/PHYSICS_SPEC.md.
##
## Robustness: each tick is divided into substeps so that no ball travels more than
## `max_substep_travel` pixels per substep (a tested equivalent of continuous collision detection
## for thin geometry), and a solid-interior check recovers any ball that still ends up inside
## terrain.
##
## Spin: angular velocity is real state. At a contact the ball's surface slips against the ground
## at (tangential speed - angular velocity * radius); friction removes that slip, trading linear
## for angular momentum like a solid ball (I = k m r^2). Backspin therefore checks or pulls a
## landing ball back, topspin drives it on, and a ball that lands without spin loses speed until
## it rolls.

const UP := Vector2(0, -1)
## Normal speeds below this are treated as resting/rolling contact, not impacts.
const ROLL_CONTACT_SPEED := 45.0

var terrain: SimTerrain
var cfg: Dictionary
var balls: Array[SimBall] = []
## Impacts produced during the last step: Array of {slot, mat, speed, pos}
var impacts: Array[Dictionary] = []
## Balls that touched terrain while sticky/grenade pending, for the match layer.
var touched: Array[Dictionary] = []
## Water frozen by Ice balls this step: Array of {slot, pos}
var froze: Array[Dictionary] = []
## Cup position for Magnet balls (set by the match layer).
var cup: Vector2 = Vector2.INF

# Material property arrays indexed by terrain material index.
var _rest: PackedFloat32Array
var _fric: PackedFloat32Array
var _roll: PackedFloat32Array
var _rest_slope_cos: PackedFloat32Array
var _bounce_min: PackedFloat32Array
var _sticky: PackedByteArray
var _boost: PackedFloat32Array
var _belt: PackedFloat32Array
var _plug: PackedFloat32Array

var gravity: float
var air_drag: float
var max_travel: float
var max_substeps: int
var iterations: int
var rest_speed: float
var rest_time: float
var max_speed: float
var max_ang: float
var ball_e: float
var ball_impulse_scale: float
var grounded_grace: float
var stuck_time: float
var creep_speed: float
var inertia_k: float
var impact_friction: float
var slip_friction: float
var air_spin_decay: float
var spin_air_accel: float


func _init(p_terrain: SimTerrain, physics_cfg: Dictionary, materials: Dictionary) -> void:
	terrain = p_terrain
	cfg = physics_cfg
	gravity = float(cfg.gravity)
	air_drag = float(cfg.air_drag)
	max_travel = float(cfg.max_substep_travel)
	max_substeps = int(cfg.max_substeps)
	iterations = int(cfg.contact_iterations)
	rest_speed = float(cfg.rest_speed)
	rest_time = float(cfg.rest_time)
	max_speed = float(cfg.max_speed)
	max_ang = float(cfg.max_angular_velocity)
	ball_e = float(cfg.ball_restitution)
	ball_impulse_scale = float(cfg.ball_impulse_scale)
	grounded_grace = float(cfg.grounded_grace)
	stuck_time = float(cfg.stuck_time)
	creep_speed = float(cfg.slow_creep_speed)
	inertia_k = float(cfg.get("inertia_k", 0.4))
	impact_friction = float(cfg.get("impact_friction", 0.35))
	slip_friction = float(cfg.get("slip_friction", 1.0))
	air_spin_decay = float(cfg.get("air_spin_decay", 0.1))
	spin_air_accel = float(cfg.get("spin_air_accel", 0.0))
	_build_material_tables(materials)


func _build_material_tables(materials: Dictionary) -> void:
	var n := terrain.material_names.size()
	_rest.resize(n); _fric.resize(n); _roll.resize(n); _rest_slope_cos.resize(n)
	_bounce_min.resize(n); _sticky.resize(n); _boost.resize(n); _belt.resize(n); _plug.resize(n)
	for i in n:
		var m: Dictionary = materials.get(terrain.material_names[i], materials.get("grass", {}))
		_rest[i] = float(m.get("restitution", 0.4))
		_fric[i] = float(m.get("friction", 0.3))
		_roll[i] = float(m.get("roll_drag", 1.0))
		_rest_slope_cos[i] = cos(deg_to_rad(float(m.get("rest_slope_deg", 12.0))))
		_bounce_min[i] = float(m.get("bounce_min", 70.0))
		_sticky[i] = 1 if bool(m.get("sticky", false)) else 0
		_boost[i] = float(m.get("boost", 0.0))
		_belt[i] = float(m.get("surface_speed", 0.0))
		_plug[i] = clampf(float(m.get("impact_tangent_loss", 0.0)), 0.0, 1.0)


func add_ball(b: SimBall) -> void:
	balls.append(b)


func step(dt: float) -> void:
	impacts.clear()
	touched.clear()
	froze.clear()
	var fastest := 0.0
	for b in balls:
		if b.active and not b.at_rest and not b.stuck:
			fastest = maxf(fastest, b.vel.length() + gravity * maxf(1.0, absf(b.gravity_scale)) * dt + b.boost_accel * dt)
	if fastest <= 0.0:
		return
	var substeps := clampi(ceili(fastest * dt / max_travel), 1, max_substeps)
	var h := dt / float(substeps)
	for _s in substeps:
		for b in balls:
			if b.active and not b.at_rest and not b.stuck:
				_integrate(b, h)
		_collide_balls()
	for b in balls:
		if b.active and not b.at_rest and not b.stuck:
			_post_tick(b, dt)


## Effective gravity acceleration for a ball at its position (fields, abilities).
func gravity_for(b: SimBall) -> Vector2:
	var g := terrain.gravity_at(b.pos, Vector2(0, gravity)) if not terrain.fields.is_empty() else Vector2(0, gravity)
	var scale := b.gravity_scale
	if b.anti_grav_timer > 0.0:
		scale = b.anti_grav_scale
	elif b.brake_timer > 0.0:
		scale *= b.brake_gravity
	return g * scale


func _integrate(b: SimBall, h: float) -> void:
	if b.slow_gravity_timer > 0.0:
		b.slow_gravity_timer -= h
		if b.slow_gravity_timer <= 0.0:
			b.gravity_scale = 1.0
	var g := gravity_for(b)
	if g.length_squared() > 1.0:
		b.g_up = -g.normalized()
	b.vel += g * h
	b.vel *= 1.0 - air_drag * h
	if b.anti_grav_timer > 0.0:
		b.anti_grav_timer -= h
	# Air Brakes: strong exponential drag for a short burst (no teleporting stop).
	if b.brake_timer > 0.0:
		b.brake_timer -= h
		b.vel *= exp(-b.brake_rate * h)
	# Nitro: thrust along the current flight direction.
	if b.boost_timer > 0.0:
		b.boost_timer -= h
		var spd0 := b.vel.length()
		var dir := b.vel / spd0 if spd0 > 1.0 else Vector2.from_angle(-PI * 0.25)
		b.vel += dir * b.boost_accel * h
		if b.boost_cap > 0.0 and b.vel.length() > b.boost_cap:
			b.vel = b.vel.normalized() * b.boost_cap
	# Magnet: a force toward the cup. Terrain still blocks the ball; it is not a homing move.
	if b.magnet_strength > 0.0 and cup != Vector2.INF:
		var to_cup := cup - b.pos
		var d := to_cup.length()
		if d > 1.0 and d < b.magnet_radius:
			var a := b.magnet_strength / (1.0 + (d / b.magnet_falloff) * (d / b.magnet_falloff))
			b.vel += to_cup / d * a * h
	var spd := b.vel.length()
	var cap := maxf(max_speed, b.boost_cap)
	if spd > cap:
		b.vel *= cap / spd
	b.pos += b.vel * h
	b.since_contact += h
	b.flight_time += h
	if b.unstick_grace > 0.0:
		b.unstick_grace -= h

	var contacted := false
	var normal_sum := Vector2.ZERO
	var last_mat := -1
	for _it in iterations:
		var hit := false
		var cand := terrain.query(b.pos)
		for idx in cand:
			var a := terrain.seg_a[idx]
			var ab := terrain.seg_b[idx] - a
			var t := clampf((b.pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var cp := a + ab * t
			var d := b.pos - cp
			var dist2 := d.length_squared()
			var r := b.radius
			if dist2 >= r * r:
				continue
			var sn := terrain.seg_n[idx]
			var dist := sqrt(dist2)
			var n: Vector2
			var pen: float
			if dist < 0.0001 or d.dot(sn) < 0.0:
				# Centre is on or behind the surface: push out along the face normal.
				n = sn
				pen = r + (0.0 if dist < 0.0001 else dist)
				b.deep = true
			else:
				n = d / dist
				pen = r - dist
				if pen > r * 0.8:
					b.deep = true
			b.pos += n * pen
			var mat := terrain.seg_mat[idx]
			if _respond(b, n, mat):
				return  # Ball became stuck; stop integrating this substep.
			hit = true
			contacted = true
			normal_sum += n
			last_mat = mat
		if b.freezes_water and _ice_contacts(b):
			hit = true
			contacted = true
			normal_sum += UP
			last_mat = terrain.ice_mat
		if not hit:
			break

	if contacted:
		b.since_contact = 0.0
		# Anti-Grav lasts until the ball meets terrain.
		b.anti_grav_timer = 0.0
		var cn := normal_sum.normalized() if normal_sum.length_squared() > 0.0 else UP
		b.contact_normal = cn
		b.contact_mat = last_mat
		_rolling_contact(b, cn, last_mat, g, h)
	else:
		# In the air spin decays slowly; the player can add top/back spin in flight.
		b.ang_vel *= 1.0 - air_spin_decay * h
		if b.spin_input != 0 and spin_air_accel > 0.0:
			var fwd := 1.0 if b.vel.x >= 0.0 else -1.0
			b.ang_vel += float(b.spin_input) * fwd * spin_air_accel * h
		b.ang_vel = clampf(b.ang_vel, -max_ang, max_ang)
	b.rot = wrapf(b.rot + b.ang_vel * h, -PI, PI)


## Continuous contact: kinetic friction removes slip (trading speed and spin), then rolling
## resistance slows rolling. Both scale with the normal load from gravity, so they vanish on
## walls and ceilings and weaken in low-gravity fields.
func _rolling_contact(b: SimBall, cn: Vector2, mat: int, g: Vector2, h: float) -> void:
	var tan := Vector2(-cn.y, cn.x)
	var vt := b.vel.dot(tan)
	var vn := b.vel.dot(cn)
	var r := b.radius
	var load := maxf(0.0, -g.dot(cn))
	var k := inertia_k
	var slip := vt - b.ang_vel * r - _belt[mat]
	var max_dv := _fric[mat] * slip_friction * load * h
	var j := clampf(slip * k / (1.0 + k), -max_dv, max_dv)
	vt -= j
	b.ang_vel += j / (k * r)
	var drag := _roll[mat] * b.roll_drag_scale * clampf(load / gravity, 0.0, 1.5)
	var f := maxf(0.0, 1.0 - drag * h)
	vt *= f
	b.ang_vel = clampf(b.ang_vel * f, -max_ang, max_ang)
	b.vel = tan * vt + cn * vn


## Ice ball against water surfaces. Returns true on contact.
func _ice_contacts(b: SimBall) -> bool:
	var any := false
	for i in terrain.water_a.size():
		var a := terrain.water_a[i]
		var ab := terrain.water_b[i] - a
		var t := clampf((b.pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := b.pos - (a + ab * t)
		var sn := terrain.water_n[i]
		# Only from above: a ball already under the surface is in the hazard.
		var height := d.dot(sn)
		if height < -b.radius * 0.6 or d.length_squared() >= b.radius * b.radius:
			continue
		b.pos += sn * (b.radius - height)
		var first := b.vel.dot(sn) < -ROLL_CONTACT_SPEED
		_respond(b, sn, terrain.ice_mat)
		if first:
			froze.append({"slot": b.slot, "pos": b.pos - sn * b.radius})
		any = true
	return any


## Resolves velocity against a contact normal. Returns true if the ball stuck.
func _respond(b: SimBall, n: Vector2, mat: int) -> bool:
	var vn := b.vel.dot(n)
	if vn >= 0.0:
		return false
	var impact := -vn
	if impact > ROLL_CONTACT_SPEED and terrain.material_names[mat] != "cup":
		b.contacts_since_shot += 1
	if b.sticky_pending or (_sticky[mat] == 1 and b.unstick_grace <= 0.0):
		b.vel = Vector2.ZERO
		b.ang_vel = 0.0
		b.stuck = true
		b.at_rest = true
		b.sticky_pending = false
		b.contact_normal = n
		b.contact_mat = mat
		b.since_contact = 0.0
		impacts.append({"slot": b.slot, "mat": mat, "speed": impact, "pos": b.pos})
		touched.append({"slot": b.slot, "pos": b.pos})
		return true
	if b.grenade_pending:
		touched.append({"slot": b.slot, "pos": b.pos})
	var tan := Vector2(-n.y, n.x)
	var vt := b.vel.dot(tan)
	var e := _rest[mat] * b.restitution_scale
	var vn_new := impact * e if impact > _bounce_min[mat] else 0.0
	if _boost[mat] > 0.0:
		if b.pad_armed and impact > 120.0:
			vn_new = maxf(vn_new, _boost[mat])
			b.pad_armed = false
	elif impact > ROLL_CONTACT_SPEED:
		b.pad_armed = true
	# Impact friction impulse (Coulomb-capped): removes surface slip, trading speed for spin.
	# Continuous rolling contact is handled by _rolling_contact instead, so putts roll a
	# predictable distance.
	if impact > ROLL_CONTACT_SPEED:
		var k := inertia_k
		var slip := vt - b.ang_vel * b.radius - _belt[mat]
		var cap := _fric[mat] * impact * (1.0 + e) * impact_friction
		var j := clampf(slip * k / (1.0 + k), -cap, cap)
		vt -= j
		b.ang_vel = clampf(b.ang_vel + j / (k * b.radius), -max_ang, max_ang)
		# Soft surfaces (sand, snow) deform and swallow sliding and rolling motion on impact.
		if _plug[mat] > 0.0:
			var keep := 1.0 - _plug[mat] * clampf(impact / 300.0, 0.0, 1.0)
			vt *= keep
			b.ang_vel *= keep
	b.vel = tan * vt + n * vn_new
	if impact > 110.0:
		impacts.append({"slot": b.slot, "mat": mat, "speed": impact, "pos": b.pos})
	return false


func _collide_balls() -> void:
	var n := balls.size()
	for i in n:
		var bi := balls[i]
		if not bi.active or not bi.collides_balls:
			continue
		for j in range(i + 1, n):
			var bj := balls[j]
			if not bj.active or not bj.collides_balls:
				continue
			var d := bj.pos - bi.pos
			var rr := bi.radius + bj.radius
			var dist2 := d.length_squared()
			if dist2 >= rr * rr:
				continue
			# Stuck and shielded balls do not move when hit (shield: no knockback).
			var inv_i := 0.0 if (bi.stuck or bi.shield > 0) else 1.0 / bi.mass
			var inv_j := 0.0 if (bj.stuck or bj.shield > 0) else 1.0 / bj.mass
			var inv_sum := inv_i + inv_j
			if inv_sum <= 0.0:
				continue
			var dist := sqrt(dist2)
			var nrm := d / dist if dist > 0.0001 else Vector2.RIGHT
			var pen := rr - dist
			bi.pos -= nrm * pen * (inv_i / inv_sum)
			bj.pos += nrm * pen * (inv_j / inv_sum)
			var rel := (bj.vel - bi.vel).dot(nrm)
			if rel < 0.0:
				var jimp := -(1.0 + ball_e) * rel / inv_sum * ball_impulse_scale
				bi.vel -= nrm * jimp * inv_i
				bj.vel += nrm * jimp * inv_j
				if inv_i > 0.0:
					bi.wake()
				if inv_j > 0.0:
					bj.wake()
				if -rel > 60.0:
					impacts.append({"slot": bi.slot, "mat": -1, "speed": -rel, "pos": (bi.pos + bj.pos) * 0.5, "other": bj.slot})


func _post_tick(b: SimBall, dt: float) -> void:
	# Recover from any remaining penetration into solid terrain (only checked after deep contacts).
	if b.deep:
		b.deep = false
		_recover(b)
	_rest_check(b, dt)


func _recover(b: SimBall) -> void:
	if terrain.is_point_solid(b.pos):
		var res := terrain.raycast(b.pos + Vector2(0, -600), Vector2.DOWN, 600.0)
		if res.hit:
			b.pos = res.pos + res.normal * (b.radius + 0.5)
			b.vel = Vector2.ZERO
			b.ang_vel = 0.0


func _rest_check(b: SimBall, dt: float) -> void:
	var speed := b.vel.length()
	var grounded := b.since_contact <= grounded_grace
	# A slow ball that is still spinning against the ground (backspin check) is not at rest.
	var slip := absf(b.vel.dot(Vector2(-b.contact_normal.y, b.contact_normal.x)) - b.ang_vel * b.radius)
	var accelerating := b.boost_timer > 0.0 or b.magnet_strength > 0.0 and speed > rest_speed * 0.5
	if grounded and speed < rest_speed and slip < rest_speed * 2.0 and not accelerating:
		var cosang := b.contact_normal.dot(b.g_up)
		var mat := maxi(b.contact_mat, 0)
		if cosang >= _rest_slope_cos[mat]:
			b.rest_timer += dt
			if b.rest_timer >= rest_time:
				_settle(b)
				return
		else:
			b.rest_timer = 0.0
	else:
		b.rest_timer = 0.0
	if grounded and speed < creep_speed:
		b.slow_timer += dt
		if b.slow_timer >= stuck_time:
			_settle(b)
	else:
		b.slow_timer = 0.0


func _settle(b: SimBall) -> void:
	b.vel = Vector2.ZERO
	b.ang_vel = 0.0
	b.at_rest = true
	b.rest_timer = 0.0
	b.slow_timer = 0.0


## Radial knockback with linear falloff. Shielded balls are immune. Returns the slots affected.
func explode(center: Vector2, radius: float, impulse: float, source_slot: int, self_scale: float) -> Array[int]:
	var hit: Array[int] = []
	for b in balls:
		if not b.active:
			continue
		var d := b.pos - center
		var dist := d.length()
		if dist > radius:
			continue
		if b.shield > 0 and b.slot != source_slot:
			continue
		var dir := d / dist if dist > 1.0 else UP
		# Bias upward a little so blasts read as "launches" instead of pushing into the ground.
		dir = (dir + UP * 0.35).normalized()
		var fall := 1.0 - dist / radius
		var scale := self_scale if b.slot == source_slot else 1.0
		b.stuck = false
		b.wake()
		b.vel += dir * impulse * fall * scale / b.mass
		b.since_contact = grounded_grace + 0.01
		hit.append(b.slot)
	return hit


# ---------------------------------------------------------------------------
# Trajectory prediction (Laser Ball guide, the solver bot, tests). Ignores other balls.
# ---------------------------------------------------------------------------

## `setup` (optional) configures the probe ball before launch, e.g. MatchSim.apply_ability.
## Returns { "points": PackedVector2Array, "contact_index": int, "hazard": bool, "end": Vector2 }
static func predict(terrain_ref: SimTerrain, physics_cfg: Dictionary, materials: Dictionary,
		start: Vector2, velocity: Vector2, radius: float, gravity_scale: float,
		max_time: float, after_contact: float, sample_every: int = 2, spin: float = 0.0,
		setup: Callable = Callable(), cup_pos: Vector2 = Vector2.INF) -> Dictionary:
	var world := SimPhysics.new(terrain_ref, physics_cfg, materials)
	world.cup = cup_pos
	var b := SimBall.new()
	b.radius = radius
	b.place(start)
	if setup.is_valid():
		setup.call(b)
	b.at_rest = false
	b.vel = velocity
	b.ang_vel = spin
	b.gravity_scale = gravity_scale * b.gravity_scale
	b.since_contact = 1.0
	world.add_ball(b)
	var pts := PackedVector2Array()
	pts.append(start)
	var dt := 1.0 / 60.0
	var t := 0.0
	var contact_at := -1
	var contact_time := 0.0
	var tick := 0
	var hazard := false
	while t < max_time:
		world.step(dt)
		t += dt
		tick += 1
		if tick % sample_every == 0:
			pts.append(b.pos)
		if contact_at == -1 and b.since_contact <= dt:
			contact_at = pts.size() - 1
			pts.append(b.pos)
			contact_time = t
		if contact_at != -1 and t - contact_time >= after_contact:
			break
		if b.at_rest or b.stuck:
			break
		if terrain_ref.zone_at(b.pos) != "":
			hazard = true
			break
		if b.pos.y > terrain_ref.bounds.end.y + 120.0:
			hazard = true
			break
	# Always finish on the true final position (samples are sparse).
	if pts[pts.size() - 1] != b.pos:
		pts.append(b.pos)
	return {"points": pts, "contact_index": contact_at, "hazard": hazard, "end": b.pos}
