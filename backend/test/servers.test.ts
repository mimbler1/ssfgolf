import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  bearer, createTestApp, heartbeat, mmStatus, newGuests, queue, registerServer, serverHeaders,
} from './helpers.ts';
import type { TestApp } from './helpers.ts';

describe('game server registry', () => {
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

  it('requires X-Server-Key', async () => {
    const missing = await t.app.inject({ method: 'POST', url: '/internal/servers/register', payload: { host: 'h', port: 1, version: '1' } });
    assert.equal(missing.statusCode, 401);
    assert.equal(missing.json().error.code, 'unauthorized');
    const wrong = await t.app.inject({
      method: 'POST',
      url: '/internal/servers/register',
      headers: { 'x-server-key': 'nope' },
      payload: { host: 'h', port: 1, version: '1' },
    });
    assert.equal(wrong.statusCode, 401);
  });

  it('registers and returns the heartbeat interval; validates body', async () => {
    const res = await t.app.inject({
      method: 'POST',
      url: '/internal/servers/register',
      headers: serverHeaders,
      payload: { host: '127.0.0.1', port: 7777, version: '0.1.0' },
    });
    assert.equal(res.statusCode, 200);
    assert.match(res.json().serverId, /^[0-9a-f-]{36}$/);
    assert.equal(res.json().heartbeatIntervalMs, 1000);
    const bad = await t.app.inject({
      method: 'POST',
      url: '/internal/servers/register',
      headers: serverHeaders,
      payload: { host: '127.0.0.1', port: 70000 },
    });
    assert.equal(bad.statusCode, 400);
  });

  it('unknown serverId -> 404', async () => {
    const hb = await heartbeat(t, '00000000-0000-4000-8000-000000000000');
    assert.equal(hb.statusCode, 404);
    const junk = await heartbeat(t, 'not-a-uuid');
    assert.equal(junk.statusCode, 404);
  });

  it('re-registering the same host:port replaces the old entry', async () => {
    const first = await registerServer(t, 7200);
    const second = await registerServer(t, 7200);
    assert.notEqual(first, second);
    assert.equal((await heartbeat(t, first)).statusCode, 404);
    assert.equal((await heartbeat(t, second)).statusCode, 200);
    assert.equal(t.ctx.registry.servers.size, 1);
  });

  it('heartbeat timeout drops the server and cancels its unstarted match', async () => {
    const sid = await registerServer(t, 7300);
    await heartbeat(t, sid, 'idle');
    const players = await newGuests(t, 4);
    for (const p of players) await queue(t, p);
    assert.equal(await t.ctx.matchmaker.tick(), 1);
    const matchId = (await mmStatus(t, players[0]!)).match.matchId;
    // Assignment delivered but never started.
    assert.ok((await heartbeat(t, sid, 'idle')).assignment);
    t.clock.advance(9_999);
    await t.ctx.tick();
    assert.equal((await mmStatus(t, players[0]!)).status, 'matched');
    t.clock.advance(1);
    await t.ctx.tick();
    for (const p of players) assert.equal((await mmStatus(t, p)).status, 'idle');
    assert.equal((await heartbeat(t, sid)).statusCode, 404);
    const { rows } = await t.pool.query('SELECT status, cancel_reason FROM matches WHERE id = $1', [matchId]);
    assert.deepEqual(rows[0], { status: 'cancelled', cancel_reason: 'server_lost' });
    // A result for a cancelled match is refused.
    const res = await t.app.inject({
      method: 'POST',
      url: `/internal/matches/${matchId}/result`,
      headers: serverHeaders,
      payload: { endedReason: 'completed', players: players.map((p, i) => ({ playerId: p.playerId, placement: i + 1 })) },
    });
    assert.equal(res.statusCode, 409);
    // Players can queue again.
    assert.equal((await queue(t, players[0]!)).statusCode, 200);
  });

  it('a started match survives the server timeout (expires later instead)', async () => {
    const sid = await registerServer(t, 7400);
    await heartbeat(t, sid, 'idle');
    const players = await newGuests(t, 4);
    for (const p of players) await queue(t, p);
    await t.ctx.matchmaker.tick();
    const a = (await heartbeat(t, sid, 'idle')).assignment;
    assert.ok(a);
    await heartbeat(t, sid, 'busy', a.matchId);
    t.clock.advance(10_000);
    await t.ctx.tick();
    assert.equal((await mmStatus(t, players[0]!)).status, 'matched');
  });

  it('heartbeat timeout returns a starting room to open', async () => {
    const sid = await registerServer(t, 7500);
    await heartbeat(t, sid, 'idle');
    const [h, m] = await newGuests(t, 2);
    assert.ok(h && m);
    const room = (await t.app.inject({ method: 'POST', url: '/v1/rooms', headers: bearer(h.token), payload: {} })).json();
    await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/join`, headers: bearer(m.token) });
    await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/ready`, headers: bearer(m.token), payload: { ready: true } });
    const started = await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/start`, headers: bearer(h.token) });
    assert.equal(started.json().status, 'in_match');
    t.clock.advance(10_000);
    await t.ctx.tick();
    const r = (await t.app.inject({ method: 'GET', url: `/v1/rooms/${room.code}`, headers: bearer(h.token) })).json();
    assert.equal(r.status, 'open');
    assert.equal(r.match, null);
    assert.ok(r.members.every((x: { ready: boolean }) => !x.ready));
  });
});
