import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireSession } from '../auth/hooks.ts';
import type { AppContext } from '../context.ts';
import { badRequest, notFound, parse } from '../errors.ts';

const ReportBody = z.object({
  playerId: z.uuid(),
  matchId: z.string().min(1).max(64),
  reason: z.enum(['name', 'griefing', 'cheating', 'other']),
  note: z.string().max(280).optional(),
});

/** Player reports (API.md §1.8): stored for moderation; one per reporter, target and match. */
export async function reportRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { pool, auth } = opts.ctx;
  app.addHook('onRequest', requireSession(auth));

  app.post('/v1/reports', async (req) => {
    const body = parse(ReportBody, req.body ?? {});
    if (body.playerId === req.playerId) throw badRequest('You cannot report yourself');
    const { rowCount } = await pool.query('SELECT 1 FROM players WHERE id = $1', [body.playerId]);
    if (!rowCount) throw notFound('Player not found');
    const res = await pool.query(
      `INSERT INTO player_reports (id, reporter_id, target_id, match_id, reason, note)
       VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (reporter_id, target_id, match_id) DO NOTHING`,
      [randomUUID(), req.playerId, body.playerId, body.matchId, body.reason, body.note ?? ''],
    );
    return { ok: true, duplicate: res.rowCount === 0 };
  });
}
