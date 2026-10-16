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
		var solver := CourseSolver.new(balance, materials)
		var shots := 0
		var holed := false
		var guard := 0
		while shots < 30 and not holed and guard < 60 * 400:
			guard += 1
			# Wait for the ball to settle so the bot doesn't interrupt its own roll.
			if sim.can_shoot(0) == "" and (b.at_rest or b.stuck or b.vel.length() < 12.0):
				var best := solver.solve(sim.terrain, b.pos)
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
