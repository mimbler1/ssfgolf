extends SceneTree
## Proves a hole can be finished without touching one material (e.g. Sticky Zone hole 7 without
## goo, the SSG3 "complete hole 7 without hitting a sticky wall" route). Every edge of that
## material is wrapped in a thin acid strip (the band where a touching ball's centre would be), so
## touching it is a hazard; the solver bot must still hole out, and the ball must never stick.
##   godot --headless --path client --script res://tests/no_touch_check.gd -- --course sticky_zone --hole 6 --material sticky

var balance: Dictionary
var materials: Dictionary


func _initialize() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	materials = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")).materials
	var args := OS.get_cmdline_user_args()
	var cid := args[args.find("--course") + 1]
	var hi := int(args[args.find("--hole") + 1])
	var mat := args[args.find("--material") + 1]
	var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/courses/%s.json" % cid))
	var hole: Dictionary = course.holes[hi]
	var t := SimTerrain.new()
	t.build(hole.duplicate(true))
	var midx := t.material_names.find(mat)
	var strips := 0
	var r := float(balance.physics.ball_radius)
	for i in t.seg_a.size():
		if t.seg_mat[i] != midx:
			continue
		var a := t.seg_a[i]
		var b := t.seg_b[i]
		var n := t.seg_n[i]
		var d := (b - a).normalized()
		# Band from the surface out to just past a touching ball's centre, a little longer than the edge.
		var pts := [a - d * 4.0, b + d * 4.0, b + d * 4.0 + n * (r + 2.0), a - d * 4.0 + n * (r + 2.0)]
		var arr: Array = []
		for p: Vector2 in pts:
			arr.append([p.x, p.y])
		(hole.zones as Array).append({"type": "acid", "points": arr})
		strips += 1
	var sim := MatchSim.new(balance, materials, course, "practice", 1)
	sim.add_player("p", "P", {})
	sim.start_practice_hole(hi)
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	var ball := sim.players[0].ball
	var solver := CourseSolver.new(balance, materials)
	var shots := 0
	var holed := false
	var touched := 0
	var guard := 0
	while shots < 30 and not holed and guard < 60 * 400:
		guard += 1
		if sim.can_shoot(0) == "" and (ball.at_rest or ball.stuck or ball.vel.length() < 12.0):
			var best := solver.solve(sim.terrain, ball.pos)
			sim.cmd_shoot(0, best.x, best.y, "standard")
			shots += 1
		sim.tick()
		if ball.stuck:
			touched += 1
		for ev in sim.take_events():
			if ev.type == "holed":
				holed = true
			elif ev.type == "hazard":
				touched += 1
	var ok := holed and touched == 0
	print("%s hole %d without touching %s (%d edges guarded): %s in %d shots, %d touches" % [cid, hi + 1, mat, strips,
		"PASS" if ok else "FAIL", shots, touched])
	quit(0 if ok else 1)
