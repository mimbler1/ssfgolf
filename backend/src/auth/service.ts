import { randomInt, randomUUID } from 'node:crypto';
import type { Pool } from '../db.ts';
import { withTransaction } from '../db.ts';
import { unauthorized } from '../errors.ts';
import { DEFAULT_APPEARANCE } from '../profile/appearance.ts';
import type { PlayerRow } from '../profile/repo.ts';
import { getPlayer } from '../profile/repo.ts';
import { hashSecret, randomToken, sha256Hex, verifySecret } from './crypto.ts';

export type GuestResult = {
  player: PlayerRow;
  deviceId: string;
  deviceSecret?: string;
  sessionToken: string;
  expiresAt: Date;
};

export type AuthService = ReturnType<typeof createAuthService>;

export function createAuthService(opts: { pool: Pool; now: () => number; sessionTtlMs: number }) {
  const { pool, now, sessionTtlMs } = opts;

  async function createSession(playerId: string): Promise<{ token: string; expiresAt: Date }> {
    const token = randomToken(32);
    const createdAt = new Date(now());
    const expiresAt = new Date(createdAt.getTime() + sessionTtlMs);
    await pool.query(
      `INSERT INTO sessions (id, player_id, token_hash, created_at, expires_at) VALUES ($1, $2, $3, $4, $5)`,
      [randomUUID(), playerId, sha256Hex(token), createdAt, expiresAt],
    );
    return { token, expiresAt };
  }

  return {
    async createGuest(displayName?: string): Promise<GuestResult> {
      const playerId = randomUUID();
      const deviceId = randomUUID();
      const deviceSecret = randomToken(32);
      const secretHash = await hashSecret(deviceSecret);
      const name = displayName ?? `Golfer${String(randomInt(0, 10000)).padStart(4, '0')}`;
      const created = new Date(now());
      await withTransaction(pool, async (c) => {
        await c.query(
          `INSERT INTO players (id, display_name, appearance, created_at, updated_at, highest_trophies_at)
           VALUES ($1, $2, $3, $4, $4, $4)`,
          [playerId, name, JSON.stringify(DEFAULT_APPEARANCE), created],
        );
        await c.query(`INSERT INTO device_credentials (device_id, player_id, secret_hash) VALUES ($1, $2, $3)`, [
          deviceId,
          playerId,
          secretHash,
        ]);
      });
      const session = await createSession(playerId);
      const player = await getPlayer(pool, playerId);
      if (!player) throw new Error('player vanished after creation');
      return { player, deviceId, deviceSecret, sessionToken: session.token, expiresAt: session.expiresAt };
    },

    async loginGuest(deviceId: string, deviceSecret: string): Promise<GuestResult> {
      const { rows } = await pool.query<{ player_id: string; secret_hash: string }>(
        `SELECT player_id, secret_hash FROM device_credentials WHERE device_id = $1`,
        [deviceId],
      );
      const cred = rows[0];
      if (!cred || !(await verifySecret(deviceSecret, cred.secret_hash))) {
        throw unauthorized('Invalid device credentials');
      }
      await pool.query(`UPDATE device_credentials SET last_login_at = $2 WHERE device_id = $1`, [
        deviceId,
        new Date(now()),
      ]);
      const player = await getPlayer(pool, cred.player_id);
      if (!player) throw unauthorized('Invalid device credentials');
      const session = await createSession(player.id);
      return { player, deviceId, sessionToken: session.token, expiresAt: session.expiresAt };
    },

    /** Returns the player id for a valid, unexpired, unrevoked session token, else null. */
    async resolveSession(token: string): Promise<string | null> {
      const { rows } = await pool.query<{ player_id: string }>(
        `SELECT player_id FROM sessions WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > $2`,
        [sha256Hex(token), new Date(now())],
      );
      return rows[0]?.player_id ?? null;
    },

    async revokeSession(token: string): Promise<void> {
      await pool.query(`UPDATE sessions SET revoked_at = $2 WHERE token_hash = $1 AND revoked_at IS NULL`, [
        sha256Hex(token),
        new Date(now()),
      ]);
    },
  };
}
