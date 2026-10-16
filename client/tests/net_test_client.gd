extends Node
## Headless network test client (developer/testing tool, never shown to players).
## Connects to a dedicated server, auto-plays by searching shots with the shared
## physics predictor, and exits with a summary when the match ends.
##   godot --headless res://tests/net_test_client.tscn -- --connect 127.0.0.1:7777 --dev-name Bot1 [--token TOKEN] [--quit-after S]

var view: NetMatchView
var _next_think := 0.0
var _t := 0.0
var _shots := 0
var _events := {}
var _quit_after := 240.0
var _name := "Bot"
var _leave_at := -1.0
var _emote_at := -1.0
## --abilities: pick random affordable balls and trigger them mid-flight (sync / collision soak).
var _use_abilities := false
var _activate_at := -1.0
var _abilities_fired := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var hp := _arg(args, "--connect", "127.0.0.1:7777").split(":")
	_name = _arg(args, "--dev-name", "Bot")
	var token := _arg(args, "--token", "dev:" + _name)
	_quit_after = float(_arg(args, "--quit-after", "240"))
	_leave_at = float(_arg(args, "--leave-after", "-1"))
	_use_abilities = args.has("--abilities")
	view = NetMatchView.new()
	add_child(view)
	view.welcomed.connect(func() -> void:
		var chars: PackedStringArray = []
		for r: Dictionary in view.roster:
			chars.append("%d=%s" % [int(r.slot), str(Appearance.normalize(r.appearance).character)])
		print("[%s] welcomed as slot %d, %d players, characters %s" % [_name, view.local_slot, view.roster.size(), ",".join(chars)])
		_emote_at = _t + 2.0)
	view.connection_lost.connect(func(r: String) -> void:
		print("[%s] connection lost: %s" % [_name, r])
		_finish(3))
	view.game_event.connect(_on_event)
	view.connect_to(hp[0], int(hp[1]), token, _arg(args, "--match", "dev"))


static func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i != -1 and i + 1 < args.size() else fallback


func _on_event(ev: Dictionary) -> void:
	var t := str(ev.type)
	_events[t] = int(_events.get(t, 0)) + 1
	match t:
		"hole_start":
			print("[%s] hole_start #%d (index %d)" % [_name, int(ev.hole_number) + 1, int(ev.hole_index)])
		"holed":
			print("[%s] slot %d holed, place %d" % [_name, int(ev.slot), int(ev.place)])
		"hole_end":
			var parts: PackedStringArray = []
			for r: Dictionary in ev.results:
				parts.append("s%d:+%d=%d" % [int(r.slot), int(r.gained), int(r.total)])
			print("[%s] hole_end %s" % [_name, " ".join(parts)])
		"match_end":
			print("[%s] MATCH_END reason=%s standings=%s shots=%d abilities=%d events=%s rtt=%.1fms" % [_name, ev.reason, JSON.stringify(ev.standings), _shots, _abilities_fired, JSON.stringify(_events), view.rtt_ms])
			_finish(0)
		"rejected":
			print("[%s] command rejected: %s" % [_name, ev.error])
		"emote":
			print("[%s] EMOTE slot %d id %d" % [_name, int(ev.slot), int(ev.emote)])


func _finish(code: int) -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(code)


func _process(delta: float) -> void:
	_t += delta
	if _t > _quit_after:
		print("[%s] TIMEOUT after %.0fs events=%s" % [_name, _t, JSON.stringify(_events)])
		get_tree().quit(4)
		return
	if _leave_at > 0.0 and _t > _leave_at:
		print("[%s] leaving deliberately" % _name)
		view.leave()
		_leave_at = -1.0
		_finish(0)
		return
	if _emote_at > 0.0 and _t > _emote_at:
		# Highest emote id: checks the server accepts the full catalogue, not just the first four.
		view.emote(Emotes.count() - 1)
		_emote_at = -1.0
	if _activate_at > 0.0 and _t > _activate_at:
		_activate_at = -1.0
		if view.ball_state(view.local_slot).get("manual", false):
			view.activate()
	if view.terrain == null or _t < _next_think:
		return
	if view.local_shot_block() != "":
		return
	_next_think = _t + randf_range(0.2, 0.6)
	var s := view.ball_state(view.local_slot)
	if s.is_empty() or not s.active:
		return
	var best := _search(s.pos)
	var ability := "standard"
	if _use_abilities and randf() < 0.55:
		var energy := float(view.player_state(view.local_slot).get("energy", 0.0))
		var options: Array[String] = []
		for a: Dictionary in GameData.abilities:
			if view.allowed_abilities.has(a.id) and str(a.id) != "standard" and float(a.cost) <= energy:
				options.append(str(a.id))
		if not options.is_empty():
			ability = options[randi() % options.size()]
			_abilities_fired += 1
			if str(GameData.ability(ability).get("activation", "none")) != "none":
				_activate_at = _t + randf_range(0.25, 0.9)
	view.shoot(best.x, best.y, ability, randf_range(-0.6, 0.6) if _use_abilities else 0.0)
	_shots += 1


## Picks (angle, power) whose predicted landing is closest to the cup.
func _search(from: Vector2) -> Vector2:
	var cup := view.terrain.cup_pos
	var bal := GameData.balance
	var best := Vector2(-PI * 0.25, 0.5)
	var best_d := INF
	var toward := 1.0 if cup.x >= from.x else -1.0
	for ai in 14:
		var elev := lerpf(0.05, 1.45, float(ai) / 13.0)
		var angle := -elev if toward > 0.0 else -PI + elev
		for pi in 10:
			var power := lerpf(0.08, 1.0, float(pi) / 9.0)
			var vel := Vector2.from_angle(angle) * MatchSim.launch_speed(bal, power)
			var r := float(bal.physics.ball_radius)
			var res := SimPhysics.predict(view.terrain, bal.physics, GameData.materials, from, vel, r, 1.0, 4.0, 3.0, 3,
				MatchSim.launch_spin(bal, vel, 0.0, r))
			var pts: PackedVector2Array = res.points
			if pts.is_empty():
				continue
			var end := pts[pts.size() - 1]
			if view.terrain.zone_at(end) != "":
				continue
			var d := end.distance_to(cup) + randf_range(0.0, 20.0)
			if d < best_d:
				best_d = d
				best = Vector2(angle, power)
	return best
