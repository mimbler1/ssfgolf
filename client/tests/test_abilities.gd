extends SceneTree
## BallPhysicsLab, headless half (docs/PHYSICS_SPEC.md, docs/POWERUP_SPEC.md).
## Runs the directive's lab tests A-H against every ball type and asserts the documented
## behaviour, then writes the comparison table to docs/physics/lab_results.md.
##   tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path client --script res://tests/test_abilities.gd

var balance: Dictionary
var materials: Dictionary
var failures := 0
## Set at the end of every test section; a section that dies on a script error never sets it.
var _section_ok := false
var passes := 0
var report: PackedStringArray = []


func _initialize() -> void:
	balance = _json("res://data/balance.json")
	materials = _json("res://data/materials.json").materials

	_run_section("test_a_standard_launch", func() -> void: test_a_standard_launch())
	_run_section("test_b_wall", func() -> void: test_b_wall())
	_run_section("test_c_rolling_hill", func() -> void: test_c_rolling_hill())
	_run_section("test_d_water", func() -> void: test_d_water())
	_run_section("test_e_sticky", func() -> void: test_e_sticky())
	_run_section("test_f_ball_collision", func() -> void: test_f_ball_collision())
	_run_section("test_g_activations", func() -> void: test_g_activations())
	_run_section("test_h_repeatability", func() -> void: test_h_repeatability())
	_run_section("test_spin", func() -> void: test_spin())
	_run_section("test_surfaces", func() -> void: test_surfaces())
	_run_section("test_gravity_field_and_conveyor", func() -> void: test_gravity_field_and_conveyor())
	_run_section("test_modes_and_counting", func() -> void: test_modes_and_counting())
	_run_section("test_six_players", func() -> void: test_six_players())
	_run_section("test_launch_curve", func() -> void: test_launch_curve())
	_run_section("test_unlocks", func() -> void: test_unlocks())
	_run_section("test_collection_catalog", func() -> void: test_collection_catalog())

	_write_report()
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


## Runs one test section and fails it if it did not reach its end (GDScript errors only abort
## the current function, which would otherwise look like a pass).
func _run_section(name: String, f: Callable) -> void:
	_section_ok = false
	f.call()
	if not _section_ok:
		failures += 1
		print("  FAIL section %s aborted (script error)" % name)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", label)
	else:
		failures += 1
		print("  FAIL ", label)


# ---------------------------------------------------------------------------
# Lab courses
# ---------------------------------------------------------------------------

func _hole(terrain: Array, extra: Dictionary = {}) -> Dictionary:
	var h := {"id": "lab", "bounds": {"x": -800, "y": -2600, "w": 9000, "h": 3200},
		"tee": {"x": 0, "y": 0}, "terrain": terrain}
	for k in extra:
		h[k] = extra[k]
	return {"id": "lab", "name": "Lab", "holes": [h]}


func _flat(mat: String = "grass", extra: Dictionary = {}) -> Dictionary:
	return _hole([{"material": mat, "smooth": false, "points": [[-800, 0], [8200, 0], [8200, 400], [-800, 400]]}], extra)


func _sim(course: Dictionary, mode: String = "practice", n: int = 1) -> MatchSim:
	var sim := MatchSim.new(balance, materials, course, mode, 1)
	for i in n:
		sim.add_player("p%d" % i, "P%d" % i, {})
	if mode == "stroke":
		sim.start_stroke(0)
	else:
		sim.start_practice_hole(0)
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	for p in sim.players:
		p.energy = 100.0
	return sim


## Shoots and records the flight. `activate_at` (s) presses Space once (or `times` times, 0.25 s apart).
func _fly(sim: MatchSim, ability: String, angle: float, power: float, spin: float = 0.0,
		activate_at: float = -1.0, times: int = 1, max_t: float = 14.0) -> Dictionary:
	var b := sim.players[0].ball
	var start := b.pos
	var err := sim.cmd_shoot(0, angle, power, ability, spin)
	var out := {"err": err, "max_h": 0.0, "first_x": INF, "flight": 0.0, "bounces": 0, "end": b.pos,
		"hazard": false, "stuck": false, "events": [], "vx_after": 0.0, "act_dx": 0.0}
	if err != "":
		return out
	var t := 0.0
	var landed := false
	var pressed := 0
	var prev_contact := false
	while t < max_t:
		if activate_at >= 0.0 and pressed < times and t >= activate_at + pressed * 0.25:
			sim.cmd_activate(0)
			pressed += 1
			if pressed == 1:
				out.vx_after = b.vel.x
				out.act_dx = b.pos.x - start.x
		sim.tick()
		t += MatchSim.DT
		for ev in sim.take_events():
			out.events.append(ev)
			if ev.type == "hazard":
				out.hazard = true
		if not b.active:
			break
		out.max_h = maxf(out.max_h, start.y - b.pos.y)
		var touching := b.since_contact <= MatchSim.DT * 1.5
		if touching and not prev_contact and b.vel.length() > 20.0:
			out.bounces += 1
		if touching and not landed:
			landed = true
			out.first_x = b.pos.x - start.x
			out.flight = t
		prev_contact = touching
		if b.stuck:
			out.stuck = true
		if b.at_rest or b.stuck:
			break
	out.end = b.pos
	out.end_dx = b.pos.x - start.x
	return out


func _has_event(r: Dictionary, type: String) -> bool:
	for ev in r.events:
		if ev.type == type:
			return true
	return false


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_a_standard_launch() -> void:
	print("Test A: standard launch (same angle 45 deg, power 0.6, no activation)")
	report.append("## Test A: standard launch\n\nSame tee, 45 degrees, power 0.6, flat grass, no activation.\n")
	report.append("| Ball | Max height | First impact | Flight (s) | Bounces | Final distance |")
	report.append("|---|---|---|---|---|---|")
	var results := {}
	for a: Dictionary in balance.abilities:
		var id := str(a.id)
		if id in ["free_shot"]:
			continue
		var sim := _sim(_flat())
		var r := _fly(sim, id, -PI * 0.25, 0.6)
		results[id] = r
		report.append("| %s | %.0f | %s | %.2f | %d | %.0f |" % [a.name, r.max_h,
			"%.0f" % r.first_x if r.first_x < INF else "none", r.flight, r.bounces, r.get("end_dx", 0.0)])
	var std: Dictionary = results.standard
	check(std.first_x > 700.0 and std.first_x < 1300.0, "standard carry is a satisfying distance (%.0f px)" % std.first_x)
	check(std.bounces >= 1 and std.bounces <= 4, "standard bounces a few times, not like rubber (%d)" % std.bounces)
	check(results.laser.end_dx == std.end_dx, "laser ball flies exactly like the standard ball")
	check(results.super.first_x > std.first_x * 1.45, "super ball carries much further (%.0f vs %.0f)" % [results.super.first_x, std.first_x])
	check(results.heavy.max_h < std.max_h, "heavy ball flies lower (%.0f vs %.0f)" % [results.heavy.max_h, std.max_h])
	check(results.heavy.bounces <= std.bounces, "heavy ball bounces no more than standard")
	check(results.anti_grav.max_h > std.max_h * 1.5, "anti-grav flies straight up its line (max h %.0f vs %.0f)" % [results.anti_grav.max_h, std.max_h])
	check(results.sticky.stuck and results.sticky.bounces <= 1, "sticky ball sticks where it lands")
	check(absf(results.sticky.end_dx - results.sticky.first_x) < 30.0, "sticky ball does not roll after landing")
	check(_has_event(results.grenade, "explode"), "grenade explodes on impact")
	report.append("")
	_section_ok = true


func test_b_wall() -> void:
	print("Test B: wall rebound")
	report.append("## Test B: wall rebound\n\nFlat shot (power 0.7, 10 degrees up) into a rock wall 500 px away.\n")
	report.append("| Ball | Rebound speed | Final position (from wall) |")
	report.append("|---|---|---|")
	var wall := _hole([{"material": "grass", "smooth": false, "points": [[-800, 0], [500, 0], [500, -1400, {"m": "rock"}],
		[700, -1400], [700, 400], [-800, 400]]}])
	var reb := {}
	for id in ["standard", "heavy", "shield", "super"]:
		var sim := _sim(wall)
		var b := sim.players[0].ball
		sim.cmd_shoot(0, -0.17, 0.7, id)
		var best := 0.0
		for i in 300:
			sim.tick()
			if b.vel.x < 0.0:
				best = maxf(best, -b.vel.x)
			if b.at_rest:
				break
		reb[id] = best
		report.append("| %s | %.0f | %.0f |" % [id, best, 500.0 - b.pos.x])
		check(b.pos.x < 500.0 - b.radius + 1.0, "%s ball never passes through the wall" % id)
	check(reb.heavy < reb.standard * 0.7, "heavy rebounds much less (%.0f vs %.0f)" % [reb.heavy, reb.standard])
	check(reb.super > reb.standard, "super ball hits the wall harder")
	report.append("")
	_section_ok = true


func test_c_rolling_hill() -> void:
	print("Test C: rolling on a hill")
	report.append("## Test C: rolling down a moderate hill\n\nBall released at rest on a 20 degree grass slope.\n")
	report.append("| Ball | Speed at bottom | Distance rolled on the flat |")
	report.append("|---|---|---|")
	var hill := _hole([{"material": "grass", "smooth": false, "points": [[-800, -600], [-600, -600], [1048, 0], [6000, 0], [6000, 400], [-800, 400]]}])
	var out := {}
	for id in ["standard", "heavy"]:
		var sim := _sim(hill)
		var b := sim.players[0].ball
		b.reset_modifiers()
		MatchSim.apply_ability(b, sim.abilities[id])
		b.place(Vector2(-400, -600 + 200.0 * 600.0 / 1648.0 - 11.0))
		b.wake()
		b.collides_balls = true
		var v_bottom := 0.0
		for i in 1800:
			sim.tick()
			if b.pos.x >= 1048.0 and v_bottom == 0.0:
				v_bottom = b.vel.length()
			if b.at_rest:
				break
		out[id] = {"v": v_bottom, "x": b.pos.x - 1048.0, "rest": b.at_rest}
		report.append("| %s | %.0f | %.0f |" % [id, v_bottom, b.pos.x - 1048.0])
		check(b.at_rest, "%s ball eventually rests (no endless creep)" % id)
	check(out.standard.v > 150.0, "ball accelerates down a 20 degree hill (%.0f px/s)" % out.standard.v)
	check(out.heavy.x > out.standard.x, "heavy ball rolls further (less rolling drag)")
	report.append("")
	_section_ok = true


func test_d_water() -> void:
	print("Test D: water")
	var pond := _flat("grass", {"zones": [{"type": "water", "points": [[700, -20], [2400, -20], [2400, 300], [700, 300]]}]})
	# Cut the ground under the pond so the water is a real basin.
	pond.holes[0].terrain = [
		{"material": "grass", "smooth": false, "points": [[-800, 0], [700, 0], [700, 300], [-800, 300]]},
		{"material": "grass", "smooth": false, "points": [[2400, 0], [8200, 0], [8200, 300], [2400, 300]]},
		{"material": "sand", "smooth": false, "points": [[700, 300], [2400, 300], [2400, 400], [700, 400]]},
	]
	var std := _fly(_sim(pond), "standard", -PI * 0.25, 0.48)
	check(std.hazard, "standard ball landing in water is a hazard")
	var ice_sim := _sim(pond)
	var ice := _fly(ice_sim, "ice", -PI * 0.25, 0.48)
	check(not ice.hazard and _has_event(ice, "freeze"), "ice ball freezes the water and stays out of the hazard")
	check(ice_sim.players[0].ball.at_rest or ice_sim.players[0].ball.pos.x > 2400.0, "ice ball comes to rest on the ice or carries on")
	var sh_sim := _sim(pond)
	var sh := _fly(sh_sim, "shield", -PI * 0.25, 0.48)
	check(_has_event(sh, "shield_block"), "shield blocks the first water contact")
	check(sh_sim.players[0].ball.shield == 0, "the shield is used up after one block")
	var sim2 := _sim(pond, "stroke")
	_fly(sim2, "standard", -PI * 0.25, 0.48)
	check(sim2.players[0].penalties == 1, "stroke play adds one penalty stroke for water")
	report.append("## Test D: water\n\n45 degrees, power 0.48, into a pond.\n")
	report.append("| Ball | Result |\n|---|---|")
	report.append("| Regular | Hazard, respawn at last shot position (+1 stroke in stroke play) |")
	report.append("| Ice | Freezes the surface, %s |" % ("rests on the ice" if ice_sim.players[0].ball.at_rest else "skims across"))
	report.append("| Shield | Bounces off the water once, then the shield is gone |\n")
	_section_ok = true


func test_e_sticky() -> void:
	print("Test E: sticky wall and ceiling")
	var wall := _hole([{"material": "grass", "smooth": false, "points": [[-800, 0], [400, 0], [400, -1400], [600, -1400], [600, 400], [-800, 400]]}])
	var sim := _sim(wall)
	var r := _fly(sim, "sticky", -0.6, 0.5)
	var b := sim.players[0].ball
	check(r.stuck and absf(b.pos.x - (400.0 - b.radius)) < 3.0 and b.pos.y < -20.0, "sticky ball sticks to a vertical wall")
	check(sim.can_shoot(0) == "" or sim.can_shoot(0) == "cooldown", "a stuck ball can be shot again")
	for i in 120:
		sim.tick()
	check(sim.cmd_shoot(0, -PI * 0.75, 0.4, "standard") == "", "shot from the wall is accepted")
	var ceil_course := _hole([
		{"material": "grass", "smooth": false, "points": [[-800, 0], [8200, 0], [8200, 400], [-800, 400]]},
		{"material": "rock", "smooth": false, "points": [[200, -400], [1400, -400], [1400, -700], [200, -700]]}])
	var sim2 := _sim(ceil_course)
	var r2 := _fly(sim2, "sticky", -1.2, 0.6)
	check(r2.stuck and sim2.players[0].ball.pos.y > -400.0 and sim2.players[0].ball.pos.y < -380.0, "sticky ball sticks to a ceiling")
	var sim3 := _sim(_hole([{"material": "grass", "smooth": false, "points": [[-800, 0], [300, 0], [500, -40, {"m": "sticky"}], [900, -40], [1100, 0], [8200, 0], [8200, 400], [-800, 400]]}]))
	var r3 := _fly(sim3, "standard", -PI * 0.25, 0.32)
	check(r3.stuck, "a standard ball is caught by sticky terrain (terrain stickiness is separate from the ability)")
	_section_ok = true


func test_f_ball_collision() -> void:
	print("Test F: ball-to-ball collision")
	report.append("## Test F: ball-to-ball collision\n\nTwo balls approach head-on at 600 px/s each.\n")
	report.append("| Pair | Ball A after | Ball B after | Momentum before | Momentum after |\n|---|---|---|---|---|")
	for pair in [["standard", "standard"], ["heavy", "standard"], ["shield", "standard"]]:
		var sim := _sim(_flat(), "practice", 2)
		var a := sim.players[0].ball
		var b := sim.players[1].ball
		for pb in [[a, pair[0], Vector2(1000, -300), 600.0], [b, pair[1], Vector2(1100, -300), -600.0]]:
			var ball: SimBall = pb[0]
			ball.reset_modifiers()
			MatchSim.apply_ability(ball, sim.abilities[pb[1]])
			ball.place(pb[2])
			ball.wake()
			ball.vel = Vector2(pb[3], 0)
			ball.collides_balls = true
			ball.since_contact = 1.0
		var p0: float = a.mass * a.vel.x + b.mass * b.vel.x
		for i in 6:
			sim.physics.step(MatchSim.DT)
		var p1: float = a.mass * a.vel.x + b.mass * b.vel.x
		report.append("| %s vs %s | %.0f | %.0f | %.0f | %.0f |" % [pair[0], pair[1], a.vel.x, b.vel.x, p0, p1])
		match pair[0]:
			"standard":
				check(a.vel.x < 0.0 and b.vel.x > 0.0, "equal balls bounce apart")
				check(absf(p1 - p0) < 1.0, "momentum is conserved (%.1f -> %.1f)" % [p0, p1])
			"heavy":
				check(a.vel.x > 0.0 and b.vel.x > 600.0, "heavy ball keeps going and launches the light ball")
				check(absf(p1 - p0) < absf(p0) * 0.01, "momentum is conserved with unequal mass (%.0f -> %.0f, air drag only)" % [p0, p1])
			"shield":
				check(a.vel.x > 590.0 and b.vel.x > 600.0, "shielded ball takes no knockback (%.0f px/s after)" % a.vel.x)
	var gs := _sim(_flat(), "practice", 2)
	gs.players[1].ball.place(Vector2(900, -9.5))
	gs.players[1].ball.collides_balls = true
	gs.players[0].ball.place(Vector2(860, -9.5))
	gs.players[0].ball.collides_balls = true
	gs.players[1].ball.shield = 1
	var hits := gs.physics.explode(Vector2(880, -5), 175.0, 1150.0, 0, 0.4)
	check(not hits.has(1), "shielded ball ignores a grenade blast")
	report.append("")
	_section_ok = true


func test_g_activations() -> void:
	print("Test G: mid-flight activation")
	report.append("## Test G: mid-flight activation\n\n45 degrees, power 0.6, Space pressed 0.5 s after the hit.\n")
	report.append("| Ball | First impact | Final distance | Note |\n|---|---|---|---|")
	var std := _fly(_sim(_flat()), "standard", -PI * 0.25, 0.6)
	var brake := _fly(_sim(_flat()), "air_brake", -PI * 0.25, 0.6, 0.0, 0.5)
	var nitro := _fly(_sim(_flat()), "nitro", -PI * 0.25, 0.6, 0.0, 0.5)
	var zig_sim := _sim(_flat())
	var zig := _fly(zig_sim, "zig_zag", -PI * 0.25, 0.6, 0.0, 0.5)
	var zig3 := _fly(_sim(_flat()), "zig_zag", -PI * 0.25, 0.6, 0.0, 0.3, 4)
	var gren := _fly(_sim(_flat()), "grenade", -PI * 0.25, 0.6, 0.0, 0.5)
	check(brake.first_x < std.first_x * 0.7, "air brakes stop the ball short (%.0f vs %.0f)" % [brake.first_x, std.first_x])
	check(brake.first_x - brake.act_dx < 160.0, "air brakes land close to where they were pressed (%.0f px on)" % (brake.first_x - brake.act_dx))
	check(_has_event(brake, "ability"), "air brakes report their activation")
	check(nitro.first_x > std.first_x * 1.15, "nitro carries further (%.0f vs %.0f)" % [nitro.first_x, std.first_x])
	check(zig.vx_after < 0.0 and zig.end_dx < std.end_dx * 0.5, "zig zag reverses horizontal direction")
	var zig_events := 0
	for ev in zig3.events:
		if ev.type == "ability":
			zig_events += 1
	check(zig_events == 3, "zig zag allows exactly three flips (%d)" % zig_events)
	check(_has_event(gren, "explode"), "grenade can be detonated manually")
	var plain := _sim(_flat())
	plain.cmd_shoot(0, -PI * 0.25, 0.6, "standard")
	for i in 30:
		plain.tick()
	check(plain.cmd_activate(0) == "unavailable", "the regular ball has nothing to activate")
	# Magnet: a cup 1300 px out; a short shot is pulled in closer than a regular one.
	var cup_course := _flat("grass", {"cup": {"x": 1300, "y": 0}})
	var std_m := _fly(_sim(cup_course), "standard", -PI * 0.25, 0.42)
	var mag_sim := _sim(cup_course)
	var mag := _fly(mag_sim, "magnet", -PI * 0.25, 0.42)
	var holed := _has_event(mag, "holed")
	check(holed or absf(mag.end.x - 1300.0) < absf(std_m.end.x - 1300.0) - 80.0,
		"magnet ends much nearer the cup (%.0f vs %.0f px away%s)" % [absf(mag.end.x - 1300.0), absf(std_m.end.x - 1300.0), ", holed" if holed else ""])
	var walled := _hole([{"material": "grass", "smooth": false, "points": [[-800, 0], [700, 0], [700, -300], [760, -300], [760, 0], [8200, 0], [8200, 400], [-800, 400]]}], {"cup": {"x": 1300, "y": 0}})
	var mw := _fly(_sim(walled), "magnet", -0.15, 0.3)
	check(mw.end.x < 700.0, "magnet does not pull the ball through a wall")
	for row in [["Regular", std, ""], ["Air Brakes", brake, "drops short, no instant stop"], ["Nitro", nitro, "thrust for 0.22 s"],
			["Zig Zag", zig, "horizontal direction mirrored"], ["Grenade", gren, "detonated in the air"],
			["Magnet (cup at 1300)", mag, "pulled toward the cup"]]:
		var r: Dictionary = row[1]
		report.append("| %s | %s | %.0f | %s |" % [row[0], "%.0f" % r.first_x if r.first_x < INF else "-", r.get("end_dx", 0.0), row[2]])
	report.append("")
	_section_ok = true


func test_h_repeatability() -> void:
	print("Test H: repeatability")
	var ends: Array[Vector2] = []
	for i in 3:
		var r := _fly(_sim(_flat()), "standard", -0.9, 0.73, 0.4)
		ends.append(r.end)
	check(ends[0] == ends[1] and ends[1] == ends[2], "identical shots give identical results (%s)" % ends[0])
	report.append("## Test H: repeatability\n\nThree identical shots (angle -0.9, power 0.73, spin +0.4) all end at %s: the simulation is deterministic.\n" % ends[0])
	_section_ok = true


func test_spin() -> void:
	print("Spin")
	report.append("## Spin on flat grass\n\n45 degrees, power 0.55.\n")
	report.append("| Spin | First impact | Final distance |\n|---|---|---|")
	var res := {}
	for s in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var r := _fly(_sim(_flat()), "standard", -PI * 0.25, 0.55, s)
		res[s] = r
		report.append("| %+.1f | %.0f | %.0f |" % [s, r.first_x, r.end_dx])
	check(absf(res[-1.0].first_x - res[0.0].first_x) < 40.0, "spin barely changes the carry (no fake air force)")
	check(res[-1.0].end_dx < res[0.0].end_dx - 200.0, "backspin checks the ball up short (%.0f vs %.0f)" % [res[-1.0].end_dx, res[0.0].end_dx])
	check(res[-1.0].end_dx - res[-1.0].first_x < 150.0, "full backspin checks the ball up near its landing spot (%.0f px on)" % (res[-1.0].end_dx - res[-1.0].first_x))
	var steep := _fly(_sim(_flat()), "standard", -1.05, 0.7, -1.0)
	check(steep.end_dx < steep.first_x - 100.0, "a steep full-backspin shot spins back (lands %.0f, ends %.0f)" % [steep.first_x, steep.end_dx])
	check(res[1.0].end_dx > res[0.0].end_dx + 200.0, "topspin runs on further (%.0f vs %.0f)" % [res[1.0].end_dx, res[0.0].end_dx])
	check(res[-0.5].end_dx < res[0.0].end_dx and res[0.5].end_dx > res[0.0].end_dx, "spin effect is graded, not on/off")
	# Slip left 0.6 s after a backspin landing: grass grips (slip converted), ice barely does.
	var slips := {}
	for m in ["grass", "ice"]:
		var ss := _sim(_flat(m))
		var sb := ss.players[0].ball
		ss.cmd_shoot(0, -0.5, 0.3, "standard", -1.0)
		var land_t := -1.0
		var t := 0.0
		while t < 5.0:
			ss.tick()
			t += MatchSim.DT
			if land_t < 0.0 and sb.since_contact < 0.02:
				land_t = t
			if land_t >= 0.0 and t - land_t >= 0.6:
				break
		slips[m] = absf(sb.vel.x - sb.ang_vel * sb.radius)
	check(slips.ice > slips.grass * 3.0, "spin grips grass but slides on ice (slip %.0f vs %.0f px/s)" % [slips.ice, slips.grass])
	var sim := _sim(_flat())
	var b := sim.players[0].ball
	sim.cmd_shoot(0, -PI * 0.3, 0.6, "standard")
	for i in 10:
		sim.tick()
	sim.cmd_spin(0, -1)
	var w0 := b.ang_vel
	for i in 20:
		sim.tick()
	sim.cmd_spin(0, 0)
	check(b.ang_vel < w0 - 5.0, "holding backspin in flight winds back spin (%.0f -> %.0f rad/s)" % [w0, b.ang_vel])
	report.append("")
	_section_ok = true


func test_surfaces() -> void:
	print("Surfaces")
	report.append("## Surfaces\n\nSame low shot (power 0.35, 25 degrees) onto each material.\n")
	report.append("| Surface | First impact | Final distance | Bounces |\n|---|---|---|---|")
	var r := {}
	for m in ["grass", "rough", "sand", "snow", "ice", "rock", "wood", "bouncy"]:
		r[m] = _fly(_sim(_flat(m)), "standard", -0.44, 0.35)
		report.append("| %s | %.0f | %.0f | %d |" % [m, r[m].first_x, r[m].end_dx, r[m].bounces])
	check(r.sand.end_dx - r.sand.first_x < 40.0, "sand plugs the ball (rolls %.0f)" % (r.sand.end_dx - r.sand.first_x))
	check(r.ice.end_dx > r.grass.end_dx * 1.5, "ice slides much further than grass")
	check(r.snow.end_dx < r.grass.end_dx and r.snow.end_dx > r.sand.end_dx, "snow is between grass and sand")
	check(absf(r.snow.end_dx - r.ice.end_dx) > 300.0, "snow and ice are different materials")
	check(r.rough.end_dx < r.grass.end_dx, "rough holds more than grass")
	check(r.bouncy.bounces > r.grass.bounces, "bouncy surfaces bounce more")
	report.append("")
	_section_ok = true


func test_gravity_field_and_conveyor() -> void:
	print("Gravity fields and conveyors")
	var low := _flat("grass", {"fields": [{"type": "gravity", "scale": 0.35, "points": [[-800, -2600], [8200, -2600], [8200, 0], [-800, 0]]}]})
	var std := _fly(_sim(_flat()), "standard", -PI * 0.25, 0.4)
	var lg := _fly(_sim(low), "standard", -PI * 0.25, 0.4)
	check(lg.max_h > std.max_h * 2.0 and lg.first_x > std.first_x * 2.0, "a low-gravity field makes the ball float (h %.0f vs %.0f)" % [lg.max_h, std.max_h])
	var flip := _hole([{"material": "grass", "smooth": false, "points": [[-800, 0], [8200, 0], [8200, 400], [-800, 400]]},
		{"material": "rock", "smooth": false, "points": [[-800, -900], [8200, -900], [8200, -1100], [-800, -1100]]}],
		{"fields": [{"type": "gravity", "vector": [0, -1500], "points": [[500, -900], [1600, -900], [1600, -120], [500, -120]]}]})
	var sim := _sim(flip)
	var b := sim.players[0].ball
	b.place(Vector2(1000, -500))
	b.wake()
	b.collides_balls = true
	for i in 600:
		sim.tick()
		if b.at_rest:
			break
	check(b.at_rest and b.pos.y < -880.0, "a ball inside an upward gravity field falls up and rests on the ceiling (y %.0f)" % b.pos.y)
	var zero := _sim(_flat("grass", {"fields": [{"type": "gravity", "scale": 0.0, "points": [[-800, -2600], [8200, -2600], [8200, -200], [-800, -200]]}]}))
	var zb := zero.players[0].ball
	zb.place(Vector2(1000, -800))
	zb.wake()
	zb.vel = Vector2(12, 0)
	zb.collides_balls = true
	var floated := false
	for i in 1200:
		zero.tick()
		if zb.at_rest:
			floated = true
			break
	check(floated and zb.pos.y < -700.0 and zero.can_shoot(0) in ["", "cooldown"], "a ball that stalls in zero gravity floats at rest and can be shot again")
	var belt := _sim(_flat("conveyor_r"))
	var bb := belt.players[0].ball
	bb.wake()
	for i in 120:
		belt.tick()
	check(bb.pos.x > 40.0, "a conveyor carries a ball resting on it (%.0f px)" % bb.pos.x)
	_section_ok = true


func test_modes_and_counting() -> void:
	print("Modes, Free Shot, Mulligan")
	var online := _sim(_flat(), "online")
	online.phase = MatchSim.Phase.PLAYING
	check(online.cmd_shoot(0, -0.8, 0.5, "free_shot") == "mode", "free shot is not available in Blitz")
	var st := _sim(_flat(), "stroke")
	var p := st.players[0]
	_fly(st, "free_shot", -0.8, 0.3)
	check(p.hole_shots == 0, "free shot does not count as a stroke")
	check(int(p.charges.free_shot) == 0, "stroke play free-shot charge is spent")
	_fly(st, "standard", -0.8, 0.3)
	check(p.hole_shots == 1, "the next regular shot counts")
	var start := p.ball.pos
	_fly(st, "mulligan", -0.8, 0.5)
	var moved := p.ball.pos.distance_to(start) > 100.0
	check(st.cmd_activate(0) == "", "mulligan can be used after the ball stops")
	check(moved and p.ball.pos.distance_to(start) < 2.0, "mulligan returns the ball to where the shot was taken")
	check(p.hole_shots == 1, "stroke play mulligan refunds the stroke")
	for i in 20:
		st.tick()
	check(st.can_shoot(0) == "", "player can shoot right after a mulligan")
	var on2 := _sim(_flat(), "practice", 2)
	on2.players[1].ball.place(Vector2(600, -9.5))
	var other := on2.players[1].ball.pos
	_fly(on2, "mulligan", -0.8, 0.5)
	on2.cmd_activate(0)
	check(on2.players[1].ball.pos == other, "mulligan never moves anyone else's ball")
	var clean := MatchSim.new(balance, materials, _flat(), "stroke", 1)
	clean.clean_ball = true
	clean.add_player("p", "P", {})
	clean.start_stroke(0)
	while clean.phase != MatchSim.Phase.PLAYING:
		clean.tick()
	check(clean.cmd_shoot(0, -0.8, 0.5, "nitro") == "no_charges", "clean ball challenge allows no abilities")
	_section_ok = true


func test_six_players() -> void:
	print("Six players")
	var course := _flat("grass", {"cup": {"x": 2000, "y": 0}})
	var sim := MatchSim.new(balance, materials, course, "online", 3)
	for i in 6:
		sim.add_player("p%d" % i, "P%d" % i, {})
	check(sim.target_points == 15, "six-player match plays to 15")
	check(_ints(sim.points_table()) == [5, 4, 3, 2, 1, 0], "six-player points 5-4-3-2-1-0")
	sim.start()
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	var xs := {}
	for p in sim.players:
		xs[snappedf(p.ball.pos.x, 0.1)] = true
	check(xs.size() == 6, "six distinct tee spots")
	var min_gap := INF
	for i in 6:
		for j in range(i + 1, 6):
			min_gap = minf(min_gap, sim.players[i].ball.pos.distance_to(sim.players[j].ball.pos))
	check(min_gap >= 18.0, "tee spots do not overlap (%.1f px)" % min_gap)
	for p in sim.players:
		check(sim.cmd_shoot(p.slot, -PI * 0.25 - p.slot * 0.03, 0.5, "standard") == "", "player %d can shoot" % p.slot)
	for i in 600:
		sim.tick()
	var moving := 0
	for p in sim.players:
		if p.ball.pos.x > 300.0:
			moving += 1
	check(moving == 6, "all six balls are simulated")
	var five := MatchSim.new(balance, materials, course, "online", 3)
	for i in 5:
		five.add_player("p%d" % i, "P%d" % i, {})
	check(_ints(five.points_table()) == [4, 3, 2, 1, 0] and five.target_points == 12, "five-player points 4-3-2-1-0 to 12")
	_section_ok = true


func _ints(a: Array) -> Array:
	return a.map(func(v: Variant) -> int: return int(v))


func test_launch_curve() -> void:
	print("Launch power curve")
	report.append("## Launch power curve\n\nCarry on flat grass at 45 degrees (first impact).\n")
	report.append("| Power | Launch speed | Carry |\n|---|---|---|")
	var carries: Array[float] = []
	for pw in [0.1, 0.25, 0.5, 0.75, 1.0]:
		var r := _fly(_sim(_flat()), "standard", -PI * 0.25, pw)
		carries.append(r.first_x)
		report.append("| %d%% | %.0f | %.0f |" % [int(pw * 100), MatchSim.launch_speed(balance, pw), r.first_x])
	var increasing := true
	for i in range(1, carries.size()):
		if carries[i] <= carries[i - 1]:
			increasing = false
	check(increasing, "more power always carries further")
	check(carries[2] / carries[4] > 0.38 and carries[2] / carries[4] < 0.6, "half power carries roughly half as far (%.2f)" % (carries[2] / carries[4]))
	report.append("")
	_section_ok = true


func test_unlocks() -> void:
	print("Unlocks")
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/unlocks.json")).abilities
	var main := ["golf_land", "beach_land", "sticky_zone", "snow_field", "gravity_lab", "spin_land"]
	var all_ok := true
	for a: Dictionary in balance.abilities:
		var c: Dictionary = table.get(str(a.id), {})
		var reachable := c.has("level") or (c.has("course") and str(c.course) in main) or c.has("achievement")
		if c.has("course") and not str(c.course) in main:
			reachable = false
		if not reachable:
			all_ok = false
			print("    no route for ", a.id)
	check(all_ok, "every ball has an achievable unlock route within the six courses")
	check(Array(Unlocks.for_level(1)) == ["standard", "nitro"], "level 1 starts with Regular and Nitro")
	check(Unlocks.for_level(13).size() == balance.abilities.size(), "level 13 unlocks every ball")
	var local := Unlocks.for_local(1, {"courses": {"golf_land": {"completed": true}}, "totals": {"holes_in_one": 1}})
	check(local.has("sticky") and local.has("air_brake") and local.has("free_shot") and not local.has("laser"),
		"solo progress: completing Golf Land unlocks Sticky + Air Brakes, a hole-in-one unlocks Free Shot")
	var sim := _sim(_flat(), "online", 2)
	sim.phase = MatchSim.Phase.PLAYING
	sim.set_allowed(sim.players[0], Unlocks.for_level(1))
	check(sim.cmd_shoot(0, -0.8, 0.5, "laser") == "not_owned", "the server rejects a locked ball")
	check(sim.cmd_shoot(1, -0.8, 0.5, "laser") == "", "another player with it unlocked may use it")
	_section_ok = true


func test_collection_catalog() -> void:
	print("Collection catalog")
	var client: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var server: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backend/data/catalog.json")))
	check(client != null and client == server, "client offline catalog is identical to the backend catalog")
	var missing: PackedStringArray = []
	for it: Dictionary in (client as Dictionary).get("items", []):
		if str(it.kind) == "character" and not InkLook.has_outfit(str(it.value)):
			missing.append(str(it.value))
	check(missing.is_empty(), "every catalog golfer is a themed ink outfit %s" % str(missing))
	_section_ok = true


func _write_report() -> void:
	var head := "# Ball Physics Lab Results\n\nGenerated by `client/tests/test_abilities.gd` from the current `data/balance.json` and\n`data/materials.json`. These are this game's tuned values measured in its own simulation; they are\nnot measurements of Super Stickman Golf 3 (see docs/PHYSICS_SPEC.md, Reference).\n\nDistances and heights in world px (a golfer is about 85 px tall); speeds in px/s.\n\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/physics"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://../docs/physics/lab_results.md"), FileAccess.WRITE)
	if f:
		f.store_string(head + "\n".join(report) + "\n")
