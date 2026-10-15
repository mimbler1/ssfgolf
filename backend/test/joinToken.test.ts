import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { describe, it } from 'node:test';
import { issueJoinToken, signJoinToken, verifyJoinToken } from '../src/joinToken.ts';

const SECRET = 'shared-secret';
const MATCH = '11111111-1111-4111-8111-111111111111';
const PLAYER = '22222222-2222-4222-8222-222222222222';

describe('join tokens', () => {
  it('uses base64url(payload).base64url(hmac) with no padding, exactly per spec', () => {
    const token = signJoinToken(SECRET, { m: MATCH, p: PLAYER, exp: 1_700_000_600 });
    const [body, sig] = token.split('.');
    assert.ok(body && sig);
    assert.ok(!token.includes('='));
    assert.deepEqual(JSON.parse(Buffer.from(body, 'base64url').toString()), { m: MATCH, p: PLAYER, exp: 1_700_000_600 });
    const expected = createHmac('sha256', SECRET).update(body).digest('base64url');
    assert.equal(sig, expected);
  });

  it('verifies a fresh token and expires it 10 minutes after issue', () => {
    const now = 1_700_000_000_000;
    const token = issueJoinToken(SECRET, MATCH, PLAYER, now);
    const ok = verifyJoinToken(SECRET, token, now);
    assert.equal(ok.ok, true);
    if (ok.ok) assert.deepEqual(ok.payload, { m: MATCH, p: PLAYER, exp: now / 1000 + 600 });
    assert.equal(verifyJoinToken(SECRET, token, now + 599_000).ok, true);
    assert.deepEqual(verifyJoinToken(SECRET, token, now + 600_000), { ok: false, reason: 'expired' });
  });

  it('rejects tampered payloads, signatures, wrong secrets and garbage', () => {
    const now = 1_700_000_000_000;
    const token = issueJoinToken(SECRET, MATCH, PLAYER, now);
    const [body, sig] = token.split('.') as [string, string];
    const forged = Buffer.from(JSON.stringify({ m: MATCH, p: '33333333-3333-4333-8333-333333333333', exp: 9_999_999_999 })).toString('base64url');
    assert.deepEqual(verifyJoinToken(SECRET, `${forged}.${sig}`, now), { ok: false, reason: 'bad_signature' });
    const flipped = sig.slice(0, -1) + (sig.endsWith('A') ? 'B' : 'A');
    assert.deepEqual(verifyJoinToken(SECRET, `${body}.${flipped}`, now), { ok: false, reason: 'bad_signature' });
    assert.deepEqual(verifyJoinToken('other-secret', token, now), { ok: false, reason: 'bad_signature' });
    assert.deepEqual(verifyJoinToken(SECRET, 'garbage', now), { ok: false, reason: 'malformed' });
    assert.deepEqual(verifyJoinToken(SECRET, `${token}.x`, now), { ok: false, reason: 'malformed' });
  });
});
