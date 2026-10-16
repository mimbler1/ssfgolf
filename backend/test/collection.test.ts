import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { catalog, pickItem, rollRarity } from '../src/collection/collection.ts';
import { DEFAULT_APPEARANCE } from '../src/profile/appearance.ts';
import { bearer, createTestApp, newGuest } from './helpers.ts';
import type { TestApp } from './helpers.ts';

describe('collection catalog', () => {
  it('only lists real cosmetics, with unique ids and valid rarities', () => {
    const c = catalog();
    const ids = new Set(c.items.map((i) => i.id));
    assert.equal(ids.size, c.items.length);
    for (const i of c.items) {
      assert.ok(['character', 'ball', 'trail'].includes(i.kind), i.id);
      assert.ok(i.rarity in c.rarities, i.id);
    }
    // Every rarity a pack can roll has at least one non-default item.
    for (const r of Object.keys(c.rarities)) {
      assert.ok(c.items.some((i) => i.rarity === r && !i.default), r);
    }
  });

  it('rolls rarities by weight and honours guarantees', () => {
    // mulberry32: a small, well-distributed deterministic PRNG for repeatable tests.
    let a = 0x9e3779b9;
    const rand = (n: number) => {
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return Math.floor((((t ^ (t >>> 14)) >>> 0) / 4294967296) * n);
    };
    const counts: Record<string, number> = {};
    for (let i = 0; i < 20000; i++) {
      const r = rollRarity(rand);
      counts[r] = (counts[r] ?? 0) + 1;
    }
    const w = catalog().rarities;
    const total = Object.values(w).reduce((s, x) => s + x.weight, 0);
    for (const [r, v] of Object.entries(w)) {
      const share = (counts[r] ?? 0) / 20000;
      assert.ok(Math.abs(share - v.weight / total) < 0.02, `${r}: ${share}`);
    }
    for (let i = 0; i < 500; i++) assert.ok(['epic', 'legendary'].includes(rollRarity(rand, 'epic')));
    // Prefers items the player does not own.
    const owned = new Map(catalog().items.filter((i) => i.rarity === 'legendary' && !i.default).slice(1).map((i) => [i.id, 1]));
    const left = catalog().items.filter((i) => i.rarity === 'legendary' && !i.default && !owned.has(i.id));
    if (left.length === 1) assert.equal(pickItem(rand, 'legendary', owned).id, left[0]?.id);
  });
});

describe('collection routes', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });

  async function setCoins(playerId: string, coins: number) {
    await t.pool.query('UPDATE players SET coins = $2 WHERE id = $1', [playerId, coins]);
  }

  it('new players own exactly the default items', async () => {
    const g = await newGuest(t);
    const res = await t.app.inject({ method: 'GET', url: '/v1/collection', headers: bearer(g.token) });
    assert.equal(res.statusCode, 200);
    const owned = res.json().owned.map((o: { itemId: string }) => o.itemId).sort();
    const defaults = catalog().items.filter((i) => i.default).map((i) => i.id).sort();
    assert.deepEqual(owned, defaults);
  });

  it('opening a pack costs coins, grants items and logs the opening', async () => {
    const g = await newGuest(t);
    await setCoins(g.playerId, 1000);
    const res = await t.app.inject({ method: 'POST', url: '/v1/packs/premium/open', headers: bearer(g.token) });
    assert.equal(res.statusCode, 200, res.body);
    const body = res.json();
    const pack = catalog().packs.find((p) => p.id === 'premium');
    assert.ok(pack);
    assert.equal(body.items.length, pack.items);
    assert.ok(['epic', 'legendary'].includes(body.items[0].rarity), 'premium guarantees epic or better');
    assert.equal(body.coins, 1000 - pack.cost + body.refund);
    const col = await t.app.inject({ method: 'GET', url: '/v1/collection', headers: bearer(g.token) });
    const owned = new Set(col.json().owned.map((o: { itemId: string }) => o.itemId));
    for (const it of body.items) assert.ok(owned.has(it.itemId));
    const { rows } = await t.pool.query('SELECT count(*)::int AS n FROM pack_openings WHERE player_id = $1', [g.playerId]);
    assert.equal(rows[0].n, 1);
  });

  it('rejects packs the player cannot afford and unknown packs', async () => {
    const g = await newGuest(t);
    await setCoins(g.playerId, 50);
    const poor = await t.app.inject({ method: 'POST', url: '/v1/packs/basic/open', headers: bearer(g.token) });
    assert.equal(poor.statusCode, 409);
    const unknown = await t.app.inject({ method: 'POST', url: '/v1/packs/mega/open', headers: bearer(g.token) });
    assert.equal(unknown.statusCode, 404);
    const me = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.equal(me.json().coins, 50, 'nothing was charged');
  });

  it('duplicates refund coins once every non-default item is owned', async () => {
    const g = await newGuest(t);
    for (const i of catalog().items.filter((x) => !x.default)) {
      await t.pool.query('INSERT INTO player_items (player_id, item_id) VALUES ($1, $2)', [g.playerId, i.id]);
    }
    await setCoins(g.playerId, 120);
    const res = await t.app.inject({ method: 'POST', url: '/v1/packs/basic/open', headers: bearer(g.token) });
    assert.equal(res.statusCode, 200);
    const body = res.json();
    assert.ok(body.items.every((i: { isNew: boolean; refund: number }) => !i.isNew && i.refund > 0));
    assert.equal(body.coins, body.refund);
  });

  it('equipping a collectible requires owning it', async () => {
    const g = await newGuest(t);
    const brick = { ...DEFAULT_APPEARANCE, character: 'brick' };
    const denied = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: brick } });
    assert.equal(denied.statusCode, 403);
    assert.equal(denied.json().error.code, 'not_owned');
    await t.pool.query('INSERT INTO player_items (player_id, item_id) VALUES ($1, $2)', [g.playerId, 'char_brick']);
    const ok = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: brick } });
    assert.equal(ok.statusCode, 200);
    // Custom (non-catalog) colours from older clients are still accepted.
    const custom = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: { ...brick, ballColor: '#123456' } } });
    assert.equal(custom.statusCode, 200);
  });

  it('reports are stored once per reporter, target and match', async () => {
    const a = await newGuest(t);
    const b = await newGuest(t);
    const body = { playerId: b.playerId, matchId: 'm-1', reason: 'griefing', note: 'kept blocking the cup' };
    const r1 = await t.app.inject({ method: 'POST', url: '/v1/reports', headers: bearer(a.token), payload: body });
    assert.equal(r1.statusCode, 200);
    assert.equal(r1.json().duplicate, false);
    const r2 = await t.app.inject({ method: 'POST', url: '/v1/reports', headers: bearer(a.token), payload: body });
    assert.equal(r2.json().duplicate, true);
    const self = await t.app.inject({ method: 'POST', url: '/v1/reports', headers: bearer(a.token), payload: { ...body, playerId: a.playerId } });
    assert.equal(self.statusCode, 400);
    const bad = await t.app.inject({ method: 'POST', url: '/v1/reports', headers: bearer(a.token), payload: { ...body, reason: 'meh' } });
    assert.equal(bad.statusCode, 400);
    const { rows } = await t.pool.query('SELECT count(*)::int AS n FROM player_reports WHERE target_id = $1', [b.playerId]);
    assert.equal(rows[0].n, 1);
  });
});
