class_name LocalMatchView
extends MatchView
## Offline practice: runs the authoritative MatchSim locally at a fixed 60 Hz and
## interpolates between ticks for smooth rendering at any refresh rate.

var sim: MatchSim
var _acc: float = 0.0
var _prev_pos: Array[Vector2] = []
var _prev_rot: Array[float] = []


## Solo stroke play through a whole course (clean = Clean Ball challenge, no abilities).
func setup_stroke(p_course_id: String, from_hole: int, appearance: Dictionary, display_name: String, clean: bool = false) -> void:
	mode = "stroke"
	course_id = p_course_id
	course = GameData.course(p_course_id)
	balance = GameData.balance.duplicate(true)
	sim = MatchSim.new(balance, GameData.materials, course, "stroke", 0)
	sim.clean_ball = clean
	sim.add_player("local", display_name, appearance)
	roster = [{"slot": 0, "playerId": "local", "name": display_name, "appearance": appearance, "trophies": 0}]
	local_slot = 0
	allowed_abilities = sim.players[0].allowed_abilities
	_prev_pos = [Vector2.ZERO]
	_prev_rot = [0.0]
	sim.start_stroke(from_hole)
	_flush_events()
	_snap_prev()


## Developer harness: a real local Blitz match (MatchSim "online" rules) with idle bot players,
## used to test the HUD and match flow for 2-6 players without servers (--dev-blitz N).
func setup_local_blitz(p_course_id: String, n: int, appearance: Dictionary, display_name: String) -> void:
	mode = "online"
	course_id = p_course_id
	course = GameData.course(p_course_id)
	balance = GameData.balance.duplicate(true)
	sim = MatchSim.new(balance, GameData.materials, course, "online", 7)
	var chars := ["rex", "mira", "bjorn", "ace", "nana", "bolt"]
	var names := ["Bram", "Mira", "Kestrel", "Ace", "Nana Birdie", "Bolt-3000"]
	roster = []
	_prev_pos = []
	_prev_rot = []
	for i in n:
		var app := appearance if i == 0 else Appearance.normalize({"character": chars[i % chars.size()]})
		var nm: String = display_name if i == 0 else names[i % names.size()]
		sim.add_player("p%d" % i, nm, app)
		roster.append({"slot": i, "playerId": "p%d" % i, "name": nm, "appearance": app, "trophies": 0})
		_prev_pos.append(Vector2.ZERO)
		_prev_rot.append(0.0)
	local_slot = 0
	target_points = sim.target_points
	allowed_abilities = sim.players[0].allowed_abilities
	sim.start()


func setup_practice(p_course_id: String, hole: int, appearance: Dictionary, display_name: String) -> void:
	mode = "practice"
	course_id = p_course_id
	course = GameData.course(p_course_id)
	balance = GameData.balance.duplicate(true)
	sim = MatchSim.new(balance, GameData.materials, course, "practice", 0)
	sim.add_player("local", display_name, appearance)
	roster = [{"slot": 0, "playerId": "local", "name": display_name, "appearance": appearance, "trophies": 0}]
	local_slot = 0
	allowed_abilities = sim.players[0].allowed_abilities
	_prev_pos = [Vector2.ZERO]
	_prev_rot = [0.0]
	set_hole(hole)


func set_hole(index: int) -> void:
	sim.start_practice_hole(index)
	_flush_events()
	_snap_prev()


func _process(delta: float) -> void:
	if sim == null:
		return
	_acc += minf(delta, 0.25)
	while _acc >= MatchSim.DT:
		_acc -= MatchSim.DT
		_snap_prev()
		sim.tick()
		if not sim.last_impacts.is_empty():
			impacts.emit(sim.last_impacts)
		_flush_events()


func _snap_prev() -> void:
	for p in sim.players:
		_prev_pos[p.slot] = p.ball.pos
		_prev_rot[p.slot] = p.ball.rot


func _flush_events() -> void:
	for ev in sim.take_events():
		if ev.type == "hole_start":
			terrain = sim.terrain
			hole_index = int(ev.hole_index)
			hole_number = int(ev.hole_number)
			hole_loaded.emit(hole_index, hole_number)
		game_event.emit(ev)


func ball_state(slot: int) -> Dictionary:
	var p := sim.players[slot]
	var b := p.ball
	var alpha := _acc / MatchSim.DT
	var pos := _prev_pos[slot].lerp(b.pos, alpha)
	if _prev_pos[slot].distance_squared_to(b.pos) > 250000.0:
		pos = b.pos
	return {
		"pos": pos, "vel": b.vel, "rot": lerp_angle(_prev_rot[slot], b.rot, alpha),
		"active": b.active, "at_rest": b.at_rest, "stuck": b.stuck,
		"grounded": b.is_grounded(float(GameData.balance.physics.grounded_grace)),
		"finished": p.finished, "connected": true, "forfeited": false,
		"manual": b.manual_available or b.mulligan_ready, "ability": b.ability, "hazard": p.hazard_timer >= 0.0,
		"grenade": b.grenade_pending, "shield": b.shield > 0, "ice": b.freezes_water,
		"anti_grav": b.anti_grav_timer > 0.0, "magnet": b.magnet_strength > 0.0,
		"brake": b.brake_timer > 0.0, "boost": b.boost_timer > 0.0,
	}


func player_state(slot: int) -> Dictionary:
	var p := sim.players[slot]
	return {"energy": p.energy, "cooldown": p.cooldown, "points": p.points, "hole_shots": p.hole_shots,
		"strokes": p.hole_shots + p.penalties, "penalties": p.penalties, "charges": p.charges}


func phase_state() -> Dictionary:
	return {"phase": sim.phase, "timer": sim.phase_timer, "hole_time": sim.hole_time, "deadline": sim.hole_deadline}


func local_shot_block() -> String:
	return sim.can_shoot(local_slot)


func shoot(angle: float, power: float, ability: String, spin: float = 0.0) -> void:
	var err := sim.cmd_shoot(local_slot, angle, power, ability, spin)
	if err != "":
		game_event.emit({"type": "rejected", "error": err})
	_flush_events()


func activate() -> void:
	sim.cmd_activate(local_slot)
	_flush_events()


func spin(dir: int) -> void:
	sim.cmd_spin(local_slot, dir)


func reset_ball() -> void:
	var err := sim.cmd_reset(local_slot)
	if err != "":
		game_event.emit({"type": "rejected", "error": err})
	_flush_events()


func emote(id: int) -> void:
	game_event.emit({"type": "emote", "slot": local_slot, "emote": id})


## Physics lab: live-tune balance values (affects only this local simulation).
func apply_tuning(section: String, key: String, value: float) -> void:
	sim.balance[section][key] = value
	if section == "physics" and sim.physics:
		sim.physics.set(_physics_field(key), value)


static func _physics_field(key: String) -> String:
	match key:
		"gravity": return "gravity"
		"air_drag": return "air_drag"
		"ball_restitution": return "ball_e"
		"rest_speed": return "rest_speed"
		_: return key
