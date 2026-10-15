import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { bearer, createTestApp, newGuest } from './helpers.ts';
import type { TestApp } from './helpers.ts';

describe('auth', () => {
  let t: TestApp;
  before(async () => {
    t = await createTestApp();
  });
  after(async () => {
    await t.close();
  });

  it('GET /health is public', async () => {
    const res = await t.app.inject({ method: 'GET', url: '/health' });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json(), { ok: true });
  });

  it('creates a guest account with a default name and returns the secret once', async () => {
    const res = await t.app.inject({ method: 'POST', url: '/v1/auth/guest', payload: {} });
    assert.equal(res.statusCode, 200);
    const b = res.json();
    assert.match(b.playerId, /^[0-9a-f-]{36}$/);
    assert.match(b.deviceId, /^[0-9a-f-]{36}$/);
    assert.match(b.deviceSecret, /^[A-Za-z0-9_-]{43}$/); // 32 bytes base64url, no padding
    assert.match(b.sessionToken, /^[A-Za-z0-9_-]{43}$/);
    assert.match(b.profile.displayName, /^Golfer\d{4}$/);
    assert.equal(b.profile.level, 1);
    assert.equal(b.profile.xp, 0);
    assert.equal(b.profile.appearance.hat, null);
    assert.equal(b.profile.appearance.shirt, 'tee');
    const expires = Date.parse(b.expiresAt) - t.clock.now();
    assert.equal(expires, 30 * 24 * 3600 * 1000);

    // Only the scrypt hash is stored.
    const { rows } = await t.pool.query('SELECT secret_hash FROM device_credentials WHERE device_id = $1', [b.deviceId]);
    assert.ok(rows[0].secret_hash.startsWith('scrypt$'));
    assert.ok(!rows[0].secret_hash.includes(b.deviceSecret));
    const { rows: s } = await t.pool.query('SELECT token_hash FROM sessions WHERE player_id = $1', [b.playerId]);
    assert.equal(s.length, 1);
    assert.notEqual(s[0].token_hash, b.sessionToken);
  });

  it('accepts body without content (no JSON body)', async () => {
    const res = await t.app.inject({ method: 'POST', url: '/v1/auth/guest' });
    assert.equal(res.statusCode, 200);
  });

  it('honours and trims a valid displayName; rejects invalid ones', async () => {
    const ok = await t.app.inject({ method: 'POST', url: '/v1/auth/guest', payload: { displayName: '  Ace_Golfer 7 ' } });
    assert.equal(ok.statusCode, 200);
    assert.equal(ok.json().profile.displayName, 'Ace_Golfer 7');
    for (const bad of ['ab', 'x'.repeat(17), 'bad-name!', '   ']) {
      const res = await t.app.inject({ method: 'POST', url: '/v1/auth/guest', payload: { displayName: bad } });
      assert.equal(res.statusCode, 400, bad);
      assert.equal(res.json().error.code, 'bad_request');
    }
  });

  it('logs in with deviceId + deviceSecret, without returning the secret', async () => {
    const g = await newGuest(t, 'LoginTest');
    const res = await t.app.inject({
      method: 'POST',
      url: '/v1/auth/guest',
      payload: { deviceId: g.deviceId, deviceSecret: g.deviceSecret },
    });
    assert.equal(res.statusCode, 200);
    const b = res.json();
    assert.equal(b.playerId, g.playerId);
    assert.equal(b.deviceId, g.deviceId);
    assert.equal('deviceSecret' in b, false);
    assert.notEqual(b.sessionToken, g.token);
    assert.equal(b.profile.displayName, 'LoginTest');
  });

  it('rejects a wrong secret or unknown device with 401', async () => {
    const g = await newGuest(t);
    const wrong = await t.app.inject({
      method: 'POST',
      url: '/v1/auth/guest',
      payload: { deviceId: g.deviceId, deviceSecret: g.deviceSecret + 'x' },
    });
    assert.equal(wrong.statusCode, 401);
    assert.deepEqual(Object.keys(wrong.json().error).sort(), ['code', 'message']);
    assert.equal(wrong.json().error.code, 'unauthorized');
    const unknown = await t.app.inject({
      method: 'POST',
      url: '/v1/auth/guest',
      payload: { deviceId: '00000000-0000-4000-8000-000000000000', deviceSecret: 'nope' },
    });
    assert.equal(unknown.statusCode, 401);
    const missing = await t.app.inject({ method: 'POST', url: '/v1/auth/guest', payload: { deviceId: g.deviceId } });
    assert.equal(missing.statusCode, 400);
  });

  it('requires a valid session on authenticated routes', async () => {
    const none = await t.app.inject({ method: 'GET', url: '/v1/me' });
    assert.equal(none.statusCode, 401);
    assert.equal(none.json().error.code, 'unauthorized');
    const bad = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer('garbage') });
    assert.equal(bad.statusCode, 401);
    const g = await newGuest(t);
    const ok = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.equal(ok.statusCode, 200);
    assert.equal(ok.json().playerId, g.playerId);
  });

  it('logout revokes only the current session', async () => {
    const g = await newGuest(t);
    const second = await t.app.inject({
      method: 'POST',
      url: '/v1/auth/guest',
      payload: { deviceId: g.deviceId, deviceSecret: g.deviceSecret },
    });
    const token2 = second.json().sessionToken as string;
    const out = await t.app.inject({ method: 'POST', url: '/v1/auth/logout', headers: bearer(g.token) });
    assert.equal(out.statusCode, 204);
    assert.equal((await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) })).statusCode, 401);
    assert.equal((await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(token2) })).statusCode, 200);
    const again = await t.app.inject({ method: 'POST', url: '/v1/auth/logout', headers: bearer(g.token) });
    assert.equal(again.statusCode, 401);
  });

  it('sessions expire after 30 days', async () => {
    const g = await newGuest(t);
    t.clock.advance(30 * 24 * 3600 * 1000 + 1);
    const res = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
    assert.equal(res.statusCode, 401);
  });

  it('returns the error shape for unknown routes', async () => {
    const res = await t.app.inject({ method: 'GET', url: '/v1/nope' });
    assert.equal(res.statusCode, 404);
    assert.equal(res.json().error.code, 'not_found');
  });

  it('rejects malformed JSON with 400 bad_request', async () => {
    const res = await t.app.inject({
      method: 'POST',
      url: '/v1/auth/guest',
      headers: { 'content-type': 'application/json' },
      payload: '{not json',
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.json().error.code, 'bad_request');
  });
});

describe('rate limiting', () => {
  it('limits per IP with a 20 burst / 10 per second bucket and exempts /internal', async () => {
    const limited = await createTestApp({ rateLimit: { enabled: true, burst: 20, perSec: 10 } });
    try {
      const codes: number[] = [];
      for (let i = 0; i < 25; i++) {
        codes.push((await limited.app.inject({ method: 'GET', url: '/health' })).statusCode);
      }
      assert.equal(codes.filter((c) => c === 200).length, 20);
      const blocked = await limited.app.inject({ method: 'GET', url: '/health' });
      assert.equal(blocked.statusCode, 429);
      assert.equal(blocked.json().error.code, 'rate_limited');
      // Another IP has its own bucket.
      const other = await limited.app.inject({ method: 'GET', url: '/health', remoteAddress: '10.0.0.9' });
      assert.equal(other.statusCode, 200);
      // /internal is exempt (gets 401 for the missing key, not 429).
      const internal = await limited.app.inject({ method: 'POST', url: '/internal/servers/register', payload: {} });
      assert.equal(internal.statusCode, 401);
      // Refill: 10 tokens per second.
      limited.clock.advance(1000);
      let ok = 0;
      for (let i = 0; i < 12; i++) {
        if ((await limited.app.inject({ method: 'GET', url: '/health' })).statusCode === 200) ok++;
      }
      assert.equal(ok, 10);
    } finally {
      await limited.close();
    }
  });
});
