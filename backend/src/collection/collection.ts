import { randomInt, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { PoolClient } from '../db.ts';
import type { Pool, Queryable } from '../db.ts';
import { withTransaction } from '../db.ts';
import { AppError, conflict, notFound } from '../errors.ts';
import type { Appearance } from '../profile/appearance.ts';

/**
 * Cosmetic collection v1 (API.md §6). The catalog (data/catalog.json) lists every collectible:
 * sprite characters, ball colours and trail colours. Items marked `default` are owned by everyone
 * and never stored. Packs are rolled on the server with crypto randomness; duplicates refund coins.
 * Cosmetics never affect gameplay.
 */

export type Rarity = 'common' | 'rare' | 'epic' | 'legendary';
export type CatalogItem = {
  id: string;
  kind: 'character' | 'ball' | 'trail';
  value: string;
  name: string;
  rarity: Rarity;
  default: boolean;
};
export type Pack = { id: string; name: string; cost: number; items: number; guarantee?: Rarity };
export type Catalog = {
  version: number;
  rarities: Record<Rarity, { weight: number; refund: number }>;
  packs: Pack[];
  items: CatalogItem[];
};

export const RARITY_ORDER: Rarity[] = ['common', 'rare', 'epic', 'legendary'];

let cached: Catalog | null = null;

export function catalog(): Catalog {
  if (!cached) {
    const file = path.join(import.meta.dirname, '..', '..', 'data', 'catalog.json');
    cached = JSON.parse(readFileSync(file, 'utf8')) as Catalog;
  }
  return cached;
}

export function itemById(id: string): CatalogItem | undefined {
  return catalog().items.find((i) => i.id === id);
}

/** Owned item ids (defaults + stored), and copies per stored item. */
export async function ownedItems(db: Queryable, playerId: string): Promise<Map<string, number>> {
  const owned = new Map<string, number>();
  for (const i of catalog().items) if (i.default) owned.set(i.id, 1);
  const { rows } = await db.query<{ item_id: string; copies: number }>(
    'SELECT item_id, copies FROM player_items WHERE player_id = $1',
    [playerId],
  );
  for (const r of rows) owned.set(r.item_id, (owned.get(r.item_id) ?? 0) + r.copies);
  return owned;
}

/** Catalog id for an appearance field value, or undefined when the value is not a collectible. */
function idFor(kind: CatalogItem['kind'], value: string | undefined): string | undefined {
  if (!value) return undefined;
  const v = value.toLowerCase();
  return catalog().items.find((i) => i.kind === kind && i.value.toLowerCase() === v)?.id;
}

/**
 * Throws 403 when an appearance uses a collectible the player does not own. Values that are not
 * catalog items (e.g. custom colours from older clients) and values unchanged from the current
 * appearance are accepted, so existing profiles keep working.
 */
export async function assertOwnsAppearance(db: Queryable, playerId: string, next: Appearance, current: Appearance): Promise<void> {
  const owned = await ownedItems(db, playerId);
  const checks: Array<[CatalogItem['kind'], string | undefined, string | undefined]> = [
    ['character', next.character, current.character],
    ['ball', next.ballColor, current.ballColor],
    ['trail', next.trailColor, current.trailColor],
  ];
  for (const [kind, value, was] of checks) {
    const id = idFor(kind, value);
    if (!id || owned.has(id)) continue;
    if (was !== undefined && value !== undefined && was.toLowerCase() === value.toLowerCase()) continue;
    throw new AppError(403, 'not_owned', `You don't own ${itemById(id)?.name ?? id} yet`);
  }
}

/** Weighted rarity roll; `min` raises the floor (pack guarantees). */
export function rollRarity(rand: (n: number) => number, min: Rarity = 'common'): Rarity {
  const r = catalog().rarities;
  const pool = RARITY_ORDER.slice(RARITY_ORDER.indexOf(min));
  const total = pool.reduce((s, k) => s + r[k].weight, 0);
  let x = rand(total);
  for (const k of pool) {
    if (x < r[k].weight) return k;
    x -= r[k].weight;
  }
  return pool[pool.length - 1] as Rarity;
}

/** Picks an item of the rarity, preferring ones the player does not own yet. */
export function pickItem(rand: (n: number) => number, rarity: Rarity, owned: Map<string, number>): CatalogItem {
  const all = catalog().items.filter((i) => i.rarity === rarity && !i.default);
  const fresh = all.filter((i) => !owned.has(i.id));
  const from = fresh.length > 0 ? fresh : all;
  return from[rand(from.length)] as CatalogItem;
}

export type OpenResult = {
  packId: string;
  cost: number;
  refund: number;
  coins: number;
  items: Array<{ itemId: string; kind: string; value: string; name: string; rarity: Rarity; isNew: boolean; refund: number }>;
};

/** Opens a pack in one transaction: spend coins, roll, grant items, refund duplicates. */
export async function openPack(pool: Pool, playerId: string, packId: string, rand: (n: number) => number = randomInt): Promise<OpenResult> {
  const pack = catalog().packs.find((p) => p.id === packId);
  if (!pack) throw notFound('Unknown pack');
  return withTransaction(pool, async (c: PoolClient) => {
    const { rows } = await c.query<{ coins: number }>('SELECT coins FROM players WHERE id = $1 FOR UPDATE', [playerId]);
    const row = rows[0];
    if (!row) throw notFound('Player not found');
    if (row.coins < pack.cost) throw conflict(`Not enough coins (need ${pack.cost})`);
    const owned = await ownedItems(c, playerId);
    const out: OpenResult['items'] = [];
    let refund = 0;
    for (let n = 0; n < pack.items; n++) {
      const min = n === 0 && pack.guarantee ? pack.guarantee : 'common';
      const rarity = rollRarity(rand, min);
      const item = pickItem(rand, rarity, owned);
      const isNew = !owned.has(item.id);
      const back = isNew ? 0 : catalog().rarities[rarity].refund;
      refund += back;
      owned.set(item.id, (owned.get(item.id) ?? 0) + 1);
      await c.query(
        `INSERT INTO player_items (player_id, item_id) VALUES ($1, $2)
         ON CONFLICT (player_id, item_id) DO UPDATE SET copies = player_items.copies + 1`,
        [playerId, item.id],
      );
      out.push({ itemId: item.id, kind: item.kind, value: item.value, name: item.name, rarity, isNew, refund: back });
    }
    const coins = row.coins - pack.cost + refund;
    await c.query('UPDATE players SET coins = $2 WHERE id = $1', [playerId, coins]);
    await c.query(
      'INSERT INTO pack_openings (id, player_id, pack_id, cost, refund, items) VALUES ($1, $2, $3, $4, $5, $6)',
      [randomUUID(), playerId, pack.id, pack.cost, refund, JSON.stringify(out)],
    );
    return { packId: pack.id, cost: pack.cost, refund, coins, items: out };
  });
}
