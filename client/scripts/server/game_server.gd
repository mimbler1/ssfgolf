extends Node
## Headless authoritative dedicated game server. One process hosts one match at a time.
##
## Usage (after `--`):
##   --server --port 7777 --public-host 127.0.0.1 --backend http://127.0.0.1:8080
##   --server-key KEY --join-secret SECRET
## Environment fallbacks: FAIRWAY_PORT, FAIRWAY_PUBLIC_HOST, FAIRWAY_BACKEND_URL,
##   FAIRWAY_GAME_SERVER_KEY, FAIRWAY_JOIN_TOKEN_SECRET.
## Developer mode: --insecure-dev [--dev-players N] accepts "dev:<name>" tokens with no backend.

enum State { IDLE, WAITING, RUNNING, FINISHING }

const HELLO_TIMEOUT := 6.0
const SNAPSHOT_EVERY := 2           ## 60 Hz sim -> 30 Hz snapshots
const CMD_WINDOW := 1.0
const CMD_MAX_PER_WINDOW := 20
const EMOTE_COOLDOWN := 1.5
const FINISH_LINGER := 8.0

var state: State = State.IDLE
var port := 7777
var public_host := "127.0.0.1"
var backend_url := "http://127.0.0.1:8080"
var server_key := "dev-server-key-change-me"
var join_secret := "dev-join-secret-change-me"
var dev_mode := false
var dev_players := 2
var _dev_course := GameData.POOL_ID

var server_id := ""
var assignment: Dictionary = {}
var sim: MatchSim
var _bound: Dictionary = {}       ## peer_id -> {slot, playerId, cmds: Array[float], last_emote: float}
var _pending: Dictionary = {}     ## peer_id -> connected_at (seconds)
## Peers with a validly signed ticket for a match the backend hasn't handed us yet.
var _deferred: Dictionary = {}    ## peer_id -> {token, protocol, version, at}
const DEFER_TIMEOUT := 8.0
var _wait_time := 0.0
var _finish_time := 0.0
var _clock := 0.0
var _hb_timer := 0.0
var _hb_interval := 1.0
var _hb_busy := false
var _registering := false
var _result_sent := false


func _ready() -> void:
	Engine.max_fps = 120
	_parse_args()
	Net.server_handler = self
	var err := Net.host(port, 16)
	if err != OK:
		_log("FATAL: could not listen on UDP port %d (error %d)" % [port, err])
		get_tree().quit(2)
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_log("Fairway Frenzy game server %s listening on UDP %d (public %s)%s" % [GameData.VERSION, port, public_host, " [INSECURE DEV MODE]" if dev_mode else ""])
	if not dev_mode:
		_register()


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	port = int(_arg(args, "--port", OS.get_environment("FAIRWAY_PORT") if OS.has_environment("FAIRWAY_PORT") else "7777"))
	public_host = _arg(args, "--public-host", OS.get_environment("FAIRWAY_PUBLIC_HOST") if OS.has_environment("FAIRWAY_PUBLIC_HOST") else "127.0.0.1")
	backend_url = _arg(args, "--backend", OS.get_environment("FAIRWAY_BACKEND_URL") if OS.has_environment("FAIRWAY_BACKEND_URL") else backend_url).trim_suffix("/")
	server_key = _arg(args, "--server-key", OS.get_environment("FAIRWAY_GAME_SERVER_KEY") if OS.has_environment("FAIRWAY_GAME_SERVER_KEY") else server_key)
	join_secret = _arg(args, "--join-secret", OS.get_environment("FAIRWAY_JOIN_TOKEN_SECRET") if OS.has_environment("FAIRWAY_JOIN_TOKEN_SECRET") else join_secret)
	dev_mode = args.has("--insecure-dev")
	dev_players = clampi(int(_arg(args, "--dev-players", "2")), 1, MatchSim.MAX_PLAYERS)
	_dev_course = _arg(args, "--dev-course", GameData.POOL_ID)


static func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i != -1 and i + 1 < args.size() else fallback


func _log(msg: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(true), msg])


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	_expire_pending()
	_retry_deferred()
	match state:
		State.IDLE:
			pass
		State.WAITING:
			_wait_time += delta
			_check_start()
		State.RUNNING:
			sim.tick()
			_broadcast_events()
			if sim.tick_count % SNAPSHOT_EVERY == 0:
				_broadcast_snapshot()
			if sim.phase == MatchSim.Phase.MATCH_OVER:
				_begin_finish()
		State.FINISHING:
			_finish_time += delta
			if _finish_time >= FINISH_LINGER and _result_sent:
				_reset()
			elif _finish_time >= FINISH_LINGER * 6.0:
				_log("Giving up waiting for result upload; resetting.")
				_reset()
	if not dev_mode:
		_hb_timer -= delta
		if _hb_timer <= 0.0 and not _hb_busy and server_id != "":
			_hb_timer = _hb_interval
			_heartbeat()


func _retry_deferred() -> void:
	for pid: int in _deferred.keys():
		var d: Dictionary = _deferred[pid]
		if not _connected(pid):
			_deferred.erase(pid)
		elif not assignment.is_empty() and str(assignment.matchId) == str(d.matchId):
			_deferred.erase(pid)
			_pending[pid] = _clock
			on_hello(pid, str(d.token), int(d.protocol), str(d.version))
		elif _clock - float(d.at) > DEFER_TIMEOUT:
			_deferred.erase(pid)
			_reject(pid, "no_match")


func _expire_pending() -> void:
	for pid: int in _pending.keys():
		if _clock - float(_pending[pid]) > HELLO_TIMEOUT:
			_log("Peer %d never authenticated; disconnecting." % pid)
			_pending.erase(pid)
			_kick(pid)


func _connected(pid: int) -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(pid)


func _kick(pid: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer and _connected(pid):
		peer.disconnect_peer(pid)


# ---------------------------------------------------------------------------
# Match lifecycle
# ---------------------------------------------------------------------------

func _begin_assignment(a: Dictionary) -> void:
	assignment = a
	var course := GameData.course(str(a.get("courseId", GameData.POOL_ID)))
	if course.is_empty() or bool(course.get("practiceOnly", false)):
		_log("Assignment %s references unknown course %s; using the full course pool." % [a.get("matchId"), a.get("courseId")])
		course = GameData.course(GameData.POOL_ID)
		assignment.courseId = GameData.POOL_ID
	sim = MatchSim.new(GameData.balance, GameData.materials, course, "online", hash(str(a.matchId)))
	# Private rooms play to the host's target; matchmaking uses the table for the player count.
	if a.get("roomCode") != null and str(a.get("roomCode", "")) != "":
		sim.target_override = int(a.get("targetPoints", 9))
	var roster: Array = a.get("players", [])
	roster.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("slot", 0)) < int(y.get("slot", 0)))
	for r: Dictionary in roster:
		var p := sim.add_player(str(r.playerId), str(r.get("displayName", "Golfer")), Appearance.normalize(r.get("appearance", {})), int(r.get("trophies", 0)))
		p.connected = false
	state = State.WAITING
	_wait_time = 0.0
	_result_sent = false
	_log("Match %s assigned: %d players, course %s, first to %d." % [a.matchId, roster.size(), assignment.courseId, sim.target_points])


func _check_start() -> void:
	var total := dev_players if dev_mode else sim.players.size()
	var joined := 0
	for p in sim.players:
		if p.ever_connected:
			joined += 1
	var timeout := float(GameData.balance.match.join_timeout)
	var all_in := joined == total and total > 0
	var min_needed := 1 if total == 1 else 2
	if all_in and _wait_time >= 0.5:
		_start_match()
	elif _wait_time >= timeout:
		if joined >= min_needed:
			for p in sim.players:
				if not p.ever_connected:
					sim.forfeit(p.slot)
			_start_match()
		else:
			_log("Match %s: only %d/%d joined before timeout; aborting." % [assignment.matchId, joined, total])
			sim.abort("aborted")
			_broadcast_events()
			_begin_finish()


func _start_match() -> void:
	state = State.RUNNING
	sim.start()
	_log("Match %s started." % assignment.matchId)
	_broadcast_events()


func _begin_finish() -> void:
	if state == State.FINISHING:
		return
	state = State.FINISHING
	_finish_time = 0.0
	_broadcast_events()
	_broadcast_snapshot()
	_log("Match %s over (%s)." % [assignment.matchId, sim.end_reason])
	_send_result()


func _reset() -> void:
	for pid: int in _bound.keys():
		_kick(pid)
	_bound.clear()
	assignment = {}
	sim = null
	state = State.IDLE
	_hb_timer = 0.0
	_log("Server idle.")
	if dev_mode:
		_dev_lobby_reset()


# ---------------------------------------------------------------------------
# Broadcasting
# ---------------------------------------------------------------------------

func _broadcast_events() -> void:
	if sim == null:
		return
	for ev in sim.take_events():
		ev["t"] = sim.time
		for pid: int in _bound:
			if _connected(pid):
				Net.s_event.rpc_id(pid, ev)


func _broadcast_snapshot() -> void:
	if sim == null or _bound.is_empty():
		return
	var data := SnapshotCodec.encode(sim, GameData.ability_index)
	for pid: int in _bound:
		if _connected(pid):
			Net.s_snapshot.rpc_id(pid, data)


# ---------------------------------------------------------------------------
# Peers & commands (called by Net)
# ---------------------------------------------------------------------------

func _on_peer_connected(pid: int) -> void:
	_pending[pid] = _clock


func _on_peer_disconnected(pid: int) -> void:
	_pending.erase(pid)
	_deferred.erase(pid)
	if _bound.has(pid):
		var b: Dictionary = _bound[pid]
		_bound.erase(pid)
		if sim and (state == State.RUNNING or state == State.WAITING):
			sim.set_connected(int(b.slot), false)
			_log("Player %s (slot %d) disconnected." % [b.playerId, b.slot])


func on_hello(pid: int, token: String, protocol: int, version: String) -> void:
	if not _pending.has(pid):
		return
	_pending.erase(pid)
	if protocol != GameData.PROTOCOL_VERSION:
		_reject(pid, "version")
		return
	var player_id := ""
	if dev_mode and token.begins_with("dev:"):
		player_id = _dev_join(token.substr(4).strip_edges().left(16))
		if player_id == "":
			_reject(pid, "match_full")
			return
	else:
		var v := JoinToken.verify(join_secret, token, int(Time.get_unix_time_from_system()))
		if not v.ok:
			_log("Rejected token from peer %d: %s" % [pid, v.reason])
			_reject(pid, "bad_token")
			return
		if assignment.is_empty() or str(v.matchId) != str(assignment.matchId):
			# The client may arrive before our next heartbeat delivers the assignment.
			if state == State.IDLE:
				_deferred[pid] = {"token": token, "protocol": protocol, "version": version, "matchId": str(v.matchId), "at": _clock}
				return
			_reject(pid, "not_in_match")
			return
		player_id = str(v.playerId)
	if state == State.FINISHING or state == State.IDLE:
		_reject(pid, "match_over")
		return
	var p := sim.player_by_id(player_id)
	if p == null:
		_reject(pid, "not_in_match")
		return
	if p.forfeited:
		_reject(pid, "match_over")
		return
	# A reconnect replaces any previous connection for the same player.
	for other: int in _bound.keys():
		if str(_bound[other].playerId) == player_id:
			_bound.erase(other)
			_kick(other)
	_bound[pid] = {"slot": p.slot, "playerId": player_id, "cmds": [], "last_emote": -10.0}
	p.ever_connected = true
	if state == State.RUNNING:
		sim.set_connected(p.slot, true)
	else:
		p.connected = true
	var roster: Array[Dictionary] = []
	for q in sim.players:
		roster.append({"slot": q.slot, "playerId": q.player_id, "name": q.display_name, "appearance": q.appearance, "trophies": q.trophies})
	Net.s_welcome.rpc_id(pid, {
		"slot": p.slot, "matchId": str(assignment.matchId), "courseId": str(assignment.courseId),
		"targetPoints": sim.target_points, "players": roster, "abilities": Array(p.allowed_abilities),
		"serverTime": sim.time, "holeIndex": sim.hole_index if state == State.RUNNING else -1,
		"holeNumber": sim.hole_number, "phase": sim.phase,
	})
	_log("Player %s joined as slot %d (peer %d)." % [player_id, p.slot, pid])


func _reject(pid: int, reason: String) -> void:
	if _connected(pid):
		Net.s_reject.rpc_id(pid, reason)
	# Give the reliable message a moment to flush before dropping the peer.
	get_tree().create_timer(0.3).timeout.connect(func() -> void: _kick(pid))


func _rate_ok(pid: int) -> bool:
	var b: Dictionary = _bound.get(pid, {})
	if b.is_empty():
		return false
	var cmds: Array = b.cmds
	while not cmds.is_empty() and _clock - float(cmds[0]) > CMD_WINDOW:
		cmds.pop_front()
	if cmds.size() >= CMD_MAX_PER_WINDOW:
		return false
	cmds.append(_clock)
	return true


func on_shoot(pid: int, seq: int, angle: float, power: float, ability: int, spin: float) -> void:
	if not _rate_ok(pid) or sim == null or state != State.RUNNING:
		return
	var b: Dictionary = _bound[pid]
	if ability < 0 or ability >= GameData.abilities.size():
		Net.s_cmd_result.rpc_id(pid, seq, "unknown_ability")
		return
	var err := sim.cmd_shoot(int(b.slot), angle, power, GameData.ability_id_at(ability), spin)
	if err != "":
		Net.s_cmd_result.rpc_id(pid, seq, err)


func on_spin(pid: int, dir: int) -> void:
	if not _rate_ok(pid) or sim == null or state != State.RUNNING:
		return
	sim.cmd_spin(int(_bound[pid].slot), dir)


func on_activate(pid: int, _seq: int) -> void:
	if not _rate_ok(pid) or sim == null or state != State.RUNNING:
		return
	sim.cmd_activate(int(_bound[pid].slot))


func on_reset(pid: int, seq: int) -> void:
	if not _rate_ok(pid) or sim == null or state != State.RUNNING:
		return
	var err := sim.cmd_reset(int(_bound[pid].slot))
	if err != "":
		Net.s_cmd_result.rpc_id(pid, seq, err)


func on_emote(pid: int, emote: int) -> void:
	if not _bound.has(pid) or sim == null or emote < 0 or emote >= Emotes.count():
		return
	var b: Dictionary = _bound[pid]
	if _clock - float(b.last_emote) < EMOTE_COOLDOWN:
		return
	b.last_emote = _clock
	var ev := {"type": "emote", "slot": int(b.slot), "emote": emote, "t": sim.time}
	for other: int in _bound:
		if _connected(other):
			Net.s_event.rpc_id(other, ev)


func on_leave(pid: int) -> void:
	if not _bound.has(pid):
		return
	var b: Dictionary = _bound[pid]
	_bound.erase(pid)
	if sim and (state == State.RUNNING or state == State.WAITING):
		sim.forfeit(int(b.slot))
		_log("Player %s left the match." % b.playerId)
	_kick(pid)


func on_ping(pid: int, client_time: float) -> void:
	if _bound.has(pid) and _connected(pid):
		Net.s_pong.rpc_id(pid, client_time, sim.time if sim else 0.0)


# ---------------------------------------------------------------------------
# Backend integration
# ---------------------------------------------------------------------------

func _http(method: HTTPClient.Method, path: String, body: Variant) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json", "X-Server-Key: %s" % server_key])
	var err := http.request(backend_url + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null}
	var out: Array = await http.request_completed
	http.queue_free()
	var status: int = out[1]
	var data: Variant = JSON.parse_string((out[3] as PackedByteArray).get_string_from_utf8()) if (out[3] as PackedByteArray).size() > 0 else null
	return {"ok": out[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300, "status": status if out[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data}


func _register() -> void:
	if _registering:
		return
	_registering = true
	while true:
		var res := await _http(HTTPClient.METHOD_POST, "/internal/servers/register", {"host": public_host, "port": port, "version": GameData.VERSION})
		if res.ok:
			server_id = str(res.data.serverId)
			_hb_interval = maxf(0.25, float(res.data.get("heartbeatIntervalMs", 1000)) / 1000.0)
			_log("Registered with backend %s as %s." % [backend_url, server_id])
			break
		_log("Backend registration failed (status %d); retrying in 3 s." % res.status)
		await get_tree().create_timer(3.0).timeout
	_registering = false


func _heartbeat() -> void:
	_hb_busy = true
	var busy := state != State.IDLE
	var res := await _http(HTTPClient.METHOD_POST, "/internal/servers/%s/heartbeat" % server_id,
		{"status": "busy" if busy else "idle", "matchId": str(assignment.matchId) if busy and assignment.has("matchId") else null})
	_hb_busy = false
	if res.status == 404:
		_log("Backend forgot this server; re-registering.")
		server_id = ""
		_register()
		return
	if not res.ok:
		return
	var a: Variant = res.data.get("assignment") if res.data is Dictionary else null
	if a is Dictionary and state == State.IDLE:
		_begin_assignment(a)


func _result_body() -> Dictionary:
	var standings := sim.standings()
	var players: Array[Dictionary] = []
	for s: Dictionary in standings:
		var p := sim.players[int(s.slot)]
		players.append({"playerId": p.player_id, "placement": int(s.placement), "points": p.points, "holesWon": p.holes_won,
			"holesPlayed": p.holes_played, "shots": p.shots, "abilitiesUsed": p.abilities_used, "disconnected": p.forfeited or not p.ever_connected})
	return {"endedReason": sim.end_reason if sim.end_reason in ["completed", "aborted"] else "aborted", "players": players, "holes": sim.hole_log}


func _send_result() -> void:
	if dev_mode:
		_log("Dev mode: result not uploaded. Standings: %s" % JSON.stringify(sim.standings()))
		_result_sent = true
		return
	var body := _result_body()
	var match_id := str(assignment.matchId)
	for attempt in 6:
		var res := await _http(HTTPClient.METHOD_POST, "/internal/matches/%s/result" % match_id, body)
		if res.ok:
			_log("Result for %s accepted by backend." % match_id)
			_result_sent = true
			return
		if res.status >= 400 and res.status < 500:
			_log("Result for %s rejected (%d): %s" % [match_id, res.status, JSON.stringify(res.data)])
			_result_sent = true
			return
		await get_tree().create_timer(2.0 * (attempt + 1)).timeout
	_log("Could not upload result for %s after retries." % match_id)
	_result_sent = true


# ---------------------------------------------------------------------------
# Developer mode (no backend): players join with "dev:<name>" tokens.
# ---------------------------------------------------------------------------

var _dev_names: Array[String] = []


## "Name@character" picks a roster character for the dev player (art review of several golfers).
func _dev_join(name: String) -> String:
	var want_char := ""
	if name.contains("@"):
		want_char = name.get_slice("@", 1)
		name = name.get_slice("@", 0)
	if name == "":
		name = "Dev"
	var id := "dev-" + name.to_lower().validate_filename()
	if state == State.IDLE:
		_begin_assignment({"matchId": "dev-%d" % Time.get_ticks_msec(), "courseId": _dev_course, "targetPoints": 9, "players": []})
	if sim.player_by_id(id) != null:
		return id
	if state != State.WAITING or sim.players.size() >= dev_players:
		return ""
	var app := Appearance.with_preset({}, Appearance.PRESETS[sim.players.size() % Appearance.PRESETS.size()].data)
	if CharacterDefs.has(want_char):
		app.character = want_char
	var p := sim.add_player(id, name, Appearance.normalize(app))
	p.connected = false
	_dev_names.append(name)
	return id


func _dev_lobby_reset() -> void:
	_dev_names.clear()
