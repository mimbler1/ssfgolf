import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { verifyJoinToken } from '../src/joinToken.ts';
import {
  JOIN_SECRET, bearer, createTestApp, heartbeat, mmStatus, newGuests, queue, registerServer, reportResult,
} from './helpers.ts';
import type { Guest, TestApp } from './helpers.ts';

describe('private rooms', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });
  beforeEach(() => {
    t.ctx.matchmaker.queue.clear();
    t.ctx.registry.servers.clear();
    t.ctx.coordinator.matches.clear();
    t.ctx.coordinator.byPlayer.clear();
    t.ctx.rooms.rooms.clear();
    t.ctx.rooms.byPlayer.clear();
  });

  const req = (g: Guest, method: 'GET' | 'POST' | 'PATCH', url: string, payload?: Record<string, unknown>) =>
    t.app.inject({ method, url, headers: bearer(g.token), ...(payload ? { payload } : {}) });

  async function createRoom(host: Guest, settings: Record<string, unknown> = {}) {
    const res = await req(host, 'POST', '/v1/rooms', settings);
    assert.equal(res.statusCode, 200, res.body);
    return res.json();
  }

  it('creates a room with defaults and a valid code', async () => {
    const [h] = await newGuests(t, 1);
    assert.ok(h);
    const room = await createRoom(h);
    assert.match(room.code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
    assert.equal(room.hostId, h.playerId);
    assert.equal(room.status, 'open');
    assert.deepEqual(room.settings, { maxPlayers: 4, targetPoints: 9, courseId: 'blitz_pool', allAbilities: true });
    assert.deepEqual(room.members, [{ playerId: h.playerId, displayName: 'Player_0', ready: false, isHost: true }]);
    assert.equal(room.match, null);
    // Already in a room -> 409 for create and queue.
    assert.equal((await req(h, 'POST', '/v1/rooms', {})).statusCode, 409);
    assert.equal((await queue(t, h)).statusCode, 409);
  });

  it('validates settings', async () => {
    const [h, h2] = await newGuests(t, 2);
    assert.ok(h && h2);
    for (const bad of [{ maxPlayers: 1 }, { maxPlayers: 7 }, { targetPoints: 2 }, { targetPoints: 22 }, { courseId: 'Bad Id' }]) {
      assert.equal((await req(h, 'POST', '/v1/rooms', bad)).statusCode, 400, JSON.stringify(bad));
    }
    const room = await createRoom(h, { maxPlayers: 2, targetPoints: 5, courseId: 'cliffs' });
    assert.deepEqual(room.settings, { maxPlayers: 2, targetPoints: 5, courseId: 'cliffs', allAbilities: true });
    const locked = await createRoom(h2, { maxPlayers: 6, allAbilities: false });
    assert.equal(locked.settings.allAbilities, false);
    assert.equal(locked.settings.maxPlayers, 6);
  });

  it('join / get / permissions / full room / unknown code', async () => {
    const [h, a, b, outsider] = await newGuests(t, 4);
    assert.ok(h && a && b && outsider);
    const room = await createRoom(h, { maxPlayers: 2 });
    const joined = await req(a, 'POST', `/v1/rooms/${room.code.toLowerCase()}/join`);
    assert.equal(joined.statusCode, 200);
    assert.equal(joined.json().members.length, 2);
    assert.equal(joined.json().members[1].isHost, false);
    // Full.
    const full = await req(b, 'POST', `/v1/rooms/${room.code}/join`);
    assert.equal(full.statusCode, 409);
    // Unknown.
    assert.equal((await req(b, 'POST', '/v1/rooms/ZZZZZZ/join')).statusCode, 404);
    assert.equal((await req(b, 'POST', '/v1/rooms/bad/join')).statusCode, 404);
    // Members only.
    assert.equal((await req(outsider, 'GET', `/v1/rooms/${room.code}`)).statusCode, 403);
    assert.equal((await req(a, 'GET', `/v1/rooms/${room.code}`)).statusCode, 200);
    // Non-host cannot change settings or start.
    assert.equal((await req(a, 'PATCH', `/v1/rooms/${room.code}`, { targetPoints: 5 })).statusCode, 403);
    assert.equal((await req(a, 'POST', `/v1/rooms/${room.code}/start`)).statusCode, 403);
    // Queued player cannot join a room.
    const [q] = await newGuests(t, 1);
    assert.ok(q);
    const room2 = await createRoom(b);
    await queue(t, q);
    assert.equal((await req(q, 'POST', `/v1/rooms/${room2.code}/join`)).statusCode, 409);
  });

  it('ready, settings change resets readiness, start requirements', async () => {
    const [h, a, b] = await newGuests(t, 3);
    assert.ok(h && a && b);
    const room = await createRoom(h);
    const code = room.code;
    // Need >= 2 members.
    assert.equal((await req(h, 'POST', `/v1/rooms/${code}/start`)).statusCode, 409);
    await req(a, 'POST', `/v1/rooms/${code}/join`);
    await req(b, 'POST', `/v1/rooms/${code}/join`);
    const r1 = await req(a, 'POST', `/v1/rooms/${code}/ready`, { ready: true });
    assert.equal(r1.statusCode, 200);
    assert.equal(r1.json().members[1].ready, true);
    assert.equal((await req(a, 'POST', `/v1/rooms/${code}/ready`, { ready: 'yes' })).statusCode, 400);
    // b not ready -> 409.
    assert.equal((await req(h, 'POST', `/v1/rooms/${code}/start`)).statusCode, 409);
    await req(b, 'POST', `/v1/rooms/${code}/ready`, { ready: true });
    // Settings change resets non-host readiness.
    await req(h, 'POST', `/v1/rooms/${code}/ready`, { ready: true });
    const patched = await req(h, 'PATCH', `/v1/rooms/${code}`, { targetPoints: 15 });
    assert.equal(patched.statusCode, 200);
    assert.equal(patched.json().settings.targetPoints, 15);
    const readies = patched.json().members.map((m: { ready: boolean; isHost: boolean }) => [m.isHost, m.ready]);
    assert.deepEqual(readies, [[true, true], [false, false], [false, false]]);
    // Cannot shrink below member count.
    assert.equal((await req(h, 'PATCH', `/v1/rooms/${code}`, { maxPlayers: 2 })).statusCode, 409);
    await req(a, 'POST', `/v1/rooms/${code}/ready`, { ready: true });
    await req(b, 'POST', `/v1/rooms/${code}/ready`, { ready: true });
    // No server -> 503 no_server, room stays open.
    const noServer = await req(h, 'POST', `/v1/rooms/${code}/start`);
    assert.equal(noServer.statusCode, 503);
    assert.equal(noServer.json().error.code, 'no_server');
    assert.equal((await req(h, 'GET', `/v1/rooms/${code}`)).json().status, 'open');

    const sid = await registerServer(t, 7100);
    await heartbeat(t, sid, 'idle');
    const started = await req(h, 'POST', `/v1/rooms/${code}/start`);
    assert.equal(started.statusCode, 200, started.body);
    const sr = started.json();
    assert.equal(sr.status, 'in_match');
    assert.equal(sr.match.serverPort, 7100);
    const hv = verifyJoinToken(JOIN_SECRET, sr.match.joinToken, t.clock.now());
    assert.ok(hv.ok && hv.payload.p === h.playerId && hv.payload.m === sr.match.matchId);
    // Member-specific token.
    const av = await req(a, 'GET', `/v1/rooms/${code}`);
    const at = verifyJoinToken(JOIN_SECRET, av.json().match.joinToken, t.clock.now());
    assert.ok(at.ok && at.payload.p === a.playerId);
    // Room in match: no new joins, no ready toggles, members can't queue.
    const [late] = await newGuests(t, 1);
    assert.ok(late);
    assert.equal((await req(late, 'POST', `/v1/rooms/${code}/join`)).statusCode, 409);
    assert.equal((await queue(t, a)).statusCode, 409);
    // Room matches don't show in matchmaking status.
    assert.equal((await mmStatus(t, a)).status, 'idle');

    const hb = await heartbeat(t, sid, 'idle');
    assert.ok(hb.assignment);
    assert.equal(hb.assignment.mode, 'private');
    assert.equal(hb.assignment.ranked, false);
    assert.equal(hb.assignment.targetPoints, 15);
    assert.equal(hb.assignment.players[0]!.playerId, h.playerId);
    assert.equal(hb.assignment.players.length, 3);

    // Result -> room back to open with everyone unready.
    const res = await reportResult(t, sr.match.matchId, {
      endedReason: 'completed',
      players: [h, a, b].map((p, i) => ({ playerId: p.playerId, placement: i + 1, points: 0, holesWon: 0, holesPlayed: 1, shots: 3 })),
    });
    assert.equal(res.statusCode, 200, res.body);
    const after = (await req(h, 'GET', `/v1/rooms/${code}`)).json();
    assert.equal(after.status, 'open');
    assert.equal(after.match, null);
    assert.ok(after.members.every((m: { ready: boolean }) => m.ready === false));
  });

  it('host leaving promotes the next member; empty room is deleted', async () => {
    const [h, a, b] = await newGuests(t, 3);
    assert.ok(h && a && b);
    const room = await createRoom(h);
    await req(a, 'POST', `/v1/rooms/${room.code}/join`);
    await req(b, 'POST', `/v1/rooms/${room.code}/join`);
    const left = await req(h, 'POST', `/v1/rooms/${room.code}/leave`);
    assert.equal(left.statusCode, 204);
    const r = (await req(a, 'GET', `/v1/rooms/${room.code}`)).json();
    assert.equal(r.hostId, a.playerId);
    assert.equal(r.members.length, 2);
    assert.equal(r.members[0].isHost, true);
    // Former host can now create/queue.
    assert.equal((await queue(t, h)).statusCode, 200);
    await req(a, 'POST', `/v1/rooms/${room.code}/leave`);
    await req(b, 'POST', `/v1/rooms/${room.code}/leave`);
    assert.equal(t.ctx.rooms.rooms.has(room.code), false);
    assert.equal((await req(a, 'GET', `/v1/rooms/${room.code}`)).statusCode, 404);
  });

  it('idle rooms are deleted after 30 minutes without member requests', async () => {
    const [h] = await newGuests(t, 1);
    assert.ok(h);
    const room = await createRoom(h);
    t.clock.advance(29 * 60_000);
    assert.equal((await req(h, 'GET', `/v1/rooms/${room.code}`)).statusCode, 200); // activity
    t.clock.advance(29 * 60_000);
    t.ctx.rooms.sweep();
    assert.equal(t.ctx.rooms.rooms.has(room.code), true);
    t.clock.advance(60_000);
    t.ctx.rooms.sweep();
    assert.equal(t.ctx.rooms.rooms.has(room.code), false);
    assert.equal(t.ctx.rooms.isInRoom(h.playerId), false);
  });
});
