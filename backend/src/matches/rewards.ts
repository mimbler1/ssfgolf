/** Reward rules, API.md §2.1. Pure functions; trophy floor is applied by the caller. */

export const TROPHY_DELTAS: Readonly<Record<number, readonly number[]>> = {
  2: [20, -12],
  3: [25, 0, -12],
  4: [30, 12, -6, -16],
};

const XP_PLACEMENT_BONUS = [30, 20, 10, 0] as const;
const COIN_PLACEMENT_BONUS = [25, 15, 8, 0] as const;

function bonus(table: readonly number[], placement: number): number {
  const idx = Math.min(Math.max(placement, 1), table.length) - 1;
  return table[idx] ?? 0;
}

/** Raw trophy delta (before the floor at 0). Disconnected players get the last-place delta. */
export function trophyDelta(playerCount: number, placement: number, disconnected: boolean): number {
  const table = TROPHY_DELTAS[playerCount];
  if (!table) return 0;
  const last = table[table.length - 1] ?? 0;
  if (disconnected) return last;
  const idx = Math.min(Math.max(placement, 1), table.length) - 1;
  return table[idx] ?? last;
}

export function baseXp(placement: number, holesWon: number): number {
  return 40 + 15 * holesWon + bonus(XP_PLACEMENT_BONUS, placement);
}

export function baseCoins(placement: number, holesWon: number): number {
  return 15 + 5 * holesWon + bonus(COIN_PLACEMENT_BONUS, placement);
}

export type RewardInput = {
  ranked: boolean;
  endedReason: 'completed' | 'aborted';
  playerCount: number;
  placement: number;
  holesWon: number;
  disconnected: boolean;
};

export type Reward = { trophyDelta: number; xpGained: number; coinsGained: number };

export function computeReward(i: RewardInput): Reward {
  if (i.endedReason === 'aborted') return { trophyDelta: 0, xpGained: 0, coinsGained: 0 };
  if (!i.ranked) {
    return { trophyDelta: 0, xpGained: Math.floor(baseXp(i.placement, i.holesWon) / 2), coinsGained: 0 };
  }
  return {
    trophyDelta: trophyDelta(i.playerCount, i.placement, i.disconnected),
    xpGained: baseXp(i.placement, i.holesWon),
    coinsGained: baseCoins(i.placement, i.holesWon),
  };
}

/** Applies the floor at 0; returns the effective delta and new total. */
export function applyTrophies(current: number, rawDelta: number): { trophiesAfter: number; effectiveDelta: number } {
  const trophiesAfter = Math.max(0, current + rawDelta);
  return { trophiesAfter, effectiveDelta: trophiesAfter - current };
}
