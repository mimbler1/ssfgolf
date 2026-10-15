import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { verifyJoinToken } from '../src/joinToken.ts';
import {
  JOIN_SECRET, bearer, createTestApp, heartbeat, mmStatus, newGuests, queue, registerServer, reportResult, setTrophies,
} from './helpers.ts';
import type { TestApp } from './helpers.ts';

describe('matchmaking', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });
  beforeEach(() => {
    // Fresh in-memory state between tests (DB rows are harmless).
    t.ctx.matchmaker.queue.clear();
    t.ctx.registry.servers.clear();
    t.ctx.coordinator.matches.clear();
    t.ctx.coordinator.byPlayer.clear();
  });

  it('starts as idle; queue -> searching with queuedAt/elapsedMs', async () => {
    const [a] = await newGuests(t, 1);
    assert.ok(a);
    assert.deepEqual(await mmStatus(t, a), { status: 'idle', queuedAt: null, elapsedMs: 0, match: null });
    const res = await queue(t, a);
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().status, 'searching');
    t.clock.advance(4200);
    const s = await mmStatus(t, a);
    assert.equal(s.status, 'searching');
    assert.equal(s.elapsedMs, 4200);
    assert.equal(Date.parse(s.queuedAt), t.clock.now() - 4200);
    // Already queued -> 409
    const again = await queue(t, a);
    assert.equal(again.statusCode, 409);
    assert.equal(again.json().error.code, 'conflict');
  });

  it('validates the queue body', async () => {
    const [a] = await newGuests(t, 1);
    assert.ok(a);
    const res = await t.app.inject({ method: 'POST', url: '/v1/matchmaking/queue', headers: bearer(a.token), payload: { mode: 'ranked' } });
    assert.equal(res.statusCode, 400);
  });

  it('matches 4 players immediately once a server registered and heartbeated; assignment delivered once', async () => {
    const players = await newGuests(t, 4);
    for (const p of players) assert.equal((await queue(t, p)).statusCode, 200);

    // No server: stays searching.
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    for (const p of players) assert.equal((await mmStatus(t, p)).status, 'searching');

    const sid = await registerServer(t, 7777);
    assert.equal((await heartbeat(t, sid, 'idle')).assignment, null);
    assert.equal(await t.ctx.matchmaker.tick(), 1);

    const statuses = await Promise.all(players.map((p) => mmStatus(t, p)));
    const matchId = statuses[0].match.matchId;
    for (const [i, s] of statuses.entries()) {
      assert.equal(s.status, 'matched');
      assert.equal(s.match.matchId, matchId);
      assert.equal(s.match.serverHost, '127.0.0.1');
      assert.equal(s.match.serverPort, 7777);
      const v = verifyJoinToken(JOIN_SECRET, s.match.joinToken, t.clock.now());
      assert.equal(v.ok, true);
      if (v.ok) {
        assert.equal(v.payload.m, matchId);
        assert.equal(v.payload.p, players[i]?.playerId);
      }
    }
    // Cancel is a no-op once matched.
    const del = await t.app.inject({ method: 'DELETE', url: '/v1/matchmaking/queue', headers: bearer(players[0]!.token) });
    assert.equal(del.statusCode, 204);
    assert.equal((await mmStatus(t, players[0]!)).status, 'matched');
    // Cannot queue while in a match.
    assert.equal((await queue(t, players[0]!)).statusCode, 409);

    const hb = await heartbeat(t, sid, 'idle');
    assert.ok(hb.assignment);
    const a = hb.assignment;
    assert.equal(a.matchId, matchId);
    assert.equal(a.mode, 'quick');
    assert.equal(a.ranked, true);
    assert.equal(a.courseId, 'sunny_meadows');
    assert.equal(a.targetPoints, 9);
    assert.equal(a.players.length, 4);
    assert.deepEqual(a.players.map((p) => p.slot), [0, 1, 2, 3]);
    assert.deepEqual(new Set(a.players.map((p) => p.playerId)), new Set(players.map((p) => p.playerId)));
    assert.equal(a.players[0]!.appearance.v, 1);
    assert.equal(typeof a.players[0]!.trophies, 'number');
    // Delivered only once.
    assert.equal((await heartbeat(t, sid, 'idle')).assignment, null);
    assert.equal((await heartbeat(t, sid, 'busy', matchId)).assignment, null);

    // Persisted.
    const { rows } = await t.pool.query('SELECT status, mode, ranked FROM matches WHERE id = $1', [matchId]);
    assert.deepEqual(rows[0], { status: 'started', mode: 'quick', ranked: true });

    // A second group can't be matched: the only server is busy.
    const more = await newGuests(t, 4);
    for (const p of more) await queue(t, p);
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    for (const p of more) assert.equal((await mmStatus(t, p)).status, 'searching');

    // After the result, players and server are idle again, and the waiting group gets the server.
    const res = await reportResult(t, matchId, {
      endedReason: 'completed',
      players: players.map((p, i) => ({ playerId: p.playerId, placement: i + 1, points: 9 - i, holesWon: 0, holesPlayed: 3, shots: 10, abilitiesUsed: {}, disconnected: false })),
      holes: [],
    });
    assert.equal(res.statusCode, 200);
    for (const p of players) assert.equal((await mmStatus(t, p)).status, 'idle');
    assert.equal(await t.ctx.matchmaker.tick(), 1);
    for (const p of more) assert.equal((await mmStatus(t, p)).status, 'matched');
  });

  it('fills with the minimum after MM_FILL_WAIT_MS', async () => {
    const sid = await registerServer(t, 7001);
    await heartbeat(t, sid, 'idle');
    const [a, b] = await newGuests(t, 2);
    assert.ok(a && b);
    await queue(t, a);
    t.clock.advance(1000);
    await queue(t, b);
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    t.clock.advance(18_999); // a has waited 19.999s
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    assert.equal((await mmStatus(t, a)).status, 'searching');
    t.clock.advance(1);
    assert.equal(await t.ctx.matchmaker.tick(), 1);
    const sa = await mmStatus(t, a);
    const sb = await mmStatus(t, b);
    assert.equal(sa.status, 'matched');
    assert.equal(sb.status, 'matched');
    assert.equal(sa.match.matchId, sb.match.matchId);
    const hb = await heartbeat(t, sid, 'idle');
    assert.equal(hb.assignment?.players.length, 2);
  });

  it('a lone player never matches (below MM_MIN_PLAYERS)', async () => {
    const sid = await registerServer(t, 7002);
    await heartbeat(t, sid, 'idle');
    const [a] = await newGuests(t, 1);
    assert.ok(a);
    await queue(t, a);
    t.clock.advance(120_000);
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    assert.equal((await mmStatus(t, a)).status, 'searching');
  });

  it('respects the trophy window, which widens by 75 every 5 s of the oldest member', async () => {
    const sid = await registerServer(t, 7003);
    await heartbeat(t, sid, 'idle');
    const [a, b] = await newGuests(t, 2);
    assert.ok(a && b);
    await setTrophies(t, a.playerId, 1000);
    await setTrophies(t, b.playerId, 1300); // 300 apart: needs window >= 300 -> 150 + 75*2 at 10s
    await queue(t, a);
    await queue(t, b);
    assert.equal(t.ctx.matchmaker.trophyWindow(0), 150);
    assert.equal(t.ctx.matchmaker.trophyWindow(4999), 150);
    assert.equal(t.ctx.matchmaker.trophyWindow(5000), 225);
    assert.equal(t.ctx.matchmaker.trophyWindow(10_000), 300);
    // Past the fill wait (20 s) the window is 150 + 75*4 = 450 >= 300, so they match then.
    t.clock.advance(19_999);
    assert.equal(await t.ctx.matchmaker.tick(), 0);
    t.clock.advance(1);
    assert.equal(await t.ctx.matchmaker.tick(), 1);
  });

  it('keeps far-apart players apart even at fill time', async () => {
    const sid = await registerServer(t, 7004);
    await heartbeat(t, sid, 'idle');
    const [a, b] = await newGuests(t, 2);
    assert.ok(a && b);
    await setTrophies(t, b.playerId, 2000);
    await queue(t, a);
    await queue(t, b);
    t.clock.advance(20_000); // window 450
    assert.equal(await t.ctx.matchmaker.tick(), 0);
  });

  it('cancel removes the player from the queue; cancelling when idle is a no-op', async () => {
    const [a] = await newGuests(t, 1);
    assert.ok(a);
    const idle = await t.app.inject({ method: 'DELETE', url: '/v1/matchmaking/queue', headers: bearer(a.token) });
    assert.equal(idle.statusCode, 204);
    await queue(t, a);
    const del = await t.app.inject({ method: 'DELETE', url: '/v1/matchmaking/queue', headers: bearer(a.token) });
    assert.equal(del.statusCode, 204);
    assert.equal((await mmStatus(t, a)).status, 'idle');
    assert.equal(t.ctx.matchmaker.queue.size, 0);
  });

  it('matched status expires after 10 minutes without a result', async () => {
    const sid = await registerServer(t, 7005);
    await heartbeat(t, sid, 'idle');
    const players = await newGuests(t, 4);
    for (const p of players) await queue(t, p);
    assert.equal(await t.ctx.matchmaker.tick(), 1);
    const matchId = (await mmStatus(t, players[0]!)).match.matchId;
    const hb = await heartbeat(t, sid, 'idle');
    await heartbeat(t, sid, 'busy', hb.assignment!.matchId);
    // Keep the server alive while time passes.
    for (let i = 0; i < 60; i++) {
      t.clock.advance(10_000);
      await heartbeat(t, sid, 'busy', matchId);
      await t.ctx.tick();
    }
    assert.equal((await mmStatus(t, players[0]!)).status, 'idle');
    const { rows } = await t.pool.query('SELECT status FROM matches WHERE id = $1', [matchId]);
    assert.equal(rows[0].status, 'expired');
  });
});
