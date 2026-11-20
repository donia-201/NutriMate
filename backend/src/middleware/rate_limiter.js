/**
 * Minimal fixed-window rate limiter per client IP (in memory).
 * Protects the paid Gemini quota. For multiple server instances,
 * replace it with a shared store such as Redis.
 */
function createRateLimiter({ windowMs, max }) {
  const hits = new Map();

  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of hits) {
      if (entry.resetAt <= now) hits.delete(key);
    }
  }, windowMs);
  cleanup.unref();

  return function rateLimiter(req, res, next) {
    const key = req.ip || 'unknown';
    const now = Date.now();

    let entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(key, entry);
    }

    entry.count += 1;

    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return res.status(429).json({
        success: false,
        message: 'Too many requests. Please try again in a few minutes.',
      });
    }

    return next();
  };
}

module.exports = { createRateLimiter };
