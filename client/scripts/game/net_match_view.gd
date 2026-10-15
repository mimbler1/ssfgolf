class_name NetMatchView
extends MatchView
## Online match view. The dedicated server is authoritative; this view only sends
## commands and renders snapshots, interpolated ~100 ms in the past for smoothness.
## Reliable events are time-stamped by the server and replayed at the same render time.

signal welcomed
signal rejected(reason: String)

const INTERP_DELAY := 0.1
const MAX_SNAPSHOTS := 40
const PING_INTERVAL := 1.0
const CONNECT_TIMEOUT := 10.0

var match_id: String = ""
var server_host: String = ""
var server_port: int = 0
var join_token: String = ""
var connected: bool = false
var rtt_ms: float = 0.0

var _snaps: Array[Dictionary] = []     ## ascending by time
var _events: Array[Dictionary] = []    ## pending, ascending by t
var _clock_offset: float = -INF
var _seq: int = 0
var _ping_timer: float = 0.0
var _connect_timer: float = 0.0
var _welcomed: bool = false
var _closing: bool = false
var _impact_cursor_tick: int = -1


func connect_to(host: String, port: int, token: String, p_match_id: String) -> void:
	mode = "online"
	server_host = host
	server_port = port
	join_token = token
	match_id = p_match_id
	balance = GameData.balance
	Net.client_handler = self
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var err := Net.join(host, port)
	if err != OK:
		call_deferred("_fail", "Could not open a connection to the game server.")


func _exit_tree() -> void:
	_shutdown()


func _shutdown(graceful: bool = false) -> void:
	if _closing:
		return
	_closing = true
	if Net.client_handler == self:
		Net.client_handler = null
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
		multiplayer.connection_failed.disconnect(_on_failed)
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if graceful:
		Net.close_after(0.3)
	else:
		Net.close()


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _on_connected() -> void:
	connected = true
	Net.c_hello.rpc_id(1, join_token, GameData.PROTOCOL_VERSION, GameData.VERSION)


func _on_failed() -> void:
	_fail("Could not connect to the game server.")


func _on_server_disconnected() -> void:
	if not _closing:
		_fail("Lost connection to the game server.")


func _fail(reason: String) -> void:
	if _closing:
		return
	connection_lost.emit(reason)
	_shutdown()


# ---------------------------------------------------------------------------
# Server -> client handlers (called by Net)
# ---------------------------------------------------------------------------

func on_welcome(data: Dictionary) -> void:
	local_slot = int(data.get("slot", 0))
	course_id = str(data.get("courseId", ""))
	course = GameData.course(course_id)
	if course.is_empty():
		_fail("Missing course data '%s'. Please update the game." % course_id)
		return
	target_points = int(data.get("targetPoints", 9))
	roster.clear()
	for r: Dictionary in data.get("players", []):
		roster.append({"slot": int(r.slot), "playerId": str(r.playerId), "name": str(r.name),
			"appearance": Appearance.normalize(r.get("appearance", {})), "trophies": int(r.get("trophies", 0))})
	allowed_abilities = PackedStringArray(data.get("abilities", ["standard"]))
	var st := float(data.get("serverTime", 0.0))
	_clock_offset = st - _now() + 0.05
	_welcomed = true
	var hi := int(data.get("holeIndex", -1))
	if hi >= 0:
		_load_hole(hi, int(data.get("holeNumber", 0)))
	welcomed.emit()


func on_reject(reason: String) -> void:
	rejected.emit(reason)
	_fail(_reject_text(reason))


static func _reject_text(reason: String) -> String:
	match reason:
		"bad_token": return "Your match ticket was not accepted. Please queue again."
		"not_in_match": return "You are not part of this match."
		"version": return "Your game version doesn't match the server. Please update."
		"match_over": return "That match has already finished."
		_: return "The server refused the connection (%s)." % reason


func on_event(ev: Dictionary) -> void:
	# Insert in time order (events normally arrive in order already).
	var t := float(ev.get("t", 0.0))
	var i := _events.size()
	while i > 0 and float(_events[i - 1].get("t", 0.0)) > t:
		i -= 1
	_events.insert(i, ev)


func on_snapshot(data: PackedByteArray) -> void:
	var s := SnapshotCodec.decode(data)
	if s.is_empty():
		return
	var sample := float(s.time) - _now()
	if sample > _clock_offset:
		_clock_offset = sample if _clock_offset == -INF else lerpf(_clock_offset, sample, 0.35)
	if not _snaps.is_empty() and float(s.time) <= float(_snaps[_snaps.size() - 1].time):
		return
	_snaps.append(s)
	while _snaps.size() > MAX_SNAPSHOTS:
		_snaps.remove_at(0)


func on_pong(client_time: float, _server_time: float) -> void:
	rtt_ms = lerpf(rtt_ms, (_now() - client_time) * 1000.0, 0.3) if rtt_ms > 0.0 else (_now() - client_time) * 1000.0


func on_cmd_result(_seq_id: int, error: String) -> void:
	if error != "":
		game_event.emit({"type": "rejected", "error": error})


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func render_time() -> float:
	return _now() + _clock_offset - INTERP_DELAY


func _process(delta: float) -> void:
	if _closing:
		return
	if not _welcomed:
		_connect_timer += delta
		if _connect_timer > CONNECT_TIMEOUT:
			_fail("The game server did not respond.")
		return
	# Slowly decay the offset so clock drift and early spikes can't push us ahead forever.
	_clock_offset -= delta * 0.002
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = PING_INTERVAL
		Net.c_ping.rpc_id(1, _now())
	var rt := render_time()
	while not _events.is_empty() and float(_events[0].get("t", 0.0)) <= rt:
		var ev: Dictionary = _events.pop_front()
		if ev.type == "hole_start":
			_load_hole(int(ev.hole_index), int(ev.hole_number))
		game_event.emit(ev)
	# Impacts from snapshots we've just passed (for sounds/particles).
	for s in _snaps:
		if float(s.time) <= rt and int(s.tick) > _impact_cursor_tick:
			_impact_cursor_tick = int(s.tick)
			if not s.impacts.is_empty():
				impacts.emit(s.impacts)


func _bracket(rt: float) -> Array:
	if _snaps.is_empty():
		return []
	if rt <= float(_snaps[0].time):
		return [_snaps[0], _snaps[0], 0.0]
	for i in range(_snaps.size() - 1, -1, -1):
		var a: Dictionary = _snaps[i]
		if float(a.time) <= rt:
			if i == _snaps.size() - 1:
				return [a, a, 0.0]
			var b: Dictionary = _snaps[i + 1]
			var span := float(b.time) - float(a.time)
			return [a, b, clampf((rt - float(a.time)) / span, 0.0, 1.0) if span > 0.0 else 0.0]
	return [_snaps[0], _snaps[0], 0.0]


func _latest() -> Dictionary:
	return _snaps[_snaps.size() - 1] if not _snaps.is_empty() else {}


func ball_state(slot: int) -> Dictionary:
	var br := _bracket(render_time())
	if br.is_empty():
		return {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0, "active": false, "at_rest": true, "stuck": false,
			"grounded": true, "finished": false, "connected": true, "forfeited": false, "manual": false,
			"ability": "standard", "hazard": false, "grenade": false}
	var a: Dictionary = _find(br[0].players, slot)
	var b: Dictionary = _find(br[1].players, slot)
	if a.is_empty():
		return {}
	var k: float = br[2]
	var out := a.duplicate()
	var teleport: bool = a.active != b.active or a.pos.distance_squared_to(b.pos) > 160000.0
	if not teleport:
		out.pos = a.pos.lerp(b.pos, k)
		out.rot = lerp_angle(a.rot, b.rot, k)
		out.vel = a.vel.lerp(b.vel, k)
	out.ability = GameData.ability_id_at(int(a.ability))
	return out


func _find(list: Array, slot: int) -> Dictionary:
	for p: Dictionary in list:
		if int(p.slot) == slot:
			return p
	return {}


func player_state(slot: int) -> Dictionary:
	var s := _latest()
	if s.is_empty():
		return {"energy": 0.0, "cooldown": 0.0, "points": 0, "hole_shots": 0}
	var p := _find(s.players, slot)
	return {"energy": p.get("energy", 0.0), "cooldown": p.get("cooldown", 0.0), "points": p.get("points", 0), "hole_shots": p.get("hole_shots", 0)}


func phase_state() -> Dictionary:
	var br := _bracket(render_time())
	if br.is_empty():
		return {"phase": MatchSim.Phase.WAITING, "timer": 0.0, "hole_time": 0.0, "deadline": INF}
	var s: Dictionary = br[0]
	var lag := render_time() - float(s.time)
	return {"phase": int(s.phase), "timer": maxf(0.0, float(s.phase_timer) - lag), "hole_time": float(s.hole_time) + lag, "deadline": float(s.deadline)}


func local_shot_block() -> String:
	var s := _latest()
	if s.is_empty():
		return "not_ready"
	if int(s.phase) != MatchSim.Phase.PLAYING:
		return "not_playing"
	var p := _find(s.players, local_slot)
	if p.is_empty() or p.finished or p.forfeited:
		return "finished"
	if p.hazard or not p.active:
		return "resetting"
	if float(p.cooldown) > 0.0:
		return "cooldown"
	if not p.grounded:
		return "airborne"
	return ""


## Latest (non-interpolated) cooldown, used to queue a shot released just before it ends.
func local_cooldown() -> float:
	var s := _latest()
	if s.is_empty():
		return 0.0
	return float(_find(s.players, local_slot).get("cooldown", 0.0))


func shoot(angle: float, power: float, ability: String) -> void:
	_seq += 1
	Net.c_shoot.rpc_id(1, _seq, angle, power, GameData.ability_index(ability))


func activate() -> void:
	_seq += 1
	Net.c_activate.rpc_id(1, _seq)


func reset_ball() -> void:
	_seq += 1
	Net.c_reset.rpc_id(1, _seq)


func emote(id: int) -> void:
	Net.c_emote.rpc_id(1, id)


func leave() -> void:
	if connected and not _closing:
		Net.c_leave.rpc_id(1)
		_shutdown(true)
	else:
		_shutdown()
