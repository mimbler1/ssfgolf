class_name MatchSim
extends RefCounted
## Authoritative match rules. Runs on the dedicated server for online play and
## locally for practice. Has no rendering or networking dependencies.

const DT := 1.0 / 60.0

enum Phase { WAITING, INTRO, COUNTDOWN, PLAYING, HOLE_RESULTS, MATCH_OVER }

class PlayerState:
	var slot: int = 0
	var player_id: String = ""
	var display_name: String = ""
	var appearance: Dictionary = {}
	var trophies: int = 0
	var ball: SimBall
	var energy: float = 0.0
	var cooldown: float = 0.0
	var points: int = 0
	var holes_won: int = 0
	var holes_played: int = 0
	var shots: int = 0
	var hole_shots: int = 0
	var abilities_used: Dictionary = {}
	var finished: bool = false
	var finish_tick: int = -1
	var place: int = 0
	var total_finish_time: float = 0.0
	var connected: bool = true
	var ever_connected: bool = false
	var disconnected_at: float = 0.0
	var forfeited: bool = false
	var last_shot_pos: Vector2 = Vector2.ZERO
	var hazard_timer: float = -1.0
	var respawned_at: float = -100.0
	var allowed_abilities: PackedStringArray = PackedStringArray()

	func in_play() -> bool:
		return not forfeited


var mode: String = "online"           ## "online" | "practice"
var phase: Phase = Phase.WAITING
var phase_timer: float = 0.0
var time: float = 0.0
var tick_count: int = 0

var balance: Dictionary
var materials: Dictionary
var course: Dictionary
var target_points: int = 9
var hole_order: PackedInt32Array = PackedInt32Array()
var hole_number: int = 0                ## 0-based count of holes started.
var hole_index: int = -1                ## Index into course.holes of the current hole.
var hole_time: float = 0.0
var hole_deadline: float = INF

var terrain: SimTerrain
var physics: SimPhysics
var players: Array[PlayerState] = []
var abilities: Dictionary = {}          ## id -> definition
var events: Array[Dictionary] = []
var last_impacts: Array[Dictionary] = []
var end_reason: String = ""
var hole_log: Array[Dictionary] = []    ## {holeId, finishOrder: [player ids]}

var _cfg_shot: Dictionary
var _cfg_energy: Dictionary
var _cfg_hole: Dictionary
var _cfg_match: Dictionary
var _grace: float


func _init(p_balance: Dictionary, p_materials: Dictionary, p_course: Dictionary, p_mode: String = "online", seed_value: int = 0) -> void:
	balance = p_balance
	materials = p_materials
	course = p_course
	mode = p_mode
	_cfg_shot = balance.shot
	_cfg_energy = balance.energy
	_cfg_hole = balance.hole
	_cfg_match = balance.match
	_grace = float(balance.physics.grounded_grace)
	target_points = int(_cfg_match.target_points)
	for a: Dictionary in balance.abilities:
		abilities[a.id] = a
	var holes: Array = course.get("holes", [])
	var order: Array = range(holes.size())
	if mode == "online" and holes.size() > 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp
	hole_order = PackedInt32Array(order)


func add_player(player_id: String, display_name: String, appearance: Dictionary, trophies: int = 0) -> PlayerState:
	var p := PlayerState.new()
	p.slot = players.size()
	p.player_id = player_id
	p.display_name = display_name
	p.appearance = appearance
	p.trophies = trophies
	p.ball = SimBall.new()
	p.ball.slot = p.slot
	p.ball.radius = float(balance.physics.ball_radius)
	p.energy = float(_cfg_energy.start)
	for id: String in abilities.keys():
		p.allowed_abilities.append(id)
	players.append(p)
	return p


func player_by_id(player_id: String) -> PlayerState:
	for p in players:
		if p.player_id == player_id:
			return p
	return null


func take_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


func _emit(ev: Dictionary) -> void:
	events.append(ev)


# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

func start() -> void:
	phase = Phase.INTRO
	phase_timer = float(_cfg_match.intro_duration) if mode == "online" else 0.01
	_emit({"type": "intro", "duration": phase_timer})


func start_practice_hole(index: int) -> void:
	hole_number = 0
	_begin_hole(index, 0.6)


func _begin_hole(index: int, countdown: float) -> void:
	hole_index = index
	var hole: Dictionary = course.holes[index]
	terrain = SimTerrain.new()
	terrain.build(hole)
	physics = SimPhysics.new(terrain, balance.physics, materials)
	hole_time = 0.0
	hole_deadline = float(_cfg_hole.max_duration) if mode == "online" else INF
	for p in players:
		var b := p.ball
		b.reset_modifiers()
		b.active = not p.forfeited
		b.collides_balls = false
		b.place(_tee_spot(p.slot))
		p.last_shot_pos = b.pos
		p.finished = false
		p.finish_tick = -1
		p.place = 0
		p.hole_shots = 0
		p.cooldown = 0.0
		p.hazard_timer = -1.0
		physics.add_ball(b)
	phase = Phase.COUNTDOWN
	phase_timer = countdown
	_emit({"type": "hole_start", "hole_index": index, "hole_number": hole_number,
		"hole_id": str(hole.get("id", "")), "countdown": countdown})


func _tee_spot(slot: int) -> Vector2:
	var offsets := [-30.0, -10.0, 10.0, 30.0]
	var spot := terrain.tee + Vector2(offsets[slot % 4] if players.size() > 1 else 0.0, -200.0)
	var hit := terrain.surface_below(spot, 1200.0)
	var ground: Vector2 = hit.pos if hit.hit else terrain.tee
	return ground + Vector2(0, -float(balance.physics.ball_radius) - 0.5)


func tick() -> void:
	time += DT
	tick_count += 1
	last_impacts = []
	_update_connections()
	match phase:
		Phase.INTRO:
			phase_timer -= DT
			if phase_timer <= 0.0:
				_begin_hole(hole_order[0], float(_cfg_hole.countdown))
		Phase.COUNTDOWN:
			phase_timer -= DT
			if phase_timer <= 0.0:
				phase = Phase.PLAYING
				_emit({"type": "go"})
		Phase.PLAYING:
			_tick_playing()
		Phase.HOLE_RESULTS:
			phase_timer -= DT
			if phase_timer <= 0.0:
				_advance_after_hole()
		_:
			pass


func _tick_playing() -> void:
	hole_time += DT
	var regen := float(_cfg_energy.regen_per_second) * DT
	var emax := float(_cfg_energy.max)
	for p in players:
		p.energy = minf(emax, p.energy + regen)
		p.cooldown = maxf(0.0, p.cooldown - DT)
		var b := p.ball
		# Grenade fuse.
		if b.grenade_pending and b.active:
			var gp: Dictionary = abilities.grenade.params
			if b.flight_time >= float(gp.fuse):
				_detonate(p)

	physics.step(DT)
	last_impacts = physics.impacts.duplicate()

	for t in physics.touched:
		var p := players[t.slot]
		if p.ball.ability == "sticky" and p.ball.stuck:
			_emit({"type": "stick", "slot": p.slot, "pos": p.ball.pos})
		elif p.ball.grenade_pending and p.ball.flight_time >= float(abilities.grenade.params.arm_time):
			_detonate(p)
	for imp in physics.impacts:
		if imp.has("other"):
			for s in [imp.slot, imp.other]:
				var p := players[s]
				if p.ball.grenade_pending and p.ball.flight_time >= float(abilities.grenade.params.arm_time):
					_detonate(p)

	var finished_now: Array[PlayerState] = []
	for p in players:
		var b := p.ball
		if p.hazard_timer >= 0.0:
			p.hazard_timer -= DT
			if p.hazard_timer < 0.0:
				_respawn(p, "hazard")
			continue
		if not b.active or p.finished:
			continue
		if terrain.cup_captures(b.pos, b.radius, b.vel.length()):
			finished_now.append(p)
			continue
		var zone := terrain.zone_at(b.pos)
		if zone != "":
			_hazard(p, zone)
			continue
		var bd := terrain.bounds
		if b.pos.y > bd.end.y + 120.0 or b.pos.x < bd.position.x - 300.0 or b.pos.x > bd.end.x + 300.0 or b.pos.y < bd.position.y - 2500.0:
			_hazard(p, "oob")

	if not finished_now.is_empty():
		_record_finishers(finished_now)

	if mode == "online":
		var remaining := 0
		for p in players:
			if p.in_play() and p.connected and not p.finished:
				remaining += 1
		if remaining == 0 or hole_time >= hole_deadline:
			_end_hole()
	elif mode == "practice":
		var all_done := true
		for p in players:
			if not p.finished:
				all_done = false
		if all_done:
			_end_hole()


func _record_finishers(list: Array[PlayerState]) -> void:
	var already := 0
	for p in players:
		if p.finished:
			already += 1
	var place := already + 1
	for p in list:
		p.finished = true
		p.finish_tick = tick_count
		p.place = place
		p.ball.active = false
		p.total_finish_time += hole_time
		_emit({"type": "holed", "slot": p.slot, "place": place, "time": hole_time, "shots": p.hole_shots})
	# Once someone finishes, the rest get a limited window.
	if already == 0 and mode == "online":
		var window := float(_cfg_hole.finish_window)
		if hole_time + window < hole_deadline:
			hole_deadline = hole_time + window
			_emit({"type": "hole_timer", "deadline": hole_deadline, "remaining": window})


func _end_hole() -> void:
	var n := players.size()
	var table: Array = _cfg_match.points.get(str(n), _cfg_match.points.get("4"))
	var results: Array[Dictionary] = []
	var order: Array[PlayerState] = []
	for p in players:
		if p.in_play():
			p.holes_played += 1
		var gained := 0
		if p.finished:
			gained = int(table[mini(p.place - 1, table.size() - 1)])
			if p.place == 1:
				p.holes_won += 1
			order.append(p)
		elif p.in_play():
			p.total_finish_time += hole_time
		p.points += gained
		results.append({"slot": p.slot, "place": p.place if p.finished else 0, "gained": gained,
			"total": p.points, "finished": p.finished, "shots": p.hole_shots})
	order.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		return a.finish_tick < b.finish_tick if a.finish_tick != b.finish_tick else a.slot < b.slot)
	var ids: Array[String] = []
	for p in order:
		ids.append(p.player_id)
	hole_log.append({"holeId": str(course.holes[hole_index].get("id", "")), "finishOrder": ids})
	hole_number += 1
	phase = Phase.HOLE_RESULTS
	phase_timer = float(_cfg_hole.results_duration) if mode == "online" else 2.2
	var over := _match_over_check()
	_emit({"type": "hole_end", "results": results, "next_in": phase_timer, "match_over": over})


func _match_over_check() -> bool:
	if mode != "online":
		return false
	var active := 0
	for p in players:
		if p.in_play():
			active += 1
	if active <= 1 and players.size() > 1:
		end_reason = "completed" if active == 1 else "aborted"
		return true
	var best := -1
	var best_count := 0
	for p in players:
		if not p.in_play():
			continue
		if p.points > best:
			best = p.points
			best_count = 1
		elif p.points == best:
			best_count += 1
	if best >= target_points and best_count == 1:
		end_reason = "completed"
		return true
	if hole_number >= int(_cfg_match.max_holes):
		end_reason = "completed"
		return true
	return false


func _advance_after_hole() -> void:
	if mode == "online" and end_reason != "":
		_finish_match(end_reason)
		return
	if mode == "practice":
		_begin_hole(hole_index, 0.6)
		return
	var next := hole_order[hole_number % hole_order.size()]
	_begin_hole(next, float(_cfg_hole.countdown))


func _finish_match(reason: String) -> void:
	phase = Phase.MATCH_OVER
	end_reason = reason
	_emit({"type": "match_end", "reason": reason, "standings": standings()})


## Final ordering: in-play players first, then points, holes won, total time, slot.
func standings() -> Array[Dictionary]:
	var list := players.duplicate()
	list.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		if a.forfeited != b.forfeited:
			return not a.forfeited
		if a.points != b.points:
			return a.points > b.points
		if a.holes_won != b.holes_won:
			return a.holes_won > b.holes_won
		if not is_equal_approx(a.total_finish_time, b.total_finish_time):
			return a.total_finish_time < b.total_finish_time
		return a.slot < b.slot)
	var out: Array[Dictionary] = []
	for i in list.size():
		var p: PlayerState = list[i]
		out.append({"slot": p.slot, "playerId": p.player_id, "name": p.display_name, "placement": i + 1,
			"points": p.points, "holesWon": p.holes_won, "disconnected": p.forfeited})
	return out


## Forces the match to end (e.g. the server is shutting down or nobody joined).
func abort(reason: String = "aborted") -> void:
	if phase == Phase.MATCH_OVER:
		return
	_finish_match(reason)


# ---------------------------------------------------------------------------
# Connections
# ---------------------------------------------------------------------------

func set_connected(slot: int, value: bool) -> void:
	var p := players[slot]
	if p.forfeited:
		return
	if p.connected == value:
		return
	p.connected = value
	if value:
		p.ever_connected = true
		_emit({"type": "player_rejoined", "slot": slot})
	else:
		p.disconnected_at = time
		_emit({"type": "player_left", "slot": slot})


func forfeit(slot: int) -> void:
	var p := players[slot]
	if p.forfeited:
		return
	p.forfeited = true
	p.connected = false
	p.ball.active = false
	_emit({"type": "player_forfeit", "slot": slot})
	if phase == Phase.PLAYING or phase == Phase.COUNTDOWN:
		var active := 0
		for q in players:
			if q.in_play():
				active += 1
		if active <= 1 and players.size() > 1:
			_end_hole()


func _update_connections() -> void:
	if mode != "online" or phase == Phase.MATCH_OVER:
		return
	var grace := float(_cfg_match.disconnect_grace)
	for p in players:
		if not p.connected and not p.forfeited and time - p.disconnected_at >= grace:
			forfeit(p.slot)


# ---------------------------------------------------------------------------
# Commands (validated; return "" on success or an error code)
# ---------------------------------------------------------------------------

func can_shoot(slot: int) -> String:
	if slot < 0 or slot >= players.size():
		return "bad_slot"
	var p := players[slot]
	if phase != Phase.PLAYING:
		return "not_playing"
	if p.forfeited or p.finished:
		return "finished"
	if p.hazard_timer >= 0.0 or not p.ball.active:
		return "resetting"
	if p.cooldown > 0.0:
		return "cooldown"
	if not p.ball.is_grounded(_grace):
		return "airborne"
	return ""


func cmd_shoot(slot: int, angle: float, power: float, ability_id: String) -> String:
	var err := can_shoot(slot)
	if err != "":
		return err
	if is_nan(angle) or is_inf(angle) or is_nan(power) or is_inf(power):
		return "bad_input"
	var p := players[slot]
	if not abilities.has(ability_id):
		return "unknown_ability"
	if not p.allowed_abilities.has(ability_id):
		return "not_owned"
	var def: Dictionary = abilities[ability_id]
	var cost := float(def.cost)
	if p.energy + 0.0001 < cost:
		return "energy"
	power = clampf(power, 0.0, 1.0)
	p.energy -= cost
	var speed := lerpf(float(_cfg_shot.min_speed), float(_cfg_shot.max_speed), power)
	var vel := Vector2.from_angle(angle) * speed
	var b := p.ball
	# Never remember a hazard position as the respawn point.
	if terrain.zone_at(b.pos) == "":
		p.last_shot_pos = b.pos
	b.reset_modifiers()
	b.ability = ability_id
	var params: Dictionary = def.get("params", {})
	match ability_id:
		"heavy":
			b.mass = float(params.mass)
			b.restitution_scale = float(params.restitution_scale)
			b.gravity_scale = float(params.gravity_scale)
			b.roll_drag_scale = float(params.roll_drag_scale)
		"sticky":
			b.sticky_pending = true
		"grenade":
			b.grenade_pending = true
			b.manual_available = true
		"nitro", "air_brake":
			b.manual_available = true
	if b.stuck:
		b.unstick_grace = 0.25
	b.stuck = false
	b.wake()
	b.vel = vel
	b.since_contact = _grace + 0.01
	b.collides_balls = true
	p.cooldown = float(_cfg_shot.cooldown)
	p.shots += 1
	p.hole_shots += 1
	if ability_id != "standard":
		p.abilities_used[ability_id] = int(p.abilities_used.get(ability_id, 0)) + 1
	_emit({"type": "shot", "slot": slot, "ability": ability_id, "pos": p.last_shot_pos, "vel": vel, "power": power})
	return ""


func cmd_activate(slot: int) -> String:
	if slot < 0 or slot >= players.size() or phase != Phase.PLAYING:
		return "not_playing"
	var p := players[slot]
	var b := p.ball
	if not b.manual_available or not b.active or b.at_rest or b.stuck or p.finished:
		return "unavailable"
	var params: Dictionary = abilities[b.ability].get("params", {})
	match b.ability:
		"nitro":
			var spd := b.vel.length()
			var dir := b.vel / spd if spd > 1.0 else Vector2.from_angle(-PI * 0.25)
			b.vel += dir * float(params.boost)
			var cap := float(params.max_speed)
			if b.vel.length() > cap:
				b.vel = b.vel.normalized() * cap
			b.since_contact = _grace + 0.01
		"air_brake":
			b.vel *= float(params.keep)
			b.gravity_scale = float(params.gravity_scale)
			b.slow_gravity_timer = float(params.slow_time)
		"grenade":
			_detonate(p)
			return ""
		_:
			return "unavailable"
	b.manual_available = false
	_emit({"type": "ability", "slot": slot, "ability": b.ability, "pos": b.pos, "vel": b.vel})
	return ""


func cmd_reset(slot: int) -> String:
	if slot < 0 or slot >= players.size() or phase != Phase.PLAYING:
		return "not_playing"
	var p := players[slot]
	if p.finished or p.forfeited or p.hazard_timer >= 0.0:
		return "unavailable"
	if p.cooldown > 0.0:
		return "cooldown"
	_respawn(p, "reset")
	p.cooldown = float(_cfg_shot.reset_cooldown)
	return ""


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _detonate(p: PlayerState) -> void:
	var b := p.ball
	var gp: Dictionary = abilities.grenade.params
	b.grenade_pending = false
	b.manual_available = false
	var hits := physics.explode(b.pos, float(gp.radius), float(gp.impulse), p.slot, float(gp.self_scale))
	for s in hits:
		players[s].ball.collides_balls = true
	_emit({"type": "explode", "slot": p.slot, "pos": b.pos, "radius": float(gp.radius), "hits": hits})


func _hazard(p: PlayerState, kind: String) -> void:
	# A respawn spot that immediately leads back into a hazard is not safe: use the tee.
	if time - p.respawned_at < 2.5:
		p.last_shot_pos = _tee_spot(p.slot)
	p.ball.active = false
	p.ball.vel = Vector2.ZERO
	p.hazard_timer = float(_cfg_hole.hazard_reset_delay)
	_emit({"type": "hazard", "slot": p.slot, "kind": kind, "pos": p.ball.pos})


func _respawn(p: PlayerState, reason: String) -> void:
	p.hazard_timer = -1.0
	var b := p.ball
	b.reset_modifiers()
	if terrain.zone_at(p.last_shot_pos) != "" or terrain.is_point_solid(p.last_shot_pos):
		p.last_shot_pos = _tee_spot(p.slot)
	b.place(p.last_shot_pos)
	b.active = true
	# Stay put if there is ground directly below; otherwise (e.g. the last shot was taken
	# from a sticky wall) let the ball settle naturally.
	var below := terrain.raycast(b.pos, Vector2.DOWN, b.radius + 6.0)
	if not below.hit or below.normal.y > -0.3:
		b.wake()
	p.cooldown = maxf(p.cooldown, 0.35)
	p.respawned_at = time
	_emit({"type": "respawn", "slot": p.slot, "pos": b.pos, "reason": reason})


func phase_name() -> String:
	return Phase.keys()[phase]
