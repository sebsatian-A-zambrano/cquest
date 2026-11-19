(() => {
  const localServer = ['127.0.0.1', 'localhost'].includes(location.hostname);
  const prefix = 'cquest.';
  const outbox = 'cquest.sqlite.pending';
  const keyPattern = /^(?:avatar|solved|campaign28\.solved|rpg\.(?:crossed|sound)|(?:draft\.|rpg\.world\.)(?:alg|c)-(?:[1-9]|1[0-4]))$/;
  const cache = new Map();
  const pending = new Map();
  let timer;
  let flushing = false;
  let available = false;

  try {
    for (const name of Object.keys(localStorage)) {
      if (name.startsWith(prefix) && keyPattern.test(name.slice(prefix.length))) {
        cache.set(name.slice(prefix.length), localStorage.getItem(name));
      }
    }
    for (const [key, mode] of Object.entries(JSON.parse(localStorage.getItem(outbox) || '{}'))) {
      if (cache.has(key) && (mode === 'save' || mode === 'import')) pending.set(key, mode);
    }
  } catch (_) {}

  function remember(key, value) {
    cache.set(key, value);
    try {
      localStorage.setItem(prefix + key, value);
      localStorage.setItem(prefix + 'meta.' + key, String(Date.now()));
    } catch (_) {}
  }

  function rememberQueue() {
    try { localStorage.setItem(outbox, JSON.stringify(Object.fromEntries(pending))); } catch (_) {}
  }

  function schedule(delay = 250) {
    clearTimeout(timer);
    timer = setTimeout(flush, delay);
  }

  async function flush() {
    if (!available || flushing || !pending.size) return;
    flushing = true;
    let failed = false;
    try {
      for (const [key, mode] of Array.from(pending)) {
        const value = cache.get(key);
        const body = JSON.stringify({key, value, import: mode === 'import'});
        const reply = await fetch('/api/progress', {
          method: 'PUT', headers: {'Content-Type': 'application/json'}, body,
          keepalive: new TextEncoder().encode(body).length < 60000,
          signal: AbortSignal.timeout(4500),
        });
        if (!reply.ok) throw new Error('save unavailable');
        if (cache.get(key) === value && pending.get(key) === mode) {
          pending.delete(key);
          rememberQueue();
        }
      }
    } catch (_) {
      failed = true;
    } finally {
      flushing = false;
      if (pending.size) schedule(failed ? 7000 : 0);
    }
  }

  globalThis.cquestSqliteSaveProgress = (key, value) => {
    if (!localServer || !keyPattern.test(key) || cache.get(key) === value) return;
    remember(key, value);
    pending.set(key, 'save');
    rememberQueue();
    schedule();
  };

  async function restore() {
    if (!localServer) return;
    let saved;
    try {
      const reply = await fetch('/api/progress', {cache: 'no-store', signal: AbortSignal.timeout(2200)});
      if (!reply.ok) return;
      saved = await reply.json();
      if (!saved || typeof saved !== 'object' || Array.isArray(saved)) return;
      available = true;
      for (const [key, value] of Object.entries(saved)) {
        if (!keyPattern.test(key) || typeof value !== 'string' || value.length > 130000 || pending.get(key) === 'save') continue;
        remember(key, value);
        pending.delete(key);
      }
      for (const key of cache.keys()) {
        if (!Object.hasOwn(saved, key) && !pending.has(key)) pending.set(key, 'import');
      }
      rememberQueue();
    } catch (_) {}
  }

  addEventListener('pagehide', flush);
  addEventListener('online', () => schedule(0));

  globalThis.cquestSqliteReady = restore().finally(() => schedule(0));
})();
