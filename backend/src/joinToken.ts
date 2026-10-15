import { createHmac, timingSafeEqual } from 'node:crypto';

/** Join token payload, see API.md §3. */
export type JoinTokenPayload = { m: string; p: string; exp: number };

export type VerifyResult =
  | { ok: true; payload: JoinTokenPayload }
  | { ok: false; reason: 'malformed' | 'bad_signature' | 'expired' };

function sign(secret: string, encodedPayload: string): string {
  return createHmac('sha256', secret).update(encodedPayload).digest('base64url');
}

/** `base64url(payloadJson) + "." + base64url(hmacSha256(secret, base64url(payloadJson)))`, no padding. */
export function signJoinToken(secret: string, payload: JoinTokenPayload): string {
  const json = JSON.stringify({ m: payload.m, p: payload.p, exp: payload.exp });
  const encoded = Buffer.from(json, 'utf8').toString('base64url');
  return `${encoded}.${sign(secret, encoded)}`;
}

export function issueJoinToken(
  secret: string,
  matchId: string,
  playerId: string,
  nowMs: number,
  ttlSec = 600,
): string {
  return signJoinToken(secret, { m: matchId, p: playerId, exp: Math.floor(nowMs / 1000) + ttlSec });
}

/** Reference verifier (mirrors what the game server does). */
export function verifyJoinToken(secret: string, token: string, nowMs: number): VerifyResult {
  const parts = token.split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return { ok: false, reason: 'malformed' };
  const encoded = parts[0];
  const expected = Buffer.from(sign(secret, encoded), 'utf8');
  const given = Buffer.from(parts[1], 'utf8');
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
    return { ok: false, reason: 'bad_signature' };
  }
  let raw: unknown;
  try {
    raw = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
  } catch {
    return { ok: false, reason: 'malformed' };
  }
  if (typeof raw !== 'object' || raw === null) return { ok: false, reason: 'malformed' };
  const p = raw as Record<string, unknown>;
  if (typeof p.m !== 'string' || typeof p.p !== 'string' || typeof p.exp !== 'number') {
    return { ok: false, reason: 'malformed' };
  }
  if (Math.floor(nowMs / 1000) >= p.exp) return { ok: false, reason: 'expired' };
  return { ok: true, payload: { m: p.m, p: p.p, exp: p.exp } };
}
