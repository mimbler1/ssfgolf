extends SceneTree
## Headless simulation tests. Run:
##   tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path client --script res://tests/test_sim.gd

var balance: Dictionary
var materials: Dictionary
var failures := 0
var passes := 0


func _initialize() -> void:
	balance = _json("res://data/balance.json")
	materials = _json("res://data/materials.json").materials
	var courses := ["res://data/courses/sunny_meadows.json"]
	var dir := DirAccess.open("res://data/courses")
	if dir:
		courses.clear()
		for f in dir.get_files():
			if f.ends_with(".json"):
				courses.append("res://data/courses/" + f)

	test_rest_on_flat()
	test_no_tunnel_max_power()
	test_cup_capture()
	test_cooldown_and_energy_validation()
	test_grenade_pushes_other_ball()
	test_sticky_wall()
	test_ball_collision_momentum()
	test_scoring_and_match_end()
	test_disconnect_forfeit()
	for path in courses:
		test_course_holes_valid(path)
		test_course_random_shots(path)

	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func _course() -> Dictionary:
	return _json("res://data/courses/sunny_meadows.json")


func _flat_course() -> Dictionary:
	return {
		"id": "test_flat", "name": "Flat", "holes": [{
			"id": "flat", "bounds": {"x": -500, "y": -2000, "w": 4000, "h": 2600},
			"tee": {"x": 0, "y": 0}, "cup": {"x": 1500, "y": 0},
			"terrain": [{"material": "grass", "smooth": false, "points": [
				[-500, -1500], [-400, -1500], [-400, 0], [3400, 0], [3400, -1500], [3500, -1500], [3500, 400], [-500, 400]]}],
			"zones": [{"type": "water", "points": [[2200, -5], [2400, -5], [2400, 0], [2200, 0]]}]
		}]
	}


func _practice(course: Dictionary, n_players: int = 1, mode: String = "practice") -> MatchSim:
	var sim := MatchSim.new(balance, materials, course, mode, 1)
	for i in n_players:
		sim.add_player("p%d" % i, "P%d" % i, {})
	if mode == "practice":
		sim.start_practice_hole(0)
	else:
		sim.start()
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	return sim


func _run(sim: MatchSim, ticks: int) -> void:
	for i in ticks:
		sim.tick()


func test_rest_on_flat() -> void:
	print("test_rest_on_flat")
	var sim := _practice(_flat_course())
	var b := sim.players[0].ball
	check(sim.cmd_shoot(0, -PI * 0.25, 0.5, "standard") == "", "shot accepted")
	var rested_at := -1
	for i in 900:
		sim.tick()
		if b.at_rest:
			rested_at = i
			break
	check(rested_at > 0, "ball comes to rest (tick %d, x=%.1f)" % [rested_at, b.pos.x])
	check(absf(b.pos.y - (-b.radius)) < 2.0, "ball rests on surface (y=%.2f)" % b.pos.y)
	check(b.pos.x > 300.0, "ball travelled forward")


func test_no_tunnel_max_power() -> void:
	print("test_no_tunnel_max_power")
	var sim := _practice(_flat_course())
	var b := sim.players[0].ball
	# Lift the ball and fire straight down at max power.
	b.pos = Vector2(100, -400)
	check(sim.cmd_shoot(0, PI * 0.5, 1.0, "standard") == "", "shot accepted")
	var min_y := INF
	var max_y := -INF
	for i in 400:
		sim.tick()
		max_y = maxf(max_y, b.pos.y)
	check(max_y <= 0.5, "never penetrated ground (max y=%.2f)" % max_y)
	check(not sim.terrain.is_point_solid(b.pos), "not inside terrain")


func test_cup_capture() -> void:
	print("test_cup_capture")
	var sim := _practice(_flat_course())
	var b := sim.players[0].ball
	b.place(Vector2(1380, -b.radius))
	check(sim.cmd_shoot(0, -0.05, 0.08, "standard") == "", "putt accepted")
	var holed := false
	for i in 600:
		sim.tick()
		for ev in sim.take_events():
			if ev.type == "holed":
				holed = true
		if holed:
			break
	check(holed, "ball rolled into cup")


func test_cooldown_and_energy_validation() -> void:
	print("test_cooldown_and_energy_validation")
	var sim := _practice(_flat_course())
	check(sim.cmd_shoot(0, -0.6, 0.3, "standard") == "", "first shot ok")
	check(sim.cmd_shoot(0, -0.6, 0.3, "standard") == "cooldown", "second shot rejected by cooldown")
	sim.players[0].energy = 0.5
	_run(sim, 400)
	sim.players[0].energy = 1.0
	sim.players[0].cooldown = 0.0
	check(sim.cmd_shoot(0, -0.6, 0.3, "grenade") == "energy", "grenade rejected without energy")
	check(sim.cmd_shoot(0, -0.6, 0.3, "made_up") == "unknown_ability", "unknown ability rejected")
	check(sim.cmd_shoot(0, NAN, 0.3, "standard") == "bad_input", "NaN rejected")
	check(sim.cmd_activate(0) == "unavailable", "activate without ability rejected")


func test_grenade_pushes_other_ball() -> void:
	print("test_grenade_pushes_other_ball")
	var sim := _practice(_flat_course(), 2)
	var a := sim.players[0].ball
	var other := sim.players[1].ball
	other.place(Vector2(400, -other.radius))
	other.collides_balls = true
	a.place(Vector2(200, -a.radius))
	sim.players[0].energy = 10.0
	check(sim.cmd_shoot(0, -0.35, 0.35, "grenade") == "", "grenade shot ok")
	var exploded := false
	for i in 300:
		sim.tick()
		for ev in sim.take_events():
			if ev.type == "explode":
				exploded = true
		if exploded:
			break
	check(exploded, "grenade exploded on impact")
	var before := other.pos
	_run(sim, 10)
	check(other.pos.distance_to(before) > 1.0 or other.vel.length() > 50.0 or not exploded, "other ball displaced or unaffected only if far (moved %.1f)" % other.pos.distance_to(before))


func test_sticky_wall() -> void:
	print("test_sticky_wall")
	var sim := _practice(_flat_course())
	var b := sim.players[0].ball
	b.place(Vector2(3200, -b.radius))
	sim.players[0].energy = 10.0
	check(sim.cmd_shoot(0, -0.6, 0.45, "sticky") == "", "sticky shot ok")
	var stuck := false
	for i in 300:
		sim.tick()
		if b.stuck:
			stuck = true
			break
	check(stuck, "ball stuck to wall")
	var p := b.pos
	_run(sim, 60)
	check(b.pos.distance_to(p) < 0.01, "stays glued")
	check(sim.can_shoot(0) == "" or sim.can_shoot(0) == "cooldown", "can shoot from wall")


func test_ball_collision_momentum() -> void:
	print("test_ball_collision_momentum")
	var sim := _practice(_flat_course(), 2)
	var a := sim.players[0].ball
	var c := sim.players[1].ball
	a.place(Vector2(300, -a.radius))
	c.place(Vector2(360, -c.radius))
	c.collides_balls = true
	check(sim.cmd_shoot(0, 0.0, 0.4, "standard") == "", "shot ok")
	_run(sim, 60)
	check(c.pos.x > 380.0, "struck ball moved forward (x=%.1f)" % c.pos.x)


func test_scoring_and_match_end() -> void:
	print("test_scoring_and_match_end")
	var course := _flat_course()
	var sim := MatchSim.new(balance, materials, course, "online", 7)
	for i in 4:
		sim.add_player("p%d" % i, "P%d" % i, {})
	sim.start()
	var guard := 0
	var holes_done := 0
	while sim.phase != MatchSim.Phase.MATCH_OVER and guard < 200000:
		guard += 1
		if sim.phase == MatchSim.Phase.PLAYING:
			# Teleport finishers in a fixed order: p0 first, p1 second, p2 third; p3 never.
			for s in 3:
				var p := sim.players[s]
				if not p.finished and sim.hole_time > 0.5 + s * 0.5:
					p.ball.pos = Vector2(sim.terrain.cup_pos.x, sim.terrain.cup_floor_y - p.ball.radius - 1)
		sim.tick()
		for ev in sim.take_events():
			if ev.type == "hole_end":
				holes_done += 1
	check(sim.phase == MatchSim.Phase.MATCH_OVER, "match ended")
	var st := sim.standings()
	check(st[0].playerId == "p0" and st[0].points >= 9, "p0 wins with %d points" % st[0].points)
	check(holes_done == 3, "three holes to reach 9 points (got %d)" % holes_done)
	check(st[1].points == 6 and st[2].points == 3 and st[3].points == 0, "points 9/6/3/0")
	check(sim.players[3].holes_played == 3, "unfinished player still counts holes played")


func test_disconnect_forfeit() -> void:
	print("test_disconnect_forfeit")
	var sim := MatchSim.new(balance, materials, _flat_course(), "online", 3)
	sim.add_player("a", "A", {})
	sim.add_player("b", "B", {})
	sim.start()
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	sim.set_connected(1, false)
	var guard := 0
	while sim.phase != MatchSim.Phase.MATCH_OVER and guard < 60 * 200:
		guard += 1
		sim.tick()
	check(sim.phase == MatchSim.Phase.MATCH_OVER, "match ends after forfeit")
	var st := sim.standings()
	check(st[0].playerId == "a" and st[1].disconnected, "connected player wins, disconnected last")


func test_course_holes_valid(path: String) -> void:
	var course := _json(path)
	print("test_course_holes_valid ", course.id)
	for i in course.holes.size():
		var t := SimTerrain.new()
		t.build(course.holes[i])
		var hid: String = course.holes[i].id
		check(t.has_cup, "%s has cup" % hid)
		var hit := t.surface_below(t.tee + Vector2(0, -200), 1200)
		check(hit.hit, "%s tee has ground" % hid)
		check(not t.is_point_solid(t.cup_pos + Vector2(0, -20)), "%s cup mouth open" % hid)
		check(t.cup_floor_y - t.cup_pos.y > 20.0, "%s cup has depth" % hid)


func test_course_random_shots(path: String) -> void:
	var course := _json(path)
	print("test_course_random_shots ", course.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in course.holes.size():
		var c := course.duplicate(true)
		var sim := MatchSim.new(balance, materials, c, "practice", 1)
		sim.add_player("p", "P", {})
		sim.start_practice_hole(i)
		while sim.phase != MatchSim.Phase.PLAYING:
			sim.tick()
		var b := sim.players[0].ball
		var bad := 0
		var shots := 0
		for s in 40:
			var wait := 0
			while sim.can_shoot(0) != "" and sim.phase == MatchSim.Phase.PLAYING and wait < 60 * 30:
				wait += 1
				sim.tick()
				if sim.terrain.is_point_solid(b.pos) and b.active:
					bad += 1
			if sim.phase != MatchSim.Phase.PLAYING:
				break
			if wait >= 60 * 30:
				bad += 1000
				print("    ball never became shootable at ", b.pos, " ", sim.can_shoot(0))
				break
			sim.players[0].energy = 10.0
			var abilities := ["standard", "standard", "heavy", "sticky", "nitro", "air_brake", "grenade"]
			sim.cmd_shoot(0, rng.randf_range(-PI * 0.95, -PI * 0.05), rng.randf_range(0.1, 1.0), abilities[s % abilities.size()])
			shots += 1
		check(bad == 0, "%s: %d shots, never inside terrain (bad ticks %d)" % [course.holes[i].id, shots, bad])

