/**
 * Minimal in-memory per-key token bucket (API.md §1.6).
 * v1 limitation: per-process only; a shared store (Redis) is the scale-out path.
 */
export type RateLimiter = {
  take(key: string): boolean;
  size(): number;
};

export function createRateLimiter(opts: { burst: number; perSec: number; now: () => number }): RateLimiter {
  const buckets = new Map<string, { tokens: number; last: number }>();
  let lastPrune = opts.now();
  const fullAfterMs = (opts.burst / opts.perSec) * 1000;

  function prune(now: number) {
    // Buckets that have fully refilled carry no state; drop them.
    for (const [key, b] of buckets) {
      if (now - b.last >= fullAfterMs) buckets.delete(key);
    }
    lastPrune = now;
  }

  return {
    take(key) {
      const now = opts.now();
      if (now - lastPrune > 60_000) prune(now);
      let b = buckets.get(key);
      if (!b) {
        b = { tokens: opts.burst, last: now };
        buckets.set(key, b);
      } else {
        const elapsedSec = Math.max(0, now - b.last) / 1000;
        b.tokens = Math.min(opts.burst, b.tokens + elapsedSec * opts.perSec);
        b.last = now;
      }
      if (b.tokens >= 1) {
        b.tokens -= 1;
        return true;
      }
      return false;
    },
    size: () => buckets.size,
  };
}
