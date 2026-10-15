import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireSession } from '../auth/hooks.ts';
import type { AppContext } from '../context.ts';
import { forbidden, notFound, parse } from '../errors.ts';
import { getMatchDetail, listMyMatches } from '../matches/results.ts';
import { AppearanceSchema, DisplayNameSchema } from './appearance.ts';
import { levelForXp } from './level.ts';
import { getPlayer, toProfile } from './repo.ts';

const PatchMeBody = z.object({
  displayName: DisplayNameSchema.optional(),
  appearance: AppearanceSchema.optional(),
});

/** `?limit=` parsing: integer >= 1, clamped to max. */
function limitQuery(def: number, max: number) {
  return z.object({
    limit: z.coerce
      .number()
      .int()
      .min(1)
      .default(def)
      .transform((n) => Math.min(n, max)),
  });
}

const UuidParam = z.object({ matchId: z.string() });
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function profileRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { pool, auth } = opts.ctx;
  app.addHook('onRequest', requireSession(auth));

  app.get('/v1/me', async (req) => {
    const row = await getPlayer(pool, req.playerId);
    if (!row) throw notFound('Player not found');
    return toProfile(row);
  });

  app.patch('/v1/me', async (req) => {
    const body = parse(PatchMeBody, req.body ?? {});
    const sets: string[] = [];
    const values: unknown[] = [req.playerId];
    if (body.displayName !== undefined) {
      values.push(body.displayName);
      sets.push(`display_name = $${values.length}`);
    }
    if (body.appearance !== undefined) {
      values.push(JSON.stringify(body.appearance));
      sets.push(`appearance = $${values.length}`);
    }
    if (sets.length) {
      values.push(new Date(opts.ctx.now()));
      sets.push(`updated_at = $${values.length}`);
      await pool.query(`UPDATE players SET ${sets.join(', ')} WHERE id = $1`, values);
    }
    const row = await getPlayer(pool, req.playerId);
    if (!row) throw notFound('Player not found');
    return toProfile(row);
  });

  app.get('/v1/me/matches', async (req) => {
    const { limit } = parse(limitQuery(20, 50), req.query ?? {});
    return { matches: await listMyMatches(pool, req.playerId, limit) };
  });

  app.get('/v1/matches/:matchId', async (req) => {
    const { matchId } = parse(UuidParam, req.params);
    if (!UUID_RE.test(matchId)) throw notFound('Match not found');
    const res = await getMatchDetail(pool, matchId, req.playerId);
    if (res.kind === 'not_found') throw notFound('Match not found or result not reported yet');
    if (res.kind === 'forbidden') throw forbidden('Only participants may read this match');
    return res.body;
  });

  app.get('/v1/leaderboard', async (req) => {
    const { limit } = parse(limitQuery(50, 100), req.query ?? {});
    const { rows } = await pool.query<{ id: string; display_name: string; trophies: number; xp: number }>(
      `SELECT id, display_name, trophies, xp FROM players
       ORDER BY trophies DESC, highest_trophies_at ASC, id ASC LIMIT $1`,
      [limit],
    );
    return {
      entries: rows.map((r, i) => ({
        rank: i + 1,
        playerId: r.id,
        displayName: r.display_name,
        trophies: r.trophies,
        level: levelForXp(r.xp),
      })),
    };
  });
}
