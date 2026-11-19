/* Each complete build has an independent offline cache. */
const BUILD_VERSION = '__CQUEST_VERSION__';
const prefix = 'cquest:' + new URL(self.registration.scope).pathname + ':';
const cacheName = prefix + BUILD_VERSION;

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const manifestUrl = new URL('offline-files.json', self.registration.scope);
    const response = await fetch(manifestUrl, {cache:'no-store'});
    if (!response.ok) throw new Error('Offline manifest is unavailable.');
    const bundle = await response.json();
    if (bundle.version !== BUILD_VERSION) throw new Error('A newer build is being published. Try again.');
    const cache = await caches.open(cacheName);
    try {
      for (let i=0; i<bundle.files.length; i+=4) {
        await Promise.all(bundle.files.slice(i,i+4).map(async path => {
          const url = new URL(path, self.registration.scope);
          const asset = await fetch(url, {cache:'reload'});
          if (!asset.ok) throw new Error('Download failed: '+path);
          await cache.put(url, asset);
        }));
      }
      await cache.put(manifestUrl, new Response(JSON.stringify(bundle), {
        headers:{'Content-Type':'application/json'},
      }));
    } catch (error) {
      await caches.delete(cacheName);
      throw error;
    }
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const previous of await caches.keys()) {
      if (previous.startsWith(prefix) && previous!==cacheName) await caches.delete(previous);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.pathname === '/api/progress' || event.request.cache === 'reload') return;
  if (event.request.method!=='GET' || url.origin!==self.location.origin ||
      !url.href.startsWith(self.registration.scope)) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    const isManifest = url.href===new URL('offline-files.json',self.registration.scope).href;
    if (event.request.mode==='navigate' || isManifest) {
      try {
        return await fetch(event.request);
      } catch (_) {
        const cached = await cache.match(url,{ignoreSearch:true});
        if (cached) return cached;
        if (event.request.mode==='navigate') {
          return await cache.match(new URL('index.html',self.registration.scope));
        }
        throw new Error('Resource unavailable offline.');
      }
    }
    return await cache.match(event.request,{ignoreSearch:true}) || fetch(event.request);
  })());
});
