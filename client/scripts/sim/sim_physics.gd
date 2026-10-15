class_name SimPhysics
extends RefCounted
## Fixed-timestep arcade golf physics shared by the server, practice mode, and
## the client's trajectory preview. Balls are circles; terrain is static segments.
##
## Robustness: each tick is divided into substeps so that no ball travels more
## than `max_substep_travel` pixels per substep (a tested equivalent of
## continuous collision detection for thin geometry), and a solid-interior check
## recovers any ball that still ends up inside terrain.

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

# Material property arrays indexed by terrain material index.
var _rest: PackedFloat32Array
var _fric: PackedFloat32Array
var _roll: PackedFloat32Array
var _rest_slope_cos: PackedFloat32Array
var _bounce_min: PackedFloat32Array
var _sticky: PackedByteArray
var _boost: PackedFloat32Array

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
	_build_material_tables(materials)


func _build_material_tables(materials: Dictionary) -> void:
	var n := terrain.material_names.size()
	_rest.resize(n); _fric.resize(n); _roll.resize(n); _rest_slope_cos.resize(n)
	_bounce_min.resize(n); _sticky.resize(n); _boost.resize(n)
	for i in n:
		var m: Dictionary = materials.get(terrain.material_names[i], materials.get("grass", {}))
		_rest[i] = float(m.get("restitution", 0.4))
		_fric[i] = float(m.get("friction", 0.3))
		_roll[i] = float(m.get("roll_drag", 1.0))
		_rest_slope_cos[i] = cos(deg_to_rad(float(m.get("rest_slope_deg", 12.0))))
		_bounce_min[i] = float(m.get("bounce_min", 70.0))
		_sticky[i] = 1 if bool(m.get("sticky", false)) else 0
		_boost[i] = float(m.get("boost", 0.0))


func add_ball(b: SimBall) -> void:
	balls.append(b)


func step(dt: float) -> void:
	impacts.clear()
	touched.clear()
	var fastest := 0.0
	for b in balls:
		if b.active and not b.at_rest and not b.stuck:
			fastest = maxf(fastest, b.vel.length() + gravity * dt)
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


func _integrate(b: SimBall, h: float) -> void:
	if b.slow_gravity_timer > 0.0:
		b.slow_gravity_timer -= h
		if b.slow_gravity_timer <= 0.0:
			b.gravity_scale = 1.0
	b.vel.y += gravity * b.gravity_scale * h
	b.vel *= 1.0 - air_drag * h
	var spd := b.vel.length()
	if spd > max_speed:
		b.vel *= max_speed / spd
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
		if not hit:
			break

	if contacted:
		b.since_contact = 0.0
		var cn := normal_sum.normalized() if normal_sum.length_squared() > 0.0 else UP
		b.contact_normal = cn
		b.contact_mat = last_mat
		# Rolling: tangential drag and spin matching the surface speed.
		var tan := Vector2(-cn.y, cn.x)
		var vt := b.vel.dot(tan)
		var vn := b.vel.dot(cn)
		# Rolling resistance comes from the normal load, so it vanishes on walls and ceilings.
		var drag := _roll[last_mat] * b.roll_drag_scale * clampf(cn.dot(UP), 0.0, 1.0)
		vt *= maxf(0.0, 1.0 - drag * h)
		b.vel = tan * vt + cn * vn
		b.ang_vel = clampf(vt / b.radius, -max_ang, max_ang)
	b.rot = wrapf(b.rot + b.ang_vel * h, -PI, PI)


## Resolves velocity against a contact normal. Returns true if the ball stuck.
func _respond(b: SimBall, n: Vector2, mat: int) -> bool:
	var vn := b.vel.dot(n)
	if vn >= 0.0:
		return false
	var impact := -vn
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
	# Coulomb-style friction impulse on real impacts only. Continuous rolling contact
	# loses speed through rolling drag instead, so putts roll a predictable distance.
	if impact > ROLL_CONTACT_SPEED:
		var jn := impact * (1.0 + e)
		var fdv := minf(absf(vt), _fric[mat] * jn * 0.35)
		vt -= signf(vt) * fdv
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
			var inv_i := 0.0 if bi.stuck else 1.0 / bi.mass
			var inv_j := 0.0 if bj.stuck else 1.0 / bj.mass
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


func _rest_check(b: SimBall, dt: float) -> void:
	var speed := b.vel.length()
	var grounded := b.since_contact <= grounded_grace
	if grounded and speed < rest_speed:
		var cosang := b.contact_normal.dot(UP)
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


## Radial knockback. Returns the slots affected.
func explode(center: Vector2, radius: float, impulse: float, source_slot: int, self_scale: float) -> Array[int]:
	var hit: Array[int] = []
	for b in balls:
		if not b.active:
			continue
		var d := b.pos - center
		var dist := d.length()
		if dist > radius:
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
# Trajectory prediction (client aim preview). Ignores other balls.
# ---------------------------------------------------------------------------

## Returns { "points": PackedVector2Array, "contact_index": int }
static func predict(terrain_ref: SimTerrain, physics_cfg: Dictionary, materials: Dictionary,
		start: Vector2, velocity: Vector2, radius: float, gravity_scale: float,
		max_time: float, after_contact: float, sample_every: int = 2) -> Dictionary:
	var world := SimPhysics.new(terrain_ref, physics_cfg, materials)
	var b := SimBall.new()
	b.radius = radius
	b.place(start)
	b.at_rest = false
	b.vel = velocity
	b.gravity_scale = gravity_scale
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
