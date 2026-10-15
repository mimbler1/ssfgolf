import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { applyTrophies, computeReward, trophyDelta } from '../src/matches/rewards.ts';
import {
  bearer, createTestApp, getMe, heartbeat, mmStatus, newGuests, registerServer, reportResult, serverHeaders,
  setTrophies, startQuickMatch,
} from './helpers.ts';
import type { Guest, TestApp } from './helpers.ts';

type PR = {
  playerId: string; placement: number; points?: number; holesWon?: number; holesPlayed?: number; shots?: number;
  abilitiesUsed?: Record<string, number>; disconnected?: boolean;
};

function result(players: PR[], endedReason: 'completed' | 'aborted' = 'completed') {
  return {
    endedReason,
    players: players.map((p) => ({
      points: 0, holesWon: 0, holesPlayed: 0, shots: 0, abilitiesUsed: {}, disconnected: false, ...p,
    })),
    holes: [{ holeId: 'sm_01', finishOrder: players.map((p) => p.playerId) }],
  };
}

describe('reward math (pure)', () => {
  it('trophy tables for 2/3/4 players, disconnected -> last', () => {
    assert.deepEqual([1, 2, 3, 4].map((p) => trophyDelta(4, p, false)), [30, 12, -6, -16]);
    assert.deepEqual([1, 2, 3].map((p) => trophyDelta(3, p, false)), [25, 0, -12]);
    assert.deepEqual([1, 2].map((p) => trophyDelta(2, p, false)), [20, -12]);
    assert.equal(trophyDelta(4, 1, true), -16);
    assert.equal(trophyDelta(3, 1, true), -12);
    assert.equal(trophyDelta(2, 1, true), -12);
  });

  it('xp and coins with placement bonus (last value beyond 4)', () => {
    const r = (placement: number, holesWon: number) =>
      computeReward({ ranked: true, endedReason: 'completed', playerCount: 4, placement, holesWon, disconnected: false });
    assert.deepEqual(r(1, 3), { trophyDelta: 30, xpGained: 115, coinsGained: 55 });
    assert.deepEqual(r(2, 1), { trophyDelta: 12, xpGained: 75, coinsGained: 35 });
    assert.deepEqual(r(3, 1), { trophyDelta: -6, xpGained: 65, coinsGained: 28 });
    assert.deepEqual(r(4, 0), { trophyDelta: -16, xpGained: 40, coinsGained: 15 });
    assert.equal(r(6, 0).xpGained, 40);
  });

  it('private halves XP (floored), no coins/trophies; aborted gives nothing', () => {
    assert.deepEqual(
      computeReward({ ranked: false, endedReason: 'completed', playerCount: 2, placement: 1, holesWon: 1, disconnected: false }),
      { trophyDelta: 0, xpGained: 42, coinsGained: 0 },
    );
    assert.deepEqual(
      computeReward({ ranked: true, endedReason: 'aborted', playerCount: 4, placement: 1, holesWon: 3, disconnected: false }),
      { trophyDelta: 0, xpGained: 0, coinsGained: 0 },
    );
    assert.deepEqual(applyTrophies(5, -16), { trophiesAfter: 0, effectiveDelta: -5 });
    assert.deepEqual(applyTrophies(0, -12), { trophiesAfter: 0, effectiveDelta: 0 });
  });
});

describe('match results', () => {
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
  });

  async function playersWith(n: number, trophies = 100): Promise<Guest[]> {
    const ps = await newGuests(t, n);
    for (const p of ps) await setTrophies(t, p.playerId, trophies);
    return ps;
  }

  it('4-player ranked rewards, stats, profile and history', async () => {
    const ps = await playersWith(4);
    const { assignment, serverId } = await startQuickMatch(t, ps);
    const [a, b, c, d] = ps as [Guest, Guest, Guest, Guest];
    const res = await reportResult(t, assignment.matchId, result([
      { playerId: a.playerId, placement: 1, points: 9, holesWon: 3, holesPlayed: 5, shots: 21, abilitiesUsed: { nitro: 2, grenade: 1, standard: 18 } },
      { playerId: b.playerId, placement: 2, points: 6, holesWon: 1, holesPlayed: 5, shots: 25, abilitiesUsed: { grenade: 1 } },
      { playerId: c.playerId, placement: 3, points: 4, holesWon: 1, holesPlayed: 5, shots: 27 },
      { playerId: d.playerId, placement: 4, points: 1, holesWon: 0, holesPlayed: 5, shots: 30 },
    ]));
    assert.equal(res.statusCode, 200, res.body);
    const byId = new Map(res.json().rewards.map((r: { playerId: string }) => [r.playerId, r]));
    assert.deepEqual(byId.get(a.playerId), { playerId: a.playerId, trophyDelta: 30, xpGained: 115, coinsGained: 55 });
    assert.deepEqual(byId.get(b.playerId), { playerId: b.playerId, trophyDelta: 12, xpGained: 75, coinsGained: 35 });
    assert.deepEqual(byId.get(c.playerId), { playerId: c.playerId, trophyDelta: -6, xpGained: 65, coinsGained: 28 });
    assert.deepEqual(byId.get(d.playerId), { playerId: d.playerId, trophyDelta: -16, xpGained: 40, coinsGained: 15 });

    const me = await getMe(t, a);
    assert.equal(me.trophies, 130);
    assert.equal(me.highestTrophies, 130);
    assert.equal(me.xp, 115);
    assert.equal(me.level, 2);
    assert.equal(me.xpIntoLevel, 15);
    assert.equal(me.xpForNextLevel, 150);
    assert.equal(me.coins, 55);
    assert.deepEqual(me.stats, {
      matches: 1, wins: 1, holesPlayed: 5, holeWins: 3, shots: 21, abilitiesUsed: 3,
      favoriteAbility: 'nitro', currentWinStreak: 1, longestWinStreak: 1,
    });
    const meD = await getMe(t, d);
    assert.equal(meD.trophies, 84);
    assert.equal(meD.highestTrophies, 100);
    assert.equal(meD.stats.wins, 0);
    assert.equal(meD.stats.currentWinStreak, 0);

    // Players and server are idle again.
    for (const p of ps) assert.equal((await mmStatus(t, p)).status, 'idle');
    assert.equal(t.ctx.registry.get(serverId)?.matchId, null);

    // Match detail + history.
    const detail = await t.app.inject({ method: 'GET', url: `/v1/matches/${assignment.matchId}`, headers: bearer(a.token) });
    assert.equal(detail.statusCode, 200);
    const dj = detail.json();
    assert.equal(dj.mode, 'quick');
    assert.equal(dj.ranked, true);
    assert.equal(dj.courseId, 'sunny_meadows');
    assert.equal(dj.endedReason, 'completed');
    assert.deepEqual(dj.players.map((p: { placement: number }) => p.placement), [1, 2, 3, 4]);
    assert.deepEqual(dj.players[0], { playerId: a.playerId, displayName: 'Player_0', placement: 1, points: 9, disconnected: false });
    assert.deepEqual(dj.myRewards, { trophyDelta: 30, trophiesAfter: 130, xpGained: 115, coinsGained: 55, levelBefore: 1, levelAfter: 2 });

    const hist = await t.app.inject({ method: 'GET', url: '/v1/me/matches', headers: bearer(c.token) });
    assert.equal(hist.statusCode, 200);
    assert.equal(hist.json().matches.length, 1);
    const s = hist.json().matches[0];
    assert.equal(s.matchId, assignment.matchId);
    assert.equal(s.placement, 3);
    assert.equal(s.playerCount, 4);
    assert.equal('players' in s, false);
    assert.deepEqual(s.myRewards, { trophyDelta: -6, trophiesAfter: 94, xpGained: 65, coinsGained: 28, levelBefore: 1, levelAfter: 1 });
  });

  it('is idempotent: a second report returns the first result and changes nothing', async () => {
    const ps = await playersWith(2);
    const { assignment } = await startQuickMatch(t, ps);
    const body = result([
      { playerId: ps[0]!.playerId, placement: 1, holesWon: 2 },
      { playerId: ps[1]!.playerId, placement: 2 },
    ]);
    const first = await reportResult(t, assignment.matchId, body);
    assert.equal(first.statusCode, 200);
    const meBefore = await getMe(t, ps[0]!);
    // Different body on purpose: still returns the stored result.
    const swapped = result([
      { playerId: ps[0]!.playerId, placement: 2 },
      { playerId: ps[1]!.playerId, placement: 1, holesWon: 5 },
    ]);
    const [second, third] = await Promise.all([
      reportResult(t, assignment.matchId, swapped),
      reportResult(t, assignment.matchId, body),
    ]);
    assert.equal(second.statusCode, 200);
    assert.deepEqual(second.json(), first.json());
    assert.deepEqual(third.json(), first.json());
    assert.deepEqual(await getMe(t, ps[0]!), meBefore);
    const { rows } = await t.pool.query('SELECT count(*)::int AS n FROM match_players WHERE match_id = $1', [assignment.matchId]);
    assert.equal(rows[0].n, 2);
    assert.deepEqual(
      first.json().rewards.map((r: { trophyDelta: number }) => r.trophyDelta),
      [20, -12],
    );
  });

  it('concurrent first reports apply rewards once', async () => {
    const ps = await playersWith(2);
    const { assignment } = await startQuickMatch(t, ps);
    const body = result([
      { playerId: ps[0]!.playerId, placement: 1 },
      { playerId: ps[1]!.playerId, placement: 2 },
    ]);
    const all = await Promise.all([1, 2, 3, 4].map(() => reportResult(t, assignment.matchId, body)));
    for (const r of all) assert.equal(r.statusCode, 200);
    assert.equal((await getMe(t, ps[0]!)).trophies, 120);
    assert.equal((await getMe(t, ps[0]!)).stats.matches, 1);
  });

  it('3-player rewards with a disconnected winner getting the last-place delta', async () => {
    const ps = await playersWith(3);
    const { assignment } = await startQuickMatch(t, ps);
    const res = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1, holesWon: 2, disconnected: true },
      { playerId: ps[1]!.playerId, placement: 2 },
      { playerId: ps[2]!.playerId, placement: 3 },
    ]));
    assert.equal(res.statusCode, 200);
    const r = res.json().rewards;
    assert.deepEqual(r.map((x: { trophyDelta: number }) => x.trophyDelta), [-12, 0, -12]);
    assert.equal(r[0].xpGained, 40 + 30 + 30);
    const detail = await t.app.inject({ method: 'GET', url: `/v1/matches/${assignment.matchId}`, headers: bearer(ps[0]!.token) });
    assert.equal(detail.json().players[0].disconnected, true);
  });

  it('trophies never go below 0', async () => {
    const ps = await playersWith(4, 5);
    const { assignment } = await startQuickMatch(t, ps);
    const res = await reportResult(t, assignment.matchId, result(ps.map((p, i) => ({ playerId: p.playerId, placement: i + 1 }))));
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json().rewards.map((x: { trophyDelta: number }) => x.trophyDelta), [30, 12, -5, -5]);
    assert.equal((await getMe(t, ps[3]!)).trophies, 0);
    assert.equal((await getMe(t, ps[0]!)).trophies, 35);
  });

  it('aborted matches record history but apply nothing', async () => {
    const ps = await playersWith(2);
    const { assignment } = await startQuickMatch(t, ps);
    const res = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1, holesWon: 3, shots: 10 },
      { playerId: ps[1]!.playerId, placement: 2 },
    ], 'aborted'));
    assert.equal(res.statusCode, 200);
    for (const r of res.json().rewards) assert.deepEqual([r.trophyDelta, r.xpGained, r.coinsGained], [0, 0, 0]);
    const me = await getMe(t, ps[0]!);
    assert.equal(me.trophies, 100);
    assert.equal(me.xp, 0);
    assert.equal(me.stats.matches, 0);
    assert.equal(me.stats.shots, 0);
    const hist = (await t.app.inject({ method: 'GET', url: '/v1/me/matches', headers: bearer(ps[0]!.token) })).json();
    assert.equal(hist.matches.length, 1);
    assert.equal(hist.matches[0].endedReason, 'aborted');
    for (const p of ps) assert.equal((await mmStatus(t, p)).status, 'idle');
  });

  it('private (unranked) matches give half XP, no coins or trophies', async () => {
    const sid = await registerServer(t, 7600);
    await heartbeat(t, sid, 'idle');
    const ps = await playersWith(2);
    const [h, m] = ps as [Guest, Guest];
    const room = (await t.app.inject({ method: 'POST', url: '/v1/rooms', headers: bearer(h.token), payload: {} })).json();
    await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/join`, headers: bearer(m.token) });
    await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/ready`, headers: bearer(m.token), payload: { ready: true } });
    const started = (await t.app.inject({ method: 'POST', url: `/v1/rooms/${room.code}/start`, headers: bearer(h.token) })).json();
    const matchId = started.match.matchId;
    const res = await reportResult(t, matchId, result([
      { playerId: h.playerId, placement: 1, holesWon: 1, holesPlayed: 2, shots: 7 },
      { playerId: m.playerId, placement: 2, holesWon: 1, holesPlayed: 2, shots: 9 },
    ]));
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json().rewards, [
      { playerId: h.playerId, trophyDelta: 0, xpGained: 42, coinsGained: 0 },
      { playerId: m.playerId, trophyDelta: 0, xpGained: 37, coinsGained: 0 },
    ]);
    const me = await getMe(t, h);
    assert.equal(me.trophies, 100);
    assert.equal(me.coins, 0);
    assert.equal(me.xp, 42);
    assert.equal(me.stats.matches, 1);
    assert.equal(me.stats.wins, 1);
    const detail = (await t.app.inject({ method: 'GET', url: `/v1/matches/${matchId}`, headers: bearer(m.token) })).json();
    assert.equal(detail.mode, 'private');
    assert.equal(detail.ranked, false);
  });

  it('win streaks: increments on wins, resets on non-first placement', async () => {
    const ps = await playersWith(2);
    const [a, b] = ps as [Guest, Guest];
    const sid = await registerServer(t, 7700);
    const play = async (winner: Guest, loser: Guest) => {
      const { assignment } = await startQuickMatch(t, [a, b], sid);
      const r = await reportResult(t, assignment.matchId, result([
        { playerId: winner.playerId, placement: 1 },
        { playerId: loser.playerId, placement: 2 },
      ]));
      assert.equal(r.statusCode, 200);
    };
    await play(a, b);
    await play(a, b);
    let me = await getMe(t, a);
    assert.equal(me.stats.currentWinStreak, 2);
    assert.equal(me.stats.longestWinStreak, 2);
    await play(b, a);
    me = await getMe(t, a);
    assert.equal(me.stats.currentWinStreak, 0);
    assert.equal(me.stats.longestWinStreak, 2);
    assert.equal(me.stats.matches, 3);
    assert.equal(me.stats.wins, 2);
    assert.equal(me.trophies, 100 + 20 + 20 - 12);
    assert.equal(me.highestTrophies, 140);
    const hist = (await t.app.inject({ method: 'GET', url: '/v1/me/matches?limit=2', headers: bearer(a.token) })).json();
    assert.equal(hist.matches.length, 2);
    assert.equal(hist.matches[0].placement, 2); // newest first
    const over = await t.app.inject({ method: 'GET', url: '/v1/me/matches?limit=500', headers: bearer(a.token) });
    assert.equal(over.statusCode, 200);
    assert.equal(over.json().matches.length, 3);
    const bad = await t.app.inject({ method: 'GET', url: '/v1/me/matches?limit=abc', headers: bearer(a.token) });
    assert.equal(bad.statusCode, 400);
  });

  it('level calculation across multiple level-ups', async () => {
    const ps = await playersWith(2);
    await t.pool.query('UPDATE players SET xp = 240 WHERE id = $1', [ps[0]!.playerId]); // level 2, 140/150
    const { assignment } = await startQuickMatch(t, ps);
    const res = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1, holesWon: 10 }, // xp 40+150+30 = 220 -> 460 total
      { playerId: ps[1]!.playerId, placement: 2 },
    ]));
    assert.equal(res.json().rewards[0].xpGained, 220);
    const me = await getMe(t, ps[0]!);
    assert.equal(me.xp, 460);
    assert.equal(me.level, 4); // 100 + 150 + 200 = 450
    assert.equal(me.xpIntoLevel, 10);
    assert.equal(me.xpForNextLevel, 250);
    const d = (await t.app.inject({ method: 'GET', url: `/v1/matches/${assignment.matchId}`, headers: bearer(ps[0]!.token) })).json();
    assert.equal(d.myRewards.levelBefore, 2);
    assert.equal(d.myRewards.levelAfter, 4);
  });

  it('validates roster membership and completeness', async () => {
    const ps = await playersWith(3);
    const [outsider] = await newGuests(t, 1);
    const { assignment } = await startQuickMatch(t, ps.slice(0, 2));
    const missing = await reportResult(t, assignment.matchId, result([{ playerId: ps[0]!.playerId, placement: 1 }]));
    assert.equal(missing.statusCode, 400);
    const extra = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1 },
      { playerId: ps[1]!.playerId, placement: 2 },
      { playerId: outsider!.playerId, placement: 3 },
    ]));
    assert.equal(extra.statusCode, 400);
    const dup = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1 },
      { playerId: ps[0]!.playerId, placement: 2 },
    ]));
    assert.equal(dup.statusCode, 400);
    const malformed = await reportResult(t, assignment.matchId, { endedReason: 'done', players: [] });
    assert.equal(malformed.statusCode, 400);
    // Nothing applied; match still reportable.
    assert.equal((await getMe(t, ps[0]!)).stats.matches, 0);
    const ok = await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1 },
      { playerId: ps[1]!.playerId, placement: 2 },
    ]));
    assert.equal(ok.statusCode, 200);
    // Unknown match / bad key.
    assert.equal((await reportResult(t, '00000000-0000-4000-8000-000000000000', result([]))).statusCode, 400);
    const unknown = await reportResult(t, '00000000-0000-4000-8000-000000000000', result([{ playerId: ps[0]!.playerId, placement: 1 }]));
    assert.equal(unknown.statusCode, 404);
    const noKey = await t.app.inject({ method: 'POST', url: `/internal/matches/${assignment.matchId}/result`, payload: {} });
    assert.equal(noKey.statusCode, 401);
    void serverHeaders;
  });

  it('GET /v1/matches/:id access control', async () => {
    const ps = await playersWith(2);
    const [outsider] = await newGuests(t, 1);
    const { assignment } = await startQuickMatch(t, ps);
    const url = `/v1/matches/${assignment.matchId}`;
    // Not reported yet -> 404 for participants.
    assert.equal((await t.app.inject({ method: 'GET', url, headers: bearer(ps[0]!.token) })).statusCode, 404);
    await reportResult(t, assignment.matchId, result([
      { playerId: ps[0]!.playerId, placement: 1 },
      { playerId: ps[1]!.playerId, placement: 2 },
    ]));
    assert.equal((await t.app.inject({ method: 'GET', url, headers: bearer(ps[1]!.token) })).statusCode, 200);
    const forbidden = await t.app.inject({ method: 'GET', url, headers: bearer(outsider!.token) });
    assert.equal(forbidden.statusCode, 403);
    assert.equal(forbidden.json().error.code, 'forbidden');
    assert.equal((await t.app.inject({ method: 'GET', url })).statusCode, 401);
    assert.equal(
      (await t.app.inject({ method: 'GET', url: '/v1/matches/00000000-0000-4000-8000-000000000000', headers: bearer(ps[0]!.token) })).statusCode,
      404,
    );
    assert.equal((await t.app.inject({ method: 'GET', url: '/v1/matches/nope', headers: bearer(ps[0]!.token) })).statusCode, 404);
  });
});

describe('leaderboard', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });

  it('orders by trophies desc, then earlier highestTrophies achievement, then playerId', async () => {
    const ps = await newGuests(t, 5);
    const set = (p: Guest, trophies: number, at: string, xp = 0) =>
      t.pool.query('UPDATE players SET trophies = $2, highest_trophies = $2, highest_trophies_at = $3, xp = $4 WHERE id = $1', [
        p.playerId, trophies, at, xp,
      ]);
    const [a, b, c, d, e] = ps as [Guest, Guest, Guest, Guest, Guest];
    await set(a, 500, '2026-01-03T00:00:00Z', 450);
    await set(b, 900, '2026-01-05T00:00:00Z');
    await set(c, 500, '2026-01-01T00:00:00Z');
    await set(d, 500, '2026-01-01T00:00:00Z');
    await set(e, 10, '2026-01-01T00:00:00Z');
    const res = await t.app.inject({ method: 'GET', url: '/v1/leaderboard', headers: bearer(a.token) });
    assert.equal(res.statusCode, 200);
    const entries = res.json().entries;
    const [cd1, cd2] = [c.playerId, d.playerId].sort();
    assert.deepEqual(entries.map((x: { playerId: string }) => x.playerId), [b.playerId, cd1, cd2, a.playerId, e.playerId]);
    assert.deepEqual(entries.map((x: { rank: number }) => x.rank), [1, 2, 3, 4, 5]);
    assert.deepEqual(entries[3], { rank: 4, playerId: a.playerId, displayName: 'Player_0', trophies: 500, level: 4 });
    const limited = await t.app.inject({ method: 'GET', url: '/v1/leaderboard?limit=2', headers: bearer(a.token) });
    assert.equal(limited.json().entries.length, 2);
    assert.equal((await t.app.inject({ method: 'GET', url: '/v1/leaderboard?limit=0', headers: bearer(a.token) })).statusCode, 400);
    assert.equal((await t.app.inject({ method: 'GET', url: '/v1/leaderboard' })).statusCode, 401);
  });
});
