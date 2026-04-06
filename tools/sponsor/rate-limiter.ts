// rate-limiter.ts
// In-memory rate limiter for sponsor service.
// In production: replace with Redis for multi-instance deployments.

const counts = new Map<string, { count: number; resetAt: number }>();

export async function checkRateLimit(
  key: string,
  limit: number,
  windowSeconds: number
): Promise<boolean> {
  const now = Date.now();
  const existing = counts.get(key);

  if (!existing || now > existing.resetAt) {
    counts.set(key, { count: 1, resetAt: now + windowSeconds * 1000 });
    return true;
  }

  if (existing.count >= limit) return false;

  existing.count++;
  return true;
}

// Cleanup expired entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, val] of counts.entries()) {
    if (now > val.resetAt) counts.delete(key);
  }
}, 5 * 60 * 1000);
