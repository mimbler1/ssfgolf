import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { DEFAULT_APPEARANCE } from '../src/profile/appearance.ts';
import { levelInfo, xpToAdvance } from '../src/profile/level.ts';
import { favoriteAbility } from '../src/profile/repo.ts';
import { bearer, createTestApp, newGuest } from './helpers.ts';
import type { TestApp } from './helpers.ts';

describe('level curve', () => {
  it('requires 100 + 50*(n-1) XP per level', () => {
    assert.equal(xpToAdvance(1), 100);
    assert.equal(xpToAdvance(2), 150);
    assert.equal(xpToAdvance(3), 200);
    assert.deepEqual(levelInfo(0), { level: 1, xpIntoLevel: 0, xpForNextLevel: 100 });
    assert.deepEqual(levelInfo(99), { level: 1, xpIntoLevel: 99, xpForNextLevel: 100 });
    assert.deepEqual(levelInfo(100), { level: 2, xpIntoLevel: 0, xpForNextLevel: 150 });
    assert.deepEqual(levelInfo(249), { level: 2, xpIntoLevel: 149, xpForNextLevel: 150 });
    assert.deepEqual(levelInfo(250), { level: 3, xpIntoLevel: 0, xpForNextLevel: 200 });
    assert.deepEqual(levelInfo(412), { level: 3, xpIntoLevel: 162, xpForNextLevel: 200 });
    assert.deepEqual(levelInfo(450), { level: 4, xpIntoLevel: 0, xpForNextLevel: 250 });
  });

  it('favoriteAbility ignores "standard" and returns null when none', () => {
    assert.equal(favoriteAbility({}), null);
    assert.equal(favoriteAbility({ standard: 50 }), null);
    assert.equal(favoriteAbility({ standard: 50, nitro: 3, grenade: 5 }), 'grenade');
    assert.equal(favoriteAbility({ nitro: 5, grenade: 5 }), 'grenade'); // tie -> alphabetical
  });
});

describe('profile', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });

  it('GET /v1/me returns the full profile shape', async () => {
    const g = await newGuest(t, 'ShapeTest');
    const res = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.equal(res.statusCode, 200);
    const p = res.json();
    assert.deepEqual(Object.keys(p).sort(), [
      'appearance', 'coins', 'createdAt', 'displayName', 'highestTrophies', 'level', 'playerId', 'stats',
      'trophies', 'xp', 'xpForNextLevel', 'xpIntoLevel',
    ]);
    assert.deepEqual(p.appearance, DEFAULT_APPEARANCE);
    assert.deepEqual(p.stats, {
      matches: 0, wins: 0, holesPlayed: 0, holeWins: 0, shots: 0, abilitiesUsed: 0,
      favoriteAbility: null, currentWinStreak: 0, longestWinStreak: 0,
    });
    assert.equal(p.xpForNextLevel, 100);
    assert.ok(!Number.isNaN(Date.parse(p.createdAt)));
  });

  it('PATCH /v1/me updates displayName and appearance', async () => {
    const g = await newGuest(t);
    const appearance = { ...DEFAULT_APPEARANCE, bodyColor: '#AABBCC', hat: 'cap', headScale: 1.3, limbThickness: 0.7 };
    const res = await t.app.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: bearer(g.token),
      payload: { displayName: 'New Name', appearance },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().displayName, 'New Name');
    assert.deepEqual(res.json().appearance, appearance);
    const again = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.deepEqual(again.json().appearance, appearance);
    const empty = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: {} });
    assert.equal(empty.statusCode, 200);
    assert.equal(empty.json().displayName, 'New Name');
  });

  it('PATCH /v1/me accepts a roster character and appearances without one', async () => {
    const g = await newGuest(t);
    const withChar = { ...DEFAULT_APPEARANCE, character: 'rex' };
    const res = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: withChar } });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json().appearance, withChar);
    // Older clients omit the field entirely.
    const legacy = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: DEFAULT_APPEARANCE } });
    assert.equal(legacy.statusCode, 200);
    assert.deepEqual(legacy.json().appearance, DEFAULT_APPEARANCE);
    const bad = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: { ...DEFAULT_APPEARANCE, character: 'Big Brick' } } });
    assert.equal(bad.statusCode, 400);
  });

  it('PATCH /v1/me stores an Appearance v2 ink look with a clothing drawing', async () => {
    const g = await newGuest(t);
    const ink = {
      hair: 'swept', hairColor: '#e0702a', headFill: 'paper', eyes: 'dots', brows: 'none', mouth: 'grin', mark: 'none',
      pantsCut: 'bell', pantsColor: '#1fb5a3', pantsColor2: '#ffd166', pantsPattern: 'solid', pantsLength: 1, pantsFlare: 1.3,
      pantsWaist: 0, pantsCuff: 'rolled', top: 'tee', topColor: '#fbf6ec', topColor2: '#1c1714', hat: '', hatColor: '#d6304a',
      eyewear: 'round', eyewearColor: '#1c1714', neck: '', neckColor: '#d6304a', back: '', backColor: '#b02a3a',
      gloves: '', glovesColor: '#ffffff', shoes: 'sneaker', shoesColor: '#ffffff', companion: '', club: 'iron',
      drawings: { pants: { v: 1, legs: 'both', strokes: [{ c: '#ffd166', w: 3.4, a: 1, p: [620, 300, 420, 470, 560, 490] }] } },
    };
    const appearance = { ...DEFAULT_APPEARANCE, v: 2, character: 'stickman', ink };
    const res = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance } });
    assert.equal(res.statusCode, 200, res.body);
    assert.deepEqual(res.json().appearance, appearance);
    const bad: Array<[string, unknown]> = [
      ['unknown ink key', { ...ink, horns: 'big' }],
      ['bad ink colour', { ...ink, pantsColor: 'teal' }],
      ['flare out of range', { ...ink, pantsFlare: 3 }],
      ['too many points', { ...ink, drawings: { pants: { v: 1, legs: 'both', strokes: [{ c: '#000000', w: 2, a: 1, p: Array(3002).fill(5) }] } } }],
      ['coordinate out of range', { ...ink, drawings: { pants: { v: 1, legs: 'both', strokes: [{ c: '#000000', w: 2, a: 1, p: [0, 1001] }] } } }],
      ['unknown drawing target', { ...ink, drawings: { face: { v: 1, legs: 'both', strokes: [] } } }],
    ];
    for (const [why, badInk] of bad) {
      const r = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance: { ...appearance, ink: badInk } } });
      assert.equal(r.statusCode, 400, why);
    }
  });

  it('PATCH /v1/me rejects bad appearance and names', async () => {
    const g = await newGuest(t);
    const bad: Array<[string, unknown]> = [
      ['unknown key', { ...DEFAULT_APPEARANCE, wings: 'big' }],
      ['unknown version', { ...DEFAULT_APPEARANCE, v: 3 }],
      ['bad color', { ...DEFAULT_APPEARANCE, bodyColor: 'red' }],
      ['short color', { ...DEFAULT_APPEARANCE, ballColor: '#fff' }],
      ['bad id', { ...DEFAULT_APPEARANCE, eyes: 'Big-Eyes' }],
      ['long id', { ...DEFAULT_APPEARANCE, mouth: 'a'.repeat(33) }],
      ['headScale low', { ...DEFAULT_APPEARANCE, headScale: 0.79 }],
      ['headScale high', { ...DEFAULT_APPEARANCE, headScale: 1.31 }],
      ['limbThickness low', { ...DEFAULT_APPEARANCE, limbThickness: 0.6 }],
      ['limbThickness high', { ...DEFAULT_APPEARANCE, limbThickness: 1.6 }],
      ['missing key', (({ trailColor: _omit, ...rest }) => rest)(DEFAULT_APPEARANCE)],
      ['not an object', 'fancy'],
    ];
    for (const [label, appearance] of bad) {
      const res = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { appearance } });
      assert.equal(res.statusCode, 400, label);
      assert.equal(res.json().error.code, 'bad_request', label);
    }
    const name = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: bearer(g.token), payload: { displayName: 'no!' } });
    assert.equal(name.statusCode, 400);
    // Nothing changed.
    const me = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.deepEqual(me.json().appearance, DEFAULT_APPEARANCE);
  });

  it('PATCH /v1/me requires auth', async () => {
    const res = await t.app.inject({ method: 'PATCH', url: '/v1/me', payload: { displayName: 'Hello' } });
    assert.equal(res.statusCode, 401);
  });
});
