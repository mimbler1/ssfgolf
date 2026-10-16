extends SceneTree
## Course design report: for each hole, the solver bot plays it with the shared physics and the
## exact simulated geometry plus every shot's path are written to JSON for review maps
## (tools/courses/preview.py). Also used by test_playable for pass/fail.
##   godot --headless --path client --script res://tests/course_report.gd -- --course <id> --out <file.json>

var balance: Dictionary
var materials: Dictionary


func _initialize() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	materials = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")).materials
	var args := OS.get_cmdline_user_args()
	var cid := args[args.find("--course") + 1]
	var out := args[args.find("--out") + 1]
	var only := int(args[args.find("--hole") + 1]) if args.has("--hole") else -1
	var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/courses/%s.json" % cid))
	var report := {"course": cid, "holes": []}
	for i in course.holes.size():
		if only >= 0 and i != only:
			continue
		report.holes.append(_play(course, i))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	quit()


func _play(course: Dictionary, i: int) -> Dictionary:
	var sim := MatchSim.new(balance, materials, course.duplicate(true), "practice", 1)
	sim.add_player("p", "P", {})
	sim.start_practice_hole(i)
	while sim.phase != MatchSim.Phase.PLAYING:
		sim.tick()
	var t := sim.terrain
	var polys: Array = []
	for poly in t.polygons:
		var pts: Array = []
		for v: Vector2 in poly.points:
			pts.append([v.x, v.y])
		var mats: Array = []
		for m in poly.edge_mats:
			mats.append(t.material_names[m])
		polys.append({"points": pts, "mats": mats})
	var zones: Array = []
	for z in t.zones:
		var zp: Array = []
		for v: Vector2 in z.points:
			zp.append([v.x, v.y])
		zones.append({"type": z.type, "points": zp})
	var fields: Array = []
	for fd in t.fields:
		var fp: Array = []
		for v: Vector2 in fd.points:
			fp.append([v.x, v.y])
		fields.append({"points": fp, "scale": fd.scale, "has_vector": fd.has_vector, "vector": [fd.vector.x, fd.vector.y]})
	var b := sim.players[0].ball
	var solver := CourseSolver.new(balance, materials)
	var shots: Array = []
	var holed := false
	var guard := 0
	var path: Array = []
	while shots.size() < 30 and not holed and guard < 60 * 400:
		guard += 1
		if sim.can_shoot(0) == "" and (b.at_rest or b.stuck or b.vel.length() < 12.0):
			if not path.is_empty():
				shots[shots.size() - 1].path = path
			path = []
			var best := solver.solve(sim.terrain, b.pos)
			shots.append({"from": [b.pos.x, b.pos.y], "angle": best.x, "power": best.y, "path": []})
			sim.cmd_shoot(0, best.x, best.y, "standard")
		sim.tick()
		if guard % 3 == 0:
			path.append([b.pos.x, b.pos.y])
		for ev in sim.take_events():
			if ev.type == "holed":
				holed = true
			elif ev.type == "hazard":
				path.append(["hazard", b.pos.x, b.pos.y])
	if not shots.is_empty():
		shots[shots.size() - 1].path = path
	var hole: Dictionary = course.holes[i]
	return {"id": hole.id, "name": hole.get("name", ""), "par": hole.get("par", 0), "bounds": [t.bounds.position.x, t.bounds.position.y, t.bounds.size.x, t.bounds.size.y],
		"tee": [t.tee.x, t.tee.y], "cup": [t.cup_pos.x, t.cup_pos.y], "has_cup": t.has_cup,
		"polygons": polys, "zones": zones, "fields": fields, "shots": shots, "holed": holed, "strokes": shots.size()}
