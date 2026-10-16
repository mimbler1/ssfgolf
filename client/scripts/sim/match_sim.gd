class_name MatchSim
extends RefCounted
## Authoritative match rules. Runs on the dedicated server for online play and locally for
## practice and stroke play. Has no rendering or networking dependencies.
## Specs: docs/PHYSICS_SPEC.md, docs/POWERUP_SPEC.md, docs/GAME_DESIGN.md.
##
## Modes:
##   "online"   - Blitz race: simultaneous play, finishing order scores points, energy + cooldowns.
##   "practice" - one hole on repeat (no scoring), energy as online.
##   "stroke"   - solo course play: the course's holes in order, strokes vs par, limited ability
##                charges per course instead of energy, penalty stroke for hazards.

const DT := 1.0 / 60.0
const MAX_PLAYERS := 6

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
	var penalties: int = 0
	var abilities_used: Dictionary = {}
	## Stroke play: remaining uses per ability for this course.
	var charges: Dictionary = {}
	## Stroke play: one entry per finished hole {hole_id, par, strokes, swish, ace}.
	var scorecard: Array[Dictionary] = []
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
	## Whether the last shot counts as a stroke (Free Shot does not).
	var last_shot_counted: bool = true

	func in_play() -> bool:
		return not forfeited


var mode: String = "online"           ## "online" | "practice" | "stroke"
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
## Stroke play "Clean Ball" challenge: no abilities at all.
var clean_ball: bool = false
## A host-chosen win target (private rooms); 0 = use the table for the player count.
var target_override: int = 0

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


## Launch speed for a shot power in [0, 1] using the tuned power curve (PHYSICS_SPEC.md §2).
## The curve is piecewise linear through `shot.power_curve` points [power, speed fraction].
static func launch_speed(bal: Dictionary, power: float) -> float:
	var shot: Dictionary = bal.shot
	var p := clampf(power, 0.0, 1.0)
	var frac := p
	var curve: Array = shot.get("power_curve", [])
	if curve.size() >= 2:
		for i in range(1, curve.size()):
			var a: Array = curve[i - 1]
			var b: Array = curve[i]
			if p <= float(b[0]) or i == curve.size() - 1:
				var span := maxf(float(b[0]) - float(a[0]), 0.0001)
				frac = lerpf(float(a[1]), float(b[1]), clampf((p - float(a[0])) / span, 0.0, 1.0))
				break
	return lerpf(float(shot.min_speed), float(shot.max_speed), frac)


## Initial angular velocity: natural roll for the horizontal speed plus the player's spin
## (-1 full backspin .. +1 full topspin), proportional to launch speed.
static func launch_spin(bal: Dictionary, vel: Vector2, spin: float, radius: float) -> float:
	var fwd := 1.0 if vel.x >= 0.0 else -1.0
	var s := clampf(spin, -1.0, 1.0)
	var gain := float(bal.shot.get("spin_gain_top", 0.0)) if s > 0.0 else float(bal.shot.get("spin_gain_back", 0.0))
	return (vel.x + fwd * s * gain * vel.length()) / radius


## Applies an ability's launch-time physics to a ball (also used by the Laser Ball guide so
## the guide and the real shot share one definition).
static func apply_ability(b: SimBall, def: Dictionary) -> void:
	var id := str(def.get("id", "standard"))
	var params: Dictionary = def.get("params", {})
	b.ability = id
	b.activations_left = int(def.get("max_activations", 0))
	b.manual_available = b.activations_left > 0
	match id:
		"heavy":
			b.mass = float(params.mass)
			b.restitution_scale = float(params.restitution_scale)
			b.gravity_scale = float(params.gravity_scale)
			b.roll_drag_scale = float(params.roll_drag_scale)
		"sticky":
			b.sticky_pending = true
		"grenade":
			b.grenade_pending = true
		"anti_grav":
			b.anti_grav_timer = float(params.duration)
			b.anti_grav_scale = float(params.gravity_scale)
		"magnet":
			b.magnet_strength = float(params.strength)
			b.magnet_falloff = float(params.falloff)
			b.magnet_radius = float(params.radius)
		"ice":
			b.freezes_water = true
		"shield":
			b.shield = int(params.blocks)
		"mulligan":
			b.mulligan_ready = true


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
		if ability_allowed_in_mode(id):
			p.allowed_abilities.append(id)
	_reset_charges(p)
	players.append(p)
	_update_target()
	return p


## Points needed to win for the current player count (match.target_points_by_count overrides).
func _update_target() -> void:
	if target_override > 0:
		target_points = target_override
		return
	var by: Dictionary = _cfg_match.get("target_points_by_count", {})
	target_points = int(by.get(str(players.size()), _cfg_match.target_points))


## Restricts a player's balls to `ids` (unlocks), always keeping the regular ball.
func set_allowed(p: PlayerState, ids: PackedStringArray) -> void:
	var out := PackedStringArray(["standard"])
	for id in ids:
		if id != "standard" and ability_allowed_in_mode(id) and not out.has(id):
			out.append(id)
	p.allowed_abilities = out
	_reset_charges(p)


func ability_allowed_in_mode(id: String) -> bool:
	if not abilities.has(id):
		return false
	var modes: Array = abilities[id].get("modes", ["online", "practice", "stroke"])
	return mode in modes


func _reset_charges(p: PlayerState) -> void:
	p.charges.clear()
	if mode != "stroke":
		return
	var per: Dictionary = balance.get("stroke", {}).get("charges", {})
	for id: String in abilities.keys():
		if id == "standard" or not ability_allowed_in_mode(id) or not p.allowed_abilities.has(id):
			continue
		p.charges[id] = 0 if clean_ball else int(per.get(id, per.get("default", 2)))


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


## Stroke play from the first hole (or `from_hole`) through the end of the course.
func start_stroke(from_hole: int = 0) -> void:
	hole_number = from_hole
	for p in players:
		_reset_charges(p)
		p.scorecard.clear()
	_begin_hole(from_hole, 0.6)


func _begin_hole(index: int, countdown: float) -> void:
	hole_index = index
	var hole: Dictionary = course.holes[index]
	terrain = SimTerrain.new()
	terrain.build(hole)
	physics = SimPhysics.new(terrain, balance.physics, materials)
	physics.cup = terrain.cup_pos if terrain.has_cup else Vector2.INF
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
		p.penalties = 0
		p.cooldown = 0.0
		p.hazard_timer = -1.0
		physics.add_ball(b)
	phase = Phase.COUNTDOWN
	phase_timer = countdown
	_emit({"type": "hole_start", "hole_index": index, "hole_number": hole_number,
		"hole_id": str(hole.get("id", "")), "countdown": countdown})


## Tee spots: up to six balls side by side around the tee, 24 px apart.
func _tee_spot(slot: int) -> Vector2:
	var n := players.size()
	var hole: Dictionary = course.holes[hole_index] if hole_index >= 0 else {}
	var spawns: Array = hole.get("spawns", [])
	var spot: Vector2
	if slot < spawns.size():
		spot = Vector2(float(spawns[slot][0]), float(spawns[slot][1])) + Vector2(0, -200.0)
	else:
		var offset := (float(slot % MAX_PLAYERS) - float(mini(n, MAX_PLAYERS) - 1) * 0.5) * 24.0 if n > 1 else 0.0
		spot = terrain.tee + Vector2(offset, -200.0)
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
		if mode != "stroke":
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

	for f in physics.froze:
		_emit({"type": "freeze", "slot": f.slot, "pos": f.pos})
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
			if b.shield > 0 and zone in (abilities.shield.params.zones as Array):
				_shield_block(p, zone)
			else:
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
	else:
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
		var b := p.ball
		p.finished = true
		p.finish_tick = tick_count
		p.place = place
		b.active = false
		p.total_finish_time += hole_time
		var strokes := p.hole_shots + p.penalties
		var swish := b.contacts_since_shot == 0 and b.flight_time > 0.05
		var ace := strokes == 1
		_emit({"type": "holed", "slot": p.slot, "place": place, "time": hole_time, "shots": p.hole_shots,
			"strokes": strokes, "swish": swish, "hole_in_one": ace})
		if mode == "stroke":
			var hole: Dictionary = course.holes[hole_index]
			p.scorecard.append({"hole_id": str(hole.get("id", "")), "par": int(hole.get("par", 3)),
				"strokes": strokes, "swish": swish, "ace": ace, "time": hole_time})
	# Once someone finishes, the rest get a limited window.
	if already == 0 and mode == "online":
		var window := float(_cfg_hole.finish_window)
		if hole_time + window < hole_deadline:
			hole_deadline = hole_time + window
			_emit({"type": "hole_timer", "deadline": hole_deadline, "remaining": window})


## Points table for this match's player count (match.points["<n>"]).
func points_table() -> Array:
	var pts: Dictionary = _cfg_match.points
	var n := players.size()
	return pts.get(str(n), pts.get(str(mini(n, MAX_PLAYERS)), pts.get("4")))


func _end_hole() -> void:
	var table := points_table()
	var results: Array[Dictionary] = []
	var order: Array[PlayerState] = []
	for p in players:
		if p.in_play():
			p.holes_played += 1
		var gained := 0
		if p.finished:
			gained = int(table[mini(p.place - 1, table.size() - 1)]) if mode == "online" else 0
			if p.place == 1:
				p.holes_won += 1
			order.append(p)
		elif p.in_play():
			p.total_finish_time += hole_time
		p.points += gained
		results.append({"slot": p.slot, "place": p.place if p.finished else 0, "gained": gained,
			"total": p.points, "finished": p.finished, "shots": p.hole_shots, "strokes": p.hole_shots + p.penalties})
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
	if mode == "stroke":
		if hole_index >= course.holes.size() - 1:
			end_reason = "completed"
			return true
		return false
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
	# A tie at the top plays on (sudden death) until one player leads at or above the target.
	if best >= target_points and best_count == 1:
		end_reason = "completed"
		return true
	if hole_number >= int(_cfg_match.max_holes):
		end_reason = "completed"
		return true
	return false


func _advance_after_hole() -> void:
	if (mode == "online" or mode == "stroke") and end_reason != "":
		_finish_match(end_reason)
		return
	if mode == "practice":
		_begin_hole(hole_index, 0.6)
		return
	if mode == "stroke":
		_begin_hole(hole_index + 1, 0.6)
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
		var row := {"slot": p.slot, "playerId": p.player_id, "name": p.display_name, "placement": i + 1,
			"points": p.points, "holesWon": p.holes_won, "disconnected": p.forfeited}
		if mode == "stroke":
			row["scorecard"] = p.scorecard.duplicate(true)
		out.append(row)
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


## Why `ability_id` cannot be used for this player's next shot ("" if it can).
func ability_block(slot: int, ability_id: String) -> String:
	var p := players[slot]
	if not abilities.has(ability_id):
		return "unknown_ability"
	if not ability_allowed_in_mode(ability_id):
		return "mode"
	if not p.allowed_abilities.has(ability_id):
		return "not_owned"
	if ability_id == "standard":
		return ""
	if mode == "stroke":
		return "" if int(p.charges.get(ability_id, 0)) > 0 else "no_charges"
	return "" if p.energy + 0.0001 >= float(abilities[ability_id].cost) else "energy"


func cmd_shoot(slot: int, angle: float, power: float, ability_id: String, spin: float = 0.0) -> String:
	var err := can_shoot(slot)
	if err != "":
		return err
	if is_nan(angle) or is_inf(angle) or is_nan(power) or is_inf(power) or is_nan(spin) or is_inf(spin):
		return "bad_input"
	err = ability_block(slot, ability_id)
	if err != "":
		return err
	var p := players[slot]
	var def: Dictionary = abilities[ability_id]
	if ability_id != "standard":
		if mode == "stroke":
			p.charges[ability_id] = int(p.charges[ability_id]) - 1
		else:
			p.energy -= float(def.cost)
	power = clampf(power, 0.0, 1.0)
	spin = clampf(spin, -1.0, 1.0) if bool(_cfg_shot.get("spin_enabled", true)) else 0.0
	var speed := launch_speed(balance, power)
	var params: Dictionary = def.get("params", {})
	if ability_id == "super":
		speed *= float(params.power_scale)
	var vel := Vector2.from_angle(angle) * speed
	var b := p.ball
	# Never remember a hazard position as the respawn point.
	if terrain.zone_at(b.pos) == "":
		p.last_shot_pos = b.pos
	b.reset_modifiers()
	apply_ability(b, def)
	if b.stuck:
		b.unstick_grace = 0.25
	b.stuck = false
	b.wake()
	b.vel = vel
	b.ang_vel = launch_spin(balance, vel, spin, b.radius)
	b.since_contact = _grace + 0.01
	b.collides_balls = true
	p.cooldown = float(_cfg_shot.cooldown) if mode != "stroke" else float(_cfg_shot.get("stroke_cooldown", 0.3))
	p.shots += 1
	p.last_shot_counted = not (ability_id == "free_shot" and mode == "stroke")
	if p.last_shot_counted:
		p.hole_shots += 1
	if ability_id != "standard":
		p.abilities_used[ability_id] = int(p.abilities_used.get(ability_id, 0)) + 1
	_emit({"type": "shot", "slot": slot, "ability": ability_id, "pos": p.last_shot_pos, "vel": vel,
		"power": power, "spin": spin, "counted": p.last_shot_counted})
	return ""


## In-flight spin input (-1 backspin, 0 release, +1 topspin). Only while the ball is airborne.
func cmd_spin(slot: int, dir: int) -> String:
	if slot < 0 or slot >= players.size() or phase != Phase.PLAYING:
		return "not_playing"
	if not bool(_cfg_shot.get("spin_in_flight", true)):
		return "unavailable"
	players[slot].ball.spin_input = clampi(dir, -1, 1)
	return ""


func cmd_activate(slot: int) -> String:
	if slot < 0 or slot >= players.size() or phase != Phase.PLAYING:
		return "not_playing"
	var p := players[slot]
	var b := p.ball
	if p.finished or not b.active:
		return "unavailable"
	# Mulligan works at any time until the next shot, including after the ball has stopped.
	if b.mulligan_ready:
		return _mulligan(p)
	if not b.manual_available or b.at_rest or b.stuck or b.activations_left <= 0:
		return "unavailable"
	var params: Dictionary = abilities[b.ability].get("params", {})
	match b.ability:
		"nitro":
			b.boost_timer = float(params.duration)
			b.boost_accel = float(params.boost) / float(params.duration)
			b.boost_cap = float(params.max_speed)
			b.since_contact = _grace + 0.01
		"air_brake":
			b.brake_timer = float(params.duration)
			b.brake_rate = float(params.rate)
			b.brake_gravity = float(params.gravity_scale)
		"zig_zag":
			# Mirror the horizontal motion (and the spin with it); vertical motion is kept.
			b.vel.x = -b.vel.x * float(params.keep)
			b.ang_vel = -b.ang_vel
			b.vel.y = minf(b.vel.y, b.vel.y * float(params.keep))
		"grenade":
			_detonate(p)
			return ""
		_:
			return "unavailable"
	b.activations_left -= 1
	b.manual_available = b.activations_left > 0
	_emit({"type": "ability", "slot": slot, "ability": b.ability, "pos": b.pos, "vel": b.vel,
		"left": b.activations_left})
	return ""


## Mulligan: the ball goes back to where the last shot was taken, the player may shoot again at
## once, and in stroke play the stroke is not counted. Only this player's ball moves; the shared
## world is never rewound (POWERUP_SPEC.md, Mulligan).
func _mulligan(p: PlayerState) -> String:
	var b := p.ball
	var from := b.pos
	b.reset_modifiers()
	b.place(p.last_shot_pos)
	b.active = true
	var below := terrain.raycast(b.pos, Vector2.DOWN, b.radius + 6.0)
	if not below.hit or below.normal.y > -0.3:
		b.wake()
	p.cooldown = minf(p.cooldown, 0.25)
	if mode == "stroke" and p.last_shot_counted:
		p.hole_shots = maxi(0, p.hole_shots - 1)
	_emit({"type": "ability", "slot": p.slot, "ability": "mulligan", "pos": b.pos, "from": from, "vel": Vector2.ZERO, "left": 0})
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
	p.cooldown = float(_cfg_shot.reset_cooldown) if mode != "stroke" else 0.3
	if mode == "stroke":
		p.penalties += 1
	return ""


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _detonate(p: PlayerState) -> void:
	var b := p.ball
	var gp: Dictionary = abilities.grenade.params
	b.grenade_pending = false
	b.manual_available = false
	b.activations_left = 0
	var hits := physics.explode(b.pos, float(gp.radius), float(gp.impulse), p.slot, float(gp.self_scale))
	for s in hits:
		players[s].ball.collides_balls = true
	_emit({"type": "explode", "slot": p.slot, "pos": b.pos, "radius": float(gp.radius), "hits": hits})


## Shield Ball meets a hazard zone: it bounces off the surface instead and the shield breaks.
func _shield_block(p: PlayerState, kind: String) -> void:
	var b := p.ball
	var top := INF
	for z in terrain.zones:
		if z["type"] == kind and z["rect"].has_point(b.pos):
			top = minf(top, (z["rect"] as Rect2).position.y)
	if top < INF:
		b.pos.y = top - b.radius - 0.5
	var bounce := float(abilities.shield.params.bounce)
	b.vel.y = -maxf(absf(b.vel.y) * bounce, float(abilities.shield.params.min_pop))
	b.shield -= 1
	b.wake()
	_emit({"type": "shield_block", "slot": p.slot, "kind": kind, "pos": b.pos})


func _hazard(p: PlayerState, kind: String) -> void:
	# A respawn spot that immediately leads back into a hazard is not safe: use the tee.
	if time - p.respawned_at < 2.5:
		p.last_shot_pos = _tee_spot(p.slot)
	p.ball.active = false
	p.ball.vel = Vector2.ZERO
	p.hazard_timer = float(_cfg_hole.hazard_reset_delay)
	if mode == "stroke":
		p.penalties += 1
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
	# from a sticky wall or frozen water) let the ball settle naturally.
	var below := terrain.raycast(b.pos, Vector2.DOWN, b.radius + 6.0)
	if not below.hit or below.normal.y > -0.3:
		b.wake()
	p.cooldown = maxf(p.cooldown, 0.35)
	p.respawned_at = time
	_emit({"type": "respawn", "slot": p.slot, "pos": b.pos, "reason": reason})


func phase_name() -> String:
	return Phase.keys()[phase]
