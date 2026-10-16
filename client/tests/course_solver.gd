class_name CourseSolver
extends RefCounted
## Hole-design solver bot shared by test_playable.gd and course_report.gd. It plays the standard
## ball (no spin, no abilities) using the authoritative physics predictor:
## - brute force over angles and powers, picking the landing nearest the cup;
## - landings near spots it has already shot from cost extra, so it explores out of dead ends
##   (a greedy bot otherwise taps forever at the foot of a wall that a person would play around).
## A hole the bot finishes is completable with the plain ball; par is set by design, not by the bot.

var balance: Dictionary
var materials: Dictionary
var visited: Array[Vector2] = []


func _init(p_balance: Dictionary, p_materials: Dictionary) -> void:
	balance = p_balance
	materials = p_materials


func solve(terrain: SimTerrain, from: Vector2) -> Vector2:
	visited.append(from)
	var cup := terrain.cup_pos
	var best := Vector2(-PI * 0.25, 0.5)
	var best_d := INF
	var r := float(balance.physics.ball_radius)
	for side in [1.0, -1.0]:
		for ai in 13:
			var elev := lerpf(0.04, 1.52, float(ai) / 12.0)
			var angle := -elev if side > 0.0 else -PI + elev
			for pi in 11:
				var power := lerpf(0.04, 1.0, float(pi) / 10.0)
				var vel := Vector2.from_angle(angle) * MatchSim.launch_speed(balance, power)
				var res := SimPhysics.predict(terrain, balance.physics, materials, from, vel, r, 1.0, 12.0, 12.0, 8,
					MatchSim.launch_spin(balance, vel, 0.0, r))
				var pts: PackedVector2Array = res.points
				var end := pts[pts.size() - 1]
				if res.hazard or terrain.zone_at(end) != "":
					continue
				var d := end.distance_to(cup) + absf(end.y - cup.y) * 0.15
				if terrain.cup_captures(end, r, 0.0) or end.distance_to(Vector2(cup.x, terrain.cup_floor_y)) < 20.0:
					d = 0.0
				else:
					for v in visited:
						if end.distance_to(v) < 70.0:
							d += 900.0
				if d < best_d:
					best_d = d
					best = Vector2(angle, power)
	return best
