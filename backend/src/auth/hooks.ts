import type { FastifyReply, FastifyRequest } from 'fastify';
import { unauthorized } from '../errors.ts';
import type { AuthService } from './service.ts';

declare module 'fastify' {
  interface FastifyRequest {
    /** Set by the auth hook on authenticated routes. */
    playerId: string;
    sessionToken: string;
  }
}

export function bearerToken(req: FastifyRequest): string | null {
  const header = req.headers.authorization;
  if (!header) return null;
  const match = /^Bearer\s+(\S+)\s*$/i.exec(header);
  return match?.[1] ?? null;
}

/** onRequest/preHandler hook that requires a valid session. */
export function requireSession(auth: AuthService) {
  return async (req: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    const token = bearerToken(req);
    if (!token) throw unauthorized('Missing bearer token');
    const playerId = await auth.resolveSession(token);
    if (!playerId) throw unauthorized('Invalid or expired session');
    req.playerId = playerId;
    req.sessionToken = token;
  };
}
