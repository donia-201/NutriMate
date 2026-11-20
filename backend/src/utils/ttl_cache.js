/**
 * Small in-memory cache with expiry.
 * `wrap` also shares one in-flight request between identical callers,
 * and never caches a failed load.
 */
class TtlCache {
  constructor({ ttlMs, maxEntries = 500 }) {
    this.ttlMs = ttlMs;
    this.maxEntries = maxEntries;
    this.store = new Map();
    this.pending = new Map();
  }

  get(key) {
    const entry = this.store.get(key);
    if (!entry) return undefined;

    if (entry.expiresAt <= Date.now()) {
      this.store.delete(key);
      return undefined;
    }

    return entry.value;
  }

  set(key, value) {
    if (!this.store.has(key) && this.store.size >= this.maxEntries) {
      const oldestKey = this.store.keys().next().value;
      this.store.delete(oldestKey);
    }

    this.store.set(key, { value, expiresAt: Date.now() + this.ttlMs });
  }

  async wrap(key, loader) {
    const cached = this.get(key);
    if (cached !== undefined) return cached;

    if (this.pending.has(key)) return this.pending.get(key);

    const promise = (async () => {
      try {
        const value = await loader();
        this.set(key, value);
        return value;
      } finally {
        this.pending.delete(key);
      }
    })();

    this.pending.set(key, promise);
    return promise;
  }
}

module.exports = { TtlCache };
