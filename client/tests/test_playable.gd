extends SceneTree
## Hole-design sanity check: a solver bot must finish every hole. Slower than test_sim.
##   tools/godot.sh --headless --script res://tests/test_playable.gd [-- --course id]

var balance: Dictionary
var materials: Dictionary
var failures := 0
var passes := 0


func _initialize() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	materials = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")).materials
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.find("--course") != -1:
		only = args[args.find("--course") + 1]
	for f in DirAccess.open("res://data/courses").get_files():
		if f.ends_with(".json") and (only == "" or f.begins_with(only)):
			test_course_playable("res://data/courses/" + f)
	print("
%d passed, %d failed" % [passes, failures])
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


## A simple solver bot must be able to finish every hole (sanity check for hole design).
func test_course_playable(path: String) -> void:
	var course := _json(path)
	print("test_course_playable ", course.id)
	var summary: PackedStringArray = []
	for i in course.holes.size():
		var sim := MatchSim.new(balance, materials, course.duplicate(true), "practice", 1)
		sim.add_player("p", "P", {})
		sim.start_practice_hole(i)
		while sim.phase != MatchSim.Phase.PLAYING:
			sim.tick()
		var b := sim.players[0].ball
		var shots := 0
		var holed := false
		var guard := 0
		while shots < 30 and not holed and guard < 60 * 400:
			guard += 1
			# Wait for the ball to settle so the bot doesn't interrupt its own roll.
			if sim.can_shoot(0) == "" and (b.at_rest or b.stuck or b.vel.length() < 12.0):
				var best := _solve_shot(sim.terrain, b.pos)
				if OS.get_cmdline_user_args().has("--verbose"):
					print("    shot %d from %s angle %.2f power %.2f" % [shots + 1, b.pos, best.x, best.y])
				sim.cmd_shoot(0, best.x, best.y, "standard")
				shots += 1
			sim.tick()
			for ev in sim.take_events():
				if ev.type == "holed":
					holed = true
		summary.append("%s=%s" % [course.holes[i].id, str(shots) if holed else "FAIL"])
		check(holed, "%s playable by solver in %d shots" % [course.holes[i].id, shots])
	print("  shots: ", ", ".join(summary))


func _solve_shot(terrain: SimTerrain, from: Vector2) -> Vector2:
	var cup := terrain.cup_pos
	var best := Vector2(-PI * 0.25, 0.5)
	var best_d := INF
	for side in [1.0, -1.0]:
		for ai in 11:
			var elev := lerpf(0.04, 1.5, float(ai) / 10.0)
			var angle := -elev if side > 0.0 else -PI + elev
			for pi in 9:
				var power := lerpf(0.05, 1.0, float(pi) / 8.0)
				var speed := lerpf(float(balance.shot.min_speed), float(balance.shot.max_speed), power)
				var res := SimPhysics.predict(terrain, balance.physics, materials, from, Vector2.from_angle(angle) * speed, float(balance.physics.ball_radius), 1.0, 12.0, 12.0, 8)
				var pts: PackedVector2Array = res.points
				var end := pts[pts.size() - 1]
				if res.hazard or terrain.zone_at(end) != "":
					continue
				var d := end.distance_to(cup)
				if terrain.cup_captures(end, 9.0, 0.0) or end.distance_to(Vector2(cup.x, terrain.cup_floor_y)) < 20.0:
					d = 0.0
				if d < best_d:
					best_d = d
					best = Vector2(angle, power)
	return best
