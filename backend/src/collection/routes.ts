import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireSession } from '../auth/hooks.ts';
import type { AppContext } from '../context.ts';
import { parse } from '../errors.ts';
import { catalog, openPack, ownedItems } from './collection.ts';

const PackParam = z.object({ packId: z.string().regex(/^[a-z0-9_]{1,32}$/) });

/** Collection routes (API.md §6): catalog, the player's collection, opening packs. */
export async function collectionRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { pool, auth } = opts.ctx;
  app.addHook('onRequest', requireSession(auth));

  app.get('/v1/catalog', async () => catalog());

  app.get('/v1/collection', async (req) => {
    const owned = await ownedItems(pool, req.playerId);
    return {
      catalogVersion: catalog().version,
      owned: [...owned.entries()].map(([itemId, copies]) => ({ itemId, copies })),
    };
  });

  app.post('/v1/packs/:packId/open', async (req) => {
    const { packId } = parse(PackParam, req.params);
    return openPack(pool, req.playerId, packId);
  });
}
