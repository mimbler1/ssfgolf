import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, parse } from '../errors.ts';
import { DisplayNameSchema } from '../profile/appearance.ts';
import { toProfile } from '../profile/repo.ts';
import type { AppContext } from '../context.ts';
import { requireSession } from './hooks.ts';

const GuestBody = z.object({
  deviceId: z.uuid().optional(),
  deviceSecret: z.string().min(1).max(256).optional(),
  displayName: DisplayNameSchema.optional(),
});

export async function authRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { auth } = opts.ctx;

  app.post('/v1/auth/guest', async (req) => {
    const body = parse(GuestBody, req.body ?? {});
    let result;
    if (body.deviceId === undefined) {
      if (body.deviceSecret !== undefined) throw badRequest('deviceSecret requires deviceId');
      result = await auth.createGuest(body.displayName);
      req.log.info({ playerId: result.player.id }, 'guest account created');
    } else {
      if (body.deviceSecret === undefined) throw badRequest('deviceSecret is required with deviceId');
      result = await auth.loginGuest(body.deviceId, body.deviceSecret);
      req.log.info({ playerId: result.player.id }, 'guest login');
    }
    return {
      playerId: result.player.id,
      deviceId: result.deviceId,
      ...(result.deviceSecret !== undefined ? { deviceSecret: result.deviceSecret } : {}),
      sessionToken: result.sessionToken,
      expiresAt: result.expiresAt.toISOString(),
      profile: toProfile(result.player),
    };
  });

  app.post('/v1/auth/logout', { onRequest: requireSession(auth) }, async (req, reply) => {
    await auth.revokeSession(req.sessionToken);
    return reply.code(204).send();
  });
}
