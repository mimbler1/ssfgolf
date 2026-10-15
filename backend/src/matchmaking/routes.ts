import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireSession } from '../auth/hooks.ts';
import type { AppContext } from '../context.ts';
import { parse } from '../errors.ts';

const QueueBody = z.object({ mode: z.literal('quick') });

export async function matchmakingRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { matchmaker, auth } = opts.ctx;
  app.addHook('onRequest', requireSession(auth));

  app.post('/v1/matchmaking/queue', async (req) => {
    parse(QueueBody, req.body ?? {});
    return matchmaker.enqueue(req.playerId);
  });

  app.get('/v1/matchmaking/status', async (req) => matchmaker.status(req.playerId));

  app.delete('/v1/matchmaking/queue', async (req, reply) => {
    matchmaker.cancel(req.playerId);
    return reply.code(204).send();
  });
}
