extends SceneTree
## Fine sweep of tee shots (plain ball, no spin) that hole in one. Used to verify signature holes
## that must be aceable (e.g. Beach Land hole 4, Snow Field hole 4) and to measure how narrow the
## window is. Prints every hit as angle (degrees above horizontal) and power.
##   godot --headless --path client --script res://tests/ace_search.gd -- --course beach_land --hole 3
##       [--elev0 5 --elev1 80 --estep 0.25 --p0 0.3 --p1 1.0 --pstep 0.005] [--left]

var balance: Dictionary
var materials: Dictionary


func _arg(args: PackedStringArray, key: String, fallback: float) -> float:
	var i := args.find(key)
	return float(args[i + 1]) if i != -1 and i + 1 < args.size() else fallback


func _initialize() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	materials = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")).materials
	var args := OS.get_cmdline_user_args()
	var cid := args[args.find("--course") + 1]
	var hi := int(_arg(args, "--hole", 0))
	var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/courses/%s.json" % cid))
	var sim := MatchSim.new(balance, materials, course, "practice", 1)
	sim.add_player("p", "P", {})
	sim.start_practice_hole(hi)
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	var terrain := sim.terrain
	var from := sim.players[0].ball.pos
	var r := float(balance.physics.ball_radius)
	var cup := terrain.cup_pos
	var side := -1.0 if args.has("--left") else 1.0
	var e0 := _arg(args, "--elev0", 5.0)
	var e1 := _arg(args, "--elev1", 80.0)
	var es := _arg(args, "--estep", 0.25)
	var p0 := _arg(args, "--p0", 0.3)
	var p1 := _arg(args, "--p1", 1.0)
	var ps := _arg(args, "--pstep", 0.005)
	var hits := 0
	var total := 0
	var elev := e0
	while elev <= e1 + 0.0001:
		var ang := -deg_to_rad(elev) if side > 0.0 else -PI + deg_to_rad(elev)
		var pw := p0
		while pw <= p1 + 0.0001:
			total += 1
			var vel := Vector2.from_angle(ang) * MatchSim.launch_speed(balance, pw)
			var res := SimPhysics.predict(terrain, balance.physics, materials, from, vel, r, 1.0, 14.0, 14.0, 8,
				MatchSim.launch_spin(balance, vel, 0.0, r))
			var pts: PackedVector2Array = res.points
			var end := pts[pts.size() - 1]
			if not res.hazard and (terrain.cup_captures(end, r, 0.0) or end.distance_to(Vector2(cup.x, terrain.cup_floor_y)) < 20.0):
				hits += 1
				print("  ACE elev %.2f power %.3f" % [elev, pw])
			pw += ps
		elev += es
	print("%s hole %d: %d aces out of %d shots (%.3f%%)" % [cid, hi + 1, hits, total, 100.0 * hits / maxf(1.0, total)])
	quit()
