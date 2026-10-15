/** XP needed to go from level n to n+1 (API.md §1.2). */
export function xpToAdvance(level: number): number {
  return 100 + 50 * (level - 1);
}

export type LevelInfo = { level: number; xpIntoLevel: number; xpForNextLevel: number };

/** `xp` is lifetime total; players start at level 1 with 0 XP. */
export function levelInfo(xp: number): LevelInfo {
  let level = 1;
  let remaining = Math.max(0, Math.floor(xp));
  while (remaining >= xpToAdvance(level)) {
    remaining -= xpToAdvance(level);
    level += 1;
  }
  return { level, xpIntoLevel: remaining, xpForNextLevel: xpToAdvance(level) };
}

export function levelForXp(xp: number): number {
  return levelInfo(xp).level;
}
