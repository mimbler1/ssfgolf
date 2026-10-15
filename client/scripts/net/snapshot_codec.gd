class_name SnapshotCodec
extends RefCounted
## Compact binary world snapshot (server -> clients, unreliable channel).

const F_ACTIVE := 1
const F_REST := 2
const F_STUCK := 4
const F_GROUNDED := 8
const F_FINISHED := 16
const F_CONNECTED := 32
const F_MANUAL := 64
const F_FORFEIT := 128
const F_HAZARD := 256
const F_GRENADE := 512
const MAX_IMPACTS := 16


static func encode(sim: MatchSim, ability_index: Callable) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u32(sim.tick_count)
	buf.put_float(sim.time)
	buf.put_u8(sim.phase)
	buf.put_float(sim.phase_timer)
	buf.put_float(sim.hole_time)
	buf.put_float(sim.hole_deadline if sim.hole_deadline < 1e20 else -1.0)
	buf.put_u8(maxi(sim.hole_index, 0))
	buf.put_u8(sim.hole_number)
	buf.put_u8(sim.players.size())
	var grace := float(sim.balance.physics.grounded_grace)
	for p in sim.players:
		var b := p.ball
		var f := 0
		if b.active: f |= F_ACTIVE
		if b.at_rest: f |= F_REST
		if b.stuck: f |= F_STUCK
		if b.is_grounded(grace): f |= F_GROUNDED
		if p.finished: f |= F_FINISHED
		if p.connected: f |= F_CONNECTED
		if b.manual_available: f |= F_MANUAL
		if p.forfeited: f |= F_FORFEIT
		if p.hazard_timer >= 0.0: f |= F_HAZARD
		if b.grenade_pending: f |= F_GRENADE
		buf.put_u8(p.slot)
		buf.put_u16(f)
		buf.put_float(b.pos.x)
		buf.put_float(b.pos.y)
		buf.put_float(b.vel.x)
		buf.put_float(b.vel.y)
		buf.put_float(b.rot)
		buf.put_u8(clampi(roundi(p.energy * 20.0), 0, 255))
		buf.put_u8(clampi(roundi(p.cooldown * 50.0), 0, 255))
		buf.put_u8(clampi(p.points, 0, 255))
		buf.put_u8(int(ability_index.call(b.ability)))
		buf.put_u8(clampi(p.hole_shots, 0, 255))
	var imps := sim.last_impacts
	var n := mini(imps.size(), MAX_IMPACTS)
	buf.put_u8(n)
	for i in n:
		var imp: Dictionary = imps[i]
		buf.put_u8(int(imp.slot))
		buf.put_u8(255 if int(imp.mat) < 0 else int(imp.mat))
		buf.put_u16(clampi(int(imp.speed), 0, 65535))
		buf.put_float(imp.pos.x)
		buf.put_float(imp.pos.y)
	return buf.data_array


## Returns {} on malformed input.
static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < 24:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = data
	var out := {}
	out.tick = buf.get_u32()
	out.time = buf.get_float()
	out.phase = buf.get_u8()
	out.phase_timer = buf.get_float()
	out.hole_time = buf.get_float()
	var dl := buf.get_float()
	out.deadline = INF if dl < 0.0 else dl
	out.hole_index = buf.get_u8()
	out.hole_number = buf.get_u8()
	var count := buf.get_u8()
	if count > 8 or data.size() < 24 + count * 28:
		return {}
	var players: Array[Dictionary] = []
	for i in count:
		var s := {}
		s.slot = buf.get_u8()
		var f := buf.get_u16()
		s.flags = f
		s.active = f & F_ACTIVE != 0
		s.at_rest = f & F_REST != 0
		s.stuck = f & F_STUCK != 0
		s.grounded = f & F_GROUNDED != 0
		s.finished = f & F_FINISHED != 0
		s.connected = f & F_CONNECTED != 0
		s.manual = f & F_MANUAL != 0
		s.forfeited = f & F_FORFEIT != 0
		s.hazard = f & F_HAZARD != 0
		s.grenade = f & F_GRENADE != 0
		s.pos = Vector2(buf.get_float(), buf.get_float())
		s.vel = Vector2(buf.get_float(), buf.get_float())
		s.rot = buf.get_float()
		s.energy = buf.get_u8() / 20.0
		s.cooldown = buf.get_u8() / 50.0
		s.points = buf.get_u8()
		s.ability = buf.get_u8()
		s.hole_shots = buf.get_u8()
		players.append(s)
	out.players = players
	var impacts: Array[Dictionary] = []
	if buf.get_position() < data.size():
		var n := mini(buf.get_u8(), MAX_IMPACTS)
		for i in n:
			if buf.get_position() + 12 > data.size():
				break
			impacts.append({"slot": buf.get_u8(), "mat": buf.get_u8(), "speed": float(buf.get_u16()), "pos": Vector2(buf.get_float(), buf.get_float())})
	out.impacts = impacts
	return out
