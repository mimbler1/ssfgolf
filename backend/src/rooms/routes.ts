import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireSession } from '../auth/hooks.ts';
import type { AppContext } from '../context.ts';
import { notFound, parse } from '../errors.ts';
import { idSchema } from '../profile/appearance.ts';
import { ROOM_CODE_ALPHABET, ROOM_CODE_LENGTH } from './rooms.ts';
import type { RoomSettings } from './rooms.ts';

const SettingsPatch = z.object({
  maxPlayers: z.int().min(2).max(6).optional(),
  targetPoints: z.int().min(3).max(21).optional(),
  courseId: idSchema.optional(),
});

const ReadyBody = z.object({ ready: z.boolean() });
const CodeParam = z.object({ code: z.string() });
const CODE_RE = new RegExp(`^[${ROOM_CODE_ALPHABET}]{${ROOM_CODE_LENGTH}}$`);

function settingsPatch(body: z.output<typeof SettingsPatch>): Partial<RoomSettings> {
  const out: Partial<RoomSettings> = {};
  if (body.maxPlayers !== undefined) out.maxPlayers = body.maxPlayers;
  if (body.targetPoints !== undefined) out.targetPoints = body.targetPoints;
  if (body.courseId !== undefined) out.courseId = body.courseId;
  return out;
}

export async function roomRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { rooms, auth } = opts.ctx;
  app.addHook('onRequest', requireSession(auth));

  const code = (params: unknown): string => {
    const c = parse(CodeParam, params).code.toUpperCase();
    if (!CODE_RE.test(c)) throw notFound('Room not found');
    return c;
  };

  app.post('/v1/rooms', async (req) => {
    const body = parse(SettingsPatch, req.body ?? {});
    const room = await rooms.create(req.playerId, settingsPatch(body));
    return rooms.view(room, req.playerId);
  });

  app.get('/v1/rooms/:code', async (req) => rooms.view(rooms.get(req.playerId, code(req.params)), req.playerId));

  app.post('/v1/rooms/:code/join', async (req) => {
    const room = await rooms.join(req.playerId, code(req.params));
    return rooms.view(room, req.playerId);
  });

  app.post('/v1/rooms/:code/leave', async (req, reply) => {
    rooms.leave(req.playerId, code(req.params));
    return reply.code(204).send();
  });

  app.post('/v1/rooms/:code/ready', async (req) => {
    const c = code(req.params);
    const body = parse(ReadyBody, req.body ?? {});
    return rooms.view(rooms.setReady(req.playerId, c, body.ready), req.playerId);
  });

  app.patch('/v1/rooms/:code', async (req) => {
    const c = code(req.params);
    const body = parse(SettingsPatch, req.body ?? {});
    return rooms.view(rooms.updateSettings(req.playerId, c, settingsPatch(body)), req.playerId);
  });

  app.post('/v1/rooms/:code/start', async (req) => {
    const room = await rooms.start(req.playerId, code(req.params));
    return rooms.view(room, req.playerId);
  });
}
